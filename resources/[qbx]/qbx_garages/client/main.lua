local config = require 'config.client'
if not config.enableClient then return end
local VEHICLES = exports.qbx_core:GetVehiclesByName()

SetNuiFocus(false, false)
SetNuiFocusKeepInput(false)

---@enum ProgressColor
local ProgressColor = {
    GREEN = 'green.5',
    YELLOW = 'yellow.5',
    RED = 'red.5'
}

---@param percent number
---@return string
local function getProgressColor(percent)
    if percent >= 75 then
        return ProgressColor.GREEN
    elseif percent > 25 then
        return ProgressColor.YELLOW
    else
        return ProgressColor.RED
    end
end

local VehicleCategory = {
    all = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22},
    car = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 17, 18, 19, 20, 22},
    air = {15, 16},
    sea = {14},
}

---@param category VehicleType
---@param vehicle number
---@return boolean
local function isOfType(category, vehicle)
    if category == VehicleType.ALL then return true end
    if category == VehicleType.CAR and config.universalGarages then return true end

    local classSet = {}

    for _, class in pairs(VehicleCategory[category]) do
        classSet[class] = true
    end

    return classSet[GetVehicleClass(vehicle)] == true
end

---@param vehicle number
local function kickOutPeds(vehicle)
    for i = -1, 5, 1 do
        local seat = GetPedInVehicleSeat(vehicle, i)
        if seat then
            TaskLeaveVehicle(seat, vehicle, 0)
        end
    end
end

local spawnLock = false
local garageUiOpen = false
local activeGarageName
local activeAccessPoint
local activeGarageVehicles = {}
local activePreviewId
local previewVehicle
local previewCamera
local previewSession
local previewRequest = 0
local markerPreviewCoords
local markerPreviewUntil = 0
local markerPreviewRunning = false
local ghostVehicles = {}

local function disableAutomaticHelmet(ped)
    if config.disableAutoHelmet == false or not ped or ped == 0 then return end
    SetPedHelmet(ped, false)
end

local function prepareVehicleForSpawn(vehicle)
    local modelName = tostring(vehicle and vehicle.modelName or '')
    local definition = VEHICLES[modelName] or VEHICLES[modelName:lower()]
    local model = definition and (tonumber(definition.hash) or joaat(definition.model or modelName))
    if not model or model == 0 or not IsModelInCdimage(model) or not IsModelAVehicle(model) then
        exports.qbx_core:Notify(locale('error.spawn_invalid_model'), 'error')
        return false
    end

    vehicle.props = type(vehicle.props) == 'table' and vehicle.props or {}
    vehicle.props.model = model
    return true
end

local function awaitSpawn(event, ...)
    local response = promise.new()
    local pending = true
    local args = table.pack(...)

    CreateThread(function()
        local success, result = pcall(function()
            return lib.callback.await(event, false, table.unpack(args, 1, args.n))
        end)
        if pending then
            pending = false
            response:resolve({ success = success, result = result })
        end
    end)

    SetTimeout(math.max(5000, tonumber(config.spawnTimeoutMs) or 15000), function()
        if not pending then return end
        pending = false
        response:resolve({ timeout = true })
    end)

    local result = Citizen.Await(response)
    if result.timeout then return nil, 'timeout' end
    if not result.success then return nil, 'failed' end
    return result.result
end

CreateThread(function()
    Wait(0)
    disableAutomaticHelmet(cache.ped or PlayerPedId())
end)

lib.onCache('ped', function(ped)
    disableAutomaticHelmet(ped)
end)

lib.onCache('vehicle', function(vehicle)
    if vehicle then disableAutomaticHelmet(cache.ped or PlayerPedId()) end
end)

local function restoreGhostVehicle(record)
    local vehicle = record and record.vehicle
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    ResetEntityAlpha(vehicle)
    SetEntityInvincible(vehicle, false)
end

