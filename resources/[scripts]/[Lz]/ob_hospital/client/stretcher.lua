local registered = {}
local pushing
local patientNetId
local pushTextVisible = false

local function showPushText()
    if pushTextVisible then return end
    lib.showTextUI(('[%s] Soltar maca'):format(Config.Stretcher.releaseKey or 'X'))
    pushTextVisible = true
end

local function hidePushText()
    if not pushTextVisible then return end
    lib.hideTextUI()
    pushTextVisible = false
end

local function playPushAnimation()
    local animation = Config.Stretcher.pushAnimation
    if not animation then return end

    local ped = PlayerPedId()
    if IsEntityPlayingAnim(ped, animation.dict, animation.clip, 3) then return end

    lib.requestAnimDict(animation.dict, 10000)
    TaskPlayAnim(ped, animation.dict, animation.clip, 2.0, 2.0, -1, animation.flag or 49, 0.0, false, false, false)
end

local function stopPushAnimation()
    local animation = Config.Stretcher.pushAnimation
    if not animation then return end
    StopAnimTask(PlayerPedId(), animation.dict, animation.clip, 1.5)
end

local function requestControl(entity)
    if NetworkHasControlOfEntity(entity) then return true end
    NetworkRequestControlOfEntity(entity)
    local timeout = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do Wait(0) end
    return NetworkHasControlOfEntity(entity)
end

local function ignoreNearbyVehicleCollisions(stretcher)
    if not DoesEntityExist(stretcher) then return end

    local stretcherCoords = GetEntityCoords(stretcher)
    local maxDistance = Config.Stretcher.vehicleCollisionDistance or 15.0

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) and #(stretcherCoords - GetEntityCoords(vehicle)) <= maxDistance then
            SetEntityNoCollisionEntity(stretcher, vehicle, false)
            SetEntityNoCollisionEntity(vehicle, stretcher, false)
        end
    end
end

local function stopPushing()
    local stretcher = pushing
    pushing = nil
    stopPushAnimation()
    hidePushText()

    if not stretcher or not DoesEntityExist(stretcher) then return end
    requestControl(stretcher)
    DetachEntity(stretcher, true, true)
    PlaceObjectOnGroundProperly(stretcher)
    SetEntityCollision(stretcher, true, true)
    ignoreNearbyVehicleCollisions(stretcher)
    FreezeEntityPosition(stretcher, true)
end

lib.addKeybind({
    name = 'ob_hospital_release_stretcher',
    description = 'Soltar maca',
    defaultKey = Config.Stretcher.releaseKey or 'X',
    onPressed = function()
        if pushing then stopPushing() end
    end
})

local function updatePushingPosition(ped, stretcher)
    local offset = Config.Stretcher.pushOffset
    local target = GetOffsetFromEntityInWorldCoords(ped, offset.x, offset.y, offset.z)
    local pedCoords = GetEntityCoords(ped)
    local foundGround, groundZ = GetGroundZFor_3dCoord(target.x, target.y, pedCoords.z + 2.0, false)
    local targetZ = foundGround and groundZ + (Config.Stretcher.pushGroundOffset or 0.0) or target.z
    local rotation = Config.Stretcher.pushRotation

    SetEntityCoordsNoOffset(stretcher, target.x, target.y, targetZ, false, false, false)
    SetEntityRotation(stretcher, rotation.x, rotation.y, GetEntityHeading(ped) + rotation.z, 2, true)
    SetEntityVelocity(stretcher, 0.0, 0.0, 0.0)
    SetEntityCollision(stretcher, true, true)
end

local function closestPlayer(maxDistance)
    local closest, closestDistance
    local ownCoords = GetEntityCoords(PlayerPedId())
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local ped = GetPlayerPed(player)
            local distance = #(ownCoords - GetEntityCoords(ped))
            if distance <= maxDistance and (not closestDistance or distance < closestDistance) then
                closest, closestDistance = player, distance
            end
        end
    end
    return closest
