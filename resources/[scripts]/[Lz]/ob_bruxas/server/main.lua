local residues = {}
local residueSequence = 0
local eloChannels = {}
local eloCooldowns = {}
local familiarFxRateLimits = {}
local activeFamiliars = {}
local familiarCooldowns = {}
local familiarSequence = 0
local activeArcaneSenses = {}
local arcaneSenseCooldowns = {}
local arcaneSenseSequence = 0
local latestResidueBySource = {}
local witchFogCooldowns = {}

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

local function isWitch(source)
    local player = getPlayer(source)
    local metadata = player and player.PlayerData and player.PlayerData.metadata or {}
    return tostring(metadata[Config.ClassMetadataKey] or ''):lower() == tostring(Config.ClassId):lower(), player
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

local function isFamiliarInterrupted(source)
    local player = Player(source)
    local state = player and player.state
    if not state then return false end

    return state.magicFauna == true
        or state.obHypnotized == true
        or state.obInVehicleAttachment == true
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

local function setFamiliarCooldown(source)
    familiarCooldowns[source] = GetGameTimer()
        + math.max(0, tonumber(Config.Familiar.returnCooldown) or 0)
end

local function hasMana(source, amount)
    if GetResourceState('ob_essencias') ~= 'started' then return false end

    local ok, snapshot = pcall(function()
        return exports.ob_essencias:GetEssenciaSnapshot(source)
    end)
    return ok and type(snapshot) == 'table' and snapshot.success == true
        and (tonumber(snapshot.value) or 0) >= math.max(0, tonumber(amount) or 0)
end

local function consumeMana(source, amount)
    if GetResourceState('ob_essencias') ~= 'started' then return false, nil end

    local ok, result = pcall(function()
        return exports.ob_essencias:ConsumeEssencia(source, amount)
    end)
    return ok and type(result) == 'table' and result.success == true, result
end

local function armFamiliarTimeout(source, token, delay)
    SetTimeout(delay, function()
        local active = activeFamiliars[source]
        if active and active.token == token and GetGameTimer() > active.expiresAt then
            activeFamiliars[source] = nil
            setFamiliarCooldown(source)
        end
    end)
end

local function setArcaneSenseCooldown(source)
    arcaneSenseCooldowns[source] = GetGameTimer()
        + math.max(0, tonumber(Config.SentidoArcano.cooldown) or 0)
end

local function armArcaneSenseTimeout(source, token, delay)
    SetTimeout(delay, function()
        local active = activeArcaneSenses[source]
        if active and active.token == token and GetGameTimer() > active.expiresAt then
            activeArcaneSenses[source] = nil
            setArcaneSenseCooldown(source)
        end
    end)
end

RegisterNetEvent('ob_bruxas:server:syncFamiliarTransformationFx', function()
    local source = source
    if not isWitch(source) then return end

    local now = GetGameTimer()
    local lastTrigger = familiarFxRateLimits[source]
    if lastTrigger and now - lastTrigger < 1200 then return end
    familiarFxRateLimits[source] = now

    local sourcePed = GetPlayerPed(source)
    if sourcePed == 0 then return end

    local fx = Config.Familiar.transformationFx or {}
    local sourceCoords = GetEntityCoords(sourcePed)
    local sourceBucket = GetPlayerRoutingBucket(source)
    local range = math.max(1.0, tonumber(fx.syncRange) or 65.0)

    for _, target in ipairs(getNearbyPlayerSources(sourceCoords, range, source, sourceBucket)) do
        TriggerClientEvent('ob_bruxas:client:showFamiliarTransformationFx', target, source)
    end
end)

