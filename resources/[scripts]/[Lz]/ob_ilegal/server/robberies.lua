local robberyStates = {}
local robberySessions = {}

local function now()
    return os.time()
end

local function getRobbery(robberyId)
    if type(robberyId) ~= 'string' then return nil end
    local robbery = Config.Robberies and Config.Robberies[robberyId]
    if not robbery or robbery.enabled ~= true or type(robbery.stages) ~= 'table' then return nil end
    return robbery
end

local function getState(robberyId)
    local state = robberyStates[robberyId]
    if state then return state end
    state = { stageIndex = 1, cooldownUntil = 0 }
    robberyStates[robberyId] = state
    return state
end

local function publicState(robberyId)
    local state = getState(robberyId)
    return {
        stageIndex = state.stageIndex,
        busy = state.busySource ~= nil,
        cooldown = math.max(0, (state.cooldownUntil or 0) - now()),
    }
end

local function broadcastState(robberyId)
    TriggerClientEvent('ob_ilegal:client:robberyState', -1, robberyId, publicState(robberyId))
end

local function setDoorState(stage, locked)
    local doorId = stage and tonumber(stage.doorId)
    if not doorId then return true end
    if GetResourceState('ox_doorlock') ~= 'started' then
        print(('[ob_ilegal] A etapa %s possui doorId %d, mas ox_doorlock não está iniciado.'):format(stage.id or 'sem_id', doorId))
        return false
    end

    local success, errorMessage = pcall(function()
        exports.ox_doorlock:setDoorState(doorId, locked and 1 or 0)
    end)
    if not success then
        print(('[ob_ilegal] Falha ao alterar doorId %d: %s'):format(doorId, errorMessage))
    end
    return success
end

local function resetDoors(robbery)
    for index = 1, #(robbery and robbery.stages or {}) do
        setDoorState(robbery.stages[index], true)
    end
end

local function classValue(value, classId, fallback)
    if type(value) == 'table' then
        if value.name then return value end
        value = value[classId] ~= nil and value[classId] or value.default
    end
    if value == nil then return fallback end
    return value
end

local function clearSession(source)
    local session = robberySessions[source]
    if not session then return nil end
    robberySessions[source] = nil
    ObIlegalServer.ReleaseSession(source, session.token)

    local state = robberyStates[session.robberyId]
    if state and state.token == session.token then
        state.busySource = nil
        state.token = nil
        state.timeoutAt = nil
    end
    return session
end

local function failSession(source, reason)
    local session = robberySessions[source]
    if not session then return { success = false, reason = reason or 'session' } end
    local robbery = getRobbery(session.robberyId)
    clearSession(source)

    if robbery and robbery.failureAlertsPolice == true then
        ObIlegalServer.SendPoliceAlert(session.coords)
    end
    broadcastState(session.robberyId)
    TriggerEvent('ob_ilegal:server:stageFailed', session.robberyId, session.stage.id, source, reason)
    return { success = false, reason = reason or 'action_failed' }
end

lib.callback.register('ob_ilegal:server:getRobberyStates', function()
    local result = {}
    for robberyId, robbery in pairs(Config.Robberies or {}) do
        if robbery.enabled == true then result[robberyId] = publicState(robberyId) end
    end
    return result
end)