end

local function registerTarget(entity)
    if registered[entity] or not DoesEntityExist(entity) then return end
    registered[entity] = true
    SetEntityCollision(entity, true, true)
    ignoreNearbyVehicleCollisions(entity)
    exports.ox_target:addLocalEntity(entity, {
        {
            name = 'ob_hospital_stretcher_push',
            icon = 'fa-solid fa-person-walking',
            label = 'Empurrar maca',
            distance = 2.2,
            canInteract = function(target) return not pushing or pushing == target end,
            onSelect = function(data)
                if pushing == data.entity then stopPushing() return end
                if pushing then stopPushing() end
                if not requestControl(data.entity) then return end
                DetachEntity(data.entity, true, true)
                FreezeEntityPosition(data.entity, true)
                pushing = data.entity
                updatePushingPosition(PlayerPedId(), data.entity)
                playPushAnimation()
                showPushText()
            end
        },
        {
            name = 'ob_hospital_stretcher_patient',
            icon = 'fa-solid fa-person-circle-plus',
            label = 'Colocar paciente na maca',
            distance = 2.2,
            onSelect = function(data)
                local player = closestPlayer(Config.Stretcher.maxPatientDistance)
                if not player then
                    exports.qbx_core:Notify('Nenhum paciente próximo.', 'error')
                    return
                end
                TriggerServerEvent('ob_hospital:server:setStretcherPatient', NetworkGetNetworkIdFromEntity(data.entity), GetPlayerServerId(player))
            end
        },
        {
            name = 'ob_hospital_stretcher_remove_patient',
            icon = 'fa-solid fa-person-circle-minus',
            label = 'Retirar paciente da maca',
            distance = 2.2,
            onSelect = function(data)
                TriggerServerEvent('ob_hospital:server:removeStretcherPatient', NetworkGetNetworkIdFromEntity(data.entity))
            end
        },
        {
            name = 'ob_hospital_stretcher_store',
            icon = 'fa-solid fa-box',
            label = 'Guardar maca',
            distance = 2.2,
            onSelect = function(data)
                if pushing == data.entity then stopPushing() end
                TriggerServerEvent('ob_hospital:server:storeStretcher', NetworkGetNetworkIdFromEntity(data.entity))
            end
        }
    })
end

RegisterNetEvent('ob_hospital:client:deployStretcher', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        exports.qbx_core:Notify('Saia do veículo para montar a maca.', 'error')
        return
    end
    local model = joaat(Config.Stretcher.models.raised)
    if not IsModelInCdimage(model) or not IsModelValid(model) then
        model = joaat(Config.Stretcher.fallbackModel)
        exports.qbx_core:Notify('Modelo da maca não carregou; usando uma cama hospitalar nativa.', 'warning')
    end
    if not IsModelInCdimage(model) or not IsModelValid(model) then
        exports.qbx_core:Notify('Não foi possível carregar o modelo da maca.', 'error')
        return
    end
    lib.requestModel(model, 10000)
    local spawn = GetOffsetFromEntityInWorldCoords(ped, Config.Stretcher.deployOffset.x, Config.Stretcher.deployOffset.y, Config.Stretcher.deployOffset.z)
    local object = CreateObject(model, spawn.x, spawn.y, spawn.z, true, true, false)
    SetEntityHeading(object, GetEntityHeading(ped))
    PlaceObjectOnGroundProperly(object)
    SetEntityCollision(object, true, true)
    ignoreNearbyVehicleCollisions(object)
    FreezeEntityPosition(object, true)
    local netId = NetworkGetNetworkIdFromEntity(object)
    SetNetworkIdCanMigrate(netId, true)
    registerTarget(object)
    TriggerServerEvent('ob_hospital:server:registerStretcher', netId)
    SetModelAsNoLongerNeeded(model)
end)

