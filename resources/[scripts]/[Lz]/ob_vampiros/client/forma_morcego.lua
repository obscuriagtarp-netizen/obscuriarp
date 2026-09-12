local transformed = false
local transitioning = false
local originalAppearance = nil
local batSequence = 0
local batProtectedHealth = math.max(500, tonumber(Config.BatForm.protectedHealth) or 2000)
local batDistortionHandles = {}
local batDistortionEntity = 0
local leaveBatForm

local DISTORTION_BONES = { 24818, 23553 }
local TRANSFORMATION_BONES = { 24818, 24816, 31086, 57005, 18905, 51826, 52301 }

local function captureAppearance(ped)
    local appearanceResource, appearance = nil, nil
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

    local model = ObVampiros.EnsureModel(data.model)
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

local function playSmoke(entity, duration)
    if not DoesEntityExist(entity) or not ObVampiros.EnsurePtfx('core') then
        return
    end
    CreateThread(function()
        local endsAt = GetGameTimer() + duration
        while GetGameTimer() < endsAt and DoesEntityExist(entity) do
            UseParticleFxAssetNextCall('core')
            SetParticleFxNonLoopedColour(0.04, 0.04, 0.05)
            StartParticleFxNonLoopedOnEntity(
                'exp_grd_grenade_smoke', entity,
                0.0, 0.0, 0.15,
                0.0, 0.0, 0.0,
                0.88, false, false, false
            )
            Wait(240)
        end
    end)
end

local function playTransformationExplosion(entity, replicate)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    local fx = Config.BatForm.transformationFx or {}
    local smokeReady = fx.smokeAsset and fx.smokeName and ObVampiros.EnsurePtfx(fx.smokeAsset)
    local trailsReady = fx.trailAsset and fx.trailName and ObVampiros.EnsurePtfx(fx.trailAsset)
    if not smokeReady and not trailsReady then return end

    if replicate then
        TriggerServerEvent('ob_vampiros:server:syncBatTransformationFx')
    end

    CreateThread(function()
        local pulses = math.max(1, math.floor(tonumber(fx.pulses) or 3))
        local interval = math.max(60, math.floor(tonumber(fx.pulseInterval) or 125))

        for pulse = 1, pulses do
            if not DoesEntityExist(entity) then return end

            if smokeReady then
                local coords = GetEntityCoords(entity)
                UseParticleFxAssetNextCall(fx.smokeAsset)
                SetParticleFxNonLoopedColour(
                    fx.smokeColor[1], fx.smokeColor[2], fx.smokeColor[3]
                )
                SetParticleFxNonLoopedAlpha(tonumber(fx.smokeAlpha) or 0.9)
                StartParticleFxNonLoopedAtCoord(
                    fx.smokeName,
                    coords.x, coords.y, coords.z + 0.55,
                    0.0, 0.0, math.random(0, 359) + 0.0,
                    (tonumber(fx.smokeScale) or 1.25) + ((pulse - 1) * 0.08),
                    false, false, false
                )
            end

            if trailsReady then
                for i = 1, #TRANSFORMATION_BONES do
                    UseParticleFxAssetNextCall(fx.trailAsset)
                    SetParticleFxNonLoopedColour(
                        fx.trailColor[1], fx.trailColor[2], fx.trailColor[3]
                    )
                    SetParticleFxNonLoopedAlpha(tonumber(fx.trailAlpha) or 0.58)
                    StartParticleFxNonLoopedOnPedBone(
                        fx.trailName,
                        entity,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        TRANSFORMATION_BONES[i],
                        tonumber(fx.trailScale) or 4.6,
                        false, false, false
                    )
                end
            end

            if pulse < pulses then Wait(interval) end
        end
    end)
end

RegisterNetEvent('ob_vampiros:client:showBatTransformationFx', function(sourceId)
    local player = GetPlayerFromServerId(tonumber(sourceId) or -1)
    if player == -1 then return end

    playTransformationExplosion(GetPlayerPed(player), false)
end)

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

