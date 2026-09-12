local enroute = false
local mechPed, mechBlip

---@param veh number
---@param props table|nil
local function applyVehicleProps(veh, props)
    if type(props) ~= 'table' or not veh or veh == 0 then
        return
    end
    lib.setVehicleProperties(veh, props)
end

---@param vehicle number
---@param plate string
---@return boolean
local function plateMatchesVehicle(vehicle, plate)
    if not DoesEntityExist(vehicle) then
        return false
    end
    local text = GetVehicleNumberPlateText(vehicle)
    if type(text) ~= 'string' then
        return false
    end
    return Core.trim(text) == Core.trim(plate)
end

local function goToTargetWalking(_x, _y, _z, vehicle, driver)
    Wait(500)
    TaskWanderStandard(driver, 10.0, 10)
    Notification(i18n.t('apps.icar.client.valet_paid', { amount = Config.ValetPrice }), 'success')
    AddVehiclekeys(vehicle)
    enroute = false
    mechBlip = nil
    Wait(35000)
    if mechPed and DoesEntityExist(mechPed) then
        DeletePed(mechPed)
    end
    mechPed = nil
end

local function goToTarget(x, y, z, vehicle, driver, vehhash, _target)
    enroute = true
    SetPedFleeAttributes(driver, 0, false)
    SetPedCombatAttributes(driver, 5, false)
    SetPedCombatAttributes(driver, 46, true)
    SetPedCanBeTargetted(driver, false)
    SetBlockingOfNonTemporaryEvents(driver, true)

    while enroute do
        Wait(500)
        local player = cache.ped
        local playerPos = GetEntityCoords(player)
        TaskVehicleDriveToCoord(driver, vehicle, playerPos.x, playerPos.y, playerPos.z, 20.0, 0, vehhash, 6, 1, true)
        SetPedCombatAttributes(driver, 17, true)
        SetPedAlertness(driver, 0)
        SetPedKeepTask(driver, true)
        local distanceToTarget = #(playerPos - GetEntityCoords(vehicle))
        if distanceToTarget < 15 then
            if mechBlip then
                RemoveBlip(mechBlip)
            end
            TaskVehicleTempAction(driver, vehicle, 27, 6000)
            if mechPed and DoesEntityExist(mechPed) then
                SetEntityHealth(mechPed, 2000)
            end
            goToTargetWalking(x, y, z, vehicle, driver)
        end
    end
end

---@param props table
---@param vehhash number
---@param driverhash number
local function spawnVehicle(x, y, z, props, vehhash, driverhash)
    local found, spawnPos, spawnHeading = GetClosestVehicleNodeWithHeading(x + math.random(-100, 100), y + math.random(-100, 100), z, 0, 3, 0)
    if not found or not spawnPos then
        Notification(i18n.t('apps.icar.client.spawn_failed'), 'error')
        enroute = false
        return
    end

    local veh = CreateVehicle(vehhash, spawnPos.x, spawnPos.y, spawnPos.z, spawnHeading or 0.0, true, false)
    if not veh or veh == 0 then
        Notification(i18n.t('apps.icar.client.spawn_failed'), 'error')
        enroute = false
        return
    end

    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetEntityAsMissionEntity(veh, true, true)
    ClearAreaOfVehicles(GetEntityCoords(veh), 5000, false, false, false, false, false)
    SetVehicleOnGroundProperly(veh)
    applyVehicleProps(veh, props)

    mechPed = CreatePedInsideVehicle(veh, 26, driverhash, -1, true, false)

    mechBlip = AddBlipForEntity(veh)
    SetBlipFlashes(mechBlip, true)
    SetBlipColour(mechBlip, 5)
    local netID = NetworkGetNetworkIdFromEntity(veh)
    SetNetworkIdExistsOnAllMachines(netID, true)
    SetNetworkIdCanMigrate(netID, true)
    TriggerServerEvent('phone:addVehicleToPersistent', props.plate, netID)
    goToTarget(x, y, z, veh, mechPed, vehhash, nil)
end