local function setSpawnGhost(netId, durationMs)
    netId = tonumber(netId)
    durationMs = math.max(0, math.floor(tonumber(durationMs) or 0))
    if not netId or durationMs == 0 then return end

    local token = (ghostVehicles[netId] and ghostVehicles[netId].token or 0) + 1
    ghostVehicles[netId] = { token = token }

    CreateThread(function()
        local waitUntil = GetGameTimer() + 5000
        local vehicle = 0

        repeat
            if NetworkDoesEntityExistWithNetworkId(netId) then
                vehicle = NetToVeh(netId)
            end
            if vehicle ~= 0 and DoesEntityExist(vehicle) then break end
            Wait(50)
        until GetGameTimer() >= waitUntil

        local record = ghostVehicles[netId]
        if not record or record.token ~= token or vehicle == 0 or not DoesEntityExist(vehicle) then
            if record and record.token == token then ghostVehicles[netId] = nil end
            return
        end

        record.vehicle = vehicle
        local ghostConfig = config.spawnGhost or {}
        local alpha = math.max(0, math.min(255, math.floor(tonumber(ghostConfig.alpha) or 185)))
        local collisionRadius = math.max(5.0, tonumber(ghostConfig.collisionRadius) or 35.0)
        local expiresAt = GetGameTimer() + durationMs
        local nearbyVehicles = {}
        local refreshAt = 0

        SetEntityAlpha(vehicle, alpha, false)
        SetEntityInvincible(vehicle, true)

        while GetGameTimer() < expiresAt and DoesEntityExist(vehicle) do
            record = ghostVehicles[netId]
            if not record or record.token ~= token then return end

            local now = GetGameTimer()
            if now >= refreshAt then
                nearbyVehicles = {}
                local vehicleCoords = GetEntityCoords(vehicle)

                for _, otherVehicle in ipairs(GetGamePool('CVehicle')) do
                    if otherVehicle ~= vehicle and DoesEntityExist(otherVehicle) then
                        local distance = #(vehicleCoords - GetEntityCoords(otherVehicle))
                        if distance <= collisionRadius then
                            nearbyVehicles[#nearbyVehicles + 1] = otherVehicle
                        end
                    end
                end

                refreshAt = now + 200
            end

            for i = 1, #nearbyVehicles do
                local otherVehicle = nearbyVehicles[i]
                if DoesEntityExist(otherVehicle) then
                    SetEntityNoCollisionEntity(vehicle, otherVehicle, true)
                    SetEntityNoCollisionEntity(otherVehicle, vehicle, true)
                end
            end

            Wait(0)
        end

        record = ghostVehicles[netId]
        if record and record.token == token then
            restoreGhostVehicle(record)
            ghostVehicles[netId] = nil
        end
    end)
end

RegisterNetEvent('qbx_garages:client:setSpawnGhost', setSpawnGhost)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, record in pairs(ghostVehicles) do
        restoreGhostVehicle(record)
    end
end)

if config.garageMarker and config.garageMarker.previewCommand then
    RegisterCommand(config.garageMarker.previewCommand, function()
        local ped = cache.ped or PlayerPedId()
        local position = GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.0, 0.0)
        local foundGround, groundZ = GetGroundZFor_3dCoord(position.x, position.y, position.z + 3.0, false)
        markerPreviewCoords = vec3(position.x, position.y, foundGround and groundZ or position.z)
        markerPreviewUntil = GetGameTimer() + 20000
        exports.qbx_core:Notify('Prévia do ícone de garagem ativa por 20 segundos.', 'primary')

        if markerPreviewRunning then return end
        markerPreviewRunning = true
        CreateThread(function()
            while markerPreviewCoords and GetGameTimer() < markerPreviewUntil do
                config.drawGarageMarker(markerPreviewCoords, 1.0)
                Wait(0)
            end
            markerPreviewCoords = nil
            markerPreviewRunning = false
        end)
    end, false)
end

local function isPlayerDataReady()
    local playerData = QBX.PlayerData
    return playerData
        and playerData.citizenid
        and playerData.job
        and playerData.gang
end

local function hasPrimaryGroup(groups)
    return isPlayerDataReady() and exports.qbx_core:HasPrimaryGroup(groups) or false
end

local function waitForFade(fadedOut)
    local deadline = GetGameTimer() + 1200
    while GetGameTimer() < deadline do
        if fadedOut == IsScreenFadedOut() then return end
        Wait(0)
    end
end

local function fadeOutShowroom()
    if IsScreenFadedOut() then return end
    DoScreenFadeOut(180)
    waitForFade(true)
end

local function fadeInShowroom()
    DoScreenFadeIn(220)
    waitForFade(false)
