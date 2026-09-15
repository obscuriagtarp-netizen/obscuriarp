local cooldowns = {}
local activeFlights = {}
local activeFlightBoosts = {}
local activeFlightDives = {}
local activeFlightControllers = {}
local activeFlightColors = {}
local activeFlightTransformAt = {}
local flightObservers = {}
local flightObserverSentAt = {}
local channelParticipants = {}
local bleedingState = {}
local serenityTokens = {}
local wingActionAt = {}
local wingPurchaseAt = {}

local function denied(message)
    return { success = false, message = message }
end

local abilityConfig = {
    voo = function() return Config.Flight end,
    cura_vital = function() return Config.VitalHeal end,
    serenidade = function() return Config.Serenity end,
    estancar = function() return Config.StopBleeding end,
}

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

local function getClass(source)
    local player = getPlayer(source)
    local metadata = player and player.PlayerData and player.PlayerData.metadata or {}
    return tostring(metadata[Config.ClassMetadataKey] or ''):lower(), player
end

local function getPowerMultiplier(source, abilityId)
    if abilityId == 'voo' or GetResourceState('ob_boxes') ~= 'started' then return 1.0 end

    local ok, multiplier = pcall(function()
        return exports.ob_boxes:GetHealerPowerMultiplier(source, abilityId)
    end)
    return ok and math.max(1.0, tonumber(multiplier) or 1.0) or 1.0
end

local function isHealer(source)
    return getClass(source) == tostring(Config.ClassId):lower()
end

local function isPowerBlocked(source)
    local player = Player(source)
    local state = player and player.state
    return state and (
        state.obscuriaPowerBlocked == true
        or state.magicFauna == true
        or state.obHypnotized == true
        or state.obInVehicleAttachment == true
    )
end

local function isHypnotizedFlight(source)
    local player = Player(source)
    local state = player and player.state
    return state
        and state.obHypnotized == true
        and state.obHealerFlight == true
end

local function contains(values, expected)
    expected = tostring(expected or ''):lower()
    for _, value in ipairs(values or {}) do
        if tostring(value):lower() == expected then return true end
    end
    return false
end

local function permissionsAllow(source, permissions, player)
    permissions = permissions or {}
    local data = player and player.PlayerData or {}
    local metadata = data.metadata or {}
    local classId = tostring(metadata[Config.ClassMetadataKey] or ''):lower()
    local jobName = type(data.job) == 'table' and data.job.name or data.job
    local gangName = type(data.gang) == 'table' and data.gang.name or data.gang

    if contains(permissions.classes, classId) then return true end
    if contains(permissions.jobs, jobName) or contains(permissions.jobs, gangName) then return true end
    if contains(permissions.citizenids, data.citizenid) then return true end

    for _, group in ipairs(permissions.groups or {}) do
        local name = tostring(group)
        if IsPlayerAceAllowed(source, name)
            or IsPlayerAceAllowed(source, ('group.%s'):format(name)) then
            return true
        end
        if type(data.groups) == 'table' and data.groups[name] then return true end
    end

    return false
end

local function wingRule(wing)
    return (Config.WingUnlocks or {})[tonumber(wing and wing.color) or 0] or {}
end

local function wingPrice(wing)
    local currency = Config.WingMenu.runeCurrency or {}
    local rule = wingRule(wing)
    return math.max(0, math.floor(tonumber(rule.priceRunes) or tonumber(currency.defaultPrice) or 0))
end

local function callRuneExport(exportKey, source, ...)
    local currency = Config.WingMenu.runeCurrency or {}
    local resource = tostring(currency.resource or '')
    local exportName = tostring(currency[exportKey] or '')
    if resource == '' or exportName == '' or GetResourceState(resource) ~= 'started' then
        return nil
    end

    local args = { ... }
    local ok, result = pcall(function()
        local provider = exports[resource]
        return provider[exportName](provider, source, table.unpack(args))
    end)
    return ok and result or nil
end

local function getRuneBalance(source)
    local balance = callRuneExport('getExport', source)
    return balance ~= nil and math.max(0, math.floor(tonumber(balance) or 0)) or nil
end

local function removeRunes(source, amount, reason)
    return callRuneExport('removeExport', source, amount, reason) == true
end

local function refundRunes(source, amount, reason)
    return callRuneExport('addExport', source, amount, reason) == true
end

local function metadataHasWing(player, wing)
    local metadata = player and player.PlayerData and player.PlayerData.metadata or {}
    local unlocked = metadata[Config.WingMenu.unlockMetadataKey]
    if type(unlocked) ~= 'table' then return false end

    local color = tostring(wing.color)
    if unlocked[wing.id] == true or unlocked[color] == true then return true end
    for _, value in pairs(unlocked) do
        if tostring(value) == wing.id or tostring(value) == color then return true end
    end
    return false
end

local function wingAllowed(source, wing, player)
    local data = player and player.PlayerData or {}
    local metadata = data.metadata or {}
    local classId = tostring(metadata[Config.ClassMetadataKey] or ''):lower()
    if classId ~= tostring(Config.ClassId):lower() then return false end
    if metadataHasWing(player, wing) then return true end
    return permissionsAllow(source, wingRule(wing).permissions, player)
end

local function installedWingColors()
    local result = {}
    local resource = tostring(Config.WingMenu.resource or '')
    local raw = resource ~= '' and LoadResourceFile(resource, 'color_slots.json') or nil
    local ok, colors = pcall(json.decode, raw or '[]')
    if not ok or type(colors) ~= 'table' then return result end
    for _, color in ipairs(colors) do
        result[math.floor(tonumber(color) or -1)] = true
    end
    return result
end

