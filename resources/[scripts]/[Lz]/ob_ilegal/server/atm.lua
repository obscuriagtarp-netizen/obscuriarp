local atmStates = {}
local sessions = {}
local modelLookup = {}

for _, modelName in ipairs(Config.Atm.models) do
    modelLookup[ObIlegalShared.ModelKey(joaat(modelName))] = true
end

local function now()
    return os.time()
end

local function stateRemaining(state)
    if not state then return 0 end
    if state.busySource then return math.max(1, state.timeoutAt - now()) end
    return math.max(0, (state.cooldownUntil or 0) - now())
end

local function broadcastState(key, status, remaining)
    TriggerClientEvent('ob_ilegal:client:atmState', -1, key, status, remaining or 0)
end

local function stopEffects(key)
    TriggerClientEvent('ob_ilegal:client:stopAtmFx', -1, key)
end

local function clearSession(source, cooldown)
    local session = sessions[source]
    if not session then return nil end
    sessions[source] = nil
    ObIlegalServer.ReleaseSession(source, session.token)
    cooldown = math.max(0, math.floor(tonumber(cooldown) or 0))

    local state = atmStates[session.key]
    if state and state.busySource == source and state.token == session.token then
        state.busySource = nil
        state.token = nil
        state.timeoutAt = nil
        state.cooldownUntil = cooldown > 0 and (now() + cooldown) or nil

        if state.cooldownUntil then
            broadcastState(session.key, 'cooldown', cooldown)
        else
            atmStates[session.key] = nil
            broadcastState(session.key, 'available', 0)
        end
    end
    stopEffects(session.key)
    return session
end

local function validateAtmPayload(payload)
    if type(payload) ~= 'table' then return nil end
    local model = tonumber(payload.model)
    local modelKey = ObIlegalShared.ModelKey(model)
    local coords = ObIlegalShared.NormalizeCoords(payload.coords)
    if not model or not modelKey or not coords or not modelLookup[modelKey] then return nil end
    local key = ObIlegalShared.AtmKey(model, coords)
    if not key then return nil end
    return model, coords, key
end

local function maybeAlert(session, chance)
    if session.alerted then return end
    chance = math.max(0.0, math.min(1.0, tonumber(chance) or 0.0))
    if math.random() <= chance then
        session.alerted = true
        ObIlegalServer.SendPoliceAlert(session.coords)
    end
end

local function failSession(source, reason)
    local session = sessions[source]
    if session then maybeAlert(session, 1.0) end
    clearSession(source, Config.Atm.failureCooldown)
    return { success = false, reason = reason or 'action_failed' }
end

lib.callback.register('ob_ilegal:server:getAtmStates', function()
    local result = {}
    for key, state in pairs(atmStates) do
        local remaining = stateRemaining(state)
        if remaining > 0 then
            result[key] = {
                status = state.busySource and 'busy' or 'cooldown',
                remaining = remaining,
            }
        else
            atmStates[key] = nil
        end
    end
    return result
end)

lib.callback.register('ob_ilegal:server:beginAtm', function(source, payload)
    if sessions[source] or ObIlegalServer.HasActiveSession(source) then
        return { success = false, reason = 'busy' }
    end

    local playerState = Player(source).state
    if playerState.obIlegalBusy == true
        or playerState.obscuriaPowerBlocked == true
        or playerState.magicFauna == true
        or playerState.obHypnotized == true then
        return { success = false, reason = 'busy' }
    end

    local classId, route = ObIlegalServer.GetClass(source)
    if not route or route.enabled ~= true then
        return { success = false, reason = 'invalid_class' }
    end

    local available, reason, playerCoords = ObIlegalServer.IsPlayerAvailable(source)
    if not available then return { success = false, reason = reason } end

    local model, coords, key = validateAtmPayload(payload)
    if not model then return { success = false, reason = 'invalid_atm' } end
    if ObIlegalShared.Distance(playerCoords, coords) > Config.Atm.serverDistance then
        return { success = false, reason = 'invalid_atm' }
    end

    local state = atmStates[key]
    if state then
        local remaining = stateRemaining(state)
        if remaining > 0 then
            return {
                success = false,
                reason = state.busySource and 'busy' or 'cooldown',
                key = key,
                remaining = remaining,
            }
        end
        atmStates[key] = nil
    end

    if ObIlegalServer.CountPolice() < (tonumber(Config.Police.minimum) or 0) then
        return { success = false, reason = 'police' }
    end
    if not ObIlegalServer.HasItem(source, route.requiredItem) then
        return { success = false, reason = 'item' }
    end
    if not ObIlegalServer.ConsumeEssence(source, route.essenceCost) then
        return { success = false, reason = 'essence' }
    end
    if not ObIlegalServer.TakeRequiredItem(source, route.requiredItem) then
        return { success = false, reason = 'item' }
    end

    local duration = math.max(1, tonumber(route.duration) or 5)
    local timeout = classId == 'humano' and 70 or math.max(45, math.ceil(duration * 3 + 12))
    local token = ('%d:%d:%d:%d'):format(source, now(), GetGameTimer(), math.random(100000, 999999))
    local session = {
        source = source,
        token = token,
        key = key,
        model = model,
        coords = coords,
        classId = classId,
        route = route,
        startedAt = GetGameTimer(),
        minimumFinishAt = GetGameTimer() + math.max(1500, math.floor(duration * 450)),
        timeoutAt = now() + timeout,
        alerted = false,
        impacted = false,
    }

    if not ObIlegalServer.ClaimSession(source, 'atm', token) then
        return { success = false, reason = 'busy' }
    end

    sessions[source] = session
    atmStates[key] = {
        busySource = source,
        token = token,
        timeoutAt = session.timeoutAt,
        coords = coords,
        model = model,
    }

    broadcastState(key, 'busy', timeout)
    TriggerClientEvent('ob_ilegal:client:startAtmFx', -1, key, classId, coords, source, timeout * 1000)
    maybeAlert(session, route.alertChance)

    return {
        success = true,
        token = token,
        key = key,
        class = classId,
        duration = duration,
        timeout = timeout,
    }
end)

