local menuOpen = false
local removalPending = false
local trackedPed = 0
local attachedWing = 0
local wingMissingSince = 0
local wingWasSeen = false
local wingModels = {}

for _, wing in ipairs(Config.WingCatalogEntries or {}) do
    wingModels[joaat(('mts_fair_v7_%s'):format(wing.color))] = true
end

local function wingResource()
    return tostring(Config.WingMenu.resource or '')
end

local function isWingActive()
    local state = LocalPlayer.state
    local stateKey = Config.WingMenu.stateKey or 'activeWingResource'
    local selectionKey = Config.WingMenu.selectionStateKey or 'obCurandeiraWing'
    return state[stateKey] == wingResource() or state[selectionKey] ~= nil
end

local function findAttachedWing(ped)
    if attachedWing ~= 0
        and DoesEntityExist(attachedWing)
        and IsEntityAttachedToEntity(attachedWing, ped) then
        return attachedWing
    end

    attachedWing = 0
    for _, object in ipairs(GetGamePool('CObject')) do
        if wingModels[GetEntityModel(object)] and IsEntityAttachedToEntity(object, ped) then
            attachedWing = object
            return object
        end
    end

    return 0
end

local function syncEquippedColor(result)
    if type(result) ~= 'table' then return end
    ObCurandeiras.SetWingEffectColor(result.equippedColor)
end

local function resetWingNui()
    menuOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
end

local function setAbilityHudRaised(raised)
    if GetResourceState('obscuriaHud') ~= 'started' then return end
    pcall(function()
        local position = raised and Config.Hud.wingMenuPosition or Config.Hud.position
        exports.obscuriaHud:SetProviderPosition('ob_curandeiras', position)
        exports.obscuriaHud:SetProviderVisible('ob_curandeiras', true)
    end)
end

local function closeWingMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
    if ObCurandeiras.IsHealer() then
        setAbilityHudRaised(false)
    end
end

local function removeDetachedWing()
    if removalPending or not isWingActive() then return end

    removalPending = true
    closeWingMenu()
    TriggerEvent('ob_curandeiras:client:forceStopFlight')
    TriggerServerEvent('ob_curandeiras:server:removeDetachedWing')
end

local function isMenuBlocked()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) or GetEntityHealth(ped) <= 0 then
        return true, 'Você não pode acessar as asas agora.'
    end
    if IsPedInAnyVehicle(ped, false) then
        return true, 'Saia do veículo para acessar as asas.'
    end
    if LocalPlayer.state.obHealerFlight == true then
        return true, 'Retorne ao solo antes de ajustar as asas.'
    end
    if ObCurandeiras.IsPowerBlocked() then
        return true, 'Sua forma atual impede o acesso às asas.'
    end
    return false
end

local function openWingMenu()
    if menuOpen or Config.WingMenu.enabled == false then return end
    local blocked, message = isMenuBlocked()
    if blocked then
        ObCurandeiras.Notify('Asas', message, 'warning')
        return
    end

    CreateThread(function()
        local ok, result = pcall(function()
            return lib.callback.await('ob_curandeiras:server:getWingMenu', false)
        end)
        if not ok or type(result) ~= 'table' or result.success ~= true then
            ObCurandeiras.Notify(
                'Asas',
                result and result.message or 'Suas coleções de asas não responderam.',
                'error'
            )
            return
        end

        syncEquippedColor(result)
        menuOpen = true
        setAbilityHudRaised(true)
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({
            action = 'open',
            wings = result.wings or {},
            equippedId = result.equippedId,
            runeBalance = result.runeBalance,
        })
    end)
end

RegisterCommand(Config.WingMenu.command, function()
    if menuOpen then
        closeWingMenu()
    else
        openWingMenu()
    end
end, false)

RegisterKeyMapping(
    Config.WingMenu.command,
    'Abrir coleções de asas',
    'keyboard',
    Config.WingMenu.key or 'F6'
)

RegisterNUICallback('close', function(_, callback)
    closeWingMenu()
    callback({ success = true })
end)

