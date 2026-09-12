local trackedPumas = {}
local pointOccupants = {}
local pointCooldowns = {}
local warnedMissingPoints = false

local function spawnConfig()
    local farm = Config.PumaFarm or {}
    return farm.spawn or {}
end

local function configuredPoints()
    return spawnConfig().points or {}
end

local function pointCoords(point)
    if not point or point.x == nil or point.y == nil or point.z == nil then return nil end
    local x = tonumber(point.x)
    local y = tonumber(point.y)
    local z = tonumber(point.z)
    if not x or not y or not z then return nil end

    return {
        x = x,
        y = y,
        z = z,
        w = tonumber(point.w or point.heading) or 0.0,
    }
end

local function configuredModels()
    local models = {}
    for _, model in ipairs((Config.PumaFarm or {}).models or {}) do
        local hash = type(model) == 'number' and model or joaat(model)
        if hash and hash ~= 0 then models[#models + 1] = hash end
    end
    return models
end

local function closestPlayer(point, routingBucket)
    local closestSource
    local closestDistance = math.huge

    for _, playerId in ipairs(GetPlayers()) do
        local source = tonumber(playerId)
        local playerPed = source and GetPlayerPed(source) or 0
        if playerPed > 0 and DoesEntityExist(playerPed)
            and GetPlayerRoutingBucket(source) == routingBucket then
            local distance = #(GetEntityCoords(playerPed) - vector3(point.x, point.y, point.z))
            if distance < closestDistance then
                closestSource = source
                closestDistance = distance
            end
        end
    end

    return closestSource, closestDistance
end

local function setPointCooldown(pointIndex, delay)
    pointCooldowns[pointIndex] = GetGameTimer() + math.max(0, math.floor(tonumber(delay) or 0))
end

local function releasePuma(entity, shouldDelete, cooldown)
    local record = trackedPumas[entity]
    if not record then return end

    trackedPumas[entity] = nil
    if pointOccupants[record.pointIndex] == entity then
        pointOccupants[record.pointIndex] = nil
    end
    setPointCooldown(record.pointIndex, cooldown)

    if shouldDelete and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end

local function maintainPumas(config)
    local now = GetGameTimer()
    local respawnDelay = math.max(0, math.floor(tonumber(config.respawnDelay) or 90000))
    local corpseLifetime = math.max(60000, math.floor(tonumber(config.unharvestedCorpseLifetime) or 600000))
    local harvestedCleanup = math.max(0, math.floor(tonumber((Config.PumaFarm or {}).cleanupDelay) or 45000))
    local despawnDistance = math.max(
        tonumber(config.activationDistance) or 220.0,
        tonumber(config.despawnDistance) or 320.0
    )
    local routingBucket = math.floor(tonumber(config.routingBucket) or 0)

    local entities = {}
    for entity in pairs(trackedPumas) do entities[#entities + 1] = entity end

    for _, entity in ipairs(entities) do
        local record = trackedPumas[entity]
        if record then
            if not DoesEntityExist(entity) then
                local cooldown = respawnDelay
                if record.harvestedAt then
                    cooldown = math.max(0, respawnDelay - (now - record.harvestedAt))
                end
                releasePuma(entity, false, cooldown)
            else
                local state = Entity(entity).state
                local dead = GetEntityHealth(entity) <= 0

                if state.obVampireHarvested == true then
                    record.harvestedAt = record.harvestedAt or now
                    local elapsed = now - record.harvestedAt
                    if elapsed >= harvestedCleanup then
                        releasePuma(entity, true, math.max(0, respawnDelay - elapsed))
                    end
                elseif dead then
                    record.deadAt = record.deadAt or now
                    if now - record.deadAt >= corpseLifetime then
                        releasePuma(entity, true, respawnDelay)
                    end
                else
                    record.deadAt = nil
                    local point = pointCoords(configuredPoints()[record.pointIndex])
                    local distance = math.huge
                    if point then
                        local _, playerDistance = closestPlayer(point, routingBucket)
                        distance = playerDistance
                    end
                    if not point or distance > despawnDistance then
                        releasePuma(entity, true, 0)
                    end
                end
            end
        end
    end
end

local function clearSpawnedPumas()
    local entities = {}
    for entity in pairs(trackedPumas) do entities[#entities + 1] = entity end
    for _, entity in ipairs(entities) do
        releasePuma(entity, true, 0)
    end
end

local function activeCount()
    local count = 0
    for _ in pairs(trackedPumas) do count = count + 1 end
    return count
end

local function shuffle(values)
    for index = #values, 2, -1 do
        local other = math.random(index)
        values[index], values[other] = values[other], values[index]
    end
end

local function availablePoints(config)
    local candidates = {}
    local now = GetGameTimer()
    local activationDistance = math.max(1.0, tonumber(config.activationDistance) or 220.0)
    local minimumDistance = math.max(0.0, tonumber(config.minimumPlayerDistance) or 28.0)
    local routingBucket = math.floor(tonumber(config.routingBucket) or 0)

    for pointIndex, rawPoint in ipairs(configuredPoints()) do
        local point = pointCoords(rawPoint)
        local cooldownUntil = pointCooldowns[pointIndex] or 0
        if point and not pointOccupants[pointIndex] and now >= cooldownUntil then
            local source, distance = closestPlayer(point, routingBucket)
            if source and distance <= activationDistance and distance >= minimumDistance then
                candidates[#candidates + 1] = {
                    pointIndex = pointIndex,
                    point = point,
                    ownerSource = source,
                }
            end
        end
    end

    shuffle(candidates)
    return candidates
end

local function spawnPuma(candidate, config, models)
    local model = models[math.random(#models)]
    local point = candidate.point
    local spawnHeight = math.max(0.5, tonumber(config.initialSpawnHeight) or 1.5)
    local entity = CreatePed(28, model, point.x, point.y, point.z + spawnHeight, point.w, true, true)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end

    local routingBucket = math.floor(tonumber(config.routingBucket) or 0)
    SetEntityRoutingBucket(entity, routingBucket)
    SetEntityOrphanMode(entity, 2)

    local state = Entity(entity).state
    state:set('obVampireFarmPuma', true, true)
    state:set('obVampireFarmPoint', candidate.pointIndex, true)

    trackedPumas[entity] = {
        pointIndex = candidate.pointIndex,
        spawnedAt = GetGameTimer(),
    }
    pointOccupants[candidate.pointIndex] = entity

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId and netId > 0 then
        TriggerClientEvent('ob_vampiros:client:configureFarmPuma', candidate.ownerSource, netId)
    end
    return true
end

CreateThread(function()
    Wait(2500)

    while true do
        local config = spawnConfig()
        local interval = math.max(1000, math.floor(tonumber(config.checkInterval) or 5000))

        if (Config.PumaFarm or {}).enabled == true and config.enabled == true then
            local points = configuredPoints()
            local models = configuredModels()

            if #points == 0 then
                if not warnedMissingPoints then
                    print('[ob_vampiros] PumaFarm: nenhum ponto configurado em Config.PumaFarm.spawn.points.')
                    warnedMissingPoints = true
                end
            elseif #models == 0 then
                if not warnedMissingPoints then
                    print('[ob_vampiros] PumaFarm: nenhum modelo de puma valido foi configurado.')
                    warnedMissingPoints = true
                end
            else
                warnedMissingPoints = false
                maintainPumas(config)

                local maximum = math.min(#points, math.max(0, math.floor(tonumber(config.maxActive) or 4)))
                local missing = maximum - activeCount()
                local batch = math.min(missing, math.max(1, math.floor(tonumber(config.maxSpawnPerCycle) or 1)))

                if batch > 0 then
                    local candidates = availablePoints(config)
                    for index = 1, math.min(batch, #candidates) do
                        spawnPuma(candidates[index], config, models)
                    end
                end
            end
        else
            clearSpawnedPumas()
        end

        Wait(interval)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    clearSpawnedPumas()
end)
