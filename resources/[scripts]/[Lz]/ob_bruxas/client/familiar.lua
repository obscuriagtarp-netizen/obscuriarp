local transformed = false
local transitioning = false
local originalAppearance = nil
local familiarCooldownEnd = 0
local leaveFamiliar
local TRANSFORMATION_BONES = { 24818, 24816, 31086, 57005, 18905, 51826, 52301 }

local function captureAppearance(ped)
    local appearanceResource = nil
    local appearance = nil

    if GetResourceState('illenium-appearance') == 'started' then
        local ok, data = pcall(function()
            return exports['illenium-appearance']:getPedAppearance(ped)
        end)
        if ok and data then
            appearanceResource, appearance = 'illenium-appearance', data
        end
    elseif GetResourceState('fivem-appearance') == 'started' then
        local ok, data = pcall(function()
            return exports['fivem-appearance']:getPedAppearance(ped)
        end)
        if ok and data then
            appearanceResource, appearance = 'fivem-appearance', data
        end
    end

    local data = {
        model = GetEntityModel(ped),
        health = GetEntityHealth(ped),
        maxHealth = GetEntityMaxHealth(ped),
        armor = GetPedArmour(ped),
        appearanceResource = appearanceResource,
        appearance = appearance,
        components = {},
        props = {},
    }

    for component = 0, 12 do
        data.components[component] = {
            drawable = GetPedDrawableVariation(ped, component),
            texture = GetPedTextureVariation(ped, component),
            palette = GetPedPaletteVariation(ped, component),
        }
    end

    for prop = 0, 7 do
        data.props[prop] = {
            index = GetPedPropIndex(ped, prop),
            texture = GetPedPropTextureIndex(ped, prop),
        }
    end

    return data
end

local function applyFallbackAppearance(data)
    local model = ObBruxas.EnsureModel(data.model)
    if not model then
        return false
    end

    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)

    local ped = PlayerPedId()
    for component, item in pairs(data.components or {}) do
        SetPedComponentVariation(ped, component, item.drawable or 0, item.texture or 0, item.palette or 0)
    end

    for prop, item in pairs(data.props or {}) do
        if item.index and item.index >= 0 then
            SetPedPropIndex(ped, prop, item.index, item.texture or 0, true)
        else
            ClearPedProp(ped, prop)
        end
    end

    return true
end

local function restoreAppearance(data)
    if data.appearanceResource and data.appearance and GetResourceState(data.appearanceResource) == 'started' then
        local ok = pcall(function()
            if data.appearanceResource == 'illenium-appearance' then
                exports['illenium-appearance']:setPlayerAppearance(data.appearance)
            else
                exports['fivem-appearance']:setPlayerAppearance(data.appearance)
            end
        end)
        if ok then
            return true
        end
    end

    return applyFallbackAppearance(data)
end

local function playSmoke(entity, duration)
    if not DoesEntityExist(entity) or not ObBruxas.EnsurePtfx('core') then
        return
    end

    CreateThread(function()
        local endAt = GetGameTimer() + duration
        local nextPulse = 0

        while GetGameTimer() < endAt and DoesEntityExist(entity) do
            local now = GetGameTimer()
            if now >= nextPulse then
                nextPulse = now + 230
                local fx = Config.Familiar.transformationFx or {}
                local color = fx.smokeColor or { 0.12, 0.0, 0.2 }
                UseParticleFxAssetNextCall('core')
                SetParticleFxNonLoopedColour(color[1], color[2], color[3])
                SetParticleFxNonLoopedAlpha(math.min(0.78, tonumber(fx.smokeAlpha) or 0.78))
                StartParticleFxNonLoopedOnEntity(
                    'exp_grd_grenade_smoke', entity,
                    0.0, 0.0, 0.12,
                    0.0, 0.0, 0.0,
                    0.92, false, false, false
                )
            end
            Wait(0)
        end
    end)
end

