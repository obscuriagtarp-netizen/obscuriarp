local logger = require '@qbx_core.modules.logger'

local function enableSpawnGhost(netId)
    local ghost = Config.spawnGhost
    if not ghost or ghost.enabled == false then return end

    local durationMs = math.max(0, math.floor(tonumber(ghost.durationMs) or 0))
    if durationMs == 0 then return end

    TriggerClientEvent('qbx_garages:client:setSpawnGhost', -1, netId, durationMs)
end

---@param vehicleId integer
---@param modelName string
local function setVehicleStateToOut(vehicleId, vehicle, modelName)
    local depotPrice = Config.calculateImpoundFee(vehicleId, modelName) or 0
    exports.qbx_vehicles:SaveVehicle(vehicle, {
        state = VehicleState.OUT,
        depotPrice = depotPrice
    })
end

---@param player table
---@param depotPrice integer
local function payDepotPrice(player, depotPrice)
    local cashBalance = player.PlayerData.money.cash
    local bankBalance = player.PlayerData.money.bank

    if cashBalance >= depotPrice then
        player.Functions.RemoveMoney('cash', depotPrice, 'paid-depot')
        return true
    elseif bankBalance >= depotPrice then
        player.Functions.RemoveMoney('bank', depotPrice, 'paid-depot')
        return true
    end
    return false
end

local function getAvailableSpawnPoint(accessPoint)
    local points = accessPoint.spawns
    if type(points) ~= 'table' or not points[1] then
        return accessPoint.spawn or accessPoint.coords
    end

    for i = 1, #points do
        local point = points[i]
        if not Config.distanceCheck or not lib.getClosestVehicle(point.xyz, Config.distanceCheck, false) then
            return point
        end
    end
end

---@param source number
---@param vehicleId integer
---@param garageName string
---@param accessPointIndex integer
---@return number? netId
lib.callback.register('qbx_garages:server:spawnVehicle', function (source, vehicleId, garageName, accessPointIndex)
    local garage = TryGetGarage(source, garageName)
    if not garage then return end

    local accessPoint = garage.accessPoints[accessPointIndex]
    if not accessPoint then
        logger.log({
            source = source,
            message = string.format(
                'Attempted to spawn a vehicle from a non-existent access point index: %d for garage: %s',
                accessPointIndex,
                garageName
            ),
            webhook = Config.logging.webhook.error,
            event = 'error',
            color = 'red'
        })

        return
    end

    local distanceBetweenPlayerAndAccessPoint = #(GetEntityCoords(GetPlayerPed(source)) - accessPoint.coords.xyz)
    if distanceBetweenPlayerAndAccessPoint > 3 then
        logger.log({
            source = source,
            message = string.format(
                'Player attempted to spawn a vehicle but was too far from the access point. Distance: %.2f, Access Point Index: %d, Garage: %s',
                distanceBetweenPlayerAndAccessPoint,
                accessPointIndex,
                garageName
            ),
            webhook = Config.logging.webhook.anticheat,
            event = 'suspicious',
            color = 'white'
        })

        return
    end
    local garageType = GetGarageType(garageName)

    local spawnCoords = getAvailableSpawnPoint(accessPoint)
    if not spawnCoords then
        exports.qbx_core:Notify(source, locale('error.no_space'), 'error')
        return
    end

    local filter = GetPlayerVehicleFilter(source, garageName)
    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId, filter)
    if not playerVehicle then
        exports.qbx_core:Notify(source, locale('error.not_owned'), 'error')
        return
    end
    if not IsPlayerVehicleAllowedInGarage(playerVehicle, garage) then
        exports.qbx_core:Notify(source, locale('error.not_correct_type'), 'error')
        return
    end
    if garageType == GarageType.DEPOT and FindPlateOnServer(playerVehicle.props.plate) then -- If depot, check if vehicle is not already spawned on the map
        return exports.qbx_core:Notify(source, locale('error.not_impound'), 'error')
    end

    if garageType == GarageType.DEPOT and playerVehicle.depotPrice then
        local player = exports.qbx_core:GetPlayer(source)
        OverrideFreeDepotPriceForOutVehicle(playerVehicle)
        local canPay = payDepotPrice(player, playerVehicle.depotPrice)

        if not canPay then
            exports.qbx_core:Notify(source, locale('error.not_enough'), 'error')
            return
        end
    end

    playerVehicle.props.lockState = 1 -- Modify the veh props lock state here to avoid conflicts with the vehicleConfig.noLock system.

    local netId, veh = qbx.spawnVehicle({
        spawnSource = spawnCoords,
        model = playerVehicle.props.model,
        props = playerVehicle.props,
        warp = Config.warpInVehicle and GetPlayerPed(source) or false,
    })

    if Config.doorsLocked then
        if GetResourceState('qbx_vehiclekeys') == 'started' then
            TriggerEvent('qb-vehiclekeys:server:setVehLockState', netId, 2)
        else
            SetVehicleDoorsLocked(veh, 2)
        end
    end

    TriggerClientEvent('vehiclekeys:client:SetOwner', source, playerVehicle.props.plate)

    Entity(veh).state:set('vehicleid', vehicleId, false)
    setVehicleStateToOut(vehicleId, veh, playerVehicle.modelName)
    enableSpawnGhost(netId)
    TriggerEvent('qbx_garages:server:vehicleSpawned', veh)
    return netId
end)

lib.callback.register('qbx_garages:server:spawnFixedVehicle', function(source, garageName, fixedIndex, accessPointIndex)
    local garage = TryGetGarage(source, garageName)
    local player = exports.qbx_core:GetPlayer(source)
    local fixedVehicle = garage and garage.fixedVehicles and garage.fixedVehicles[tonumber(fixedIndex)]
    local accessPoint = garage and garage.accessPoints[tonumber(accessPointIndex)]
    if not garage or not fixedVehicle or not accessPoint or not getCanAccessGarage(player, garage) then return end

    if #(GetEntityCoords(GetPlayerPed(source)) - accessPoint.coords.xyz) > 3.0 then return end
    local spawnCoords = getAvailableSpawnPoint(accessPoint)
    if not spawnCoords then
        exports.qbx_core:Notify(source, locale('error.no_space'), 'error')
        return
    end

    local modelName = tostring(fixedVehicle.model):lower()
    if not VEHICLES[modelName] then return end
    local props = fixedVehicle.props or { model = joaat(modelName), plate = fixedVehicle.plate or 'SERVICO' }
    props.model = props.model or joaat(modelName)
    props.plate = props.plate or fixedVehicle.plate or 'SERVICO'
    local netId, veh = qbx.spawnVehicle({
        spawnSource = spawnCoords,
        model = props.model,
        props = props,
        warp = Config.warpInVehicle and GetPlayerPed(source) or false,
    })
    if Config.doorsLocked then SetVehicleDoorsLocked(veh, 2) end
    TriggerClientEvent('vehiclekeys:client:SetOwner', source, props.plate)
    enableSpawnGhost(netId)
    return netId
end)

function OverrideFreeDepotPriceForOutVehicle(vehicle)
    if VehicleState.OUT ~= vehicle.state then return end
    if vehicle.depotPrice and vehicle.depotPrice > 0 then return end

    vehicle.depotPrice = Config.calculateImpoundFee(vehicle.id, vehicle.modelName)
end