local function setBlocked(enabled)
    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set('obscuriaPowerBlocked', enabled == true, true)
        LocalPlayer.state:set('invBusy', enabled == true, true)
        LocalPlayer.state:set('inv_busy', enabled == true, true)
        LocalPlayer.state:set('Buttons', enabled == true, true)
        LocalPlayer.state:set('obBatForm', enabled == true, true)
    end
    if enabled then
        TriggerEvent('magic:client:forceCloseGrimoire', true)
        TriggerServerEvent('magic:server:setWandState', false)
        SetNuiFocus(false, false)
    end
    ObVampiros.UpdateAbility('passo_sombrio', { enabled = not enabled })
    ObVampiros.UpdateAbility('hipnose', { enabled = not enabled })
    ObVampiros.UpdateAbility('abraco_noite', { enabled = not enabled })
    ObVampiros.UpdateAbility('forma_morcego', { enabled = true, selected = enabled })
end

local function isBatFormInterrupted()
    local state = LocalPlayer and LocalPlayer.state
    if not state then return false end

    return state.magicFauna == true
        or state.obHypnotized == true
        or state.obInVehicleAttachment == true
end

local function safeGroundPosition(coords, ped)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    local ray = StartShapeTestRay(
        coords.x, coords.y, coords.z + 0.4,
        coords.x, coords.y, coords.z - 30.0,
        1,
        ped or PlayerPedId(),
        7
    )
    local status, hit, hitCoords = GetShapeTestResult(ray)
    local timeout = GetGameTimer() + 180
    while status == 1 and GetGameTimer() < timeout do
        Wait(0)
        status, hit, hitCoords = GetShapeTestResult(ray)
    end

    if status == 2 and hit == 1 and hitCoords then
        return vector3(coords.x, coords.y, hitCoords.z + 0.95)
    end

    return coords
end

local function stopBatDistortion()
    for i = 1, #batDistortionHandles do
        local handle = batDistortionHandles[i]
        if handle and handle ~= 0 and DoesParticleFxLoopedExist(handle) then
            StopParticleFxLooped(handle, true)
        end
    end
    batDistortionHandles = {}
    batDistortionEntity = 0
end