lib.callback.register('ob_ilegal:server:beginRobberyStage', function(source, robberyId, requestedStage)
    local robbery = getRobbery(robberyId)
    if not robbery then return { success = false, reason = 'invalid_robbery' } end
    if ObIlegalServer.HasActiveSession(source) then return { success = false, reason = 'busy' } end

    local state = getState(robberyId)
    if state.cooldownUntil > now() then
        return { success = false, reason = 'cooldown', remaining = state.cooldownUntil - now() }
    end
    if state.busySource then return { success = false, reason = 'busy' } end

    requestedStage = math.floor(tonumber(requestedStage) or 0)
    if requestedStage ~= state.stageIndex then
        return { success = false, reason = 'stage', stageIndex = state.stageIndex }
    end

    local stage = robbery.stages[requestedStage]
    local coords = stage and ObIlegalShared.NormalizeCoords(stage.coords)
    if not stage or not coords then return { success = false, reason = 'invalid_stage' } end

    local classId, route = ObIlegalServer.GetClass(source)
    local allowedClasses = type(robbery.allowedClasses) == 'table' and robbery.allowedClasses or {}
    if not route or route.enabled ~= true or allowedClasses[classId] ~= true then
        return { success = false, reason = 'invalid_class' }
    end

    local available, reason, playerCoords = ObIlegalServer.IsPlayerAvailable(source)
    local serverDistance = math.max(1.5, tonumber(stage.serverDistance) or 3.0)
    if not available or ObIlegalShared.Distance(playerCoords, coords) > serverDistance then
        return { success = false, reason = reason or 'distance' }
    end
    if ObIlegalServer.CountPolice() < (tonumber(robbery.minimumPolice) or 0) then
        return { success = false, reason = 'police' }
    end

    local requiredItem = classValue(stage.requiredItem, classId, nil)
    if not ObIlegalServer.HasItem(source, requiredItem) then
        return { success = false, reason = 'item' }
    end

    local token = ('robbery:%s:%d:%d:%d'):format(robberyId, source, GetGameTimer(), math.random(100000, 999999))
    if not ObIlegalServer.ClaimSession(source, 'robbery', token) then
        return { success = false, reason = 'busy' }
    end

    local essenceCost = math.max(0, math.floor(tonumber(classValue(stage.essenceCost, classId, 0)) or 0))
    if not ObIlegalServer.ConsumeEssence(source, essenceCost) then
        ObIlegalServer.ReleaseSession(source, token)
        return { success = false, reason = 'essence' }
    end
    if not ObIlegalServer.TakeRequiredItem(source, requiredItem) then
        ObIlegalServer.ReleaseSession(source, token)
        return { success = false, reason = 'item' }
    end

    local options = type(stage.minigame) == 'table' and stage.minigame or {}
    local timeout = math.max(30, math.floor((tonumber(options.timeLimit) or 30) + 15))
    local session = {
        source = source,
        token = token,
        robberyId = robberyId,
        robbery = robbery,
        stageIndex = requestedStage,
        stage = stage,
        coords = coords,
        classId = classId,
        startedAt = GetGameTimer(),
        minimumFinishAt = GetGameTimer() + math.max(
            900,
            math.floor(tonumber(stage.minimumDuration) or (stage.type == 'vault' and 3500 or 2500))
        ),
        timeoutAt = now() + timeout,
    }
    robberySessions[source] = session
    state.busySource = source
    state.token = token
    state.timeoutAt = session.timeoutAt
    if requestedStage == 1 and robbery.alertOnStart == true and state.alertSent ~= true then
        state.alertSent = true
        ObIlegalServer.SendPoliceAlert(coords)
    end
    broadcastState(robberyId)

    return {
        success = true,
        token = token,
        class = classId,
        stageType = stage.type,
        stageId = stage.id,
        minigame = options,
        timeout = timeout,
    }
end)