lib.callback.register('ob_bruxas:server:beginFamiliar', function(source)
    if not isWitch(source) or isPowerBlocked(source) or activeFamiliars[source] then
        return { success = false, reason = 'unavailable' }
    end

    if (familiarCooldowns[source] or 0) > GetGameTimer() then
        return { success = false, reason = 'cooldown' }
    end

    local cost = math.max(1, tonumber(Config.Familiar.sustainCost) or 1)
    if not hasMana(source, cost) then
        return { success = false, reason = 'mana' }
    end

    local now = GetGameTimer()
    local interval = math.max(1000, tonumber(Config.Familiar.sustainInterval) or 8000)
    local grace = math.max(1000, tonumber(Config.Familiar.sustainGrace) or 3000)
    familiarSequence = familiarSequence + 1
    local token = familiarSequence

    activeFamiliars[source] = {
        token = token,
        nextChargeAt = now + interval,
        expiresAt = now + interval + grace,
    }
    armFamiliarTimeout(source, token, interval + grace + 250)
    return { success = true }
end)

lib.callback.register('ob_bruxas:server:sustainFamiliar', function(source)
    local active = activeFamiliars[source]
    if not active or not isWitch(source) or isFamiliarInterrupted(source) then
        activeFamiliars[source] = nil
        setFamiliarCooldown(source)
        return { success = false, reason = 'inactive' }
    end

    local now = GetGameTimer()
    if now > active.expiresAt then
        activeFamiliars[source] = nil
        setFamiliarCooldown(source)
        return { success = false, reason = 'expired' }
    end

    if now + 250 < active.nextChargeAt then
        return { success = true, charged = false }
    end

    local cost = math.max(1, tonumber(Config.Familiar.sustainCost) or 1)
    local consumed, manaState = consumeMana(source, cost)
    if not consumed then
        activeFamiliars[source] = nil
        setFamiliarCooldown(source)
        return { success = false, reason = 'mana' }
    end

    if (tonumber(manaState and manaState.value) or 0) <= 0 then
        activeFamiliars[source] = nil
        setFamiliarCooldown(source)
        return { success = true, charged = true, depleted = true }
    end

    local interval = math.max(1000, tonumber(Config.Familiar.sustainInterval) or 8000)
    local grace = math.max(1000, tonumber(Config.Familiar.sustainGrace) or 3000)
    active.nextChargeAt = now + interval
    active.expiresAt = now + interval + grace
    armFamiliarTimeout(source, active.token, interval + grace + 250)
    return { success = true, charged = true }
end)

RegisterNetEvent('ob_bruxas:server:familiarEnded', function()
    local source = source
    activeFamiliars[source] = nil
    setFamiliarCooldown(source)
end)

lib.callback.register('ob_bruxas:server:beginArcaneSense', function(source)
    if not isWitch(source) or isPowerBlocked(source) or activeArcaneSenses[source] then
        return { success = false, reason = 'unavailable' }
    end

    if (arcaneSenseCooldowns[source] or 0) > GetGameTimer() then
        return { success = false, reason = 'cooldown' }
    end

    local cost = math.max(1, tonumber(Config.SentidoArcano.sustainCost) or 1)
    if not hasMana(source, cost) then
        return { success = false, reason = 'mana' }
    end

    local now = GetGameTimer()
    local interval = math.max(1000, tonumber(Config.SentidoArcano.sustainInterval) or 3000)
    local grace = math.max(1000, tonumber(Config.SentidoArcano.sustainGrace) or 1800)
    arcaneSenseSequence = arcaneSenseSequence + 1
    local token = arcaneSenseSequence

    activeArcaneSenses[source] = {
        token = token,
        nextChargeAt = now + interval,
        expiresAt = now + interval + grace,
    }
    armArcaneSenseTimeout(source, token, interval + grace + 250)
    return { success = true }
end)