end

local function deletePreviewVehicle()
    if previewVehicle and DoesEntityExist(previewVehicle) then
        SetEntityAsMissionEntity(previewVehicle, true, true)
        DeleteEntity(previewVehicle)
    end
    previewVehicle = nil
    activePreviewId = nil
end

local function offsetFrom(coords, offset)
    local result = GetOffsetFromCoordAndHeadingInWorldCoords(
        coords.x,
        coords.y,
        coords.z,
        coords.w or 0.0,
        offset.x,
        offset.y,
        offset.z
    )
    return vec3(result.x, result.y, result.z)
end

local function showroomProfile(garageInfo, accessPoint)
    local custom = accessPoint.preview or garageInfo.preview
    local customType = type(custom)
    local vehicleCoords
    if customType == 'vector3' or customType == 'vector4' then
        vehicleCoords = custom
        custom = {}
    else
        custom = custom or {}
        vehicleCoords = custom.vehicle or accessPoint.spawn or accessPoint.coords
    end

    local profileName = garageInfo.vehicleType == VehicleType.AIR and 'air'
        or garageInfo.vehicleType == VehicleType.SEA and 'sea'
        or 'car'
    local profile = config.showroom.profiles[profileName] or config.showroom.profiles.car
    local heading = vehicleCoords.w or 0.0
    local vehiclePosition = vec4(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z, heading)
    local playerOffset = custom.playerOffset or profile.playerOffset
    local cameraOffset = custom.cameraOffset or profile.cameraOffset
    local lookAtOffset = custom.lookAtOffset or profile.lookAtOffset
    local playerPosition = custom.player or offsetFrom(vehiclePosition, playerOffset)
    local cameraPosition = custom.camera or offsetFrom(vehiclePosition, cameraOffset)
    local lookAt = custom.lookAt or offsetFrom(vehiclePosition, lookAtOffset)
    local alignPedToVehicle = profile.alignPedToVehicle
    if custom.alignPedToVehicle ~= nil then alignPedToVehicle = custom.alignPedToVehicle end

    return {
        vehicle = vehiclePosition,
        player = playerPosition,
        playerHeading = custom.playerHeading or playerPosition.w or (heading + (custom.playerHeadingOffset or profile.playerHeadingOffset or 90.0)),
        playerHeadingOffset = custom.playerHeadingOffset or profile.playerHeadingOffset or 90.0,
        alignPedToVehicle = alignPedToVehicle,
        playerSide = custom.playerSide or profile.playerSide or 'left',
        playerSideGap = tonumber(custom.playerSideGap or profile.playerSideGap) or 0.22,
        playerForwardOffset = tonumber(custom.playerForwardOffset or profile.playerForwardOffset) or 0.0,
        camera = cameraPosition,
        lookAt = lookAt,
        fov = tonumber(custom.fov or profile.fov) or 41.0,
        scenario = custom.scenario or config.showroom.scenario,
        vehicleType = garageInfo.vehicleType,
    }
end

local function startShowroomScenario(profile, position, heading)
    local ped = cache.ped or PlayerPedId()
    SetEntityCoordsNoOffset(ped, position.x, position.y, position.z, false, false, false)
    SetEntityHeading(ped, heading)
    ClearPedTasksImmediately(ped)
    TaskStartScenarioAtPosition(
        ped,
        profile.scenario,
        position.x,
        position.y,
        position.z,
        heading,
        -1,
        true,
        true
    )
    FreezeEntityPosition(ped, true)
end

local function alignShowroomPedToVehicle(vehicle)
    if not previewSession or not DoesEntityExist(vehicle) then return end

    local profile = previewSession.profile
    if not profile.alignPedToVehicle then return end

    local minimum, maximum = GetModelDimensions(GetEntityModel(vehicle))
    local sideOffset = profile.playerSide == 'right'
        and (maximum.x + profile.playerSideGap)
        or (minimum.x - profile.playerSideGap)
    local position = GetOffsetFromEntityInWorldCoords(vehicle, sideOffset, profile.playerForwardOffset, 0.0)
    local groundPosition = vec3(position.x, position.y, profile.player.z)
    local heading = GetEntityHeading(vehicle) + profile.playerHeadingOffset
    startShowroomScenario(profile, groundPosition, heading)

    local ped = cache.ped or PlayerPedId()
    local deadline = GetGameTimer() + 800
    while GetGameTimer() < deadline and not IsPedUsingScenario(ped, profile.scenario) do
        Wait(0)
    end
    if not previewSession.pedReady then
        Wait(350)
        SetEntityVisible(ped, true, false)
        previewSession.pedReady = true
    end
