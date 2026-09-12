ObVampiros = ObVampiros or {}

local BiteAnimation = {}
local lockedTargets = {}
local approachFxStates = {}
local approachFxSequence = 0
local APPROACH_FX_BONES = { 51826, 52301, 46078 }

local function settings()
    return Config.NightEmbrace.biteAnimation or {}
end

local function isValidPed(ped)
    return ped and ped ~= 0 and DoesEntityExist(ped) and not IsEntityDead(ped)
end

local function approachEffectSettings()
    local approach = settings().approach or {}
    return approach.effect or {}
end

local function restoreApproachAppearance(ped, alpha, visible)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    if alpha and alpha < 255 then
        SetEntityAlpha(ped, alpha, false)
    else
        ResetEntityAlpha(ped)
    end
    SetEntityVisible(ped, visible ~= false, false)
end

local function stopApproachFx(ped, expectedToken)
    local state = approachFxStates[ped]
    if not state or (expectedToken and state.token ~= expectedToken) then return end

    approachFxStates[ped] = nil
    restoreApproachAppearance(ped, state.originalAlpha, state.originalVisible)
end

local function emitApproachSmoke(ped)
    if not isValidPed(ped) then return end

    local effect = approachEffectSettings()
    local asset = tostring(effect.asset or 'scr_powerplay')
    if not ObVampiros.EnsurePtfx(asset) then return end

    local color = effect.color or { 0.52, 0.0, 0.055 }
    for i = 1, #APPROACH_FX_BONES do
        UseParticleFxAssetNextCall(asset)
        SetParticleFxNonLoopedColour(
            tonumber(color[1]) or 0.52,
            tonumber(color[2]) or 0.0,
            tonumber(color[3]) or 0.055
        )
        SetParticleFxNonLoopedAlpha(tonumber(effect.alpha) or 0.92)
        StartParticleFxNonLoopedOnPedBone(
            tostring(effect.name or 'sp_powerplay_beast_appear_trails'),
            ped,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            APPROACH_FX_BONES[i],
            tonumber(effect.scale) or 4.8,
            false, false, false
        )
    end
end

local function startApproachFx(ped, duration, restoreAlpha)
    if not isValidPed(ped) then return nil end

    stopApproachFx(ped)
    approachFxSequence = approachFxSequence + 1
    local token = approachFxSequence
    local effect = approachEffectSettings()
    local state = {
        token = token,
        originalAlpha = restoreAlpha or GetEntityAlpha(ped),
        originalVisible = IsEntityVisible(ped),
    }
    approachFxStates[ped] = state
    if effect.hideBody ~= false then
        SetEntityVisible(ped, false, false)
    else
        SetEntityAlpha(ped, math.floor(tonumber(effect.bodyAlpha) or 38), false)
    end

    CreateThread(function()
        local endsAt = GetGameTimer() + math.max(100, tonumber(duration) or 900)
        local interval = math.max(60, tonumber(effect.pulseInterval) or 105)
        while approachFxStates[ped] == state and GetGameTimer() < endsAt
            and isValidPed(ped) do
            emitApproachSmoke(ped)
            Wait(interval)
        end
        stopApproachFx(ped, token)
    end)
    return token
end

RegisterNetEvent('ob_vampiros:client:showEmbraceApproachFx', function(sourceId, duration)
    local player = GetPlayerFromServerId(tonumber(sourceId) or -1)
    if player == -1 then return end

    local ped = GetPlayerPed(player)
    if isValidPed(ped) then
        startApproachFx(ped, duration, 255)
    end
end)

function BiteAnimation.GetAlignmentDelay()
    return math.max(0, tonumber(settings().alignmentDelay) or 250)
end

function BiteAnimation.GetApproachDuration(ped, targetPed, forcedDuration)
    local approach = settings().approach or {}
    local minimum = math.max(0, tonumber(approach.minimumDuration) or 320)
    local maximum = math.max(minimum, tonumber(approach.maximumDuration) or 900)

    if forcedDuration then
        return math.min(maximum, math.max(minimum, tonumber(forcedDuration) or maximum))
    end
    if isValidPed(ped) and isValidPed(targetPed) then
        local distance = #(GetEntityCoords(targetPed) - GetEntityCoords(ped))
        local speed = math.max(1.0, tonumber(approach.speed) or 18.0)
        return math.floor(math.min(maximum, math.max(minimum, distance / speed * 1000.0)))
    end
    return maximum
