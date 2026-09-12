local registered = {}
local pushing
local patientNetId

local function requestControl(entity)
    if NetworkHasControlOfEntity(entity) then return true end
    NetworkRequestControlOfEntity(entity)
    local timeout = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do Wait(0) end
    return NetworkHasControlOfEntity(entity)
end

local function stopPushing()
    if not pushing or not DoesEntityExist(pushing) then pushing = nil return end
    requestControl(pushing)
    DetachEntity(pushing, true, true)
    PlaceObjectOnGroundProperly(pushing)
    FreezeEntityPosition(pushing, true)
    pushing = nil
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
                FreezeEntityPosition(data.entity, false)
                AttachEntityToEntity(
                    data.entity, PlayerPedId(), 0,
                    Config.Stretcher.pushOffset.x, Config.Stretcher.pushOffset.y, Config.Stretcher.pushOffset.z,
                    Config.Stretcher.pushRotation.x, Config.Stretcher.pushRotation.y, Config.Stretcher.pushRotation.z,
                    false, false, true, false, 2, true
                )
                pushing = data.entity
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
        exports.qbx_core:Notify('Pack de maca não encontrado; usando o modelo de contingência.', 'warning')
    end
    lib.requestModel(model, 10000)
    local spawn = GetOffsetFromEntityInWorldCoords(ped, Config.Stretcher.deployOffset.x, Config.Stretcher.deployOffset.y, Config.Stretcher.deployOffset.z)
    local object = CreateObject(model, spawn.x, spawn.y, spawn.z, true, true, false)
    SetEntityHeading(object, GetEntityHeading(ped))
    PlaceObjectOnGroundProperly(object)
    FreezeEntityPosition(object, true)
    local netId = NetworkGetNetworkIdFromEntity(object)
    SetNetworkIdCanMigrate(netId, true)
    registerTarget(object)
    TriggerServerEvent('ob_hospital:server:registerStretcher', netId)
    SetModelAsNoLongerNeeded(model)
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

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopPushing()
    if patientNetId then DetachEntity(PlayerPedId(), true, true) end
    for entity in pairs(registered) do
        if DoesEntityExist(entity) then exports.ox_target:removeLocalEntity(entity) end
    end
end)