end

local function showPreviewVehicle(vehicleData)
    if not previewSession or not vehicleData then return false end
    local id = tostring(vehicleData.id)
    if activePreviewId == id and previewVehicle and DoesEntityExist(previewVehicle) then return true end

    previewRequest += 1
    local request = previewRequest
    local model = joaat(tostring(vehicleData.modelName or ''))
    if not IsModelInCdimage(model) or not IsModelAVehicle(model) then return false end

    local loaded = pcall(lib.requestModel, model, 10000)
    if not loaded or request ~= previewRequest or not previewSession then return false end

    deletePreviewVehicle()
    local position = previewSession.profile.vehicle
    RequestCollisionAtCoord(position.x, position.y, position.z)
    previewVehicle = CreateVehicle(model, position.x, position.y, position.z, position.w, false, false)
    if previewVehicle == 0 then
        previewVehicle = nil
        SetModelAsNoLongerNeeded(model)
        return false
    end

    SetEntityAsMissionEntity(previewVehicle, true, true)
    SetEntityCollision(previewVehicle, false, false)
    SetEntityInvincible(previewVehicle, true)
    SetVehicleDoorsLocked(previewVehicle, 2)
    SetVehicleEngineOn(previewVehicle, false, true, true)
    SetVehicleLights(previewVehicle, 2)
    SetVehicleDirtLevel(previewVehicle, 0.0)
    pcall(function()
        lib.setVehicleProperties(previewVehicle, vehicleData.props or {})
    end)
    if previewSession.profile.vehicleType ~= VehicleType.SEA then
        SetVehicleOnGroundProperly(previewVehicle)
    end
    FreezeEntityPosition(previewVehicle, true)
    alignShowroomPedToVehicle(previewVehicle)

    activePreviewId = id
    SetEntityAlpha(previewVehicle, 0, false)
    for alpha = 55, 255, 50 do
        if request ~= previewRequest or not DoesEntityExist(previewVehicle) then break end
        SetEntityAlpha(previewVehicle, math.min(alpha, 255), false)
        Wait(18)
    end
    if previewVehicle and DoesEntityExist(previewVehicle) then ResetEntityAlpha(previewVehicle) end
    SetModelAsNoLongerNeeded(model)
    return true
end

local function enterGarageShowroom(garageName, garageInfo, accessPoint)
    local profile = showroomProfile(garageInfo, accessPoint)
    local callbackOk, entered = pcall(function()
        return lib.callback.await('qbx_garages:server:enterPreview', false, garageName)
    end)
    if not callbackOk or not entered then return false end

    fadeOutShowroom()
    local ped = cache.ped
    local current = GetEntityCoords(ped)
    previewSession = {
        returnPosition = vec4(current.x, current.y, current.z, GetEntityHeading(ped)),
        profile = profile,
        pedReady = false,
    }

    RequestCollisionAtCoord(profile.vehicle.x, profile.vehicle.y, profile.vehicle.z)
    SetFocusPosAndVel(profile.vehicle.x, profile.vehicle.y, profile.vehicle.z, 0.0, 0.0, 0.0)
    ClearPedTasksImmediately(ped)
    SetEntityVisible(ped, false, false)
    SetEntityCoordsNoOffset(ped, profile.player.x, profile.player.y, profile.player.z, false, false, false)
    SetEntityHeading(ped, profile.playerHeading)
    FreezeEntityPosition(ped, true)

    previewCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(previewCamera, profile.camera.x, profile.camera.y, profile.camera.z)
    PointCamAtCoord(previewCamera, profile.lookAt.x, profile.lookAt.y, profile.lookAt.z)
    SetCamFov(previewCamera, profile.fov)
    SetCamActive(previewCamera, true)
    RenderScriptCams(true, false, 0, true, true)
    return true
end