lib.callback.register('ob_bruxas:server:sustainArcaneSense', function(source)
    local active = activeArcaneSenses[source]
    if not active or not isWitch(source) or isPowerBlocked(source) then
        activeArcaneSenses[source] = nil
        setArcaneSenseCooldown(source)
        return { success = false, reason = 'inactive' }
    end

    local now = GetGameTimer()
    if now > active.expiresAt then
        activeArcaneSenses[source] = nil
        setArcaneSenseCooldown(source)
        return { success = false, reason = 'expired' }
    end

    if now + 250 < active.nextChargeAt then
        return { success = true, charged = false }
    end

    local cost = math.max(1, tonumber(Config.SentidoArcano.sustainCost) or 1)
    local consumed, manaState = consumeMana(source, cost)
    if not consumed then
        activeArcaneSenses[source] = nil
        setArcaneSenseCooldown(source)
        return { success = false, reason = 'mana' }
    end

    if (tonumber(manaState and manaState.value) or 0) <= 0 then
        activeArcaneSenses[source] = nil
        setArcaneSenseCooldown(source)
        return { success = true, charged = true, depleted = true }
    end

    local interval = math.max(1000, tonumber(Config.SentidoArcano.sustainInterval) or 3000)
    local grace = math.max(1000, tonumber(Config.SentidoArcano.sustainGrace) or 1800)
    active.nextChargeAt = now + interval
    active.expiresAt = now + interval + grace
    armArcaneSenseTimeout(source, active.token, interval + grace + 250)
    return { success = true, charged = true }
end)

RegisterNetEvent('ob_bruxas:server:arcaneSenseEnded', function()
    local source = source
    activeArcaneSenses[source] = nil
    setArcaneSenseCooldown(source)
end)

local function normalizeCoords(coords)
    if not coords then return nil end

    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return nil end

    return {
        x = x + 0.0,
        y = y + 0.0,
        z = z + 0.0,
    }
end

local function residueDistanceSquared(first, second)
    local dx = first.x - second.x
    local dy = first.y - second.y
    local dz = first.z - second.z
    return (dx * dx) + (dy * dy) + (dz * dz)
end

local function removeResidue(id)
    id = tostring(id or '')
    local entry = residues[id]
    if not entry then return false end

    residues[id] = nil
    if entry.source and latestResidueBySource[entry.source] == id then
        latestResidueBySource[entry.source] = nil
    end
    return true
end

local function pruneExpiredResidues(now)
    now = now or GetGameTimer()
    for id, entry in pairs(residues) do
        if entry.expiresAt <= now then removeResidue(id) end
    end
end

local function makeResidueRoom()
    local maximum = math.max(16, tonumber(Config.SentidoArcano.maxResidues) or 256)
    local count, oldestId, oldestAt = 0, nil, math.huge

    for id, entry in pairs(residues) do
        count = count + 1
        local updatedAt = tonumber(entry.updatedAt) or 0
        if updatedAt < oldestAt then
            oldestId, oldestAt = id, updatedAt
        end
    end

    if count >= maximum and oldestId then removeResidue(oldestId) end
end

local function createResidue(data)
    if type(data) ~= 'table' then return nil end

    local coords = normalizeCoords(data.coords)
    if not coords then return nil end

    local now = GetGameTimer()
    local duration = math.max(1000, tonumber(data.duration) or Config.SentidoArcano.defaultResidueDuration)
    local owner = tonumber(data.source)
    local bucket = data.bucket ~= nil and tonumber(data.bucket) or nil
    local amount = math.max(0, tonumber(data.amount) or 0)
    pruneExpiredResidues(now)

    if owner then
        local previousId = latestResidueBySource[owner]
        local previous = previousId and residues[previousId] or nil
        local mergeDistance = math.max(0.25, tonumber(Config.SentidoArcano.residueMergeDistance) or 3.0)
        local mergeWindow = math.max(500, tonumber(Config.SentidoArcano.residueMergeWindow) or 12000)

        if previous
            and previous.bucket == bucket
            and now - previous.updatedAt <= mergeWindow
            and residueDistanceSquared(previous.coords, coords) <= mergeDistance * mergeDistance then
            previous.expiresAt = now + duration
            previous.updatedAt = now
            previous.amount = previous.amount + amount
            previous.strength = math.min(2.2, 1.0 + previous.amount * 0.04)
            return previous.id
        end
    end

    makeResidueRoom()
    residueSequence = residueSequence + 1
    local id = tostring(data.id or ('arcane_%s'):format(residueSequence))

    residues[id] = {
        id = id,
        kind = tostring(data.kind or 'magic'),
        label = tostring(data.label or 'Residuo arcano'),
        coords = coords,
        source = owner,
        bucket = bucket,
        amount = amount,
        strength = math.min(2.2, 1.0 + amount * 0.04),
        createdAt = now,
        updatedAt = now,
        expiresAt = now + duration,
    }

    if owner then latestResidueBySource[owner] = id end

    return id