RegisterNUICallback('wingAction', function(data, callback)
    if not menuOpen then
        callback({ success = false, message = 'As coleções estão fechadas.' })
        return
    end

    local blocked, message = isMenuBlocked()
    if blocked then
        callback({ success = false, message = message })
        closeWingMenu()
        return
    end

    CreateThread(function()
        local ok, result = pcall(function()
            return lib.callback.await(
                'ob_curandeiras:server:wingAction',
                false,
                tostring(data.action or ''),
                tostring(data.wingId or '')
            )
        end)
        if not ok or type(result) ~= 'table' then
            callback({ success = false, message = 'A asa não respondeu.' })
            return
        end
        callback(result)
    end)
end)

RegisterNUICallback('buyWing', function(data, callback)
    if not menuOpen then
        callback({ success = false, message = 'As coleções estão fechadas.' })
        return
    end

    local blocked, message = isMenuBlocked()
    if blocked then
        callback({ success = false, message = message })
        closeWingMenu()
        return
    end

    CreateThread(function()
        local ok, result = pcall(function()
            return lib.callback.await(
                'ob_curandeiras:server:buyWing',
                false,
                tostring(data.wingId or '')
            )
        end)
        callback(ok and type(result) == 'table' and result or {
            success = false,
            message = 'A compra não pôde ser concluída.',
        })
    end)
end)

RegisterNetEvent('ob_curandeiras:client:wingState', function(equippedId, effectColor)
    ObCurandeiras.SetWingEffectColor(effectColor)
    if equippedId then
        removalPending = false
        trackedPed = PlayerPedId()
        attachedWing = 0
        wingMissingSince = 0
        wingWasSeen = false
    end
    if not menuOpen then return end
    SendNUIMessage({ action = 'state', equippedId = equippedId })
end)

RegisterNetEvent('ob_curandeiras:client:wingForcedOff', function()
    removalPending = false
    trackedPed = PlayerPedId()
    attachedWing = 0
    wingMissingSince = 0
    wingWasSeen = false
    ObCurandeiras.SetWingEffectColor(nil)
    closeWingMenu()
end)

RegisterNetEvent('ob_curandeiras:client:refreshWingMenu', function()
    if not menuOpen then return end
    CreateThread(function()
        local ok, result = pcall(function()
            return lib.callback.await('ob_curandeiras:server:getWingMenu', false)
        end)
        if ok and type(result) == 'table' and result.success == true then
            syncEquippedColor(result)
            SendNUIMessage({
                action = 'open',
                wings = result.wings or {},
                equippedId = result.equippedId,
                runeBalance = result.runeBalance,
            })
        end
    end)
end)

CreateThread(function()
    while true do
        if menuOpen then
            local blocked = isMenuBlocked()
            if blocked or IsPauseMenuActive() then
                closeWingMenu()
            end
            Wait(250)
        else
            Wait(1000)
        end
    end
end)

for _, eventName in ipairs({
    'illenium-appearance:client:openClothingShop',
    'illenium-appearance:client:openClothingShopMenu',
    'illenium-appearance:client:OpenClothingRoom',
    'illenium-appearance:client:openOutfitMenu',
    'illenium-appearance:client:OpenBarberShop',
    'illenium-appearance:client:OpenTattooShop',
    'illenium-appearance:client:OpenSurgeonShop',
    'qb-clothing:client:openMenu',
    'qb-clothing:client:openOutfitMenu',
}) do
    RegisterNetEvent(eventName, function()
        removeDetachedWing()
    end)
end

CreateThread(function()
    while true do
        if not isWingActive() then
            removalPending = false
            trackedPed = PlayerPedId()
            attachedWing = 0
            wingMissingSince = 0
            wingWasSeen = false
            Wait(750)
        else
            local ped = PlayerPedId()
            local now = GetGameTimer()

            if trackedPed ~= 0 and ped ~= trackedPed then
                removeDetachedWing()
            elseif ObCurandeiras.IsPowerBlocked() then
                removeDetachedWing()
            elseif findAttachedWing(ped) ~= 0 then
                wingWasSeen = true
                wingMissingSince = 0
            else
                if wingMissingSince == 0 then wingMissingSince = now end
                local gracePeriod = wingWasSeen and 750 or 4000
                if now - wingMissingSince >= gracePeriod then
                    removeDetachedWing()
                end
            end

            trackedPed = ped
            Wait(250)
        end
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    resetWingNui()
    CreateThread(function()
        Wait(250)
        SendNUIMessage({ action = 'close' })
    end)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        resetWingNui()
    end
end)