local function playTransformationExplosion(entity, replicate)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    local fx = Config.Familiar.transformationFx or {}
    local smokeColor = fx.smokeColor or { 0.12, 0.0, 0.2 }
    local trailColor = fx.trailColor or { 0.46, 0.035, 0.68 }
    local smokeReady = fx.smokeAsset and fx.smokeName and ObBruxas.EnsurePtfx(fx.smokeAsset)
    local trailsReady = fx.trailAsset and fx.trailName and ObBruxas.EnsurePtfx(fx.trailAsset)
    if not smokeReady and not trailsReady then return end

    if replicate then
        TriggerServerEvent('ob_bruxas:server:syncFamiliarTransformationFx')
    end

    CreateThread(function()
        local pulses = math.max(1, math.floor(tonumber(fx.pulses) or 3))
        local interval = math.max(60, math.floor(tonumber(fx.pulseInterval) or 125))

        for pulse = 1, pulses do
            if not DoesEntityExist(entity) then return end

            if smokeReady then
                local coords = GetEntityCoords(entity)
                UseParticleFxAssetNextCall(fx.smokeAsset)
                SetParticleFxNonLoopedColour(smokeColor[1], smokeColor[2], smokeColor[3])
                SetParticleFxNonLoopedAlpha(tonumber(fx.smokeAlpha) or 0.9)
                StartParticleFxNonLoopedAtCoord(
                    fx.smokeName,
                    coords.x, coords.y, coords.z + 0.55,
                    0.0, 0.0, math.random(0, 359) + 0.0,
                    (tonumber(fx.smokeScale) or 1.2) + ((pulse - 1) * 0.08),
                    false, false, false
                )
            end

            if trailsReady then
                for i = 1, #TRANSFORMATION_BONES do
                    UseParticleFxAssetNextCall(fx.trailAsset)
                    SetParticleFxNonLoopedColour(trailColor[1], trailColor[2], trailColor[3])
                    SetParticleFxNonLoopedAlpha(tonumber(fx.trailAlpha) or 0.58)
                    StartParticleFxNonLoopedOnPedBone(
                        fx.trailName,
                        entity,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        TRANSFORMATION_BONES[i],
                        tonumber(fx.trailScale) or 4.4,
                        false, false, false
                    )
                end
            end

            if pulse < pulses then Wait(interval) end
        end
    end)
end

RegisterNetEvent('ob_bruxas:client:showFamiliarTransformationFx', function(sourceId)
    local player = GetPlayerFromServerId(tonumber(sourceId) or -1)
    if player == -1 then return end

    playTransformationExplosion(GetPlayerPed(player), false)
end)

local function setBlocked(enabled)
    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set('obscuriaPowerBlocked', enabled == true, true)
        LocalPlayer.state:set('invBusy', enabled == true, true)
        LocalPlayer.state:set('inv_busy', enabled == true, true)
        LocalPlayer.state:set('Buttons', enabled == true, true)
        LocalPlayer.state:set('obFamiliar', enabled == true, true)
    end

    if enabled then
        TriggerEvent('magic:client:forceCloseGrimoire', true)
        TriggerServerEvent('magic:server:setWandState', false)
        SetNuiFocus(false, false)
    end

    ObBruxas.UpdateAbility('sentido_arcano', { enabled = not enabled })
    ObBruxas.UpdateAbility('elo_arcano', { enabled = not enabled })
    ObBruxas.UpdateAbility('familiar', { selected = enabled })
end

local function isFamiliarInterrupted()
    local state = LocalPlayer and LocalPlayer.state
    if not state then return false end

    return state.magicFauna == true
        or state.obHypnotized == true
        or state.obInVehicleAttachment == true
end

local function getEntityFootZ(entity, coords)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return coords.z
    end

    local minimum = GetModelDimensions(GetEntityModel(entity))
    return coords.z + ((minimum and minimum.z) or 0.0)
end