local function leaveGarageShowroom(skipServer)
    if not previewSession then return end
    fadeOutShowroom()
    previewRequest += 1
    deletePreviewVehicle()

    if previewCamera and DoesCamExist(previewCamera) then
        SetCamActive(previewCamera, false)
        DestroyCam(previewCamera, false)
    end
    previewCamera = nil
    RenderScriptCams(false, false, 0, true, true)
    ClearFocus()

    local ped = cache.ped
    local returnPosition = previewSession.returnPosition
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityCoordsNoOffset(ped, returnPosition.x, returnPosition.y, returnPosition.z, false, false, false)
    SetEntityHeading(ped, returnPosition.w)
    previewSession = nil
    if not skipServer then
        pcall(function()
            lib.callback.await('qbx_garages:server:exitPreview', false)
        end)
    end
    fadeInShowroom()
end

local function closeGarageUi(force)
    if not force and not garageUiOpen then return end
    garageUiOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
    leaveGarageShowroom(false)
    activeGarageName = nil
    activeAccessPoint = nil
    activeGarageVehicles = {}
end

local function formatGarageMoney(value)
    local amount = math.floor(tonumber(value) or 0)
    local formatted = tostring(amount)
    while true do
        local replaced, count = formatted:gsub('^(-?%d+)(%d%d%d)', '%1.%2')
        formatted = replaced
        if count == 0 then break end
    end
    return formatted
end

local function getVehicleDisplayClass(vehicle, garage)
    if vehicle.displayClass then return vehicle.displayClass end
    if garage.vehicleUiClasses and garage.vehicleUiClasses[vehicle.modelName] then
        return garage.vehicleUiClasses[vehicle.modelName]
    end
    if garage.uiClass then return garage.uiClass end
    if garage.vehicleType == VehicleType.AIR then return 'vip' end
    if garage.vehicleType == VehicleType.SEA then return 'truck' end
    return 'car'
end

local function getVehicleLabel(vehicle)
    local definition = VEHICLES[vehicle.modelName] or {}
    local brand = definition.brand or ''
    local name = vehicle.label or definition.name or vehicle.modelName or 'Veículo'
    if brand ~= '' and not name:lower():find(brand:lower(), 1, true) then
        return ('%s %s'):format(brand, name)
    end
    return name
end

local function getVehicleCard(vehicle, garage)
    local props = vehicle.props or {}
    local modelName = tostring(vehicle.modelName or ''):lower()
    local engine = math.max(0, math.min(100, math.floor((tonumber(props.engineHealth) or 1000) / 10)))
    local body = math.max(0, math.min(100, math.floor((tonumber(props.bodyHealth) or 1000) / 10)))
    local fuel = math.max(0, math.min(100, math.floor(tonumber(props.fuelLevel) or 100)))
    local tyres = tonumber(props.tireHealth or props.tyreHealth or 100) or 100
    tyres = math.max(0, math.min(100, math.floor(tyres)))
    local primaryColor = props.color1 or props.primaryColor or props.customPrimaryColor
    local color = type(primaryColor) == 'table' and table.concat(primaryColor, ', ') or tostring(primaryColor or 'Original')

    local vipRental = type(vehicle.vipRental) == 'table' and vehicle.vipRental or nil
    local rentalExpired = vipRental and vipRental.managed == true and vipRental.active ~= true

    return {
        id = vehicle.id,
        fixed = vehicle.fixed == true,
        fixedIndex = vehicle.fixedIndex,
        model = modelName,
        name = getVehicleLabel(vehicle),
        brand = (VEHICLES[vehicle.modelName] or {}).brand or 'Obscuria',
        plate = tostring(props.plate or 'SEM PLACA'):sub(1, 8),
        displayClass = getVehicleDisplayClass(vehicle, garage),
        state = vehicle.state,
        stateLabel = rentalExpired and ((vipRental.label or 'Locação do veículo') .. ' vencida')
            or (vehicle.fixed and 'Serviço disponível' or (vehicle.state == VehicleState.IMPOUNDED and 'No pátio' or 'Pronto para retirar')),
        depotPrice = formatGarageMoney(vehicle.depotPrice),
        vipRental = vipRental,
        metrics = {
            engine = engine,
            body = body,
            fuel = fuel,
            tyres = tyres,
            color = color,
        },
        tunings = {
            engine = tonumber(props.modEngine) or 0,
            armor = tonumber(props.modArmor) or 0,
            turbo = props.modTurbo == true,
            brakes = tonumber(props.modBrakes) or 0,
            transmission = tonumber(props.modTransmission) or 0,
            suspension = tonumber(props.modSuspension) or 0,
        },
    }
