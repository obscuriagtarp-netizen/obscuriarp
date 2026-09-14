local logger = require '@qbx_core.modules.logger'
local spawningVehicles = {}

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

local function preparePlayerVehicle(playerVehicle)
    local modelName = tostring(playerVehicle and playerVehicle.modelName or '')
    local definition = VEHICLES[modelName] or VEHICLES[modelName:lower()]
    local props = playerVehicle and playerVehicle.props
    if not definition or type(props) ~= 'table' then return nil, modelName end

    local model = tonumber(definition.hash) or joaat(definition.model or modelName)
    local plate = tostring(props.plate or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if not model or model == 0 or plate == '' then return nil, modelName end

    props.model = model
    props.plate = plate
    return props, modelName
end

---@param source number
---@param vehicleId integer
---@param garageName string
---@param accessPointIndex integer
---@return number? netId
lib.callback.register('qbx_garages:server:spawnVehicle', function (source, vehicleId, garageName, accessPointIndex)
    vehicleId = tonumber(vehicleId)
    local garage = TryGetGarage(source, garageName)
    if not garage or not vehicleId then return end

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
    if GetResourceState('ob_vip') == 'started' then
        local called, allowed, rental = pcall(function()
            return exports.ob_vip:CanUseVehicle(source, vehicleId)
        end)
        if not called then
            exports.qbx_core:Notify(source, 'Não foi possível validar a mensalidade VIP agora.', 'error')
            return
        end
        if allowed == false then
            if rental and rental.validationUnavailable then
                exports.qbx_core:Notify(source, 'O sistema VIP ainda está iniciando. Tente novamente em instantes.', 'error')
                return
            end
            local price = rental and tonumber(rental.renewalRunes) or 0
            exports.qbx_core:Notify(source, ('Mensalidade VIP vencida. Renove este veículo por %d Runas.'):format(price), 'error')
            return
        end
    else
        local queried, rental = pcall(MySQL.single.await, [[
            SELECT expires_at, renewal_runes
            FROM ob_vip_vehicle_rentals
            WHERE vehicle_id = ? AND citizenid = ?
            LIMIT 1
        ]], { vehicleId, playerVehicle.citizenid })
        if queried and rental and tonumber(rental.expires_at) <= os.time() then
            exports.qbx_core:Notify(source, ('Mensalidade VIP vencida. Inicie o ob_vip para renovar por %d Runas.'):format(
                tonumber(rental.renewal_runes) or 0
            ), 'error')
            return
        end
    end
    if not IsPlayerVehicleAllowedInGarage(playerVehicle, garage) then
        exports.qbx_core:Notify(source, locale('error.not_correct_type'), 'error')
        return
    end
    local props, modelName = preparePlayerVehicle(playerVehicle)
    if not props then
        logger.log({
            source = source,
            message = ('Invalid vehicle data prevented garage spawn. vehicleId=%s model=%s'):format(vehicleId, modelName),
            webhook = Config.logging.webhook.error,
            event = 'error',
            color = 'red'
        })
        exports.qbx_core:Notify(source, locale('error.spawn_invalid_model'), 'error')
        return
    end
    if spawningVehicles[vehicleId] then
        exports.qbx_core:Notify(source, locale('error.spawn_in_progress'), 'error')
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

    props.lockState = 1 -- Modify the veh props lock state here to avoid conflicts with the vehicleConfig.noLock system.

    spawningVehicles[vehicleId] = source
    local success, netId, veh = pcall(function()
        return qbx.spawnVehicle({
            spawnSource = spawnCoords,
            model = props.model,
            props = props,
            warp = Config.warpInVehicle and GetPlayerPed(source) or false,
        })
    end)
    spawningVehicles[vehicleId] = nil
    if not success or not netId or not veh or veh == 0 then
        logger.log({
            source = source,
            message = ('Vehicle spawn failed. vehicleId=%s model=%s'):format(vehicleId, modelName),
            webhook = Config.logging.webhook.error,
            event = 'error',
            color = 'red'
        })
        exports.qbx_core:Notify(source, locale('error.spawn_failed'), 'error')
        return
    end

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