local function placePedAtFootZ(ped, coords, footZ)
    local minimum = GetModelDimensions(GetEntityModel(ped))
    local targetZ = footZ - ((minimum and minimum.z) or 0.0) + 0.025

    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, false, false)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, targetZ, false, false, false)
    RequestCollisionAtCoord(coords.x, coords.y, targetZ)

    local timeout = GetGameTimer() + 650
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        Wait(0)
    end

    SetEntityCollision(ped, true, true)
    SetEntityHasGravity(ped, true)
    FreezeEntityPosition(ped, false)
end

local function fadeOut()
    DoScreenFadeOut(260)
    local timeout = GetGameTimer() + 900
    while not IsScreenFadedOut() and GetGameTimer() < timeout do
        Wait(0)
    end
end

local function fadeIn()
    if IsScreenFadedOut() then
        DoScreenFadeIn(480)
    end
end

local function startControlBlock()
    CreateThread(function()
        while transformed do
            local ped = PlayerPedId()
            DisablePlayerFiring(PlayerId(), true)
            SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 45, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 143, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
            DisableControlAction(0, 289, true)
            Wait(0)
        end
    end)
end

local function startSustainLoop()
    CreateThread(function()
        local sustainInterval = math.max(1000, tonumber(Config.Familiar.sustainInterval) or 8000)
        local nextChargeAt = GetGameTimer() + sustainInterval

        while transformed do
            local now = GetGameTimer()
            if now >= nextChargeAt then
                nextChargeAt = now + sustainInterval
                local ok, result = pcall(function()
                    return lib.callback.await('ob_bruxas:server:sustainFamiliar', false)
                end)

                if not ok or type(result) ~= 'table' or result.success ~= true then
                    ObBruxas.FailAbility('familiar')
                    leaveFamiliar(false)
                    return
                end

                if result.depleted == true then
                    leaveFamiliar(false)
                    return
                end
            end

            if not ObBruxas.IsWitch() or isFamiliarInterrupted() then
                leaveFamiliar(true)
                return
            end
            Wait(200)
        end
    end)
end