lib.callback.register('ob_ilegal:server:impactAtm', function(source, token)
    local session = sessions[source]
    if not session or session.token ~= token or session.impacted then
        return { success = false, reason = 'session' }
    end

    local available, reason, playerCoords = ObIlegalServer.IsPlayerAvailable(source)
    local maximumDistance = (tonumber(Config.Atm.serverDistance) or 3.5) + 2.0
    if not available or ObIlegalShared.Distance(playerCoords, session.coords) > maximumDistance then
        return { success = false, reason = reason or 'invalid_atm' }
    end

    local currentClass = ObIlegalServer.GetClass(source)
    if currentClass ~= session.classId then
        return { success = false, reason = 'invalid_class' }
    end

    session.impacted = true
    session.impactedAt = GetGameTimer()
    TriggerClientEvent('ob_ilegal:client:routeImpact', -1, {
        key = session.key,
        classId = session.classId,
        coords = session.coords,
        sourceId = source,
    })
    return { success = true }
end)

lib.callback.register('ob_ilegal:server:finishAtm', function(source, token, successful)
    local session = sessions[source]
    if not session or session.token ~= token then
        return { success = false, reason = 'session' }
    end

    if successful ~= true then
        return failSession(source, 'action_failed')
    end

    if GetGameTimer() < session.minimumFinishAt then
        return failSession(source, 'too_fast')
    end

    if session.impacted ~= true then
        return failSession(source, 'action_failed')
    end

    local available, reason, playerCoords = ObIlegalServer.IsPlayerAvailable(source)
    if not available or ObIlegalShared.Distance(playerCoords, session.coords) > Config.Atm.serverDistance then
        return failSession(source, reason or 'invalid_atm')
    end

    local currentClass = ObIlegalServer.GetClass(source)
    if currentClass ~= session.classId then
        return failSession(source, 'invalid_class')
    end

    local created, reward, dropCount = ObIlegalDrops.Create(
        source,
        session.coords,
        playerCoords,
        session.route.rewardMultiplier
    )
    if not created then return failSession(source, 'inventory') end
    clearSession(source, Config.Atm.successCooldown)

    return { success = true, reward = reward, dropCount = dropCount }
end)

RegisterNetEvent('ob_ilegal:server:cancelAtm', function(token)
    local source = source
    local session = sessions[source]
    if session and session.token == token then
        failSession(source, 'action_failed')
    end
end)

AddEventHandler('playerDropped', function()
    failSession(source, 'action_failed')
end)

CreateThread(function()
    while true do
        Wait(10000)
        local expired = {}
        for source, session in pairs(sessions) do
            if not GetPlayerName(source) or session.timeoutAt <= now() then
                expired[#expired + 1] = source
            end
        end
        for i = 1, #expired do
            failSession(expired[i], 'action_failed')
        end

        for key, state in pairs(atmStates) do
            if not state.busySource and stateRemaining(state) <= 0 then
                atmStates[key] = nil
                broadcastState(key, 'available', 0)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for key in pairs(atmStates) do stopEffects(key) end
end)