local function wingPayload(wing, player, installed, source)
    local rule = wingRule(wing)
    local modelAvailable = installed[wing.color] == true
    local unlocked = modelAvailable and wingAllowed(source, wing, player)
    local effect = wing.effectColor or { 0.35, 0.9, 0.55 }

    return {
        id = tostring(wing.id),
        label = tostring(rule.label or wing.label or wing.id),
        description = tostring(rule.description
            or 'Uma manifestação etérea vinculada à essência de sua portadora.'),
        color = math.floor(tonumber(wing.color) or 1),
        image = tostring(wing.image or ''),
        effectColor = {
            tonumber(effect[1]) or 0.35,
            tonumber(effect[2]) or 0.9,
            tonumber(effect[3]) or 0.55,
        },
        tier = tostring(rule.tier or (modelAvailable and 'Bloqueado' or 'Em breve')),
        modelAvailable = modelAvailable,
        unlocked = unlocked,
        locked = not unlocked,
        priceRunes = wingPrice(wing),
        lockReason = modelAvailable and 'Esta asa ainda não foi desbloqueada.'
            or 'Modelo aguardando disponibilidade.',
    }
end

local function normalizedWingEffectColor(effect)
    if type(effect) ~= 'table' then return nil end
    return {
        math.max(0.0, math.min(1.0, tonumber(effect[1] or effect['1'] or effect.r) or 0.35)),
        math.max(0.0, math.min(1.0, tonumber(effect[2] or effect['2'] or effect.g) or 0.9)),
        math.max(0.0, math.min(1.0, tonumber(effect[3] or effect['3'] or effect.b) or 0.55)),
    }
end

local function setWingEffectColorState(playerState, effect)
    local key = Config.WingMenu.colorStateKey or 'obCurandeiraWingFx'
    local color = normalizedWingEffectColor(effect)

    playerState:set(key, color and ('%.4f,%.4f,%.4f'):format(color[1], color[2], color[3]) or nil, true)
    playerState:set(('%sR'):format(key), color and color[1] or nil, true)
    playerState:set(('%sG'):format(key), color and color[2] or nil, true)
    playerState:set(('%sB'):format(key), color and color[3] or nil, true)
    return color
end

local function playerWingEffectColor(source)
    local player = Player(source)
    local state = player and player.state
    local key = Config.WingMenu.colorStateKey or 'obCurandeiraWingFx'
    if state then
        local red = tonumber(state[('%sR'):format(key)])
        local green = tonumber(state[('%sG'):format(key)])
        local blue = tonumber(state[('%sB'):format(key)])
        if red and green and blue then
            return normalizedWingEffectColor({ red, green, blue })
        end

        local packed = state[key]
        if type(packed) == 'string' then
            red, green, blue = packed:match('^([^,]+),([^,]+),([^,]+)$')
            red, green, blue = tonumber(red), tonumber(green), tonumber(blue)
            if red and green and blue then
                return normalizedWingEffectColor({ red, green, blue })
            end
        elseif type(packed) == 'table' then
            local color = normalizedWingEffectColor(packed)
            if color then return color end
        end

        local selectedId = tostring(state[Config.WingMenu.selectionStateKey] or '')
        for _, wing in ipairs(Config.WingCatalogEntries or {}) do
            if tostring(wing.id) == selectedId then
                return normalizedWingEffectColor(wing.effectColor)
            end
        end
    end

    return normalizedWingEffectColor(Config.Flight.fx and Config.Flight.fx.color)
        or { 0.35, 0.9, 0.55 }
end

local function visibleWingOrder()
    local configured = Config.WingMenu.visibleColors
    if configured == 'all' then return nil, nil end

    local order = {}
    local colors = {}
    for index, color in ipairs(type(configured) == 'table' and configured or {}) do
        color = math.floor(tonumber(color) or -1)
        if color >= 0 and not colors[color] then
            colors[color] = true
            order[color] = index
        end
    end
    return colors, order
end