end

local function blockApproachControls()
    DisablePlayerFiring(PlayerId(), true)
    DisableControlAction(0, 21, true)
    DisableControlAction(0, 22, true)
    DisableControlAction(0, 23, true)
    DisableControlAction(0, 24, true)
    DisableControlAction(0, 25, true)
    DisableControlAction(0, 30, true)
    DisableControlAction(0, 31, true)
    DisableControlAction(0, 44, true)
    DisableControlAction(0, 75, true)
end

local function placeDestinationOnGround(ped, destination, referenceZ)
    RequestCollisionAtCoord(destination.x, destination.y, referenceZ)
    local foundGround, groundZ = GetGroundZFor_3dCoord(
        destination.x,
        destination.y,
        referenceZ + 15.0,
        false
    )
    if not foundGround then return destination end

    local minimum = GetModelDimensions(GetEntityModel(ped))
    local bottomOffset = minimum and minimum.z and math.max(0.0, -minimum.z) or 0.95
    return vector3(destination.x, destination.y, groundZ + bottomOffset + 0.03)
end

function BiteAnimation.Approach(ped, targetPed, forcedDuration, options)
    if not isValidPed(ped) or not isValidPed(targetPed) then return false end
    options = type(options) == 'table' and options or {}

    local config = settings()
    local approach = config.approach or {}
    local offset = config.targetOffset or {}
    local origin = GetEntityCoords(ped)
    local target = GetEntityCoords(targetPed)
    local delta = target - origin
    local horizontalDistance = math.sqrt(delta.x * delta.x + delta.y * delta.y)
    local direction

    if horizontalDistance > 0.001 then
        direction = vector3(delta.x / horizontalDistance, delta.y / horizontalDistance, 0.0)
    else
        direction = GetEntityForwardVector(ped)
        direction = vector3(direction.x, direction.y, 0.0)
    end

    local right = vector3(-direction.y, direction.x, 0.0)
    local destination = target
        - direction * (tonumber(offset.y) or 0.45)
        - right * (tonumber(offset.x) or 0.10)
        - vector3(0.0, 0.0, tonumber(offset.z) or 0.0)
    if options.keepAboveGround == true then
        destination = placeDestinationOnGround(ped, destination, math.max(origin.z, target.z))
    end
    local heading = GetHeadingFromVector_2d(direction.x, direction.y)
    local duration = BiteAnimation.GetApproachDuration(ped, targetPed, forcedDuration)

    ClearPedTasksImmediately(ped)
    SetEntityHeading(ped, heading)
    SetEntityCollision(ped, false, false)
    SetEntityHasGravity(ped, false)
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)

    local dictionary = tostring(approach.dictionary or '')
    local clip = tostring(approach.clip or '')
    if dictionary ~= '' and clip ~= ''
        and ObVampiros.EnsureAnim(dictionary, approach.loadTimeout) then
        TaskPlayAnim(
            ped, dictionary, clip,
            4.0, -4.0, duration + 300,
            math.floor(tonumber(approach.flag) or 1),
            0.0, false, false, false
        )
        SetPedKeepTask(ped, true)
    end

    local approachFxToken = startApproachFx(ped, duration)
    TriggerServerEvent('ob_vampiros:server:syncEmbraceApproachFx', duration)

    local startedAt = GetGameTimer()
    while isValidPed(ped) and isValidPed(targetPed)
        and GetGameTimer() - startedAt < duration do
        local progress = math.min(1.0, (GetGameTimer() - startedAt) / math.max(1, duration))
        local eased = progress * progress * (3.0 - 2.0 * progress)
        local arc = math.sin(eased * math.pi) * (tonumber(approach.height) or 0.22)
        local coords = origin + (destination - origin) * eased + vector3(0.0, 0.0, arc)

        blockApproachControls()
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
        SetEntityVelocity(ped, 0.0, 0.0, 0.0)
        ForceEntityAiAndAnimationUpdate(ped)
        Wait(0)
    end

    if isValidPed(ped) then
        SetEntityCoordsNoOffset(
            ped, destination.x, destination.y, destination.z,
            false, false, false
        )
        SetEntityHeading(ped, heading)
        SetEntityVelocity(ped, 0.0, 0.0, 0.0)
        SetEntityHasGravity(ped, true)
        SetEntityCollision(ped, true, true)
        SetPedKeepTask(ped, false)
        ClearPedTasksImmediately(ped)
    end
    stopApproachFx(ped, approachFxToken)
    return isValidPed(ped) and isValidPed(targetPed)