lib.callback.register('ob_ilegal:server:finishRobberyStage', function(source, token, successful)
    local session = robberySessions[source]
    if not session or session.token ~= token then
        return { success = false, reason = 'session' }
    end
    if successful ~= true then return failSession(source, 'action_failed') end
    if GetGameTimer() < session.minimumFinishAt then return failSession(source, 'too_fast') end

    local available, reason, playerCoords = ObIlegalServer.IsPlayerAvailable(source)
    local maximumDistance = math.max(2.5, tonumber(session.stage.serverDistance) or 3.0) + 1.5
    if not available or ObIlegalShared.Distance(playerCoords, session.coords) > maximumDistance then
        return failSession(source, reason or 'distance')
    end
    if ObIlegalServer.GetClass(source) ~= session.classId then
        return failSession(source, 'invalid_class')
    end

    local robberyId = session.robberyId
    local robbery = session.robbery
    local state = getState(robberyId)
    local completedStage = session.stage
    local isFinal = session.stageIndex >= #robbery.stages
    local reward, dropCount

    if isFinal then
        local origin = ObIlegalShared.NormalizeCoords(completedStage.rewardOrigin) or session.coords
        local route = Config.Classes[session.classId] or {}
        local created
        created, reward, dropCount = ObIlegalDrops.Create(
            source,
            origin,
            playerCoords,
            route.rewardMultiplier or 1.0,
            robbery.reward
        )
        if not created then return failSession(source, 'inventory') end
    end

    clearSession(source)
    setDoorState(completedStage, false)
    if isFinal then
        state.stageIndex = 1
        state.cooldownUntil = now() + math.max(0, math.floor(tonumber(robbery.cooldown) or 0))
        state.awaitingReset = true
        state.progressExpiresAt = nil
    else
        state.stageIndex = session.stageIndex + 1
        state.progressExpiresAt = now() + math.max(60, math.floor(tonumber(robbery.sequenceTimeout) or 1800))
    end
    broadcastState(robberyId)

    local eventPayload = {
        robberyId = robberyId,
        stageId = completedStage.id,
        stageIndex = session.stageIndex,
        doorId = completedStage.doorId,
        final = isFinal,
        source = source,
    }
    TriggerEvent('ob_ilegal:server:stageCompleted', eventPayload)
    TriggerClientEvent('ob_ilegal:client:stageCompleted', -1, eventPayload)

    return {
        success = true,
        final = isFinal,
        nextStage = isFinal and nil or state.stageIndex,
        reward = reward,
        dropCount = dropCount,
    }
end)

RegisterNetEvent('ob_ilegal:server:cancelRobberyStage', function(token)
    local session = robberySessions[source]
    if session and session.token == token then failSession(source, 'action_failed') end
end)

exports('GetRobberyState', function(robberyId)
    if not getRobbery(robberyId) then return nil end
    return publicState(robberyId)
end)

exports('ResetRobbery', function(robberyId)
    local robbery = getRobbery(robberyId)
    if not robbery then return false end
    local state = getState(robberyId)
    if state.busySource then clearSession(state.busySource) end
    robberyStates[robberyId] = { stageIndex = 1, cooldownUntil = 0 }
    resetDoors(robbery)
    broadcastState(robberyId)
    TriggerEvent('ob_ilegal:server:robberyReset', robberyId)
    TriggerClientEvent('ob_ilegal:client:robberyReset', -1, robberyId)
    return true
end)

AddEventHandler('playerDropped', function()
    if robberySessions[source] then failSession(source, 'action_failed') end
    ObIlegalServer.ReleaseSession(source)
end)

CreateThread(function()
    while true do
        Wait(10000)
        local expired = {}
        for source, session in pairs(robberySessions) do
            if not GetPlayerName(source) or session.timeoutAt <= now() then
                expired[#expired + 1] = source
            end
        end
        for index = 1, #expired do failSession(expired[index], 'action_failed') end

        for robberyId, state in pairs(robberyStates) do
            if state.awaitingReset and (state.cooldownUntil or 0) <= now() then
                state.awaitingReset = nil
                state.alertSent = nil
                resetDoors(getRobbery(robberyId))
                TriggerEvent('ob_ilegal:server:robberyReset', robberyId)
                TriggerClientEvent('ob_ilegal:client:robberyReset', -1, robberyId)
                broadcastState(robberyId)
            elseif not state.busySource
                and state.stageIndex > 1
                and (state.progressExpiresAt or 0) <= now() then
                robberyStates[robberyId] = { stageIndex = 1, cooldownUntil = 0 }
                resetDoors(getRobbery(robberyId))
                TriggerEvent('ob_ilegal:server:robberyReset', robberyId)
                TriggerClientEvent('ob_ilegal:client:robberyReset', -1, robberyId)
                broadcastState(robberyId)
            end
        end
    end
end)