end

---@param vehicle table
---@param garageName string
---@param accessPoint integer
local function takeOutOfGarage(vehicle, garageName, accessPoint)
    if spawnLock then
        exports.qbx_core:Notify(locale('error.spawn_in_progress'), 'error')
        return
    end
    if not prepareVehicleForSpawn(vehicle) then return end
    spawnLock = true

    local success, result = pcall(function()
        if cache.vehicle then
            exports.qbx_core:Notify(locale('error.in_vehicle'), 'error')
            return
        end

        local netId
        local spawnError
        if vehicle.fixed then
            netId, spawnError = awaitSpawn('qbx_garages:server:spawnFixedVehicle', garageName, vehicle.fixedIndex, accessPoint)
        else
            netId, spawnError = awaitSpawn('qbx_garages:server:spawnVehicle', vehicle.id, garageName, accessPoint)
        end
        if not netId then
            exports.qbx_core:Notify(locale(spawnError == 'timeout' and 'error.spawn_timeout' or 'error.spawn_failed'), 'error')
            return
        end

        local veh = lib.waitFor(function()
            if NetworkDoesEntityExistWithNetworkId(netId) then
                return NetToVeh(netId)
            end
        end)

        if veh == 0 then
            exports.qbx_core:Notify(locale('error.spawn_failed'), 'error')
            return
        end

        if config.engineOn then
            SetVehicleEngineOn(veh, true, true, false)
        end
    end)
    spawnLock = false
    if not success then
        print(('^1[qbx_garages] Falha local ao retirar veículo: %s^7'):format(tostring(result)))
        exports.qbx_core:Notify(locale('error.spawn_failed'), 'error')
    end
end

---@param garageName string
---@param garageInfo GarageConfig
---@param accessPoint integer
local function openGarageMenu(garageName, garageInfo, accessPoint)
    ---@type PlayerVehicle[]?
    local vehicleEntities = lib.callback.await('qbx_garages:server:getGarageVehicles', false, garageName)

    if not vehicleEntities then
        exports.qbx_core:Notify(locale('error.no_vehicles'), 'error')
        return
    end

    table.sort(vehicleEntities, function(a, b) return getVehicleLabel(a) < getVehicleLabel(b) end)
    local vehicles = {}
    activeGarageVehicles = {}
    for i = 1, #vehicleEntities do
        local entity = vehicleEntities[i]
        local card = getVehicleCard(entity, garageInfo)
        vehicles[i] = card
        activeGarageVehicles[tostring(card.id)] = entity
    end

    local accessPointInfo = garageInfo.accessPoints[accessPoint]
    if not enterGarageShowroom(garageName, garageInfo, accessPointInfo) then
        activeGarageVehicles = {}
        exports.qbx_core:Notify('Não foi possível abrir a garagem.', 'error')
        return
    end
    pcall(showPreviewVehicle, vehicleEntities[1])

    activeGarageName = garageName
    activeAccessPoint = accessPoint
    garageUiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        garage = {
            name = garageName,
            label = garageInfo.label,
            uiClass = garageInfo.uiClass or 'car',
            type = garageInfo.type,
        },
        vehicles = vehicles,
    })
    fadeInShowroom()
end

RegisterNUICallback('close', function(_, cb)
    closeGarageUi()
    cb({ ok = true })
end)

RegisterNUICallback('ready', function(_, cb)
    closeGarageUi(true)
    cb({ ok = true })
end)

RegisterNUICallback('previewVehicle', function(data, cb)
    if not garageUiOpen then
        cb({ ok = false })
        return
    end
    local selected = activeGarageVehicles[tostring(data and data.id)]
    local success, result = pcall(showPreviewVehicle, selected)
    cb({ ok = success and result == true })
end)