end

function BiteAnimation.Prepare(ped, role, otherPed)
    if not isValidPed(ped) or not isValidPed(otherPed) then return false end

    if role == 'target' then
        local casterCoords = GetEntityCoords(otherPed)
        local targetCoords = GetEntityCoords(ped)

        ClearPedTasksImmediately(ped)
        ClearPedSecondaryTask(ped)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCanPlayAmbientAnims(ped, false)
        SetPedCanPlayAmbientBaseAnims(ped, false)
        SetPedCanRagdoll(ped, false)
        SetEntityCollision(ped, false, false)
        DetachEntity(ped, true, true)
        SetEntityHeading(
            ped,
            GetHeadingFromVector_2d(
                casterCoords.x - targetCoords.x,
                casterCoords.y - targetCoords.y
            )
        )
        FreezeEntityPosition(ped, true)
        lockedTargets[ped] = true
    else
        TaskTurnPedToFaceEntity(ped, otherPed, BiteAnimation.GetAlignmentDelay())
    end

    return true
end

function BiteAnimation.Release(ped, role)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end

    if role == 'target' and lockedTargets[ped] then
        lockedTargets[ped] = nil
        DetachEntity(ped, true, true)
        SetEntityCollision(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, false)
        SetPedCanPlayAmbientAnims(ped, true)
        SetPedCanPlayAmbientBaseAnims(ped, true)
        SetPedCanRagdoll(ped, true)
    end

    stopApproachFx(ped)
    SetPedKeepTask(ped, false)
    SetEntityHasGravity(ped, true)
    SetEntityCollision(ped, true, true)
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    return true
end

function BiteAnimation.IsTargetLocked(ped)
    return lockedTargets[ped] ~= nil
end

function BiteAnimation.StopAllApproachFx()
    local peds = {}
    for ped in pairs(approachFxStates) do peds[#peds + 1] = ped end
    for i = 1, #peds do stopApproachFx(peds[i]) end
end

function BiteAnimation.Play(ped, role, duration)
    if not isValidPed(ped) then return false end

    local config = settings()
    local dictionary = tostring(config.dictionary or 'r9@feed@new')
    local clip = role == 'target'
        and tostring(config.targetClip or 'slave')
        or tostring(config.casterClip or 'master')
    local flag = role == 'target'
        and tonumber(config.targetFlag)
        or tonumber(config.casterFlag)

    if not ObVampiros.EnsureAnim(dictionary, config.loadTimeout) then return false end

    TaskPlayAnim(
        ped,
        dictionary,
        clip,
        tonumber(config.blendIn) or 1.0,
        tonumber(config.blendOut) or 1.0,
        math.max(500, tonumber(duration) or 7000),
        math.floor(flag or tonumber(config.flag) or 32),
        0.0,
        false,
        false,
        false
    )
    SetPedKeepTask(ped, true)
    return true
end

function BiteAnimation.ApplyAftermath(ped)
    if not isValidPed(ped) then return false end

    local duration = math.max(0, tonumber(settings().aftermathRagdoll) or 6000)
    if duration <= 0 then return false end

    SetPedCanRagdoll(ped, true)
    CreateThread(function()
        local endsAt = GetGameTimer() + duration
        while isValidPed(ped) and GetGameTimer() < endsAt do
            if not IsPedRagdoll(ped) then
                local remaining = math.max(250, endsAt - GetGameTimer())
                SetPedToRagdoll(ped, remaining, remaining, 0, false, false, false)
            end
            Wait(200)
        end
    end)
    return true
end

ObVampiros.BiteAnimation = BiteAnimation

CreateThread(function()
    Wait(0)
    local config = settings()
    ObVampiros.EnsureAnim(
        tostring(config.dictionary or 'r9@feed@new'),
        config.loadTimeout
    )

    local approach = config.approach or {}
    if approach.dictionary then
        ObVampiros.EnsureAnim(
            tostring(approach.dictionary),
            approach.loadTimeout
        )
    end
    local effect = approach.effect or {}
    if effect.asset then
        ObVampiros.EnsurePtfx(tostring(effect.asset))
    end
end)