local function enterFamiliar()
    if transitioning or transformed or not ObBruxas.IsWitch() or ObBruxas.IsPowerBlocked() then
        return
    end

    local cooldownRemaining = familiarCooldownEnd - GetGameTimer()
    if cooldownRemaining > 0 then
        ObBruxas.ClearSelection()
        ObBruxas.Notify(
            'Familiar',
            ('A forma felina ainda esta se recompondo (%ss).'):format(math.ceil(cooldownRemaining / 1000)),
            'warning',
            2500
        )
        return
    end

    local catModel = ObBruxas.EnsureModel(Config.Familiar.model)
    if not catModel then
        ObBruxas.Notify('Familiar', 'O modelo do gato nao foi encontrado.', 'error')
        ObBruxas.ClearSelection()
        return
    end

    local authorized, result = pcall(function()
        return lib.callback.await('ob_bruxas:server:beginFamiliar', false)
    end)
    if not authorized or type(result) ~= 'table' or result.success ~= true then
        SetModelAsNoLongerNeeded(catModel)
        ObBruxas.ClearSelection()
        ObBruxas.FailAbility('familiar')
        return
    end

    transitioning = true
    local oldPed = PlayerPedId()
    originalAppearance = captureAppearance(oldPed)
    local coords = GetEntityCoords(oldPed)
    local heading = GetEntityHeading(oldPed)

    FreezeEntityPosition(oldPed, true)
    if ObBruxas.EnsureAnim('amb@world_human_bum_standing@drunk@idle_a') then
        TaskPlayAnim(oldPed, 'amb@world_human_bum_standing@drunk@idle_a', 'idle_b', 4.0, -4.0, Config.Familiar.transitionTime, 49, 0.0, false, false, false)
    end
    playTransformationExplosion(oldPed, true)
    Wait(math.max(350, Config.Familiar.transitionTime - 320))
    fadeOut()

    SetPlayerModel(PlayerId(), catModel)
    SetModelAsNoLongerNeeded(catModel)

    local cat = PlayerPedId()
    SetEntityCoordsNoOffset(cat, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(cat, heading)
    SetPedComponentVariation(cat, 0, 0, Config.Familiar.textureVariation or 1, 0)
    SetEntityMaxHealth(cat, math.max(originalAppearance.maxHealth or 200, 100))
    SetEntityHealth(cat, math.max(1, originalAppearance.health or 200))
    SetPedArmour(cat, originalAppearance.armor or 0)
    SetPedDiesWhenInjured(cat, false)
    SetEntityCollision(cat, true, true)
    FreezeEntityPosition(cat, false)

    transformed = true
    transitioning = false
    setBlocked(true)
    playSmoke(cat, 850)
    fadeIn()
    startControlBlock()
    startSustainLoop()
    ObBruxas.Notify(
        'Familiar',
        'Forma felina assumida. A transformacao permanece enquanto houver mana.',
        'success'
    )
end

leaveFamiliar = function(silent)
    if transitioning or not transformed then
        return
    end

    transitioning = true
    transformed = false
    local cat = PlayerPedId()
    local coords = GetEntityCoords(cat)
    local footZ = getEntityFootZ(cat, coords)
    local heading = GetEntityHeading(cat)
    local health = GetEntityHealth(cat)

    FreezeEntityPosition(cat, true)
    playTransformationExplosion(cat, true)
    Wait(650)
    fadeOut()

    local data = originalAppearance
    originalAppearance = nil
    if data then
        restoreAppearance(data)
        Wait(0)
        local ped = PlayerPedId()
        placePedAtFootZ(ped, coords, footZ)
        SetEntityHeading(ped, heading)
        local maxHealth = math.max(data.maxHealth or 200, 100)
        SetEntityMaxHealth(ped, maxHealth)
        SetEntityHealth(ped, math.min(maxHealth, math.max(101, health)))
        SetPedArmour(ped, data.armor or 0)
        SetPedDiesWhenInjured(ped, true)
        playTransformationExplosion(ped, false)
    end

    setBlocked(false)
    ObBruxas.ClearSelection()
    transitioning = false
    fadeIn()
    TriggerServerEvent('ob_bruxas:server:familiarEnded')

    if not silent then
        local cooldown = math.max(0, tonumber(Config.Familiar.returnCooldown) or 0)
        familiarCooldownEnd = GetGameTimer() + cooldown
        ObBruxas.StartCooldown('familiar', cooldown)
        ObBruxas.Notify('Familiar', 'Voce retorna a sua forma original.', 'inform')
    end
end

RegisterNetEvent('ob_bruxas:client:toggleFamiliar', function()
    if transformed then
        leaveFamiliar(false)
    else
        enterFamiliar()
    end
end)

RegisterNetEvent('ob_bruxas:client:forceRestoreFamiliar', function()
    leaveFamiliar(true)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and transformed then
        if LocalPlayer and LocalPlayer.state then
            LocalPlayer.state:set('obscuriaPowerBlocked', false, true)
            LocalPlayer.state:set('invBusy', false, true)
            LocalPlayer.state:set('inv_busy', false, true)
            LocalPlayer.state:set('Buttons', false, true)
            LocalPlayer.state:set('obFamiliar', false, true)
        end
        leaveFamiliar(true)
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= 'obscuriaHud' then
        return
    end

    SetTimeout(900, function()
        local remaining = familiarCooldownEnd - GetGameTimer()
        if remaining > 0 then
            ObBruxas.StartCooldown('familiar', remaining)
        end
    end)
end)

RegisterNetEvent('qbx_core:client:onSetMetaData', function(key)
    if key ~= Config.ClassMetadataKey or not transformed then return end

    SetTimeout(150, function()
        if transformed and not ObBruxas.IsWitch() then
            leaveFamiliar(true)
        end
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if transformed then
        leaveFamiliar(true)
    end
end)