RegisterNUICallback('renewVipVehicle', function(data, cb)
    if not garageUiOpen then
        cb({ ok = false, error = 'garage_closed' })
        return
    end
    local selected = activeGarageVehicles[tostring(data and data.id)]
    if not selected or selected.fixed then
        cb({ ok = false, error = 'rental_not_found' })
        return
    end
    if GetResourceState('ob_vip') ~= 'started' then
        cb({ ok = false, error = 'vip_unavailable' })
        return
    end

    local result = lib.callback.await('ob_vip:server:renewVehicle', false, selected.id)
        or { ok = false, error = 'renewal_failed' }
    if result.ok and type(result.rental) == 'table' then
        selected.vipRental = result.rental
        exports.qbx_core:Notify(('Veículo liberado por mais %d dias.'):format(tonumber(result.rental.durationDays) or 30), 'success')
    else
        local messages = {
            insufficient_runes = 'Você não possui Runas suficientes para renovar este veículo.',
            rental_busy = 'Esta mensalidade já está sendo processada.',
            rental_not_found = 'A mensalidade deste veículo não foi encontrada.',
            rental_active = 'Este veículo já está com a mensalidade ativa.',
            vip_unavailable = 'O sistema VIP não está disponível agora.',
            slow_down = 'Aguarde um instante antes de tentar renovar novamente.',
            database_initializing = 'O sistema VIP ainda está iniciando.',
        }
        exports.qbx_core:Notify(messages[result.error] or 'Não foi possível renovar o veículo. Nenhuma Runa foi perdida.', 'error')
    end
    cb(result)
end)

RegisterNUICallback('spawn', function(data, cb)
    if not garageUiOpen or not activeGarageName or not activeAccessPoint then
        cb({ ok = false })
        return
    end
    local selected = activeGarageVehicles[tostring(data and data.id)]
    if not selected then
        cb({ ok = false })
        return
    end
    local garageName = activeGarageName
    local accessPoint = activeAccessPoint
    closeGarageUi()
    takeOutOfGarage(selected, garageName, accessPoint)
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if garageUiOpen then
            HideHudAndRadarThisFrame()
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            Wait(0)
        else
            Wait(250)
        end
    end
end)

---@param vehicle number
---@param garageName string
local function parkVehicle(vehicle, garageName)
    if GetVehicleNumberOfPassengers(vehicle) ~= 1 then
        local isParkable = lib.callback.await('qbx_garages:server:isParkable', false, garageName, NetworkGetNetworkIdFromEntity(vehicle))

        if not isParkable then
            exports.qbx_core:Notify(locale('error.not_owned'), 'error', 5000)
            return
        end

        kickOutPeds(vehicle)
        SetVehicleDoorsLocked(vehicle, 2)
        Wait(1500)
        lib.callback.await('qbx_garages:server:parkVehicle', false, NetworkGetNetworkIdFromEntity(vehicle), lib.getVehicleProperties(vehicle), garageName)
        exports.qbx_core:Notify(locale('success.vehicle_parked'), 'primary', 4500)
    else
        exports.qbx_core:Notify(locale('error.vehicle_occupied'), 'error', 3500)
    end
end

---@param garage GarageConfig
---@return boolean
local function checkCanAccess(garage)
    if garage.groups and not hasPrimaryGroup(garage.groups) then
        exports.qbx_core:Notify(locale('error.no_access'), 'error')
        return false
    end
    if cache.vehicle and not isOfType(garage.vehicleType, cache.vehicle) then
        exports.qbx_core:Notify(locale('error.not_correct_type'), 'error')
        return false
    end
    return true
end

