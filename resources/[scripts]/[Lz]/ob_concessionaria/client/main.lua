local RESOURCE = GetCurrentResourceName()
local uiOpen = false
local activeDealership
local testDriveVehicle
local testDriveReturn

local function notify(message, notifyType)
    if GetResourceState('qbx_core') ~= 'started' then return end
    pcall(function()
        exports.qbx_core:Notify(tostring(message), notifyType or 'inform', 5000)
    end)
end

local function closeUi()
    uiOpen = false
    activeDealership = nil
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
end

local function openDealership(id)
    local payload = lib.callback.await('ob_concessionaria:openDealership', false, id)
    if not payload or payload.ok == false then
        if payload and payload.message then notify(payload.message, payload.type or 'error') end
        return
    end

    activeDealership = id
    uiOpen = true
    SetNuiFocus(true, true)
    SetCursorLocation(0.5, 0.5)
    SendNUIMessage({ action = 'open', data = payload })
end

local function openAdmin()
    local payload = lib.callback.await('ob_concessionaria:openAdmin', false)
    if not payload or payload.ok == false then
        if payload and payload.message then notify(payload.message, payload.type or 'error') end
        return
    end

    uiOpen = true
    activeDealership = nil
    SetNuiFocus(true, true)
    SetCursorLocation(0.5, 0.5)
    SendNUIMessage({ action = 'openAdmin', data = payload })
end

local function drawTestDriveTimer(seconds)
    SetTextFont(4)
    SetTextScale(0.38, 0.38)
    SetTextCentre(true)
    SetTextOutline()
    SetTextColour(244, 225, 169, 240)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(('TEST DRIVE  %ss'):format(seconds))
    EndTextCommandDisplayText(0.5, 0.90)
end

local function finishTestDrive(reason)
    if testDriveVehicle and DoesEntityExist(testDriveVehicle) then DeleteEntity(testDriveVehicle) end
    testDriveVehicle = nil

    local ped = PlayerPedId()
    if testDriveReturn then SetEntityCoords(ped, testDriveReturn.x, testDriveReturn.y, testDriveReturn.z, false, false, false, false) end
    testDriveReturn = nil
    lib.callback.await('ob_concessionaria:finishTestDrive', false)

    if reason == 'leftVehicle' then notify('Test drive cancelado ao sair do veículo.', 'inform') end
    if reason == 'timeout' then notify('Test drive finalizado.', 'inform') end
end

local function startTestDrive(result)
    local ped = PlayerPedId()
    local model = joaat(tostring(result.model or ''))
    if not IsModelInCdimage(model) or not IsModelAVehicle(model) then
        notify('Modelo indisponível para test drive.', 'error')
        lib.callback.await('ob_concessionaria:finishTestDrive', false)
        return
    end

    RequestModel(model)
    local loadDeadline = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < loadDeadline do Wait(20) end
    if not HasModelLoaded(model) then
        notify('O veículo demorou demais para carregar.', 'error')
        lib.callback.await('ob_concessionaria:finishTestDrive', false)
        return
    end

    testDriveReturn = GetEntityCoords(ped)
    local spawn = result.spawn
    testDriveVehicle = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, false)
    if not testDriveVehicle or testDriveVehicle == 0 or not DoesEntityExist(testDriveVehicle) then
        testDriveVehicle = nil
        testDriveReturn = nil
        SetModelAsNoLongerNeeded(model)
        notify('Não foi possível criar o veículo de teste.', 'error')
        lib.callback.await('ob_concessionaria:finishTestDrive', false)
        return
    end
    SetEntityAsMissionEntity(testDriveVehicle, true, true)
    SetVehicleNumberPlateText(testDriveVehicle, 'OBTEST')
    SetVehicleDirtLevel(testDriveVehicle, 0.0)
    SetVehicleEngineOn(testDriveVehicle, true, true, false)
    SetPedIntoVehicle(ped, testDriveVehicle, -1)
    SetModelAsNoLongerNeeded(model)

    local finishAt = GetGameTimer() + (tonumber(result.seconds) or 45) * 1000
    CreateThread(function()
        while testDriveVehicle and GetGameTimer() < finishAt do
            if not IsPedInVehicle(PlayerPedId(), testDriveVehicle, false) then
                finishTestDrive('leftVehicle')
                return
            end
            drawTestDriveTimer(math.max(0, math.ceil((finishAt - GetGameTimer()) / 1000)))
            Wait(0)
        end
        if testDriveVehicle then finishTestDrive('timeout') end
    end)