CreateThread(function()
    while true do
        if pushing then
            local ped = PlayerPedId()
            local invalidState = IsEntityDead(ped)
                or IsPedRagdoll(ped)
                or IsPedFalling(ped)
                or IsPedInAnyVehicle(ped, false)
                or not DoesEntityExist(pushing)

            if invalidState then
                stopPushing()
                Wait(250)
            else
                updatePushingPosition(ped, pushing)
                playPushAnimation()
                DisableControlAction(0, 22, true) -- Jump
                DisableControlAction(0, 23, true) -- Enter vehicle
                DisableControlAction(0, 24, true) -- Attack
                DisableControlAction(0, 25, true) -- Aim
                Wait(0)
            end
        else
            Wait(500)
        end
    end
end)

RegisterNetEvent('ob_hospital:client:deleteStretcher', function(netId)
    local entity = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if entity == 0 then return end
    if pushing == entity then stopPushing() end
    exports.ox_target:removeLocalEntity(entity)
    registered[entity] = nil
    if requestControl(entity) then DeleteEntity(entity) end
end)

RegisterNetEvent('ob_hospital:client:setOnStretcher', function(netId, enabled)
    local ped = PlayerPedId()
    if not enabled then
        patientNetId = nil
        DetachEntity(ped, true, true)
        ClearPedTasksImmediately(ped)
        local coords = GetEntityCoords(ped)
        SetEntityCoords(ped, coords.x, coords.y, coords.z + 0.15, false, false, false, false)
        return
    end
    local object = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if object == 0 then return end
    patientNetId = netId
    lib.requestAnimDict('anim@gangops@morgue@table@', 10000)
    AttachEntityToEntity(
        ped, object, 0,
        Config.Stretcher.patientOffset.x, Config.Stretcher.patientOffset.y, Config.Stretcher.patientOffset.z,
        Config.Stretcher.patientRotation.x, Config.Stretcher.patientRotation.y, Config.Stretcher.patientRotation.z,
        false, false, false, false, 2, true
    )
    TaskPlayAnim(ped, 'anim@gangops@morgue@table@', 'body_search', 8.0, -8.0, -1, 1, 0.0, false, false, false)
end)

AddStateBagChangeHandler('obHospitalStretcher', nil, function(bagName, _, value)
    if value ~= true then return end
    local entity = GetEntityFromStateBagName(bagName)
    if entity and entity ~= 0 then registerTarget(entity) end
end)

CreateThread(function()
    while true do
        if patientNetId then
            lib.showTextUI('[E] Sair da maca')
            while patientNetId do
                local ped = PlayerPedId()
                if IsControlJustPressed(0, 38) then
                    TriggerServerEvent('ob_hospital:server:removeStretcherPatient', patientNetId)
                    Wait(500)
                end
                if not IsEntityPlayingAnim(ped, 'anim@gangops@morgue@table@', 'body_search', 3) then
                    TaskPlayAnim(ped, 'anim@gangops@morgue@table@', 'body_search', 8.0, -8.0, -1, 1, 0.0, false, false, false)
                end
                Wait(0)
            end
            lib.hideTextUI()
        else
            Wait(750)
        end
    end
end)

CreateThread(function()
    while true do
        for _, object in ipairs(GetGamePool('CObject')) do
            if Entity(object).state.obHospitalStretcher then registerTarget(object) end
        end
        Wait(5000)
    end
end)

CreateThread(function()
    while true do
        local hasStretcher = false

        for entity in pairs(registered) do
            if DoesEntityExist(entity) then
                hasStretcher = true
                ignoreNearbyVehicleCollisions(entity)
            else
                registered[entity] = nil
            end
        end

        Wait(hasStretcher and 100 or 1000)
    end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    pushing = nil
    stopPushAnimation()
    hidePushText()

    if patientNetId then
        patientNetId = nil
        DetachEntity(PlayerPedId(), true, true)
        ClearPedTasksImmediately(PlayerPedId())
    end

    for entity in pairs(registered) do
        exports.ox_target:removeLocalEntity(entity)
    end

    registered = {}
end)
