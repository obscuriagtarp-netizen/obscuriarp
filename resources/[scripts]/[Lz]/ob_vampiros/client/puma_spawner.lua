local configuredPumas = {}
local pendingPumas = {}

local function spawnConfig()
    return ((Config.PumaFarm or {}).spawn or {})
end

local function pointForEntity(entity)
    local pointIndex = tonumber(Entity(entity).state.obVampireFarmPoint)
    local point = pointIndex and (spawnConfig().points or {})[pointIndex]
    if not point then return nil end
    return point
end

local function settlePedOnGround(entity, point)
    local config = spawnConfig()
    local probeHeight = math.max(20.0, tonumber(config.groundProbeHeight) or 75.0)
    local clearance = math.max(0.01, tonumber(config.groundClearance) or 0.04)
    local minimum = GetModelDimensions(GetEntityModel(entity))
    local modelBottomOffset = minimum and minimum.z and math.max(0.0, -minimum.z) or 0.55
    local timeout = GetGameTimer() + math.max(1000, math.floor(tonumber(config.groundSettleTimeout) or 3000))

    RequestCollisionAtCoord(point.x + 0.0, point.y + 0.0, point.z + 0.0)

    repeat
        local foundGround, groundZ = GetGroundZFor_3dCoord(
            point.x + 0.0,
            point.y + 0.0,
            point.z + probeHeight,
            false
        )
        if foundGround then
            FreezeEntityPosition(entity, true)
            SetEntityCoordsNoOffset(
                entity,
                point.x + 0.0,
                point.y + 0.0,
                groundZ + modelBottomOffset + clearance,
                false,
                false,
                false
            )
            SetEntityHeading(entity, tonumber(point.w or point.heading) or GetEntityHeading(entity))
            Wait(100)
            FreezeEntityPosition(entity, false)
            return true
        end
        Wait(50)
    until GetGameTimer() >= timeout or not DoesEntityExist(entity)

    return false
end

local function configurePuma(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) or IsEntityDead(entity) then return false end
    if not NetworkHasControlOfEntity(entity) then return false end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId <= 0 then return false end

    local point = pointForEntity(entity)
    if not point then return false end

    local config = spawnConfig()
    SetEntityAsMissionEntity(entity, true, false)
    SetPedCanRagdoll(entity, true)
    SetPedCanRagdollFromPlayerImpact(entity, true)
    SetPedKeepTask(entity, true)
    SetBlockingOfNonTemporaryEvents(entity, false)
    SetPedFleeAttributes(entity, 0, false)
    SetPedCombatAbility(entity, 2)
    SetPedCombatMovement(entity, 3)
    SetPedCombatRange(entity, 1)
    SetPedAsEnemy(entity, config.aggressive == true)
    SetPedSeeingRange(entity, tonumber(config.detectionDistance) or 35.0)
    SetPedHearingRange(entity, tonumber(config.detectionDistance) or 35.0)
    SetPedAlertness(entity, config.aggressive == true and 3 or 1)
    settlePedOnGround(entity, point)
    TaskWanderInArea(
        entity,
        point.x + 0.0,
        point.y + 0.0,
        point.z + 0.0,
        math.max(5.0, tonumber(config.roamRadius) or 45.0),
        2.0,
        8.0
    )

    configuredPumas[netId] = entity
    return true
end

local function configureNetworkPuma(netId)
    netId = math.floor(tonumber(netId) or 0)
    if netId <= 0 or pendingPumas[netId] then return end
    pendingPumas[netId] = true

    CreateThread(function()
        local timeout = GetGameTimer() + 8000
        while GetGameTimer() < timeout do
            if NetworkDoesEntityExistWithNetworkId(netId) then
                local entity = NetworkGetEntityFromNetworkId(netId)
                if entity > 0 and DoesEntityExist(entity) then
                    if not NetworkHasControlOfEntity(entity) then
                        NetworkRequestControlOfEntity(entity)
                    elseif configurePuma(entity) then
                        break
                    end
                end
            end
            Wait(100)
        end
        pendingPumas[netId] = nil
    end)
end

RegisterNetEvent('ob_vampiros:client:configureFarmPuma', configureNetworkPuma)

AddStateBagChangeHandler('obVampireFarmPuma', nil, function(bagName, _, value)
    if value ~= true then return end

    CreateThread(function()
        Wait(100)
        local entity = GetEntityFromStateBagName(bagName)
        if entity and entity > 0 and DoesEntityExist(entity) and NetworkHasControlOfEntity(entity) then
            configurePuma(entity)
        end
    end)
end)

CreateThread(function()
    while true do
        Wait(5000)
        for _, entity in ipairs(GetGamePool('CPed')) do
            if DoesEntityExist(entity) and Entity(entity).state.obVampireFarmPuma == true then
                local netId = NetworkGetNetworkIdFromEntity(entity)
                if NetworkHasControlOfEntity(entity) and configuredPumas[netId] ~= entity then
                    configurePuma(entity)
                end
            end
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    configuredPumas = {}
    pendingPumas = {}
end)
