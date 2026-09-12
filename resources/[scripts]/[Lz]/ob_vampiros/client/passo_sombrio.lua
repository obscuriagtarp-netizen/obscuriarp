local shadowStepActive = false
local shadowDistortionActive = false
local shadowDistortionHandles = {}
local shadowWasJumping = false
local shadowShiftWasDown = false
local lastJumpBurstAt = 0
local lastShiftBurstAt = 0

local SMOKE_BONES = {
    24818, 24817, 24816, 31086, 2108, 20781, 2992,
    22711, 16335, 46078, 14201, 52301, 51826, 58271,
    11816, 23553, 6442, 23639, 57005, 18905,
}
local DISTORTION_BONES = { 24818, 23553 }

local function stopParticle(handle)
    if handle and handle ~= 0 and DoesParticleFxLoopedExist(handle) then
        StopParticleFxLooped(handle, true)
    end
end

local function stopDistortion()
    for i = 1, #shadowDistortionHandles do
        stopParticle(shadowDistortionHandles[i])
    end
    shadowDistortionHandles = {}
    shadowDistortionActive = false
end

local function startDistortion(ped)
    if shadowDistortionActive then return end

    local fx = Config.ShadowStep.effect
    if not ObVampiros.EnsurePtfx(fx.distortionAsset) then return end

    for i = 1, #DISTORTION_BONES do
        UseParticleFxAssetNextCall(fx.distortionAsset)
        local handle = StartParticleFxLoopedOnEntityBone(
            fx.distortionName,
            ped,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            DISTORTION_BONES[i],
            fx.distortionScale,
            false, false, false
        )
        if handle and handle ~= 0 then
            shadowDistortionHandles[#shadowDistortionHandles + 1] = handle
        end
    end

    shadowDistortionActive = #shadowDistortionHandles > 0
end

local function setDistortion(active, ped)
    if active then
        startDistortion(ped)
    else
        stopDistortion()
    end
end

local function playSmokeBurst(ped, replicate)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end

    local fx = Config.ShadowStep.effect
    if not ObVampiros.EnsurePtfx(fx.smokeAsset) then return end

    for i = 1, #SMOKE_BONES do
        UseParticleFxAssetNextCall(fx.smokeAsset)
        SetParticleFxNonLoopedAlpha(fx.smokeAlpha)
        SetParticleFxNonLoopedColour(fx.smokeColor[1], fx.smokeColor[2], fx.smokeColor[3])
        StartParticleFxNonLoopedOnPedBone(
            fx.smokeName,
            ped,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            SMOKE_BONES[i],
            fx.smokeScale,
            false, false, false
        )
    end

    if replicate then
        TriggerServerEvent('ob_vampiros:server:shadowSmokeBurst')
    end
end

RegisterNetEvent('ob_vampiros:client:shadowSmokeBurst', function(sourceId)
    local player = GetPlayerFromServerId(tonumber(sourceId) or -1)
    if player == -1 then return end
    playSmokeBurst(GetPlayerPed(player), false)
end)

local function stopShadowStep(silent, serverAlreadyStopped)
    if not shadowStepActive then
        stopDistortion()
        return
    end

    shadowStepActive = false
    shadowWasJumping = false
    shadowShiftWasDown = false
    lastJumpBurstAt = 0
    lastShiftBurstAt = 0
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    SetPedMoveRateOverride(PlayerPedId(), 1.0)
    StopGameplayCamShaking(true)
    stopDistortion()
    ObVampiros.UpdateAbility('passo_sombrio', { selected = false })

    if not silent then
        ObVampiros.StartCooldown('passo_sombrio', Config.ShadowStep.cooldown)
    end
    if not serverAlreadyStopped then
        TriggerServerEvent('ob_vampiros:server:shadowStepEnded')
    end
end

RegisterNetEvent('ob_vampiros:client:passoSombrio', function()
    if shadowStepActive then
        stopShadowStep(false, false)
        return
    end

    if not ObVampiros.IsVampire() or ObVampiros.IsPowerBlocked() then
        ObVampiros.FailAbility('passo_sombrio')
        return
    end
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        ObVampiros.FailAbility('passo_sombrio')
        return
    end

    if not ObVampiros.Authorize('passo_sombrio') then
        return
    end

    shadowStepActive = true
    shadowWasJumping = false
    shadowShiftWasDown = false
    lastJumpBurstAt = 0
    lastShiftBurstAt = 0
    ObVampiros.UpdateAbility('passo_sombrio', { selected = true })
    playSmokeBurst(PlayerPedId(), true)

    CreateThread(function()
        local sustainInterval = math.max(1000, tonumber(Config.ShadowStep.sustainInterval) or 5000)
        local nextChargeAt = GetGameTimer() + sustainInterval

        while shadowStepActive do
            local ped = PlayerPedId()
            local now = GetGameTimer()
            local speedKmh = GetEntitySpeed(ped) * 3.6
            local running = IsPedOnFoot(ped) and (IsPedRunning(ped) or IsPedSprinting(ped))
            local distorting = running
                and speedKmh >= (Config.ShadowStep.effect.distortionMinimumKmh or 40.0)
            local jumping = IsPedJumping(ped)
            local shiftDown = IsControlPressed(0, 21)
            local burstCooldown = math.max(250, tonumber(Config.ShadowStep.effect.smokeBurstCooldown) or 500)
            local weakened = ObVampiros.IsSolarWeakened()
            local solar = Config.SolarWeakness and Config.SolarWeakness.shadowStep or {}
            local sprintMultiplier = weakened
                and (tonumber(solar.sprintMultiplier) or 1.18)
                or (tonumber(Config.ShadowStep.sprintMultiplier) or 1.45)
            local moveRate = weakened
                and (tonumber(solar.moveRate) or 1.12)
                or (tonumber(Config.ShadowStep.moveRate) or 1.35)

            SetRunSprintMultiplierForPlayer(PlayerId(), math.min(1.49, math.max(1.0, sprintMultiplier)))
            SetPedMoveRateOverride(ped, math.max(1.0, moveRate))
            RestorePlayerStamina(PlayerId(), 1.0)
            setDistortion(distorting, ped)

            if jumping and not shadowWasJumping and now - lastJumpBurstAt >= burstCooldown then
                playSmokeBurst(ped, true)
                lastJumpBurstAt = now
            elseif shiftDown and not shadowShiftWasDown
                and GetEntitySpeed(ped) >= (Config.ShadowStep.effect.smokeMinimumSpeed or 1.2)
                and now - lastShiftBurstAt >= burstCooldown then
                playSmokeBurst(ped, true)
                lastShiftBurstAt = now
            end
            shadowWasJumping = jumping
            shadowShiftWasDown = shiftDown

            if Config.ShadowStep.highJump and (not weakened or solar.highJump ~= false) then
                SetSuperJumpThisFrame(PlayerId())
            end

            if now >= nextChargeAt then
                nextChargeAt = now + sustainInterval
                local ok, result = pcall(function()
                    return lib.callback.await('ob_vampiros:server:sustainShadowStep', false)
                end)
                if not ok or type(result) ~= 'table' or result.success ~= true then
                    ObVampiros.FailAbility('passo_sombrio')
                    local serverConfirmedStop = ok and type(result) == 'table'
                    stopShadowStep(false, serverConfirmedStop)
                    return
                end
            end

            if IsEntityDead(ped) or not ObVampiros.IsVampire() or ObVampiros.IsPowerBlocked() then
                stopShadowStep(false, false)
                return
            end
            Wait(0)
        end
    end)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        stopShadowStep(true, true)
    end
end)