local function catalogWings(source)
    local _, player = getClass(source)
    if not player then return {} end
    local installed = installedWingColors()
    local visible, order = visibleWingOrder()
    local result = {}
    local catalogOrder = {}
    for index, wing in ipairs(Config.WingCatalogEntries or {}) do
        catalogOrder[wing.color] = index
        if visible == nil or visible[wing.color] then
            local payload = wingPayload(wing, player, installed, source)
            if payload.modelAvailable or Config.WingMenu.showUnavailable == true then
                result[#result + 1] = payload
            end
        end
    end

    local configuredOrder = order or catalogOrder
    table.sort(result, function(left, right)
        if left.unlocked ~= right.unlocked then
            return left.unlocked == true
        end
        return (configuredOrder[left.color] or math.huge)
            < (configuredOrder[right.color] or math.huge)
    end)

    return result
end

local function allowedWings(source)
    local result = {}
    for _, wing in ipairs(catalogWings(source)) do
        if wing.unlocked == true then result[#result + 1] = wing end
    end
    return result
end

local function findAllowedWing(source, wingId)
    wingId = tostring(wingId or '')
    for _, wing in ipairs(allowedWings(source)) do
        if wing.id == wingId then return wing end
    end
    return nil
end

local function findWingInList(wings, wingId)
    wingId = tostring(wingId or '')
    for _, wing in ipairs(wings) do
        if wing.id == wingId then return wing end
    end
    return nil
end

local function reconcileEquippedWing(playerState, allowed)
    local stateKey = Config.WingMenu.stateKey
    local selectionKey = Config.WingMenu.selectionStateKey
    local resource = Config.WingMenu.resource

    if playerState[stateKey] ~= resource then
        if playerState[selectionKey] ~= nil then
            playerState:set(selectionKey, nil, true)
            setWingEffectColorState(playerState, nil)
        end
        return nil
    end

    local wing = findWingInList(allowed, playerState[selectionKey])
    if not wing then
        local colorKey = Config.WingMenu.colorStateKey or 'obCurandeiraWingFx'
        local red = tonumber(playerState[('%sR'):format(colorKey)])
        local green = tonumber(playerState[('%sG'):format(colorKey)])
        local blue = tonumber(playerState[('%sB'):format(colorKey)])

        if red and green and blue then
            for _, candidate in ipairs(allowed) do
                local color = normalizedWingEffectColor(candidate.effectColor)
                if color
                    and math.abs(color[1] - red) < 0.001
                    and math.abs(color[2] - green) < 0.001
                    and math.abs(color[3] - blue) < 0.001 then
                    wing = candidate
                    break
                end
            end
        end
    end

    if not wing then
        for _, candidate in ipairs(allowed) do
            if candidate.color == Config.WingMenu.freeColor then
                wing = candidate
                break
            end
        end
    end

    wing = wing or allowed[1]
    if wing then
        playerState:set(selectionKey, wing.id, true)
        setWingEffectColorState(playerState, wing.effectColor)
    end
    return wing
end

local function wingActionDelay()
    return math.max(200, tonumber(Config.WingMenu.actionCooldown) or 500)
end

lib.callback.register('ob_curandeiras:server:getWingMenu', function(source)
    if Config.WingMenu.enabled == false then
        return denied('As coleções de asas estão indisponíveis.')
    end
    if not isHealer(source) then
        return denied('Somente Curandeiras conseguem abrir estas coleções.')
    end
    if isPowerBlocked(source) then
        return denied('Voce nao consegue controlar suas asas enquanto esta hipnotizada.')
    end

    local wings = catalogWings(source)
    local allowed = allowedWings(source)

    local playerState = Player(source).state
    local equippedWing = reconcileEquippedWing(playerState, allowed)
    local equippedId = equippedWing and equippedWing.id or nil
    local equippedColor = equippedWing
        and setWingEffectColorState(playerState, equippedWing.effectColor)
        or nil

    return {
        success = true,
        wings = wings,
        equippedId = equippedId,
        equippedColor = equippedColor,
        runeBalance = getRuneBalance(source) or 0,
    }
end)

lib.callback.register('ob_curandeiras:server:wingAction', function(source, action, wingId)
    if isPowerBlocked(source) then
        return denied('Voce nao consegue controlar suas asas enquanto esta hipnotizada.')
    end
    action = tostring(action or '')
    local wing = findAllowedWing(source, wingId)
    if not wing then return denied('Essa asa não pertence às suas coleções.') end

    local eventByAction = {
        open = 'abrir',
        close = 'fechar',
        flap = 'bater',
        hide = 'remove',
    }
    if action ~= 'equip' and not eventByAction[action] then
        return denied('Movimento de asa inválido.')
    end

    local resource = tostring(Config.WingMenu.resource or '')
    if resource == '' or GetResourceState(resource) ~= 'started' then
        return denied('O vínculo das asas está indisponível.')
    end
    if activeFlights[source] then
        return denied('Retorne ao solo antes de ajustar as asas.')
    end

    local playerState = Player(source).state
    local allowed = allowedWings(source)
    local equippedWing = reconcileEquippedWing(playerState, allowed)
    local minimumInterval = wingActionDelay()
    local now = GetGameTimer()
    if wingActionAt[source] and now - wingActionAt[source] < minimumInterval then
        return denied('Aguarde a asa concluir o movimento.')
    end

    if action == 'equip' then
        wingActionAt[source] = now
        playerState:set(Config.WingMenu.selectionStateKey, wing.id, true)
        local effectColor = setWingEffectColorState(playerState, wing.effectColor)
        TriggerClientEvent('ob_curandeiras:client:wingState', source, wing.id, effectColor)
        TriggerClientEvent(('%s:spawn'):format(resource), source, wing.color)
        SetTimeout(700, function()
            if not GetPlayerName(source) then return end
            local state = Player(source).state
            if state[Config.WingMenu.stateKey] == resource then
                state:set(Config.WingMenu.selectionStateKey, wing.id, true)
                TriggerClientEvent('ob_curandeiras:client:wingState', source, wing.id, effectColor)
            end
        end)
        return {
            success = true,
            message = 'Asas manifestadas.',
            settleMs = math.max(minimumInterval, 750),
        }
    end

    if not equippedWing then return denied('Manifeste uma asa primeiro.') end
    if equippedWing.id ~= wing.id then
        return denied('Selecione a asa que está manifestada.')
    end

    local eventName = eventByAction[action]
    wingActionAt[source] = now
    TriggerClientEvent(('%s:%s'):format(resource, eventName), source)
    if action == 'hide' then
        playerState:set(Config.WingMenu.selectionStateKey, nil, true)
        setWingEffectColorState(playerState, nil)
        TriggerClientEvent('ob_curandeiras:client:wingState', source, nil, nil)
        return { success = true, message = 'Asas ocultadas.', settleMs = minimumInterval }
    end

    local messages = {
        open = 'Asas abertas.',
        close = 'Asas recolhidas.',
        flap = 'Asas em movimento.',
    }
    return { success = true, message = messages[action], settleMs = minimumInterval }
end)

local function catalogWingByColor(color)
    color = math.floor(tonumber(color) or -1)
    for _, wing in ipairs(Config.WingCatalogEntries or {}) do
        if wing.color == color then return wing end
    end
    return nil
end

local function updateWingUnlock(source, color, granted)
    local player = getPlayer(source)
    local wing = catalogWingByColor(color)
    if not player or not wing then return false, 'Jogador ou asa inválida.' end

    local metadata = player.PlayerData.metadata or {}
    local current = metadata[Config.WingMenu.unlockMetadataKey]
    local unlocked = {}
    if type(current) == 'table' then
        for key, value in pairs(current) do
            if value == true then
                unlocked[tostring(key)] = true
            elseif type(value) == 'string' or type(value) == 'number' then
                unlocked[tostring(value)] = true
            end
        end
    end

    local colorKey = tostring(wing.color)
    if granted then
        unlocked[colorKey] = true
    else
        unlocked[colorKey] = nil
    end

    local metadataUpdated = false
    if GetResourceState('qbx_core') == 'started' then
        metadataUpdated = pcall(function()
            exports.qbx_core:SetMetadata(
                source,
                Config.WingMenu.unlockMetadataKey,
                unlocked
            )
        end)
    end

    if not metadataUpdated and player.Functions then
        local setter = player.Functions.SetMetaData or player.Functions.SetMetadata
        if type(setter) == 'function' then
            metadataUpdated = pcall(setter, Config.WingMenu.unlockMetadataKey, unlocked)
        end
    end

    if not metadataUpdated then
        return false, 'A persistência de metadata está indisponível.'
    end

    local saved = pcall(function()
        exports.qbx_core:Save(source)
    end)
    if not saved then
        return false, 'Não foi possível salvar a liberação no personagem.'
    end
    return true
end

lib.callback.register('ob_curandeiras:server:buyWing', function(source, wingId)
    if not isHealer(source) then
        return denied('Somente Curandeiras podem desbloquear asas.')
    end

    local now = GetGameTimer()
    if wingPurchaseAt[source] and now - wingPurchaseAt[source] < 1200 then
        return denied('Aguarde a compra anterior ser concluída.')
    end
    wingPurchaseAt[source] = now

    wingId = tostring(wingId or '')
    local wing
    for _, entry in ipairs(Config.WingCatalogEntries or {}) do
        if tostring(entry.id) == wingId then
            wing = entry
            break
        end
    end
    if not wing then return denied('Essa asa não existe nas coleções.') end

    local installed = installedWingColors()
    if installed[wing.color] ~= true then
        return denied('O modelo desta asa ainda não está disponível.')
    end

    local _, player = getClass(source)
    if not player then return denied('Personagem indisponível.') end
    if wingAllowed(source, wing, player) then
        return denied('Esta asa já pertence às suas coleções.')
    end

    local price = wingPrice(wing)
    if price <= 0 then return denied('Esta asa não possui um preço configurado.') end

    local balance = getRuneBalance(source)
    if balance == nil then
        return denied('O saldo de Runas está indisponível no momento.')
    end
    if balance < price then
        return denied(('Você precisa de %s Runas para desbloquear esta asa.'):format(price))
    end
    if not removeRunes(source, price, ('wing_unlock:%s'):format(wing.id)) then
        return denied('Não foi possível descontar as Runas.')
    end

    local updated, message = updateWingUnlock(source, wing.color, true)
    if not updated then
        updateWingUnlock(source, wing.color, false)
        refundRunes(source, price, ('wing_unlock_refund:%s'):format(wing.id))
        return denied(message or 'Não foi possível salvar a asa. Suas Runas foram devolvidas.')
    end

    return {
        success = true,
        message = ('Asa desbloqueada por %s Runas.'):format(price),
        balance = getRuneBalance(source) or (balance - price),
        tier = 'Liberada',
    }
end)

exports('GrantWing', function(source, color)
    return updateWingUnlock(source, color, true)
end)

exports('RevokeWing', function(source, color)
    return updateWingUnlock(source, color, false)
end)

exports('HasWing', function(source, color)
    local wing = catalogWingByColor(color)
    local _, player = getClass(source)
    return wing ~= nil and player ~= nil and wingAllowed(source, wing, player)
end)

local function getNearbyPlayerSources(coords, radius, bucket)
    local result = {}
    local nearby = lib.getNearbyPlayers(coords, radius) or {}

    for index = 1, #nearby do
        local target = tonumber(nearby[index].id)
        if target and (bucket == nil or GetPlayerRoutingBucket(target) == bucket) then
            result[#result + 1] = target
        end
    end

    return result
end

local function remainingCooldown(source, abilityId)
    local expiresAt = cooldowns[source] and cooldowns[source][abilityId] or 0
    return math.max(0, expiresAt - GetGameTimer())
end

local function setCooldown(source, abilityId, duration)
    cooldowns[source] = cooldowns[source] or {}
    cooldowns[source][abilityId] = GetGameTimer() + math.max(0, tonumber(duration) or 0)
end

local function clearActiveFlight(source, applyCooldown)
    local wasActive = activeFlights[source] ~= nil
    activeFlights[source] = nil
    activeFlightBoosts[source] = nil
    activeFlightDives[source] = nil
    activeFlightControllers[source] = nil
    activeFlightColors[source] = nil
    activeFlightTransformAt[source] = nil
    flightObservers[source] = nil
    flightObserverSentAt[source] = nil

    if not wasActive then return false end
    if applyCooldown then
        setCooldown(source, 'voo', Config.Flight.cooldown)
    end

    TriggerClientEvent('ob_curandeiras:client:remoteFlightFx', -1, source, false)
    TriggerClientEvent('ob_curandeiras:client:remoteFlightBoostState', -1, source, false)
    TriggerClientEvent('ob_curandeiras:client:remoteFlightDiveState', -1, source, false)
    return true
end

local function clearWingState(source, removeObject)
    local player = Player(source)
    if not player or not player.state then return end

    local state = player.state
    local resource = tostring(Config.WingMenu.resource or '')
    local stateKey = Config.WingMenu.stateKey or 'activeWingResource'
    local selectionKey = Config.WingMenu.selectionStateKey or 'obCurandeiraWing'
    local wasEquipped = state[stateKey] == resource or state[selectionKey] ~= nil
    local wasFlying = clearActiveFlight(source, true)
    if not wasEquipped and not wasFlying then return end

    TriggerClientEvent('ob_curandeiras:client:forceStopFlight', source)
    if removeObject and resource ~= '' and GetResourceState(resource) == 'started' then
        TriggerClientEvent(('%s:remove'):format(resource), source)
    end

    state:set(stateKey, nil, true)
    state:set(selectionKey, nil, true)
    setWingEffectColorState(state, nil)
    TriggerClientEvent('ob_curandeiras:client:wingState', source, nil, nil)
    TriggerClientEvent('ob_curandeiras:client:wingForcedOff', source)
end

RegisterNetEvent('ob_curandeiras:server:removeDetachedWing', function()
    clearWingState(source, true)
end)

local wingRemovedEvent = tostring(Config.WingMenu.resource or '')
if wingRemovedEvent ~= '' then
    RegisterNetEvent(('%s:sync:removed'):format(wingRemovedEvent), function()
        clearWingState(source, false)
    end)
end

local function removeEssence(source, amount)
    amount = math.max(0, tonumber(amount) or 0)
    if amount <= 0 then return true, nil end
    if GetResourceState('ob_essencias') ~= 'started' then
        return false, { reason = 'resource', value = 0, max = 0 }
    end
    local ok, result = pcall(function()
        return exports.ob_essencias:ConsumeEssencia(source, amount)
    end)
    if not ok or type(result) ~= 'table' then
        return false, { reason = 'export', value = 0, max = 0 }
    end
    return result.success == true, result
end

local function hasRequiredFlightWing(source)
    local config = Config.Flight.wing or {}
    if config.required == false then return true end

    local resource = tostring(config.resource or '')
    if resource == '' or GetResourceState(resource) ~= 'started' then
        return false
    end

    local player = Player(source)
    local stateKey = tostring(config.stateKey or 'activeWingResource')
    return player and player.state[stateKey] == resource
end

local function stopFlightFromExhaustion(source, token)
    if activeFlights[source] ~= token then return end

    activeFlights[source] = nil
    activeFlightBoosts[source] = nil
    activeFlightDives[source] = nil
    activeFlightControllers[source] = nil
    activeFlightColors[source] = nil
    activeFlightTransformAt[source] = nil
    flightObservers[source] = nil
    flightObserverSentAt[source] = nil
    setCooldown(source, 'voo', Config.Flight.cooldown)
    TriggerClientEvent('ob_curandeiras:client:remoteFlightFx', -1, source, false)
    TriggerClientEvent('ob_curandeiras:client:remoteFlightBoostState', -1, source, false)
    TriggerClientEvent('ob_curandeiras:client:remoteFlightDiveState', -1, source, false)
    TriggerClientEvent('ob_curandeiras:client:flightEssenceDepleted', source)
end

local function startFlightSustain(source, token)
    local cost = math.max(0, tonumber(Config.Flight.sustainCost) or 5)
    local interval = math.max(1000, tonumber(Config.Flight.sustainInterval) or 10000)
    if cost <= 0 then return end

    CreateThread(function()
        while activeFlights[source] == token do
            Wait(interval)
            if activeFlights[source] ~= token then return end

            local hypnotizedFlight = isHypnotizedFlight(source)
            if not isHealer(source) or (isPowerBlocked(source) and not hypnotizedFlight) then
                stopFlightFromExhaustion(source, token)
                return
            end

            if not hypnotizedFlight then
                local consumed = removeEssence(source, cost)
                if not consumed then
                    stopFlightFromExhaustion(source, token)
                    return
                end
            end
        end
    end)
end

local function authorize(source, abilityId, deferCooldown, essenceCostOverride)
    abilityId = tostring(abilityId or '')
    local factory = abilityConfig[abilityId]
    if not factory or not isHealer(source) then
        return denied('A energia vital nao reconhece esse poder.')
    end
    if isPowerBlocked(source) then
        return denied('Voce nao consegue usar habilidades enquanto esta hipnotizada.')
    end
    if abilityId == 'voo' and activeFlights[source] then
        return denied('Suas asas ja estao manifestadas.')
    end
    if abilityId == 'voo' and not hasRequiredFlightWing(source) then
        return denied('Equipe suas asas antes de tentar voar.')
    end
    local remaining = remainingCooldown(source, abilityId)
    if remaining > 0 then
        return denied(('O poder ainda se recupera (%ss).'):format(math.ceil(remaining / 1000)))
    end
    local config = factory()
    local essenceCost = essenceCostOverride ~= nil and essenceCostOverride or config.essenceCost
    local consumed, essenceState = removeEssence(source, essenceCost)
    if not consumed then
        local current = math.max(0, tonumber(essenceState and essenceState.value) or 0)
        local maximum = math.max(0, tonumber(essenceState and essenceState.max) or 0)
        return denied(('Energia insuficiente (%d/%d).'):format(current, maximum))
    end
    if abilityId == 'voo' then
        local token = GetGameTimer()
        activeFlights[source] = token
        activeFlightColors[source] = playerWingEffectColor(source)
        startFlightSustain(source, token)
    elseif not deferCooldown then
        setCooldown(source, abilityId, config.cooldown)
    end
    return { success = true }
end

lib.callback.register('ob_curandeiras:server:authorize', function(source, abilityId)
    if abilityId ~= 'voo' then return denied('Solicitacao de poder invalida.') end
    return authorize(source, abilityId, false)
end)

lib.callback.register('ob_curandeiras:server:authorizeNpc', function(source, abilityId)
    if abilityId ~= 'cura_vital' and abilityId ~= 'serenidade' and abilityId ~= 'estancar' then
        return denied('Tratamento invalido.')
    end
    return authorize(source, abilityId, false)
end)

lib.callback.register('ob_curandeiras:server:getActiveFlights', function()
    local result = {}
    for source in pairs(activeFlights) do
        if GetPlayerName(source) then
            result[#result + 1] = {
                source = source,
                controllerNetId = activeFlightControllers[source] or 0,
                effectColor = activeFlightColors[source] or playerWingEffectColor(source),
            }
        end
    end
    return result
end)

lib.callback.register('ob_curandeiras:server:getActiveFlightBoosts', function()
    local result = {}
    for source in pairs(activeFlightBoosts) do
        if activeFlights[source] and GetPlayerName(source) then
            result[#result + 1] = {
                source = source,
                effectColor = activeFlightColors[source] or playerWingEffectColor(source),
            }
        end
    end
    return result
end)

lib.callback.register('ob_curandeiras:server:getActiveFlightDives', function()
    local result = {}
    for source in pairs(activeFlightDives) do
        if activeFlights[source] and GetPlayerName(source) then
            result[#result + 1] = source
        end
    end
    return result
end)

RegisterNetEvent('ob_curandeiras:server:flightFx', function(active, controllerNetId)
    local source = source
    if active == true and activeFlights[source] and isHealer(source) then
        controllerNetId = math.max(0, math.floor(tonumber(controllerNetId) or 0))
        activeFlightControllers[source] = controllerNetId
        local effectColor = playerWingEffectColor(source)
        activeFlightColors[source] = effectColor
        TriggerClientEvent(
            'ob_curandeiras:client:remoteFlightFx',
            -1,
            source,
            true,
            controllerNetId,
            effectColor
        )
    end
end)

RegisterNetEvent('ob_curandeiras:server:flightBoostState', function(active)
    local source = source
    if not activeFlights[source] or not isHealer(source) then return end

    active = active == true
    if (activeFlightBoosts[source] == true) == active then return end

    activeFlightBoosts[source] = active or nil
    TriggerClientEvent(
        'ob_curandeiras:client:remoteFlightBoostState',
        -1,
        source,
        active,
        activeFlightColors[source] or playerWingEffectColor(source)
    )
end)

RegisterNetEvent('ob_curandeiras:server:flightDiveState', function(active)
    local source = source
    if not activeFlights[source] or not isHealer(source) then return end

    active = active == true
    if (activeFlightDives[source] == true) == active then return end

    activeFlightDives[source] = active or nil
    TriggerClientEvent(
        'ob_curandeiras:client:remoteFlightDiveState',
        -1,
        source,
        active
    )
end)

local function readTransformVector(value)
    if type(value) ~= 'table' then return nil end

    local x = tonumber(value.x)
    local y = tonumber(value.y)
    local z = tonumber(value.z)
    if not x or not y or not z then return nil end

    return vector3(x, y, z)
end

local function rebuildFlightObservers()
    local lod = Config.Flight.lod or {}
    local maximum = math.max(1, math.floor(tonumber(lod.maxCustomSyncFlights) or 8))
    local closeDistance = math.max(5.0, tonumber(lod.closeDistance) or 40.0)
    local mediumDistance = math.max(closeDistance, tonumber(lod.mediumDistance) or 90.0)
    local maximumDistance = math.max(mediumDistance, tonumber(Config.Flight.syncRange) or 160.0)
    local closeInterval = math.max(100, tonumber(lod.closeSyncInterval) or 125)
    local mediumInterval = math.max(closeInterval, tonumber(lod.mediumSyncInterval) or 250)
    local farInterval = math.max(mediumInterval, tonumber(lod.farSyncInterval) or 500)
    local activeFlightData = {}
    local nearbyPlayerData = {}
    local candidatesByTarget = {}
    local nextObservers = {}

    for source in pairs(activeFlights) do
        nextObservers[source] = {}
        local ped = GetPlayerPed(source)
        if ped ~= 0 then
            activeFlightData[source] = {
                coords = GetEntityCoords(ped),
                bucket = GetPlayerRoutingBucket(source),
            }
        end
    end

    for source, sourceData in pairs(activeFlightData) do
        local nearby = lib.getNearbyPlayers(sourceData.coords, maximumDistance) or {}
        for index = 1, #nearby do
            local target = tonumber(nearby[index].id)
            if target and target ~= source then
                local targetData = activeFlightData[target] or nearbyPlayerData[target]
                if targetData == nil then
                    local targetPed = GetPlayerPed(target)
                    targetData = targetPed ~= 0 and {
                        coords = GetEntityCoords(targetPed),
                        bucket = GetPlayerRoutingBucket(target),
                    } or false
                    nearbyPlayerData[target] = targetData
                end

                if targetData and sourceData.bucket == targetData.bucket then
                    local candidates = candidatesByTarget[target] or {}
                    candidatesByTarget[target] = candidates
                    candidates[#candidates + 1] = {
                        source = source,
                        distance = #(sourceData.coords - targetData.coords),
                    }
                end
            end
        end
    end

    for target, candidates in pairs(candidatesByTarget) do
        table.sort(candidates, function(first, second)
            return first.distance < second.distance
        end)

        for index = 1, math.min(maximum, #candidates) do
            local candidate = candidates[index]
            local interval = farInterval
            if candidate.distance <= closeDistance then
                interval = closeInterval
            elseif candidate.distance <= mediumDistance then
                interval = mediumInterval
            end

            nextObservers[candidate.source] = nextObservers[candidate.source] or {}
            nextObservers[candidate.source][target] = interval
        end
    end

    flightObservers = nextObservers
    flightObserverSentAt = {}
end

CreateThread(function()
    while true do
        if next(activeFlights) then
            rebuildFlightObservers()
            Wait(math.max(
                500,
                tonumber(Config.Flight.lod and Config.Flight.lod.refreshInterval) or 750
            ))
        else
            flightObservers = {}
            flightObserverSentAt = {}
            Wait(1500)
        end
    end
end)

RegisterNetEvent('ob_curandeiras:server:flightTransform', function(data)
    local source = source
    if not activeFlights[source] or type(data) ~= 'table' then
        return
    end

    local now = GetGameTimer()
    if activeFlightTransformAt[source] and now - activeFlightTransformAt[source] < 100 then
        return
    end

    local coords = readTransformVector(data.coords)
    local rotation = readTransformVector(data.rotation)
    local velocity = readTransformVector(data.velocity)
    if not coords or not rotation or not velocity then return end

    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - coords) > 25.0 then return end

    activeFlightTransformAt[source] = now
    local payload = {
        coords = { x = coords.x, y = coords.y, z = coords.z },
        rotation = { x = rotation.x, y = rotation.y, z = rotation.z },
        velocity = { x = velocity.x, y = velocity.y, z = velocity.z },
    }
    if flightObservers[source] == nil then
        rebuildFlightObservers()
    end
    local observers = flightObservers[source] or {}
    local sentAt = flightObserverSentAt[source] or {}
    flightObserverSentAt[source] = sentAt

    for target, interval in pairs(observers) do
        if not sentAt[target] or now - sentAt[target] >= interval then
            sentAt[target] = now
            TriggerClientEvent(
                'ob_curandeiras:client:remoteFlightTransform',
                target,
                source,
                payload
            )
        end
    end
end)

RegisterNetEvent('ob_curandeiras:server:flightEnded', function()
    local source = source
    if not activeFlights[source] then return end
    activeFlights[source] = nil
    activeFlightBoosts[source] = nil
    activeFlightDives[source] = nil
    activeFlightControllers[source] = nil
    activeFlightColors[source] = nil
    activeFlightTransformAt[source] = nil
    flightObservers[source] = nil
    flightObserverSentAt[source] = nil
    setCooldown(source, 'voo', Config.Flight.cooldown)
    TriggerClientEvent('ob_curandeiras:client:remoteFlightFx', -1, source, false)
    TriggerClientEvent('ob_curandeiras:client:remoteFlightBoostState', -1, source, false)
    TriggerClientEvent('ob_curandeiras:client:remoteFlightDiveState', -1, source, false)
end)

RegisterNetEvent('ob_curandeiras:server:flightAborted', function()
    local source = source
    local startedAt = activeFlights[source]
    if not startedAt or (GetGameTimer() - startedAt) > 5000 then return end
    activeFlights[source] = nil
    activeFlightBoosts[source] = nil
    activeFlightDives[source] = nil
    activeFlightControllers[source] = nil
    activeFlightColors[source] = nil
    activeFlightTransformAt[source] = nil
    flightObservers[source] = nil
    flightObserverSentAt[source] = nil
    TriggerClientEvent('ob_curandeiras:client:remoteFlightFx', -1, source, false)
    TriggerClientEvent('ob_curandeiras:client:remoteFlightBoostState', -1, source, false)
    TriggerClientEvent('ob_curandeiras:client:remoteFlightDiveState', -1, source, false)
end)

local function validTarget(source, targetSource, distance)
    targetSource = tonumber(targetSource)
    if not targetSource or not getPlayer(targetSource) then
        return false, 'O alvo nao esta disponivel.'
    end
    if GetPlayerRoutingBucket(source) ~= GetPlayerRoutingBucket(targetSource) then
        return false, 'O alvo nao esta no mesmo plano.'
    end
    local sourcePed, targetPed = GetPlayerPed(source), GetPlayerPed(targetSource)
    if sourcePed == 0 or targetPed == 0 then
        return false, 'O alvo nao pode receber esse tratamento.'
    end
    if targetSource ~= source
        and #(GetEntityCoords(sourcePed) - GetEntityCoords(targetPed)) > distance then
        return false, 'O alvo esta longe demais.'
    end
    return true, nil, sourcePed, targetPed
end

local function setMetadata(source, key, value)
    if not key or key == '' then return false end
    local ok = pcall(function()
        exports.qbx_core:SetMetadata(source, key, value)
    end)
    if ok then return true end
    local player = getPlayer(source)
    if player and player.Functions then
        if player.Functions.SetMetaData then
            player.Functions.SetMetaData(key, value)
            return true
        elseif player.Functions.SetMetadata then
            player.Functions.SetMetadata(key, value)
            return true
        end
    end
    return false
end

local function applyGradualHeal(targetSource, duration, fraction)
    TriggerClientEvent(
        'ob_curandeiras:client:applyGradualHeal',
        targetSource,
        math.max(1000, tonumber(duration) or 10000),
        math.max(0.0, math.min(1.0, tonumber(fraction) or 1.0))
    )
end

local function applySerenity(targetSource, restoredMana, durationMs)
    durationMs = math.max(1000, math.floor(tonumber(durationMs) or Config.Serenity.effectDuration))
    local state = Player(targetSource).state
    state:set(Config.Compatibility.stressStateKey or 'stress', 0, true)
    setMetadata(targetSource, Config.Compatibility.stressMetadataKey, 0)
    serenityTokens[targetSource] = (serenityTokens[targetSource] or 0) + 1
    local token = serenityTokens[targetSource]
    state:set('obSerene', true, true)
    state:set('obFear', false, true)
    state:set('obAnxiety', false, true)
    state:set('obExhausted', false, true)
    TriggerClientEvent(
        'ob_curandeiras:client:serenityApplied',
        targetSource,
        durationMs,
        math.max(0, math.floor(tonumber(restoredMana) or 0))
    )
    SetTimeout(durationMs, function()
        if serenityTokens[targetSource] == token and GetPlayerName(targetSource) then
            Player(targetSource).state:set('obSerene', false, true)
        end
    end)
end

local function setBleeding(targetSource, active, severity)
    active = active == true
    bleedingState[targetSource] = active and math.max(1, tonumber(severity) or 1) or nil
    if GetPlayerName(targetSource) then
        Player(targetSource).state:set('obBleeding', active, true)
        Player(targetSource).state:set('obBleedingSeverity', active and bleedingState[targetSource] or 0, true)
    end
    return true
end

exports('SetBleeding', setBleeding)
exports('IsBleeding', function(targetSource)
    return bleedingState[tonumber(targetSource)] ~= nil, bleedingState[tonumber(targetSource)] or 0
end)

local function stopBleeding(targetSource)
    setBleeding(targetSource, false, 0)
    for _, adapter in ipairs(Config.Compatibility.bleedingClientEvents or {}) do
        if adapter.value ~= nil then
            TriggerClientEvent(adapter.name, targetSource, adapter.value)
        else
            TriggerClientEvent(adapter.name, targetSource)
        end
    end
    TriggerClientEvent('ob_curandeiras:client:bleedingStopped', targetSource)
end

lib.callback.register('ob_curandeiras:server:useTargetAbility', function(source, abilityId, targetSource)
    abilityId = tostring(abilityId or '')
    if abilityId ~= 'cura_vital' and abilityId ~= 'serenidade' and abilityId ~= 'estancar' then
        return denied('Tratamento invalido.')
    end
    targetSource = tonumber(targetSource)
    if not targetSource then
        return denied('O alvo nao esta disponivel.')
    end

    local config = abilityConfig[abilityId]()
    local powerMultiplier = getPowerMultiplier(source, abilityId)
    if channelParticipants[source] or channelParticipants[targetSource] then
        return denied('Uma canalizacao ja esta em andamento.')
    end
    local valid, message, _, targetPed = validTarget(source, targetSource, config.distance + 0.75)
    if not valid then return denied(message) end
    if abilityId == 'estancar'
        and GetResourceState(Config.Compatibility.medicalResource or 'qbx_medical') ~= 'started' then
        return denied('O sistema medical esta indisponivel. Tente novamente em instantes.')
    end
    local selfSerenity = abilityId == 'serenidade' and targetSource == source
    local authorized = authorize(source, abilityId, false, selfSerenity and 0 or nil)
    if not authorized.success then return authorized end

    local channelDuration = math.max(800, config.channelDuration)
    local fxDuration = channelDuration
    local fxKind = 'heal'
    if abilityId == 'cura_vital' then
        fxDuration = fxDuration + math.max(1000, math.floor(Config.VitalHeal.healDuration / powerMultiplier))
    elseif abilityId == 'serenidade' then
        fxKind = 'serenity'
        fxDuration = fxDuration + math.min(
            math.max(0, (tonumber(Config.Serenity.effectDuration) or 30000) * powerMultiplier),
            10000
        )
    else
        fxKind = 'bleeding'
        fxDuration = fxDuration + math.max(
            0,
            tonumber(Config.StopBleeding.effectDuration) or 6000
        )
    end

    channelParticipants[source] = true
    channelParticipants[targetSource] = true
    local netId = NetworkGetNetworkIdFromEntity(targetPed)
    local targetCoords = GetEntityCoords(targetPed)
    local targetBucket = GetPlayerRoutingBucket(targetSource)
    local fxRange = math.max(10.0, tonumber(Config.TreatmentFx.syncRange) or 80.0)
    local targetReceivedFx = false
    for _, observer in ipairs(getNearbyPlayerSources(targetCoords, fxRange, targetBucket)) do
        targetReceivedFx = targetReceivedFx or observer == targetSource
        TriggerClientEvent(
            'ob_curandeiras:client:targetFx',
            observer,
            netId,
            fxKind,
            fxDuration,
            targetSource
        )
    end
    if not targetReceivedFx then
        TriggerClientEvent(
            'ob_curandeiras:client:targetFx',
            targetSource,
            netId,
            fxKind,
            fxDuration,
            targetSource
        )
    end

    SetTimeout(channelDuration, function()
        channelParticipants[source] = nil
        channelParticipants[targetSource] = nil
        if isPowerBlocked(source) then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Canalizacao interrompida',
                description = 'A hipnose rompeu sua concentracao.',
                type = 'error',
            })
            return
        end
        local stillValid = validTarget(source, targetSource, config.distance + 2.0)
        if not stillValid then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Canalizacao interrompida',
                description = 'O alvo saiu do alcance antes do tratamento terminar.',
                type = 'error',
            })
            return
        end

        if abilityId == 'cura_vital' then
            applyGradualHeal(
                targetSource,
                math.max(1000, math.floor(Config.VitalHeal.healDuration / powerMultiplier)),
                math.min(1.0, Config.VitalHeal.healFraction * powerMultiplier)
            )
        elseif abilityId == 'serenidade' then
            local restoredMana = 0
            if targetSource == source and GetResourceState('ob_essencias') == 'started' then
                local restoreAmount = math.max(0, math.floor((tonumber(Config.Serenity.selfManaRestore) or 20) * powerMultiplier + 0.5))
                local before, maximum = exports.ob_essencias:GetEssencia(source)
                if restoreAmount > 0 and exports.ob_essencias:AddEssencia(source, restoreAmount) == true then
                    local after = exports.ob_essencias:GetEssencia(source)
                    restoredMana = math.max(0, math.min(tonumber(maximum) or 0, tonumber(after) or 0) - (tonumber(before) or 0))
                end
            end
            applySerenity(targetSource, restoredMana, Config.Serenity.effectDuration * powerMultiplier)
        else
            stopBleeding(targetSource)
            applyGradualHeal(
                targetSource,
                math.max(1000, math.floor(Config.StopBleeding.healDuration / powerMultiplier)),
                math.min(1.0, Config.StopBleeding.healFraction * powerMultiplier)
            )
        end
    end)

    return { success = true }
end)

AddEventHandler('playerDropped', function()
    local source = source
    if activeFlights[source] then
        TriggerClientEvent('ob_curandeiras:client:remoteFlightFx', -1, source, false)
        TriggerClientEvent('ob_curandeiras:client:remoteFlightBoostState', -1, source, false)
        TriggerClientEvent('ob_curandeiras:client:remoteFlightDiveState', -1, source, false)
    end
    activeFlights[source] = nil
    activeFlightBoosts[source] = nil
    activeFlightDives[source] = nil
    activeFlightControllers[source] = nil
    activeFlightColors[source] = nil
    activeFlightTransformAt[source] = nil
    flightObservers[source] = nil
    flightObserverSentAt[source] = nil
    for _, observers in pairs(flightObservers) do
        observers[source] = nil
    end
    cooldowns[source] = nil
    channelParticipants[source] = nil
    bleedingState[source] = nil
    serenityTokens[source] = nil
    wingActionAt[source] = nil
    wingPurchaseAt[source] = nil
end)
