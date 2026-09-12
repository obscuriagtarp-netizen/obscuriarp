local cooldowns = {}
local activeBatForms = {}
local activeShadowSteps = {}
local shadowSmokeRateLimits = {}
local batTransformationFxRateLimits = {}
local embraceApproachFxRateLimits = {}
local pendingHypnosisCasts = {}
local activeHypnosisTargets = {}
local embraceParticipants = {}
local activePumaEmbraces = {}
local pumaEmbraceLocks = {}
local activePumaHarvests = {}
local pumaHarvestLocks = {}
local batSequence = 0
local shadowStepSequence = 0
local hypnosisSequence = 0
local hypnosisStateSequence = 0
local pumaEmbraceSequence = 0
local pumaHarvestSequence = 0

local abilityConfig = {
    passo_sombrio = function() return Config.ShadowStep end,
    forma_morcego = function() return Config.BatForm end,
    hipnose = function() return Config.Hypnosis end,
    abraco_noite = function() return Config.NightEmbrace end,
}

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

local function getClass(source)
    local player = getPlayer(source)
    local metadata = player and player.PlayerData and player.PlayerData.metadata or {}
    return tostring(metadata[Config.ClassMetadataKey] or ''):lower(), player
end

local function isVampire(source)
    return getClass(source) == tostring(Config.ClassId):lower()
end

local function isSolarWeakened(source)
    local player = Player(source)
    local state = player and player.state
    return Config.SolarWeakness and Config.SolarWeakness.enabled ~= false
        and state and state.obSunWeakened == true or false
end

local function scaledAbilityValue(value, multiplier)
    value = math.max(0, tonumber(value) or 0)
    multiplier = math.max(0, tonumber(multiplier) or 1.0)
    return math.max(0, math.floor((value * multiplier) + 0.5))
end

local function getBatSustainCost(source, config)
    local cost = math.max(1, tonumber(config.sustainCost) or 1)
    if isSolarWeakened(source) then
        local solar = Config.SolarWeakness and Config.SolarWeakness.batForm or {}
        cost = cost * math.max(1.0, tonumber(solar.sustainCostMultiplier) or 4.0)
    end
    return math.max(1, math.ceil(cost))
end

local function isPowerBlocked(source)
    local player = Player(source)
    local state = player and player.state
    return state and (
        state.obscuriaPowerBlocked == true
        or state.magicFauna == true
        or state.obHypnotized == true
        or state.obInVehicleAttachment == true
        or state.obVampireHarvesting == true
    )
end

local function isBatFormInterrupted(source)
    local player = Player(source)
    local state = player and player.state
    if not state then return false end

    return state.magicFauna == true
        or state.obHypnotized == true
        or state.obInVehicleAttachment == true
end

local function applyHypnosisState(targetSource, duration)
    targetSource = tonumber(targetSource)
    local player = targetSource and Player(targetSource)
    if not player then return end

    hypnosisStateSequence = hypnosisStateSequence + 1
    local token = hypnosisStateSequence
    activeHypnosisTargets[targetSource] = token
    player.state:set('obHypnotized', true, true)

    SetTimeout(duration, function()
        if activeHypnosisTargets[targetSource] ~= token then return end
        activeHypnosisTargets[targetSource] = nil
        if GetPlayerName(targetSource) then
            Player(targetSource).state:set('obHypnotized', false, true)
        end
    end)
end