end

exports('CreateArcaneResidue', createResidue)
exports('RemoveArcaneResidue', removeResidue)

AddEventHandler('ob_bruxas:server:createResidue', function(data, callback)
    local id = createResidue(data)
    if type(callback) == 'function' then
        callback(id)
    end
end)

AddEventHandler('ob_bruxas:server:removeResidue', function(id)
    removeResidue(id)
end)

AddEventHandler('ob_essencias:server:spent', function(playerSource, amount, essenceData)
    playerSource = tonumber(playerSource)
    amount = math.max(0, tonumber(amount) or 0)
    if not playerSource or amount <= 0 then return end

    essenceData = type(essenceData) == 'table' and essenceData or {}
    local classId = tostring(essenceData.class or ''):lower()
    if not Config.SentidoArcano.colors[classId] then return end

    local ped = GetPlayerPed(playerSource)
    if ped == 0 then return end

    createResidue({
        source = playerSource,
        amount = amount,
        kind = classId,
        label = ('Resquicio de %s'):format(tostring(essenceData.label or 'essencia')),
        coords = GetEntityCoords(ped),
        bucket = GetPlayerRoutingBucket(playerSource),
        duration = math.max(120000, tonumber(Config.SentidoArcano.defaultResidueDuration) or 120000),
    })
end)