---@param garageName string
---@param garage GarageConfig
---@param accessPoint AccessPoint
---@param accessPointIndex integer
local function createZones(garageName, garage, accessPoint, accessPointIndex)
    CreateThread(function()
        accessPoint.dropPoint = accessPoint.dropPoint or accessPoint.spawn
        local drawRadius = accessPoint.drawRadius or 60
        local dropDrawRadius = accessPoint.dropDrawRadius or 60
        local useRadius = accessPoint.useRadius or 1
        local dropUseRadius = accessPoint.dropUseRadius or 1.5
        local dropZone, coordsZone
        local dropPromptShown = false
        local function createDropZone()
            if dropZone then return end
            dropZone = lib.zones.sphere({
                coords = accessPoint.dropPoint,
                radius = dropUseRadius,
                onEnter = function()
                    if cache.vehicle then
                        dropPromptShown = true
                        lib.showTextUI(locale('info.park_e'))
                    end
                end,
                onExit = function()
                    if dropPromptShown then
                        dropPromptShown = false
                        lib.hideTextUI()
                    end
                end,
                inside = function()
                    if not cache.vehicle then
                        if dropPromptShown then
                            dropPromptShown = false
                            lib.hideTextUI()
                        end
                        return
                    end

                    if not dropPromptShown then
                        dropPromptShown = true
                        lib.showTextUI(locale('info.park_e'))
                    end

                    if IsControlJustReleased(0, 38) then
                        if not checkCanAccess(garage) then return end
                        parkVehicle(cache.vehicle, garageName)
                    end
                end,
                debug = config.debugPoly
            })
        end

        local function createCoordsZone()
            if coordsZone then return end
            coordsZone = lib.zones.sphere({
                coords = accessPoint.coords,
                radius = useRadius,
                onEnter = function()
                    if accessPoint.dropPoint and cache.vehicle then return end
                    lib.showTextUI((garage.type == GarageType.DEPOT and locale('info.impound_e')) or (cache.vehicle and locale('info.park_e')) or locale('info.car_e'))
                end,
                onExit = function()
                    lib.hideTextUI()
                end,
                inside = function()
                    if accessPoint.dropPoint and cache.vehicle then return end
                    if IsControlJustReleased(0, 38) then
                        if not checkCanAccess(garage) then return end
                        if cache.vehicle and garage.type ~= GarageType.DEPOT then
                            parkVehicle(cache.vehicle, garageName)
                        else
                            openGarageMenu(garageName, garage, accessPointIndex)
                        end
                    end
                end,
                debug = config.debugPoly
            })
        end

        lib.zones.sphere({
            coords = accessPoint.coords,
            radius = drawRadius,
            onEnter = function()
                createCoordsZone()
            end,
            onExit = function()
                if coordsZone then
                    coordsZone:remove()
                    coordsZone = nil
                end
            end,
            inside = function()
                config.drawGarageMarker(accessPoint.coords.xyz, useRadius)
            end,
            debug = config.debugPoly,
        })

        if accessPoint.dropPoint and garage.type ~= GarageType.DEPOT then
            lib.zones.sphere({
                coords = accessPoint.dropPoint,
                radius = dropDrawRadius,
                onEnter = function()
                    createDropZone()
                end,
                onExit = function()
                    if dropZone then
                        dropZone:remove()
                        dropZone = nil
                    end
                    dropPromptShown = false
                end,
                inside = function()
                    config.drawDropOffMarker(accessPoint.dropPoint, dropUseRadius)
                end,
                debug = config.debugPoly,
            })
        end
    end)
end

---@param garageInfo GarageConfig
---@param accessPoint AccessPoint
local function createBlips(garageInfo, accessPoint)
    if garageInfo.blipOnlyForGroups and garageInfo.groups and not hasPrimaryGroup(garageInfo.groups) then
        return
    end
    local blip = AddBlipForCoord(accessPoint.coords.x, accessPoint.coords.y, accessPoint.coords.z)
    SetBlipSprite(blip, accessPoint.blip.sprite or 357)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.45)
    SetBlipAsShortRange(blip, true)
    SetBlipColour(blip, accessPoint.blip.color or 3)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(accessPoint.blip.name or garageInfo.label)
    EndTextCommandSetBlipName(blip)
end

local function createGarage(name, garage)
    local accessPoints = garage.accessPoints
    for i = 1, #accessPoints do
        local accessPoint = accessPoints[i]

        if accessPoint.blip then
            createBlips(garage, accessPoint)
        end

        createZones(name, garage, accessPoint, i)
    end
end

local function createGarages()
    local garages = lib.callback.await('qbx_garages:server:getGarages')
    for name, garage in pairs(garages) do
        createGarage(name, garage)
    end
end

RegisterNetEvent('qbx_garages:client:garageRegistered', function(name, garage)
    CreateThread(function()
        while not isPlayerDataReady() do
            Wait(250)
        end

        createGarage(name, garage)
    end)
end)

CreateThread(function()
    closeGarageUi(true)

    while not isPlayerDataReady() do
        Wait(250)
    end

    createGarages()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    leaveGarageShowroom(true)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
end)