local function startBatDistortion(ped)
    if batDistortionEntity == ped and #batDistortionHandles > 0 then return end

    stopBatDistortion()
    local fx = Config.BatForm.flightDistortion
    if not fx or not ObVampiros.EnsurePtfx(fx.asset) then return end

    for i = 1, #DISTORTION_BONES do
        UseParticleFxAssetNextCall(fx.asset)
        local handle = StartParticleFxLoopedOnEntityBone(
            fx.name,
            ped,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            DISTORTION_BONES[i],
            fx.scale or 1.05,
            false, false, false
        )
        if handle and handle ~= 0 then
            batDistortionHandles[#batDistortionHandles + 1] = handle
        end
    end

    if #batDistortionHandles > 0 then
        batDistortionEntity = ped
    end
end

local function updateBatDistortion(ped)
    local fx = Config.BatForm.flightDistortion
    local active = fx and GetEntitySpeed(ped) >= (tonumber(fx.minimumSpeed) or 2.5)
    if active then
        startBatDistortion(ped)
    else
        stopBatDistortion()
    end
end

local function initializeBatAppearance(ped)
    if not DoesEntityExist(ped) then return end

    SetPedDefaultComponentVariation(ped)
    for _, component in ipairs(Config.BatForm.components or {}) do
        local id = math.max(0, math.floor(tonumber(component.id) or 0))
        local drawable = math.max(0, math.floor(tonumber(component.drawable) or 0))
        local texture = math.max(0, math.floor(tonumber(component.texture) or 0))
        local drawableCount = GetNumberOfPedDrawableVariations(ped, id)
        if drawableCount > drawable then
            local textureCount = GetNumberOfPedTextureVariations(ped, id, drawable)
            if textureCount > 0 then
                texture = math.min(texture, textureCount - 1)
            else
                texture = 0
            end
            SetPedComponentVariation(ped, id, drawable, texture, 0)
        end
    end

    ResetEntityAlpha(ped)
    SetEntityVisible(ped, true, false)
    SetEntityAlwaysPrerender(ped, true)
    SetEntityLocallyVisible(ped)
end

local function applyBatProtection(ped)
    local protectedHealth = math.max(500, tonumber(batProtectedHealth) or 500)
    if GetEntityMaxHealth(ped) < protectedHealth then
        SetEntityMaxHealth(ped, protectedHealth)
    end
    if GetEntityHealth(ped) < protectedHealth then
        SetEntityHealth(ped, protectedHealth)
    end

    SetPlayerInvincible(PlayerId(), true)
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetEntityCollision(ped, true, true)
    SetEntityProofs(ped, true, true, true, true, true, true, true, true)
    SetPedCanRagdoll(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetPedSuffersCriticalHits(ped, false)
    SetPedDiesWhenInjured(ped, false)
end

local function clearBatProtection(ped)
    SetPlayerInvincible(PlayerId(), false)
    SetEntityInvincible(ped, false)
    SetEntityCanBeDamaged(ped, true)
    SetEntityCollision(ped, true, true)
    SetEntityProofs(ped, false, false, false, false, false, false, false, false)
    SetPedCanRagdoll(ped, true)
    SetPedCanRagdollFromPlayerImpact(ped, true)
    SetPedSuffersCriticalHits(ped, true)
    SetPedDiesWhenInjured(ped, true)
end

local function recoverBatAfterImpact(ped)
    if not IsEntityDead(ped) and GetEntityHealth(ped) > 0 then
        return ped
    end

    stopBatDistortion()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, false, false)
    local recovered = PlayerPedId()
    applyBatProtection(recovered)
    Wait(0)

    recovered = PlayerPedId()
    initializeBatAppearance(recovered)
    SetEntityCoordsNoOffset(recovered, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(recovered, heading)
    SetEntityHasGravity(recovered, true)
    applyBatProtection(recovered)
    return recovered
end

local function startBatStateLoop()
    CreateThread(function()
        local sustainInterval = math.max(1000, tonumber(Config.BatForm.sustainInterval) or 8000)
        local nextChargeAt = GetGameTimer() + sustainInterval

        while transformed do
            local now = GetGameTimer()
            local bat = recoverBatAfterImpact(PlayerPedId())
            SetEntityLocallyVisible(bat)
            DisablePlayerFiring(PlayerId(), true)
            SetCurrentPedWeapon(bat, GetHashKey('WEAPON_UNARMED'), true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)

            applyBatProtection(bat)
            updateBatDistortion(bat)
            if now >= nextChargeAt then
                nextChargeAt = now + sustainInterval
                local ok, result = pcall(function()
                    return lib.callback.await('ob_vampiros:server:sustainBatForm', false)
                end)
                if not ok or type(result) ~= 'table' or result.success ~= true then
                    ObVampiros.FailAbility('forma_morcego')
                    leaveBatForm(false)
                    return
                end
            end

            if not ObVampiros.IsVampire() or isBatFormInterrupted() then
                leaveBatForm(true)
                return
            end
            Wait(0)
        end
    end)
end

local function enterBatForm()
    if transitioning or transformed or not ObVampiros.IsVampire() or ObVampiros.IsPowerBlocked() then
        ObVampiros.FailAbility('forma_morcego')
        return
    end
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        ObVampiros.FailAbility('forma_morcego')
        return
    end

    local model = ObVampiros.EnsureModel(Config.BatForm.model)
    if not model then
        ObVampiros.ClearSelection()
        ObVampiros.FailAbility('forma_morcego')
        return
    end
    if not ObVampiros.Authorize('forma_morcego') then
        SetModelAsNoLongerNeeded(model)
        return
    end

    transitioning = true
    local oldPed = PlayerPedId()
    originalAppearance = captureAppearance(oldPed)
    local coords, heading = GetEntityCoords(oldPed), GetEntityHeading(oldPed)
    FreezeEntityPosition(oldPed, true)
    if ObVampiros.EnsureAnim('amb@world_human_bum_standing@drunk@idle_a') then
        TaskPlayAnim(oldPed, 'amb@world_human_bum_standing@drunk@idle_a', 'idle_b', 4.0, -4.0, Config.BatForm.transitionTime, 49, 0.0, false, false, false)
    end
    playTransformationExplosion(oldPed, true)
    Wait(math.max(450, Config.BatForm.transitionTime - 300))
    fadeOut()

    local protectedHealth = math.max(
        originalAppearance.maxHealth or 200,
        tonumber(Config.BatForm.protectedHealth) or 2000
    )
    batProtectedHealth = protectedHealth
    SetPlayerModel(PlayerId(), model)
    local bat = PlayerPedId()
    applyBatProtection(bat)
    SetModelAsNoLongerNeeded(model)
    Wait(0)

    bat = PlayerPedId()
    initializeBatAppearance(bat)
    SetEntityCoordsNoOffset(bat, coords.x, coords.y, coords.z + 0.65, false, false, false)
    SetEntityHeading(bat, heading)
    SetEntityMaxHealth(bat, protectedHealth)
    SetEntityHealth(bat, protectedHealth)
    SetPedArmour(bat, originalAppearance.armor or 0)
    SetEntityHasGravity(bat, true)
    applyBatProtection(bat)
    FreezeEntityPosition(bat, false)

    transformed = true
    transitioning = false
    batSequence = batSequence + 1
    setBlocked(true)
    playSmoke(bat, 800)
    fadeIn()
    startBatStateLoop()
end

leaveBatForm = function(silent)
    if transitioning or not transformed then
        return
    end

    batSequence = batSequence + 1
    transitioning = true
    transformed = false
    stopBatDistortion()
    local bat = PlayerPedId()
    SetEntityAlwaysPrerender(bat, false)
    local coords = safeGroundPosition(GetEntityCoords(bat), bat)
    local heading = GetEntityHeading(bat)
    local health = Config.BatForm.preserveHealth and originalAppearance and originalAppearance.health
        or GetEntityHealth(bat)
    SetEntityHasGravity(bat, true)
    FreezeEntityPosition(bat, true)
    playTransformationExplosion(bat, true)
    Wait(650)
    fadeOut()

    local data = originalAppearance
    originalAppearance = nil
    if data then
        restoreAppearance(data)
        Wait(0)
        local ped = PlayerPedId()
        ResetEntityAlpha(ped)
        SetEntityVisible(ped, true, false)
        SetEntityAlwaysPrerender(ped, false)
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
        SetEntityHeading(ped, heading)
        local maxHealth = math.max(data.maxHealth or 200, 100)
        SetEntityMaxHealth(ped, maxHealth)
        SetEntityHealth(ped, math.min(maxHealth, math.max(105, health)))
        SetPedArmour(ped, data.armor or 0)
        clearBatProtection(ped)
        SetEntityHasGravity(ped, true)
        FreezeEntityPosition(ped, false)
        playTransformationExplosion(ped, false)
    end

    batProtectedHealth = math.max(500, tonumber(Config.BatForm.protectedHealth) or 2000)
    setBlocked(false)
    transitioning = false
    fadeIn()
    TriggerServerEvent('ob_vampiros:server:batEnded')
    if not silent then
        ObVampiros.StartCooldown('forma_morcego', Config.BatForm.returnCooldown)
    end
end

RegisterNetEvent('ob_vampiros:client:toggleBatForm', function()
    if transformed then
        leaveBatForm(false)
    else
        enterBatForm()
    end
end)

RegisterNetEvent('ob_vampiros:client:forceRestoreBat', function()
    leaveBatForm(true)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    stopBatDistortion()
    if transformed then leaveBatForm(true) end
end)