local function buildArcaneSnapshot(source)
    local now = GetGameTimer()
    local snapshot = {}
    pruneExpiredResidues(now)

    local sourcePed = GetPlayerPed(source)
    if sourcePed == 0 then return snapshot end

    local sourceCoords = GetEntityCoords(sourcePed)
    local sourceBucket = GetPlayerRoutingBucket(source)
    local renderDistance = math.max(1.0, tonumber(Config.SentidoArcano.renderDistance) or 80.0)
    local nearby = {}

    for _, entry in pairs(residues) do
        if entry.source ~= source and (entry.bucket == nil or entry.bucket == sourceBucket) then
            local distanceSquared = residueDistanceSquared(sourceCoords, entry.coords)
            if distanceSquared <= renderDistance * renderDistance then
                nearby[#nearby + 1] = {
                    entry = entry,
                    distanceSquared = distanceSquared,
                }
            end
        end
    end

    table.sort(nearby, function(first, second)
        return first.distanceSquared < second.distanceSquared
    end)

    local visibleLimit = math.max(8, tonumber(Config.SentidoArcano.maxVisibleResidues) or 48)
    for index = 1, math.min(#nearby, visibleLimit) do
        local entry = nearby[index].entry
        snapshot[#snapshot + 1] = {
            id = entry.id,
            kind = entry.kind,
            coords = entry.coords,
            strength = entry.strength,
            ttl = entry.expiresAt - now,
        }
    end

    if Config.SentidoArcano.showCreaturesWithoutResidue == true then
        local creatureDistance = Config.SentidoArcano.creatureDistance
        for _, target in ipairs(getNearbyPlayerSources(
            sourceCoords,
            creatureDistance,
            source,
            sourceBucket
        )) do
            local player = getPlayer(target)
            local metadata = player and player.PlayerData and player.PlayerData.metadata or {}
            local classId = tostring(metadata[Config.ClassMetadataKey] or ''):lower()

            if classId ~= '' and classId ~= 'humano' then
                local targetPed = GetPlayerPed(target)
                if targetPed ~= 0 then
                    snapshot[#snapshot + 1] = {
                        id = ('creature_%s'):format(target),
                        kind = 'creature',
                        coords = normalizeCoords(GetEntityCoords(targetPed)),
                        ttl = 5500,
                    }
                end
            end
        end
    end

    return snapshot
end

RegisterNetEvent('ob_bruxas:server:requestArcaneSnapshot', function()
    local source = source
    if isPowerBlocked(source) then return end
    if not isWitch(source) or not activeArcaneSenses[source] then return end

    TriggerClientEvent('ob_bruxas:client:arcaneSnapshot', source, buildArcaneSnapshot(source))
end)

CreateThread(function()
    while true do
        Wait(math.max(5000, tonumber(Config.SentidoArcano.cleanupInterval) or 30000))
        pruneExpiredResidues()
    end
end)

local function getMaxMana(metadata)
    for _, key in ipairs(Config.Mana.maxMetadataKeys or {}) do
        local value = tonumber(metadata[key])
        if value and value > 0 then
            return value
        end
    end

    return tonumber(Config.Mana.defaultMax) or 100
end

local function restoreMana(targetSource, amount)
    local resource = Config.Mana.resource
    local exportName = Config.Mana.serverExport
    if resource and resource ~= '' and exportName and exportName ~= '' and GetResourceState(resource) == 'started' then
        local ok, result = pcall(function()
            if resource == 'ob_essencias' and exportName == 'AddEssencia' then
                return exports.ob_essencias:AddEssencia(targetSource, amount)
            end
            return false
        end)
        if ok and result ~= false then
            return true
        end
    end

    local player = getPlayer(targetSource)
    if not player or not player.PlayerData then
        return false
    end

    local metadata = player.PlayerData.metadata or {}
    local maxMana = getMaxMana(metadata)
    local currentMana = tonumber(metadata[Config.Mana.metadataKey])
    if currentMana == nil then
        currentMana = maxMana
    end

    local newMana = math.min(maxMana, math.max(0, currentMana + amount))
    if newMana ~= currentMana then
        local updated = pcall(function()
            exports.qbx_core:SetMetadata(targetSource, Config.Mana.metadataKey, newMana)
        end)

        if not updated and player.Functions and player.Functions.SetMetaData then
            player.Functions.SetMetaData(Config.Mana.metadataKey, newMana)
        end

        if GetPlayerName(targetSource) then
            Player(targetSource).state:set(Config.Mana.metadataKey, newMana, true)
        end
    end

    return true
end

exports('RestoreMana', restoreMana)

local function stopElo(source, message)
    eloChannels[source] = nil
    TriggerClientEvent('ob_bruxas:client:eloStopped', source, message)
end

RegisterNetEvent('ob_bruxas:server:startElo', function(targetSource)
    local source = source
    local witch = isWitch(source)
    if not witch or isPowerBlocked(source) or eloChannels[source] then
        TriggerClientEvent('ob_bruxas:client:eloDenied', source, 'Nao foi possivel iniciar a canalizacao.')
        return
    end

    local now = GetGameTimer()
    if (eloCooldowns[source] or 0) > now then
        TriggerClientEvent('ob_bruxas:client:eloDenied', source, 'O Elo Arcano ainda esta se recompondo.')
        return
    end

    targetSource = tonumber(targetSource) or source
    if not getPlayer(targetSource) then
        targetSource = source
    end

    local casterPed = GetPlayerPed(source)
    local targetPed = GetPlayerPed(targetSource)
    if casterPed == 0 or targetPed == 0 then
        TriggerClientEvent('ob_bruxas:client:eloDenied', source, 'O alvo nao esta disponivel.')
        return
    end

    local startCoords = GetEntityCoords(casterPed)
    if targetSource ~= source then
        if GetPlayerRoutingBucket(source) ~= GetPlayerRoutingBucket(targetSource) then
            TriggerClientEvent('ob_bruxas:client:eloDenied', source, 'O aliado nao esta no mesmo plano.')
            return
        end

        local targetCoords = GetEntityCoords(targetPed)
        if #(startCoords - targetCoords) > Config.EloArcano.targetDistance + 1.0 then
            TriggerClientEvent('ob_bruxas:client:eloDenied', source, 'O aliado esta longe demais.')
            return
        end
    end

    local token = ('%s:%s'):format(source, now)
    eloChannels[source] = {
        token = token,
        target = targetSource,
    }
    eloCooldowns[source] = now + Config.EloArcano.cooldown

    TriggerClientEvent('ob_bruxas:client:eloStarted', source, targetSource, Config.EloArcano.duration, targetSource == source)

    local fxCoords = GetEntityCoords(targetPed)
    local fxBucket = GetPlayerRoutingBucket(targetSource)
    local fxRange = math.max(10.0, tonumber(Config.EloArcano.fx.syncRange) or 80.0)
    for _, observer in ipairs(getNearbyPlayerSources(fxCoords, fxRange, nil, fxBucket)) do
        TriggerClientEvent(
            'ob_bruxas:client:eloFx',
            observer,
            targetSource,
            Config.EloArcano.duration
        )
    end

    CreateThread(function()
        local elapsed = 0
        while elapsed < Config.EloArcano.duration do
            Wait(Config.EloArcano.tickInterval)
            elapsed = elapsed + Config.EloArcano.tickInterval

            local channel = eloChannels[source]
            if not channel or channel.token ~= token then
                return
            end

            local currentCasterPed = GetPlayerPed(source)
            local currentTargetPed = GetPlayerPed(targetSource)
            if currentCasterPed == 0 or currentTargetPed == 0
                or not isWitch(source) or isPowerBlocked(source) then
                stopElo(source, 'A ligacao arcana foi interrompida.')
                return
            end

            if targetSource ~= source then
                local casterCoords = GetEntityCoords(currentCasterPed)
                local targetCoords = GetEntityCoords(currentTargetPed)
                if #(casterCoords - targetCoords) > Config.EloArcano.targetDistance + 2.0 then
                    stopElo(source, 'O aliado saiu do alcance do elo.')
                    return
                end
            end

            local amount = targetSource == source and Config.EloArcano.selfManaPerTick or Config.EloArcano.allyManaPerTick
            restoreMana(targetSource, amount)
        end

        if eloChannels[source] and eloChannels[source].token == token then
            stopElo(source)
        end
    end)
end)

RegisterNetEvent('ob_bruxas:server:cancelElo', function()
    eloChannels[source] = nil
end)

lib.callback.register('ob_bruxas:server:castWitchFog', function(source)
    if not isWitch(source) or isPowerBlocked(source) then
        return { success = false, reason = 'class' }
    end

    local config = Config.NevoaBruxas or {}
    local now = GetGameTimer()
    local cooldown = math.max(0, tonumber(config.cooldown) or 40000)
    if (witchFogCooldowns[source] or 0) > now then
        return { success = false, reason = 'cooldown' }
    end

    local sourcePed = GetPlayerPed(source)
    if sourcePed == 0 then
        return { success = false, reason = 'ped' }
    end

    local cost = math.max(0, tonumber(config.essenceCost) or 18)
    if cost > 0 then
        local consumed = consumeMana(source, cost)
        if not consumed then
            return { success = false, reason = 'mana' }
        end
    end

    witchFogCooldowns[source] = now + cooldown

    local coords = GetEntityCoords(sourcePed)
    local bucket = GetPlayerRoutingBucket(source)
    local syncRange = math.max(10.0, tonumber(config.syncRange) or 90.0)
    local duration = math.max(1000, tonumber(config.duration) or 20000)
    local radius = math.max(2.0, tonumber(config.radius) or 8.5)

    for _, target in ipairs(getNearbyPlayerSources(coords, syncRange, source, bucket)) do
        TriggerClientEvent(
            'ob_bruxas:client:showWitchFog',
            target,
            { x = coords.x, y = coords.y, z = coords.z },
            duration,
            radius
        )
    end

    return {
        success = true,
        cooldown = cooldown,
        duration = duration,
        radius = radius,
        coords = { x = coords.x, y = coords.y, z = coords.z },
    }
end)

AddEventHandler('playerDropped', function()
    local source = source
    eloChannels[source] = nil
    eloCooldowns[source] = nil
    familiarFxRateLimits[source] = nil
    activeFamiliars[source] = nil
    familiarCooldowns[source] = nil
    activeArcaneSenses[source] = nil
    arcaneSenseCooldowns[source] = nil
    latestResidueBySource[source] = nil
    witchFogCooldowns[source] = nil

    for caster, channel in pairs(eloChannels) do
        if channel.target == source then
            stopElo(caster, 'O aliado deixou o alcance do elo.')
        end
    end
end)