end

CreateThread(function()
    Wait(0)
    closeUi()
end)

CreateThread(function()
    for _, shop in pairs(Config.Dealerships or {}) do
        local blipConfig = shop.blip or {}
        if shop.coords and blipConfig.enabled ~= false then
            local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
            SetBlipSprite(blip, blipConfig.sprite or 225)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, blipConfig.scale or 0.70)
            SetBlipColour(blip, blipConfig.color or 27)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(blipConfig.name or shop.label or 'Concessionária')
            EndTextCommandSetBlipName(blip)
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 700
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        if not uiOpen then
            for id, shop in pairs(Config.Dealerships or {}) do
                local shopCoords = shop.coords
                local distance = shopCoords and #(coords - shopCoords) or 999.0
                if distance <= 10.0 then
                    sleep = 0
                    exports.ob_markers:Draw('concessionaria', shopCoords, {
                        distance = distance,
                        drawDistance = 10.0,
                        height = 1.0,
                        size = 0.92,
                    })

                    if distance <= (tonumber(Config.OpenDistance) or 2.0) then
                        if IsControlJustReleased(0, 38) then
                            openDealership(id)
                            Wait(500)
                            break
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNUICallback('close', function(_, cb)
    closeUi()
    cb({ ok = true })
end)

RegisterNUICallback('buyVehicle', function(data, cb)
    local result = activeDealership and lib.callback.await('ob_concessionaria:buyVehicle', false, activeDealership, data and data.id) or { ok = false, message = 'Concessionária não encontrada.' }
    cb(result or { ok = false })
    if result and result.message and not result.ok then notify(result.message, 'error') end
    if result and result.payload then SendNUIMessage({ action = 'refresh', data = result.payload }) end
end)

RegisterNUICallback('testDrive', function(data, cb)
    local result = activeDealership and lib.callback.await('ob_concessionaria:startTestDrive', false, activeDealership, data and data.id) or { ok = false, message = 'Concessionária não encontrada.' }
    cb(result or { ok = false })
    if not result or not result.ok then
        if result and result.message then notify(result.message, 'error') end
        return
    end
    closeUi()
    notify(('Test drive iniciado por %ss.'):format(result.seconds or 45), 'success')
    startTestDrive(result)
end)

RegisterNUICallback('adminSaveVehicle', function(data, cb)
    local result = lib.callback.await('ob_concessionaria:adminSaveVehicle', false, data or {}) or { ok = false }
    cb(result)
    if result.message and not result.ok then notify(result.message, 'error') end
    if result.payload then SendNUIMessage({ action = 'refreshAdmin', data = result.payload }) end
end)

RegisterNUICallback('adminSetVehicleEnabled', function(data, cb)
    local result = lib.callback.await('ob_concessionaria:adminSetVehicleEnabled', false, data and data.id, data and data.enabled) or { ok = false }
    cb(result)
    if result.message and not result.ok then notify(result.message, 'error') end
    if result.payload then SendNUIMessage({ action = 'refreshAdmin', data = result.payload }) end
end)

RegisterNUICallback('adminDeleteVehicle', function(data, cb)
    local result = lib.callback.await('ob_concessionaria:adminDeleteVehicle', false, data and data.id) or { ok = false }
    cb(result)
    if result.message and not result.ok then notify(result.message, 'error') end
    if result.payload then SendNUIMessage({ action = 'refreshAdmin', data = result.payload }) end
end)

RegisterCommand('conceclose', closeUi, false)
RegisterKeyMapping('conceclose', 'Fechar concessionária', 'keyboard', 'ESCAPE')
RegisterCommand('conceadmin', openAdmin, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    closeUi()
    if testDriveVehicle and DoesEntityExist(testDriveVehicle) then
        DeleteEntity(testDriveVehicle)
    end
    testDriveVehicle = nil
    testDriveReturn = nil
end)