---@param envelope table|nil
---@return table|nil
local function enrichVehicleList(envelope)
    if type(envelope) ~= 'table' or not envelope.success or type(envelope.data) ~= 'table' then
        return envelope
    end
    local list = envelope.data.vehicles
    if type(list) ~= 'table' then
        return envelope
    end
    for i = 1, #list do
        local v = list[i]
        if type(v) == 'table' then
            local model = v.name
            if type(model) == 'number' then
                local display = GetDisplayNameFromVehicleModel(model)
                local label = GetLabelText(display)
                v.displayName = (label and label ~= '' and label ~= 'NULL') and label or display
            else
                v.displayName = type(model) == 'string' and model or 'Vehicle'
            end
        end
    end
    return envelope
end

RegisterNUICallback('icar:list', function(_, cb)
    local result = lib.callback.await('phone:icar:list', false, {})
    cb(enrichVehicleList(result))
end)

RegisterNUICallback('icar:setDealershipWaypoint', function(_, cb)
    local loc = Config.IcarDealershipLocation
    local x, y = loc.x, loc.y
    if type(loc) == 'table' and loc.x and loc.y then
        x, y = loc.x, loc.y
    end
    if type(x) == 'number' and type(y) == 'number' then
        SetNewWaypoint(x, y)
    end
    cb({ success = true })
end)

RegisterNUICallback('icar:getQsGarages', function(_, cb)
    if GetResourceState('qs-advancedgarages') ~= 'started' then
        Notification(i18n.t('apps.icar.client.no_advanced_garages'), 'info')
        cb({ success = false, message = i18n.t('apps.icar.client.no_advanced_garages') })
        return
    end
    local data = exports['qs-advancedgarages']:GetGarages()
    cb({ success = true, data = data })
end)

RegisterNUICallback('icar:sellQsGarage', function(data, cb)
    if GetResourceState('qs-advancedgarages') ~= 'started' then
        Notification(i18n.t('apps.icar.client.no_advanced_garages'), 'info')
        cb({ success = false, message = i18n.t('apps.icar.client.no_advanced_garages') })
        return
    end
    local name = data and data.name
    if type(name) ~= 'string' or name == '' then
        cb({ success = false, message = 'Invalid property' })
        return
    end
    local res = exports['qs-advancedgarages']:SellGarage(name)
    cb({ success = true, data = res })
end)

RegisterNUICallback('icar:take', function(data, cb)
    if not Config.Valet then
        Notification(i18n.t('apps.icar.client.valet_disabled'), 'info')
        cb({ success = false, message = i18n.t('apps.icar.client.valet_disabled') })
        return
    end
    local plate = data and data.plate
    local result = lib.callback.await('phone:icar:take', false, { plate = plate })
    cb(result)
end)

RegisterNetEvent('phone:icar:takeVehicle', function(data, inGarage)
    if enroute then
        Notification(i18n.t('apps.icar.client.valet_busy'), 'info')
        return
    end

    if not inGarage then
        Notification(i18n.t('apps.icar.client.not_in_garage'), 'error')
        return
    end

    local pay = lib.callback.await('phone:icar:valetPay', false, {})
    if type(pay) ~= 'table' or not pay.success then
        local msg = type(pay) == 'table' and pay.message or i18n.t('apps.icar.client.no_money')
        Notification(msg, 'error')
        return
    end

    if type(data) ~= 'table' or type(data.plate) ~= 'string' then
        return
    end

    local pool = GetGamePool('CVehicle')
    for i = 1, #pool do
        local vehicle = pool[i]
        if plateMatchesVehicle(vehicle, data.plate) then
            local vehicleCoords = GetEntityCoords(vehicle)
            SetNewWaypoint(vehicleCoords.x, vehicleCoords.y)
            Notification(i18n.t('apps.icar.client.waypoint_set'), 'info')
            return
        end
    end

    TriggerServerEvent('phone:setVehicleToOutSide', data.plate)

    local player = cache.ped
    local playerPos = GetEntityCoords(player)

    local driverhash = 999748158
    local vehhash = data.model
    if type(vehhash) == 'string' then
        vehhash = joaat(vehhash)
    end
    if type(vehhash) ~= 'number' then
        Notification(i18n.t('apps.icar.client.spawn_failed'), 'error')
        return
    end

    lib.requestModel(driverhash)
    lib.requestModel(vehhash)

    spawnVehicle(playerPos.x, playerPos.y, playerPos.z, data, vehhash, driverhash)
end)