local function getNearbyPlayerSources(coords, radius, excludedSource, bucket)
    local result = {}
    local nearby = lib.getNearbyPlayers(coords, radius) or {}

    for index = 1, #nearby do
        local target = tonumber(nearby[index].id)
        if target and target ~= excludedSource
            and (bucket == nil or GetPlayerRoutingBucket(target) == bucket) then
            result[#result + 1] = target
        end
    end

    return result
end

local function notifyDenied(source, message)
    return {
        success = false,
        message = message,
    }
end

local function remainingCooldown(source, abilityId)
    local expiresAt = cooldowns[source] and cooldowns[source][abilityId] or 0
    return math.max(0, expiresAt - GetGameTimer())
end

local function setCooldown(source, abilityId, duration)
    cooldowns[source] = cooldowns[source] or {}
    cooldowns[source][abilityId] = GetGameTimer() + math.max(0, tonumber(duration) or 0)
end

local function armShadowStepTimeout(source, token, delay)
    SetTimeout(delay, function()
        local active = activeShadowSteps[source]
        if active and active.token == token and GetGameTimer() > active.expiresAt then
            activeShadowSteps[source] = nil
            setCooldown(source, 'passo_sombrio', Config.ShadowStep.cooldown)
        end
    end)
end

local function armBatFormTimeout(source, token, delay)
    SetTimeout(delay, function()
        local active = activeBatForms[source]
        if active and active.token == token and GetGameTimer() > active.expiresAt then
            activeBatForms[source] = nil
            setCooldown(source, 'forma_morcego', Config.BatForm.returnCooldown)
        end
    end)
end

local function removeEssence(source, amount)
    amount = math.max(0, tonumber(amount) or 0)
    if amount <= 0 then
        return true, nil
    end

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

local function hasEssence(source, amount)
    if GetResourceState('ob_essencias') ~= 'started' then
        return false
    end

    local ok, snapshot = pcall(function()
        return exports.ob_essencias:GetEssenciaSnapshot(source)
    end)
    return ok and type(snapshot) == 'table' and snapshot.success == true
        and (tonumber(snapshot.value) or 0) >= math.max(0, tonumber(amount) or 0)
end

local function addEssence(source, amount)
    if GetResourceState('ob_essencias') ~= 'started' then return false end
    amount = math.max(0, math.floor((tonumber(amount) or 0) + 0.5))
    if amount <= 0 then return true end

    local snapshotOk, before = pcall(function()
        return exports.ob_essencias:GetEssenciaSnapshot(source)
    end)
    if not snapshotOk or type(before) ~= 'table' or before.success ~= true then return false end

    local target = math.min(tonumber(before.max) or 100, (tonumber(before.value) or 0) + amount)
    if target <= (tonumber(before.value) or 0) then return true end

    pcall(function()
        exports.ob_essencias:AddEssencia(source, amount)
    end)

    local afterOk, after = pcall(function()
        return exports.ob_essencias:GetEssenciaSnapshot(source)
    end)
    if afterOk and type(after) == 'table' and (tonumber(after.value) or 0) >= target then
        TriggerClientEvent('ob_essencias:client:update', source, after)
        return true
    end

    pcall(function()
        return exports.ob_essencias:SetEssencia(source, target)
    end)

    local finalOk, final = pcall(function()
        return exports.ob_essencias:GetEssenciaSnapshot(source)
    end)
    if finalOk and type(final) == 'table' and final.success == true then
        TriggerClientEvent('ob_essencias:client:update', source, final)
        if (tonumber(final.value) or 0) >= target then return true end
    end

    local player = getPlayer(source)
    local key = tostring(before.key or 'sangue')
    local updated = false
    if player and player.Functions then
        local setter = player.Functions.SetMetaData or player.Functions.SetMetadata
        if setter then
            local ok, result = pcall(function()
                return setter(key, target)
            end)
            updated = ok and result ~= false
        end
    end
    if updated then
        local payload = {
            success = true,
            class = before.class,
            key = key,
            maxKey = before.maxKey,
            label = before.label,
            value = target,
            max = tonumber(before.max) or 100,
        }
        local statePlayer = Player(source)
        if statePlayer and statePlayer.state then
            statePlayer.state:set('essencia', target, true)
            statePlayer.state:set('essenciaMax', payload.max, true)
            statePlayer.state:set('essenciaKey', key, true)
        end
        TriggerClientEvent('ob_essencias:client:update', source, payload)
        return true
    end
    return false
end

local function distributedChunk(total, index, ticks)
    total = math.max(0, math.floor((tonumber(total) or 0) + 0.5))
    ticks = math.max(1, math.floor(tonumber(ticks) or 1))
    index = math.max(1, math.min(ticks, math.floor(tonumber(index) or 1)))
    return math.floor(total * index / ticks) - math.floor(total * (index - 1) / ticks)
end

local function embraceApproachDuration(distance)
    local bite = Config.NightEmbrace.biteAnimation or {}
    local approach = bite.approach or {}
    local minimum = math.max(0, tonumber(approach.minimumDuration) or 320)
    local maximum = math.max(minimum, tonumber(approach.maximumDuration) or 900)

    if distance then
        local speed = math.max(1.0, tonumber(approach.speed) or 18.0)
        return math.floor(math.min(maximum, math.max(minimum, distance / speed * 1000.0)))
    end
    return maximum
end

local function embracePreludeDuration(approachDuration)
    local bite = Config.NightEmbrace.biteAnimation or {}
    return math.max(0, tonumber(approachDuration) or embraceApproachDuration())
        + math.max(0, tonumber(bite.alignmentDelay) or 250)
end

local function grantDrainReward(source, healthAmount, essenceAmount)
    if essenceAmount > 0 then
        addEssence(source, essenceAmount)
    end
    if healthAmount > 0 then
        TriggerClientEvent('ob_vampiros:client:applyDrainHeal', source, healthAmount)
    end
end

local function authorize(source, abilityId, deferCooldown)
    abilityId = tostring(abilityId or '')
    local configFactory = abilityConfig[abilityId]
    if not configFactory or not isVampire(source) then
        return notifyDenied(source, 'Seu sangue nao responde a esse poder.')
    end
    if isPowerBlocked(source) then
        return notifyDenied(source, 'Voce nao consegue usar poderes neste estado.')
    end

    if abilityId == 'forma_morcego' and activeBatForms[source] then
        return notifyDenied(source, 'Voce ja esta na forma de morcego.')
    end

    local remaining = remainingCooldown(source, abilityId)
    if remaining > 0 then
        return notifyDenied(source, ('O poder ainda se recupera (%ss).'):format(math.ceil(remaining / 1000)))
    end

    local config = configFactory()
    if abilityId == 'forma_morcego' then
        local sustainCost = getBatSustainCost(source, config)
        if not hasEssence(source, sustainCost) then
            return notifyDenied(source, 'Essencia de sangue insuficiente.')
        end

        local now = GetGameTimer()
        local interval = math.max(1000, tonumber(config.sustainInterval) or 8000)
        local grace = math.max(1000, tonumber(config.sustainGrace) or 3000)
        batSequence = batSequence + 1
        local token = batSequence
        activeBatForms[source] = {
            token = token,
            nextChargeAt = now + interval,
            expiresAt = now + interval + grace,
        }
        armBatFormTimeout(source, token, interval + grace + 250)
        return { success = true }
    end

    if abilityId == 'passo_sombrio' then
        local active = activeShadowSteps[source]
        if active then
            return notifyDenied(source, 'O Passo Sombrio ja esta ativo.')
        end

        local sustainCost = math.max(1, tonumber(config.sustainCost) or 2)
        if not hasEssence(source, sustainCost) then
            return notifyDenied(source, 'Essencia de sangue insuficiente.')
        end

        local now = GetGameTimer()
        local interval = math.max(1000, tonumber(config.sustainInterval) or 5000)
        local grace = math.max(1000, tonumber(config.sustainGrace) or 3000)
        shadowStepSequence = shadowStepSequence + 1
        local token = shadowStepSequence
        activeShadowSteps[source] = {
            token = token,
            nextChargeAt = now + interval,
            expiresAt = now + interval + grace,
        }
        armShadowStepTimeout(source, token, interval + grace + 250)
        return { success = true }
    end

    if abilityId == 'abraco_noite' then
        if not deferCooldown then
            setCooldown(source, abilityId, config.cooldown)
        end
        return { success = true }
    end

    local consumed, essenceState = removeEssence(source, config.essenceCost)
    if not consumed then
        local current = math.max(0, tonumber(essenceState and essenceState.value) or 0)
        local maximum = math.max(0, tonumber(essenceState and essenceState.max) or 0)
        return notifyDenied(source, ('Essencia de sangue insuficiente (%d/%d).'):format(current, maximum))
    end

    if not deferCooldown then
        setCooldown(source, abilityId, config.cooldown)
    end

    return { success = true }
end

local function pumaFarmConfig()
    return Config.PumaFarm or {}
end

local function inventoryCount(source, itemName)
    if GetResourceState('ox_inventory') ~= 'started' then return nil end
    local ok, count = pcall(function()
        return exports.ox_inventory:Search(source, 'count', itemName)
    end)
    return ok and math.max(0, math.floor(tonumber(count) or 0)) or nil
end

local function collectionRequirement()
    local collection = pumaFarmConfig().collection or {}
    local item = tostring(collection.requiredItem or '')
    if item == '' then return nil end
    return {
        item = item,
        label = tostring(collection.requiredItemLabel or item),
        amount = math.max(1, math.floor(tonumber(collection.requiredAmount) or 1)),
        consume = collection.consumeRequiredItem ~= false,
    }
end

local function pumaEssenceRoom(source)
    if GetResourceState('ob_essencias') ~= 'started' then
        return nil, 'O fluxo da essencia esta indisponivel.'
    end

    local ok, snapshot = pcall(function()
        return exports.ob_essencias:GetEssenciaSnapshot(source)
    end)
    if not ok or type(snapshot) ~= 'table' or snapshot.success ~= true then
        return nil, 'Nao foi possivel consultar sua essencia de sangue.'
    end

    local current = math.max(0, tonumber(snapshot.value) or 0)
    local maximum = math.max(current, tonumber(snapshot.max) or 100)
    return math.max(0, maximum - current)
end

local function isPumaModel(model)
    for _, configuredModel in ipairs(pumaFarmConfig().models or {}) do
        local hash = type(configuredModel) == 'number' and configuredModel or joaat(configuredModel)
        if model == hash then return true end
    end
    return false
end

local function clearPumaHarvest(source, expectedToken)
    local session = activePumaHarvests[source]
    if not session or expectedToken and session.token ~= expectedToken then return end

    activePumaHarvests[source] = nil
    if pumaHarvestLocks[session.netId] == session.token then
        pumaHarvestLocks[session.netId] = nil
    end

    if session.entity and DoesEntityExist(session.entity) then
        local state = Entity(session.entity).state
        if tonumber(state.obVampireHarvester) == source then
            state:set('obVampireHarvester', false, true)
        end
    end

    if GetPlayerName(source) then
        Player(source).state:set('obVampireHarvesting', false, true)
    end
end

local function validatePumaCarcass(source, netId)
    local playerPed = GetPlayerPed(source)
    if playerPed <= 0 or GetEntityHealth(playerPed) <= 0 then
        return nil, 'Voce precisa estar vivo para coletar o sangue.'
    end

    netId = math.floor(tonumber(netId) or 0)
    if netId <= 0 then return nil, 'Esta carcaca nao pode ser identificada.' end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity <= 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 1
        or not isPumaModel(GetEntityModel(entity)) then
        return nil, 'Este animal nao e uma fonte valida de sangue.'
    end
    if GetEntityHealth(entity) > 0 then
        return nil, 'O puma ainda esta vivo.'
    end

    local maxDistance = math.max(1.0, tonumber(pumaFarmConfig().serverDistance) or 4.0)
    if #(GetEntityCoords(playerPed) - GetEntityCoords(entity)) > maxDistance then
        return nil, 'Voce se afastou demais da carcaca.'
    end

    local state = Entity(entity).state
    if state.obVampireFarmPuma ~= true then
        return nil, 'Este puma nao pertence ao ponto de caca.'
    end
    if state.obVampireEmbracer then
        return nil, 'Outro vampiro ainda esta drenando esta onca.'
    end
    if GetEntityRoutingBucket(entity) ~= GetPlayerRoutingBucket(source) then
        return nil, 'Esta carcaca nao esta no mesmo plano.'
    end
    if state.obVampireHarvested == true then
        return nil, 'Esta carcaca ja foi drenada.'
    end
    return entity
end

local function rollPumaRewards()
    local rewards = {}
    for _, entry in ipairs(pumaFarmConfig().rewards or {}) do
        local chance = math.max(0, math.min(100, tonumber(entry.chance) or 100))
        if math.random(1, 10000) <= math.floor(chance * 100) then
            local minimum = math.max(1, math.floor(tonumber(entry.min) or 1))
            local maximum = math.max(minimum, math.floor(tonumber(entry.max) or minimum))
            rewards[#rewards + 1] = {
                item = tostring(entry.item or ''),
                label = tostring(entry.label or entry.item or 'Item'),
                amount = math.random(minimum, maximum),
            }
        end
    end
    return rewards
end

local function givePumaRewards(source, rewards, requirement)
    if GetResourceState('ox_inventory') ~= 'started' then
        return false, 'Inventario indisponivel.'
    end
    if #rewards == 0 then return false, 'As recompensas do farm nao foram configuradas.' end

    local requirementRemoved = false
    if requirement then
        local count = inventoryCount(source, requirement.item)
        if count == nil then return false, 'Inventario indisponivel.' end
        if count < requirement.amount then
            return false, ('Voce precisa de %dx %s para recolher o sangue.'):format(requirement.amount, requirement.label)
        end

        if requirement.consume then
            local removeOk, removed = pcall(function()
                return exports.ox_inventory:RemoveItem(source, requirement.item, requirement.amount)
            end)
            if not removeOk or removed ~= true then
                return false, ('Nao foi possivel utilizar o %s.'):format(requirement.label)
            end
            requirementRemoved = true
        end
    end

    local function restoreRequirement()
        if not requirementRemoved then return end
        local restoredOk, restored = pcall(function()
            return exports.ox_inventory:AddItem(source, requirement.item, requirement.amount)
        end)
        if not restoredOk or restored ~= true then
            print(('[ob_vampiros] Falha ao devolver %dx %s ao ID %s.'):format(
                requirement.amount, requirement.item, source
            ))
        end
        requirementRemoved = false
    end

    local added = {}
    for _, reward in ipairs(rewards) do
        local canCarryOk, canCarry = pcall(function()
            return exports.ox_inventory:CanCarryItem(source, reward.item, reward.amount)
        end)
        if not canCarryOk or canCarry ~= true then
            restoreRequirement()
            return false, 'Nao ha espaco suficiente no inventario.'
        end
    end

    for _, reward in ipairs(rewards) do
        local callOk, success = pcall(function()
            return exports.ox_inventory:AddItem(source, reward.item, reward.amount)
        end)
        if not callOk or success ~= true then
            for _, previous in ipairs(added) do
                pcall(function()
                    exports.ox_inventory:RemoveItem(source, previous.item, previous.amount)
                end)
            end
            restoreRequirement()
            return false, 'Nao foi possivel guardar os itens coletados.'
        end
        added[#added + 1] = reward
    end
    return true
end

lib.callback.register('ob_vampiros:server:beginPumaHarvest', function(source, netId, mode)
    local config = pumaFarmConfig()
    mode = tostring(mode or '')
    if config.enabled ~= true then return notifyDenied(source, 'A coleta de pumas esta indisponivel.') end
    if mode ~= 'collect' and mode ~= 'feed' then return notifyDenied(source, 'Acao de coleta invalida.') end
    if not isVampire(source) then return notifyDenied(source, 'Apenas vampiros conseguem extrair este sangue.') end
    if isPowerBlocked(source) then return notifyDenied(source, 'Voce nao consegue se alimentar neste estado.') end
    if activePumaHarvests[source] then return notifyDenied(source, 'Voce ja esta drenando uma carcaca.') end

    if mode == 'collect' then
        local requirement = collectionRequirement()
        if requirement then
            local count = inventoryCount(source, requirement.item)
            if count == nil then return notifyDenied(source, 'Inventario indisponivel.') end
            if count < requirement.amount then
                return notifyDenied(source, ('Voce precisa de %dx %s para recolher o sangue.'):format(
                    requirement.amount, requirement.label
                ))
            end
        end
    else
        local room, reason = pumaEssenceRoom(source)
        if room == nil then return notifyDenied(source, reason) end
        if room <= 0 then return notifyDenied(source, 'Sua essencia de sangue ja esta completa.') end
    end

    local entity, reason = validatePumaCarcass(source, netId)
    if not entity then return notifyDenied(source, reason) end

    netId = math.floor(tonumber(netId))
    if pumaHarvestLocks[netId] then return notifyDenied(source, 'Outro vampiro ja esta drenando esta carcaca.') end
    local entityState = Entity(entity).state
    if entityState.obVampireHarvester then return notifyDenied(source, 'Outro vampiro ja esta drenando esta carcaca.') end

    pumaHarvestSequence = pumaHarvestSequence + 1
    local token = pumaHarvestSequence
    local duration = math.max(2500, math.floor(tonumber(config.actionDuration) or 8000))
    local timeout = math.max(duration + 3000, math.floor(tonumber(config.lockTimeout) or 16000))
    activePumaHarvests[source] = {
        token = token,
        netId = netId,
        entity = entity,
        startedAt = GetGameTimer(),
        duration = duration,
        mode = mode,
    }
    pumaHarvestLocks[netId] = token
    entityState:set('obVampireHarvester', source, true)
    Player(source).state:set('obVampireHarvesting', true, true)

    SetTimeout(timeout, function()
        clearPumaHarvest(source, token)
    end)
    return { success = true, token = token, duration = duration }
end)

lib.callback.register('ob_vampiros:server:finishPumaHarvest', function(source, token, netId)
    local session = activePumaHarvests[source]
    token = math.floor(tonumber(token) or 0)
    netId = math.floor(tonumber(netId) or 0)
    if not session or session.token ~= token or session.netId ~= netId
        or pumaHarvestLocks[netId] ~= token then
        return notifyDenied(source, 'Esta coleta nao e mais valida.')
    end

    local function fail(message)
        clearPumaHarvest(source, token)
        return notifyDenied(source, message)
    end
    if GetGameTimer() - session.startedAt < session.duration - 500 then
        return fail('A coleta foi interrompida antes de terminar.')
    end
    if not isVampire(source) then return fail('Sua natureza vampirica nao foi confirmada.') end

    local state = Player(source).state
    if state.magicFauna == true or state.obHypnotized == true or state.obInVehicleAttachment == true then
        return fail('A coleta foi interrompida pelo seu estado atual.')
    end

    local entity, reason = validatePumaCarcass(source, netId)
    if not entity or entity ~= session.entity then return fail(reason or 'A carcaca nao esta mais disponivel.') end

    local rewards = {}
    local essenceGain = 0
    if session.mode == 'collect' then
        rewards = rollPumaRewards()
        local delivered, deliveryError = givePumaRewards(source, rewards, collectionRequirement())
        if not delivered then return fail(deliveryError) end
    else
        local room, reason = pumaEssenceRoom(source)
        if room == nil then return fail(reason) end
        essenceGain = math.min(
            room,
            math.max(1, math.floor(tonumber((pumaFarmConfig().feeding or {}).essenceGain) or 30))
        )
        if essenceGain <= 0 then return fail('Sua essencia de sangue ja esta completa.') end
        if not addEssence(source, essenceGain) then
            return fail('Nao foi possivel absorver a essencia desta carcaca.')
        end
    end

    Entity(entity).state:set('obVampireHarvestMode', session.mode, true)
    Entity(entity).state:set('obVampireHarvested', true, true)
    clearPumaHarvest(source, token)

    local cleanupDelay = math.max(0, math.floor(tonumber(pumaFarmConfig().cleanupDelay) or 45000))
    if cleanupDelay > 0 then
        SetTimeout(cleanupDelay, function()
            if DoesEntityExist(entity) and Entity(entity).state.obVampireHarvested == true then
                DeleteEntity(entity)
            end
        end)
    end
    return {
        success = true,
        mode = session.mode,
        rewards = rewards,
        essenceGain = essenceGain,
    }
end)

RegisterNetEvent('ob_vampiros:server:cancelPumaHarvest', function(token)
    clearPumaHarvest(source, math.floor(tonumber(token) or 0))
end)

lib.callback.register('ob_vampiros:server:authorize', function(source, abilityId)
    if abilityId ~= 'passo_sombrio' and abilityId ~= 'forma_morcego' then
        return notifyDenied(source, 'Solicitacao de poder invalida.')
    end
    return authorize(source, abilityId, false)
end)

lib.callback.register('ob_vampiros:server:sustainShadowStep', function(source)
    local active = activeShadowSteps[source]
    if not active then
        return notifyDenied(source, 'O Passo Sombrio nao esta ativo.')
    end

    if not isVampire(source) or isPowerBlocked(source) then
        activeShadowSteps[source] = nil
        setCooldown(source, 'passo_sombrio', Config.ShadowStep.cooldown)
        return notifyDenied(source, 'O Passo Sombrio nao esta ativo.')
    end

    local now = GetGameTimer()
    if now > active.expiresAt then
        activeShadowSteps[source] = nil
        setCooldown(source, 'passo_sombrio', Config.ShadowStep.cooldown)
        return notifyDenied(source, 'O Passo Sombrio perdeu a canalizacao.')
    end

    if now + 250 < active.nextChargeAt then
        return { success = true, charged = false }
    end

    local interval = math.max(1000, tonumber(Config.ShadowStep.sustainInterval) or 5000)
    local cost = math.max(1, tonumber(Config.ShadowStep.sustainCost) or 2)
    local consumed = removeEssence(source, cost)
    if not consumed then
        activeShadowSteps[source] = nil
        setCooldown(source, 'passo_sombrio', Config.ShadowStep.cooldown)
        return notifyDenied(source, 'Essencia de sangue esgotada.')
    end

    active.nextChargeAt = now + interval
    local grace = math.max(1000, tonumber(Config.ShadowStep.sustainGrace) or 3000)
    active.expiresAt = now + interval + grace
    armShadowStepTimeout(source, active.token, interval + grace + 250)
    return { success = true, charged = true }
end)

lib.callback.register('ob_vampiros:server:sustainBatForm', function(source)
    local active = activeBatForms[source]
    if not active then
        return notifyDenied(source, 'A Forma de Morcego nao esta ativa.')
    end

    if not isVampire(source) or isBatFormInterrupted(source) then
        activeBatForms[source] = nil
        setCooldown(source, 'forma_morcego', Config.BatForm.returnCooldown)
        return notifyDenied(source, 'A Forma de Morcego nao esta ativa.')
    end

    local now = GetGameTimer()
    if now > active.expiresAt then
        activeBatForms[source] = nil
        setCooldown(source, 'forma_morcego', Config.BatForm.returnCooldown)
        return notifyDenied(source, 'A Forma de Morcego perdeu a canalizacao.')
    end

    if now + 250 < active.nextChargeAt then
        return { success = true, charged = false }
    end

    local interval = math.max(1000, tonumber(Config.BatForm.sustainInterval) or 8000)
    local cost = getBatSustainCost(source, Config.BatForm)
    local consumed = removeEssence(source, cost)
    if not consumed then
        activeBatForms[source] = nil
        setCooldown(source, 'forma_morcego', Config.BatForm.returnCooldown)
        return notifyDenied(source, 'Essencia de sangue esgotada.')
    end

    active.nextChargeAt = now + interval
    local grace = math.max(1000, tonumber(Config.BatForm.sustainGrace) or 3000)
    active.expiresAt = now + interval + grace
    armBatFormTimeout(source, active.token, interval + grace + 250)
    return { success = true, charged = true }
end)

RegisterNetEvent('ob_vampiros:server:shadowStepEnded', function()
    local source = source
    if not activeShadowSteps[source] then
        return
    end

    activeShadowSteps[source] = nil
    setCooldown(source, 'passo_sombrio', Config.ShadowStep.cooldown)
end)

RegisterNetEvent('ob_vampiros:server:shadowSmokeBurst', function()
    local source = source
    if not activeShadowSteps[source] or not isVampire(source) then return end

    local now = GetGameTimer()
    local interval = math.max(250, tonumber(Config.ShadowStep.effect.smokeSyncInterval) or 400)
    if now - (shadowSmokeRateLimits[source] or 0) < interval then return end
    shadowSmokeRateLimits[source] = now

    local sourcePed = GetPlayerPed(source)
    if sourcePed == 0 then return end

    local sourceCoords = GetEntityCoords(sourcePed)
    local sourceBucket = GetPlayerRoutingBucket(source)
    local range = math.max(1.0, tonumber(Config.ShadowStep.effect.smokeSyncRange) or 50.0)

    for _, target in ipairs(getNearbyPlayerSources(sourceCoords, range, source, sourceBucket)) do
        TriggerClientEvent('ob_vampiros:client:shadowSmokeBurst', target, source)
    end
end)

RegisterNetEvent('ob_vampiros:server:syncBatTransformationFx', function()
    local source = source
    if not isVampire(source) then return end

    local now = GetGameTimer()
    if now - (batTransformationFxRateLimits[source] or 0) < 1200 then return end
    batTransformationFxRateLimits[source] = now

    local sourcePed = GetPlayerPed(source)
    if sourcePed == 0 then return end

    local fx = Config.BatForm.transformationFx or {}
    local sourceCoords = GetEntityCoords(sourcePed)
    local sourceBucket = GetPlayerRoutingBucket(source)
    local range = math.max(1.0, tonumber(fx.syncRange) or 65.0)

    for _, target in ipairs(getNearbyPlayerSources(sourceCoords, range, source, sourceBucket)) do
        TriggerClientEvent('ob_vampiros:client:showBatTransformationFx', target, source)
    end
end)

RegisterNetEvent('ob_vampiros:server:syncEmbraceApproachFx', function(duration)
    local source = source
    if not embraceParticipants[source] or not isVampire(source) then return end

    local now = GetGameTimer()
    if now - (embraceApproachFxRateLimits[source] or 0) < 500 then return end
    embraceApproachFxRateLimits[source] = now

    local bite = Config.NightEmbrace.biteAnimation or {}
    local approach = bite.approach or {}
    local effect = approach.effect or {}
    local minimum = math.max(100, tonumber(approach.minimumDuration) or 320)
    local maximum = math.max(minimum, tonumber(approach.maximumDuration) or 900)
    duration = math.min(maximum, math.max(minimum, tonumber(duration) or maximum))

    local sourcePed = GetPlayerPed(source)
    if sourcePed == 0 then return end

    local sourceCoords = GetEntityCoords(sourcePed)
    local sourceBucket = GetPlayerRoutingBucket(source)
    local range = math.max(1.0, tonumber(effect.syncRange) or 65.0)

    for _, target in ipairs(getNearbyPlayerSources(sourceCoords, range, source, sourceBucket)) do
        TriggerClientEvent(
            'ob_vampiros:client:showEmbraceApproachFx',
            target, source, duration
        )
    end
end)

RegisterNetEvent('ob_vampiros:server:batEnded', function()
    local source = source
    if not activeBatForms[source] then
        return
    end
    activeBatForms[source] = nil
    setCooldown(source, 'forma_morcego', Config.BatForm.returnCooldown)
end)

local function validTarget(source, targetSource, maxDistance)
    targetSource = tonumber(targetSource)
    if not targetSource or targetSource == source or not getPlayer(targetSource) then
        return false, 'O alvo nao esta disponivel.'
    end
    if GetPlayerRoutingBucket(source) ~= GetPlayerRoutingBucket(targetSource) then
        return false, 'O alvo nao esta no mesmo plano.'
    end

    local sourcePed, targetPed = GetPlayerPed(source), GetPlayerPed(targetSource)
    if sourcePed == 0 or targetPed == 0 then
        return false, 'O alvo nao esta disponivel.'
    end
    if #(GetEntityCoords(sourcePed) - GetEntityCoords(targetPed)) > maxDistance then
        return false, 'O alvo esta longe demais.'
    end
    return true, nil, sourcePed, targetPed
end

lib.callback.register('ob_vampiros:server:beginHypnosis', function(source)
    local authorized = authorize(source, 'hipnose', false)
    if not authorized.success then
        return authorized
    end

    hypnosisSequence = hypnosisSequence + 1
    local token = hypnosisSequence
    local castTime = math.max(0, tonumber(Config.Hypnosis.castTime) or 850)
    local tokenLifetime = castTime + 3000
    local duration = math.max(1000, tonumber(Config.Hypnosis.duration) or 10000)
    local weakened = isSolarWeakened(source)
    local failed = false
    if weakened then
        local solar = Config.SolarWeakness and Config.SolarWeakness.hypnosis or {}
        local chance = math.max(0, math.min(100, tonumber(solar.successChance) or 55))
        failed = math.random(1, 10000) > math.floor(chance * 100)
        duration = math.max(1000, math.floor(duration * math.max(0.1, tonumber(solar.durationMultiplier) or 0.45)))
    end
    pendingHypnosisCasts[source] = {
        token = token,
        expiresAt = GetGameTimer() + tokenLifetime,
        duration = duration,
        failed = failed,
    }
    SetTimeout(tokenLifetime + 200, function()
        local pending = pendingHypnosisCasts[source]
        if pending and pending.token == token and GetGameTimer() >= pending.expiresAt then
            pendingHypnosisCasts[source] = nil
        end
    end)

    return {
        success = true,
        token = token,
        duration = duration,
        solarFailed = failed,
    }
end)

lib.callback.register('ob_vampiros:server:hitHypnosis', function(source, token, targetSource)
    local pending = pendingHypnosisCasts[source]
    token = tonumber(token)
    if not pending or pending.token ~= token or GetGameTimer() > pending.expiresAt then
        pendingHypnosisCasts[source] = nil
        return notifyDenied(source, 'O impulso hipnotico se dissipou.')
    end

    pendingHypnosisCasts[source] = nil
    if isPowerBlocked(source) then
        return notifyDenied(source, 'Voce nao consegue usar poderes enquanto esta hipnotizado.')
    end
    local distance = math.max(1.0, tonumber(Config.Hypnosis.distance) or 40.0)
    local beamWidth = math.max(0.1, tonumber(Config.Hypnosis.beamWidth) or 5.0)
    local valid, message = validTarget(source, targetSource, distance + beamWidth)
    if not valid then
        return notifyDenied(source, message)
    end

    if pending.failed then
        return notifyDenied(source, 'A luz do dia enfraqueceu sua hipnose e o alvo resistiu.')
    end

    local duration = math.max(1000, tonumber(pending.duration) or Config.Hypnosis.duration or 10000)
    applyHypnosisState(targetSource, duration)
    TriggerClientEvent(
        'ob_vampiros:client:applyHypnosis', tonumber(targetSource),
        duration
    )
    TriggerClientEvent(
        'ob_vampiros:client:showHypnosisHeadFx', -1,
        tonumber(targetSource), duration
    )
    return { success = true, duration = duration }
end)

RegisterNetEvent('ob_vampiros:server:finishHypnosis', function(token)
    local source = source
    local pending = pendingHypnosisCasts[source]
    if pending and pending.token == tonumber(token) then
        pendingHypnosisCasts[source] = nil
    end
end)

local function setPlayerClass(targetSource, classId)
    local _, player = getClass(targetSource)
    if not player or not player.Functions then
        return false
    end
    if player.Functions.SetMetaData then
        player.Functions.SetMetaData(Config.ClassMetadataKey, classId)
        return true
    end
    if player.Functions.SetMetadata then
        player.Functions.SetMetadata(Config.ClassMetadataKey, classId)
        return true
    end
    return false
end

local function validatePumaEmbraceTarget(source, netId)
    if (Config.NightEmbrace or {}).allowFarmPumaTarget ~= true then
        return nil, 'A drenagem de oncas esta desativada.'
    end

    netId = math.floor(tonumber(netId) or 0)
    if netId <= 0 then return nil, 'Esta onca nao pode ser identificada.' end

    local sourcePed = GetPlayerPed(source)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if sourcePed <= 0 or entity <= 0 or not DoesEntityExist(entity)
        or GetEntityType(entity) ~= 1 or not isPumaModel(GetEntityModel(entity)) then
        return nil, 'O alvo nao e uma onca valida do farm.'
    end

    local state = Entity(entity).state
    if state.obVampireFarmPuma ~= true or state.obVampireHarvested == true then
        return nil, 'O alvo nao e uma onca valida do farm.'
    end
    if GetEntityHealth(entity) <= 1 then return nil, 'A onca ja esta morta.' end
    if GetEntityRoutingBucket(entity) ~= GetPlayerRoutingBucket(source) then
        return nil, 'A onca nao esta no mesmo plano.'
    end

    local maximum = math.max(1.0, tonumber(Config.NightEmbrace.distance) or 15.0) + 0.65
    if #(GetEntityCoords(sourcePed) - GetEntityCoords(entity)) > maximum then
        return nil, 'A onca esta longe demais.'
    end

    local lockOwner = pumaEmbraceLocks[netId]
    if lockOwner and lockOwner ~= source then
        return nil, 'Outro vampiro ja esta drenando esta onca.'
    end
    local stateOwner = tonumber(state.obVampireEmbracer)
    if stateOwner and stateOwner ~= source then
        return nil, 'Outro vampiro ja esta drenando esta onca.'
    end

    return entity, nil, netId
end

local function clearPumaEmbrace(source, expectedToken)
    local session = activePumaEmbraces[source]
    if not session or expectedToken and session.token ~= expectedToken then return end

    activePumaEmbraces[source] = nil
    embraceParticipants[source] = nil
    if pumaEmbraceLocks[session.netId] == source then
        pumaEmbraceLocks[session.netId] = nil
    end
    if session.entity and DoesEntityExist(session.entity) then
        local state = Entity(session.entity).state
        if tonumber(state.obVampireEmbracer) == source then
            state:set('obVampireEmbracer', false, true)
        end
    end
end

lib.callback.register('ob_vampiros:server:beginPumaEmbrace', function(source, netId)
    if embraceParticipants[source] then
        return notifyDenied(source, 'Um dreno vital ja esta em andamento.')
    end

    local entity, reason, normalizedNetId = validatePumaEmbraceTarget(source, netId)
    if not entity then return notifyDenied(source, reason) end

    local authorized = authorize(source, 'abraco_noite', false)
    if not authorized.success then return authorized end

    local duration = math.max(1500, tonumber(Config.NightEmbrace.channelDuration) or 6000)
    local prelude = embracePreludeDuration()
    local totalDuration = prelude + duration
    local ticks = math.max(1, math.floor(tonumber(Config.NightEmbrace.ticks) or 10))
    local weakened = isSolarWeakened(source)
    local solar = Config.SolarWeakness and Config.SolarWeakness.nightEmbrace or {}
    local drainAmount = scaledAbilityValue(
        Config.NightEmbrace.drainAmount,
        weakened and solar.damageMultiplier or 1.0
    )
    local healthGain = scaledAbilityValue(
        Config.NightEmbrace.healthGain,
        weakened and solar.healthGainMultiplier or 1.0
    )
    local essenceGain = scaledAbilityValue(
        Config.NightEmbrace.pumaEssenceGain or 4,
        weakened and solar.essenceGainMultiplier or 1.0
    )
    local interval = math.max(100, math.floor(duration / ticks))
    pumaEmbraceSequence = pumaEmbraceSequence + 1
    local token = pumaEmbraceSequence
    activePumaEmbraces[source] = {
        token = token,
        entity = entity,
        netId = normalizedNetId,
        nextTick = 1,
        nextTickAt = GetGameTimer() + interval,
        rewardedTick = 0,
        ticks = ticks,
        drainAmount = drainAmount,
        healthGain = healthGain,
        essenceGain = essenceGain,
        interval = interval,
        expiresAt = GetGameTimer() + totalDuration + 1800,
    }
    embraceParticipants[source] = true
    pumaEmbraceLocks[normalizedNetId] = source
    Entity(entity).state:set('obVampireEmbracer', source, true)

    SetTimeout(totalDuration + 2000, function()
        clearPumaEmbrace(source, token)
    end)
    return {
        success = true,
        token = token,
        duration = duration,
        ticks = ticks,
        drainAmount = drainAmount,
    }
end)

lib.callback.register('ob_vampiros:server:pumaEmbraceTick', function(source, token, tick)
    local session = activePumaEmbraces[source]
    tick = math.floor(tonumber(tick) or 0)
    if not session or session.token ~= tonumber(token) or tick ~= session.nextTick
        or GetGameTimer() > session.expiresAt or not isVampire(source)
        or isPowerBlocked(source) then
        clearPumaEmbrace(source, session and session.token)
        return notifyDenied(source, 'O fluxo vital foi interrompido.')
    end

    local entity = validatePumaEmbraceTarget(source, session.netId)
    if not entity or entity ~= session.entity then
        clearPumaEmbrace(source, session.token)
        return notifyDenied(source, 'A onca nao esta mais disponivel para drenagem.')
    end

    local now = GetGameTimer()
    if now + 150 < session.nextTickAt then
        return notifyDenied(source, 'A drenagem ainda nao completou este ciclo.')
    end

    if session.rewardedTick < tick then
        grantDrainReward(
            source,
            distributedChunk(session.healthGain, tick, session.ticks),
            distributedChunk(session.essenceGain, tick, session.ticks)
        )
        session.rewardedTick = tick
    end

    session.nextTick = session.nextTick + 1
    session.nextTickAt = math.max(session.nextTickAt + session.interval, now)
    return { success = true }
end)

RegisterNetEvent('ob_vampiros:server:finishPumaEmbrace', function(token)
    local source = source
    local session = activePumaEmbraces[source]
    if session and session.token == tonumber(token) then
        clearPumaEmbrace(source, session.token)
    end
end)

lib.callback.register('ob_vampiros:server:useEmbrace', function(source, targetSource, mode)
    mode = tostring(mode or 'drain')
    if mode ~= 'drain' and mode ~= 'transform' then
        return notifyDenied(source, 'Ritual invalido.')
    end

    targetSource = tonumber(targetSource)
    if embraceParticipants[source] or embraceParticipants[targetSource] then
        return notifyDenied(source, 'Um Abraco da Noite ja esta em andamento.')
    end

    local valid, message, sourcePed, targetPed = validTarget(source, targetSource, Config.NightEmbrace.distance + 0.65)
    if not valid then
        return notifyDenied(source, message)
    end
    if GetVehiclePedIsIn(sourcePed, false) ~= 0 or GetVehiclePedIsIn(targetPed, false) ~= 0 then
        return notifyDenied(source, 'O Abraco da Noite exige que ambos estejam fora de veiculos.')
    end

    if mode == 'transform' then
        local targetClass = getClass(targetSource)
        if not Config.NightEmbrace.transformationEnabled then
            return notifyDenied(source, 'A transformacao por lore esta desativada.')
        end
        if not IsPlayerAceAllowed(source, Config.NightEmbrace.transformationAce) then
            return notifyDenied(source, 'Voce nao possui permissao para esse ritual de lore.')
        end
        if targetClass ~= 'humano' then
            return notifyDenied(source, 'Apenas humanos podem receber esse abraco.')
        end
    end

    local authorized = authorize(source, 'abraco_noite', false)
    if not authorized.success then
        return authorized
    end

    local sourceCoords = GetEntityCoords(sourcePed)
    local targetCoords = GetEntityCoords(targetPed)
    local dx = targetCoords.x - sourceCoords.x
    local dy = targetCoords.y - sourceCoords.y
    local dz = targetCoords.z - sourceCoords.z
    local approachDuration = embraceApproachDuration(math.sqrt(dx * dx + dy * dy + dz * dz))
    local duration = math.max(1500, tonumber(Config.NightEmbrace.channelDuration) or 6000)
    local prelude = embracePreludeDuration(approachDuration)
    local totalDuration = prelude + duration
    local weakened = isSolarWeakened(source)
    local solar = Config.SolarWeakness and Config.SolarWeakness.nightEmbrace or {}
    local drainAmount = scaledAbilityValue(
        Config.NightEmbrace.drainAmount,
        weakened and solar.damageMultiplier or 1.0
    )
    local healthGain = scaledAbilityValue(
        Config.NightEmbrace.healthGain,
        weakened and solar.healthGainMultiplier or 1.0
    )
    local essenceGain = scaledAbilityValue(
        Config.NightEmbrace.essenceGain,
        weakened and solar.essenceGainMultiplier or 1.0
    )
    embraceParticipants[source] = true
    embraceParticipants[targetSource] = true
    SetTimeout(totalDuration + 2500, function()
        embraceParticipants[source] = nil
        embraceParticipants[targetSource] = nil
    end)
    TriggerClientEvent(
        'ob_vampiros:client:beginEmbrace', source,
        'caster', targetSource, duration, approachDuration
    )
    TriggerClientEvent(
        'ob_vampiros:client:beginEmbrace', targetSource,
        'target', source, duration, approachDuration
    )
    TriggerClientEvent('ob_vampiros:client:showRedHeadAura', -1, source, totalDuration)

    if mode == 'transform' then
        SetTimeout(totalDuration, function()
            embraceParticipants[source] = nil
            embraceParticipants[targetSource] = nil
            if isPowerBlocked(source) then return end
            local stillValid = validTarget(source, targetSource, Config.NightEmbrace.distance + 2.0)
            if not stillValid then return end
            if setPlayerClass(targetSource, Config.ClassId) then
                TriggerClientEvent('classeSelector:classChanged', targetSource, Config.ClassId)
            end
        end)
    else
        CreateThread(function()
            local ticks = math.max(1, math.floor(tonumber(Config.NightEmbrace.ticks) or 10))
            local interval = math.max(100, math.floor(duration / ticks))
            local floorHealth = math.max(1, tonumber(Config.NightEmbrace.minimumTargetHealth) or 105)

            Wait(prelude)
            for tick = 1, ticks do
                Wait(interval)
                if isPowerBlocked(source) then break end
                local valid = validTarget(
                    source, targetSource, Config.NightEmbrace.distance + 2.0
                )
                if not valid then break end

                local damage = distributedChunk(drainAmount, tick, ticks)
                local callbackOk, drained = pcall(function()
                    return lib.callback.await(
                        'ob_vampiros:client:applyDrainDamage', targetSource,
                        damage, floorHealth
                    )
                end)
                drained = callbackOk and math.max(0, tonumber(drained) or 0) or 0
                if drained <= 0 then break end

                grantDrainReward(
                    source,
                    distributedChunk(healthGain, tick, ticks),
                    distributedChunk(essenceGain, tick, ticks)
                )
            end

            embraceParticipants[source] = nil
            embraceParticipants[targetSource] = nil
        end)
    end

    return {
        success = true,
        message = mode == 'transform' and 'O ritual de transformacao foi iniciado.' or 'A energia vital comeca a fluir.',
    }
end)

AddEventHandler('playerDropped', function()
    local source = source
    clearPumaHarvest(source)
    clearPumaEmbrace(source)
    cooldowns[source] = nil
    activeBatForms[source] = nil
    activeShadowSteps[source] = nil
    shadowSmokeRateLimits[source] = nil
    batTransformationFxRateLimits[source] = nil
    embraceApproachFxRateLimits[source] = nil
    pendingHypnosisCasts[source] = nil
    activeHypnosisTargets[source] = nil
    embraceParticipants[source] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local harvestingSources = {}
    for harvestingSource in pairs(activePumaHarvests) do
        harvestingSources[#harvestingSources + 1] = harvestingSource
    end
    for _, harvestingSource in ipairs(harvestingSources) do
        clearPumaHarvest(harvestingSource)
    end
    local embracingSources = {}
    for embracingSource in pairs(activePumaEmbraces) do
        embracingSources[#embracingSources + 1] = embracingSource
    end
    for _, embracingSource in ipairs(embracingSources) do
        clearPumaEmbrace(embracingSource)
    end
    for targetSource in pairs(activeHypnosisTargets) do
        if GetPlayerName(targetSource) then
            Player(targetSource).state:set('obHypnotized', false, true)
        end
    end
end)
