local Magic = MagicHelpers

local blinkCasting = false
local PENUMBRA_ASSET = "scr_powerplay"
local PENUMBRA_FX = "sp_powerplay_beast_appear_trails"
local PENUMBRA_BONES = { 51826, 52301, 46078 }
local remoteBlinkTokens = {}
local COLLISION_FLAGS = 511

local function GetBlinkConfig()
    return (Config.Spells and Config.Spells["blink"]) or {}
end

local function Clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function EaseInOut(t)
    t = Clamp(t, 0.0, 1.0)
    return t * t * (3.0 - (2.0 * t))
end

local function Normalize(v)
    local mag = #(v)
    if mag < 0.0001 then
        return vector3(0.0, 0.0, 0.0)
    end

    return v / mag
end

local function RotationToDirection(rot)
    local pitch = math.rad(rot.x)
    local yaw = math.rad(rot.z)

    return vector3(
        -math.sin(yaw) * math.cos(pitch),
        math.cos(yaw) * math.cos(pitch),
        math.sin(pitch)
    )
end

local function EnsureAnimDict(dict, timeoutMs)
    if not dict or dict == "" then
        return false
    end

    if HasAnimDictLoaded(dict) then
        return true
    end

    RequestAnimDict(dict)
    local timeout = GetGameTimer() + (timeoutMs or 2500)
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(0)
    end

    return HasAnimDictLoaded(dict)
end

local function EnsurePtfxAsset(asset)
    if HasNamedPtfxAssetLoaded(asset) then
        return true
    end

    RequestNamedPtfxAsset(asset)
    local timeout = GetGameTimer() + 2000
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < timeout do
        Wait(0)
    end

    return HasNamedPtfxAssetLoaded(asset)
end

local function PlayConfiguredAnim(ped, animCfg, durationOverride)
    if not animCfg or not animCfg.dict or not animCfg.anim then
        return false
    end

    if not EnsureAnimDict(animCfg.dict, animCfg.loadTimeout) then
        return false
    end

    TaskPlayAnim(
        ped,
        animCfg.dict,
        animCfg.anim,
        8.0,
        -8.0,
        durationOverride or animCfg.duration or -1,
        animCfg.flag or 49,
        0.0,
        false,
        false,
        false
    )

    return true
end

local function PlayPurpleBurst(coords, scale)
    if not coords or not EnsurePtfxAsset("core") then
        return
    end

    local fxScale = scale or 1.0

    UseParticleFxAssetNextCall("core")
    SetParticleFxNonLoopedColour(0.48, 0.02, 0.86)
    StartParticleFxNonLoopedAtCoord(
        "exp_grd_grenade_smoke",
        coords.x,
        coords.y,
        coords.z - 0.2,
        0.0,
        0.0,
        0.0,
        fxScale * 0.72,
        false,
        false,
        false
    )

    UseParticleFxAssetNextCall("core")
    SetParticleFxNonLoopedColour(0.74, 0.18, 1.0)
    StartParticleFxNonLoopedAtCoord(
        "exp_grd_grenade_smoke",
        coords.x + 0.12,
        coords.y - 0.08,
        coords.z + 0.18,
        0.0,
        0.0,
        0.0,
        fxScale * 0.46,
        false,
        false,
        false
    )
end

local function PlayPenumbraTrail(ped, charge)
    if not DoesEntityExist(ped) or not EnsurePtfxAsset(PENUMBRA_ASSET) then
        return
    end

    local scale = 4.8 + ((charge or 0.0) * 1.1)

    for _, bone in ipairs(PENUMBRA_BONES) do
        UseParticleFxAssetNextCall(PENUMBRA_ASSET)
        SetParticleFxNonLoopedColour(0.502, 0.0, 0.502)
        SetParticleFxNonLoopedAlpha(1.0)
        StartParticleFxNonLoopedOnPedBone(
            PENUMBRA_FX,
            ped,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            bone,
            scale,
            false,
            false,
            false
        )
    end
end

local function SetBlinkPedVisible(ped, visible)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end

    SetEntityVisible(ped, visible == true, false)
    if visible == true then
        ResetEntityAlpha(ped)
    else
        SetEntityAlpha(ped, 0, false)
    end
end

local function RestoreRemoteBlink(sourceId, withBurst)
    local player = GetPlayerFromServerId(sourceId)
    if player == -1 then return end

    local ped = GetPlayerPed(player)
    if ped == 0 or not DoesEntityExist(ped) then return end

    SetBlinkPedVisible(ped, true)
    if Main and Main.SetWandVisibleFor then
        Main.SetWandVisibleFor(sourceId, true)
    end
    if withBurst == true then
        PlayPurpleBurst(GetEntityCoords(ped) + vector3(0.0, 0.0, 0.45), 1.15)
    end
end

RegisterNetEvent("magic:client:blinkVisual", function(sourceId, active, charge, duration)
    sourceId = tonumber(sourceId)
    if not sourceId or sourceId == GetPlayerServerId(PlayerId()) then return end

    local token = (remoteBlinkTokens[sourceId] or 0) + 1
    if active ~= true then
        remoteBlinkTokens[sourceId] = nil
        RestoreRemoteBlink(sourceId, true)
        return
    end

    remoteBlinkTokens[sourceId] = token
    charge = Clamp(tonumber(charge) or 1.0, 0.0, 1.0)
    duration = math.max(500, math.min(6500, tonumber(duration) or 1800))

    CreateThread(function()
        local endsAt = GetGameTimer() + duration + 700
        local nextFxAt = 0
        local started = false

        while remoteBlinkTokens[sourceId] == token and GetGameTimer() < endsAt do
            local player = GetPlayerFromServerId(sourceId)
            local ped = player ~= -1 and GetPlayerPed(player) or 0

            if ped ~= 0 and DoesEntityExist(ped) then
                if not started then
                    started = true
                    PlayPurpleBurst(GetEntityCoords(ped) + vector3(0.0, 0.0, 0.65), 1.0 + charge)
                end

                SetBlinkPedVisible(ped, false)
                if Main and Main.SetWandVisibleFor then
                    Main.SetWandVisibleFor(sourceId, false)
                end
                if GetGameTimer() >= nextFxAt then
                    nextFxAt = GetGameTimer() + 170
                    PlayPenumbraTrail(ped, charge)
                end
            end

            Wait(30)
        end

        if remoteBlinkTokens[sourceId] == token then
            remoteBlinkTokens[sourceId] = nil
            RestoreRemoteBlink(sourceId, true)
        end
    end)
end)

local function GetChargeValue()
    local charge = 1.0

    if MagicGrimoire and MagicGrimoire.ConsumePendingCharge then
        charge = MagicGrimoire.ConsumePendingCharge("blink") or charge
    end

    return Clamp(tonumber(charge) or 1.0, 0.0, 1.0)
end

local function AwaitShapeTest(handle, timeoutMs)
    local status, hit, hitCoords, surfaceNormal, entity = GetShapeTestResult(handle)
    local timeout = GetGameTimer() + (timeoutMs or 180)

    while status == 1 and GetGameTimer() < timeout do
        Wait(0)
        status, hit, hitCoords, surfaceNormal, entity = GetShapeTestResult(handle)
    end

    return status == 2 and hit == 1, hitCoords, surfaceNormal, entity
end

local function TraceRay(from, to, ped)
    return AwaitShapeTest(StartShapeTestRay(
        from.x, from.y, from.z,
        to.x, to.y, to.z,
        COLLISION_FLAGS,
        ped,
        7
    ))
end

local function TraceCapsule(from, to, radius, ped)
    return AwaitShapeTest(StartShapeTestCapsule(
        from.x, from.y, from.z,
        to.x, to.y, to.z,
        radius,
        COLLISION_FLAGS,
        ped,
        7
    ))
end

local function ResolveLocalFloor(target, origin, cfg, ped)
    local offsetZ = tonumber(cfg.landingOffsetZ) or 0.95
    local depth = math.max(4.0, tonumber(cfg.groundProbeDepth) or 160.0)
    local probeHeights = { math.max(origin.z, target.z), target.z, origin.z }
    local tested = {}

    for _, probeZ in ipairs(probeHeights) do
        local key = math.floor(probeZ * 10.0)
        if not tested[key] then
            tested[key] = true
            local from = vector3(target.x, target.y, probeZ + 1.25)
            local to = vector3(target.x, target.y, probeZ - depth)
            local hit, hitCoords = TraceRay(from, to, ped)
            if hit and hitCoords then
                return vector3(target.x, target.y, hitCoords.z + offsetZ)
            end
        end
    end

    return nil
end

local function HasStandingClearance(target, ped, cfg)
    local radius = math.max(0.25, tonumber(cfg.clearanceRadius) or 0.36)
    local from = target + vector3(0.0, 0.0, -0.42)
    local to = target + vector3(0.0, 0.0, 0.72)
    local hit = TraceCapsule(from, to, radius, ped)
    return hit ~= true
end

local function FindSafeLanding(target, origin, direction, ped, cfg)
    local retreatStep = math.max(0.25, tonumber(cfg.landingRetreatStep) or 0.5)
    local retreatLimit = math.max(1.0, tonumber(cfg.landingRetreatLimit) or 3.0)
    local attempts = math.floor(retreatLimit / retreatStep)

    for attempt = 0, attempts do
        local candidate = target - (direction * (attempt * retreatStep))
        local grounded = ResolveLocalFloor(candidate, origin, cfg, ped)
        if grounded and HasStandingClearance(grounded, ped, cfg) then
            return grounded
        end
    end

    return nil
end

local function HasLandingSurface(target, ped)
    local from = target + vector3(0.0, 0.0, 0.35)
    local to = target - vector3(0.0, 0.0, 1.65)
    return TraceRay(from, to, ped) == true
end

local function TraceBlinkArc(origin, target, height, ped, cfg)
    local segments = math.max(8, math.floor(tonumber(cfg.collisionSegments) or 16))
    local radius = math.max(0.25, tonumber(cfg.pathRadius) or 0.38)
    local previous = origin

    for index = 1, segments do
        local t = index / segments
        local arc = math.sin(t * math.pi) * height
        local current = vector3(
            origin.x + ((target.x - origin.x) * t),
            origin.y + ((target.y - origin.y) * t),
            origin.z + ((target.z - origin.z) * t) + arc
        )
        local hit, hitCoords, surfaceNormal = TraceCapsule(previous, current, radius, ped)
        if hit then
            return false, hitCoords, surfaceNormal
        end
        previous = current
    end

    return true
end

local function GetFlightHeightCandidates(origin, target, cfg)
    local distance = #(target - origin)
    local configured = math.max(0.0, tonumber(cfg.flightHeight) or 5.0)
    local preferred = math.max(configured, math.min(10.0, distance * 0.06))
    return { preferred, math.min(2.0, preferred), 0.15 }
end

local function ResolveImpactRoute(origin, hitCoords, surfaceNormal, direction, ped, cfg)
    if not hitCoords then
        return nil, nil
    end

    local offsetZ = tonumber(cfg.landingOffsetZ) or 0.95
    local walkableNormalZ = tonumber(cfg.walkableNormalZ) or 0.55
    if surfaceNormal and surfaceNormal.z >= walkableNormalZ then
        local surfaceLanding = vector3(hitCoords.x, hitCoords.y, hitCoords.z + offsetZ)
        if HasStandingClearance(surfaceLanding, ped, cfg) then
            return surfaceLanding, nil
        end
    end

    local impactDirection = Normalize(vector3(
        hitCoords.x - origin.x,
        hitCoords.y - origin.y,
        0.0
    ))
    if #(impactDirection) < 0.0001 then
        impactDirection = direction
    end

    local clearance = math.max(0.75, tonumber(cfg.wallClearance) or 1.05)
    local safePoint = hitCoords - (impactDirection * clearance)
    local landing = FindSafeLanding(safePoint, origin, impactDirection, ped, cfg)
    if not landing then
        return nil, nil
    end

    local impactPoint = vector3(
        safePoint.x,
        safePoint.y,
        math.max(hitCoords.z, landing.z + 0.75)
    )
    return landing, impactPoint
end

local function FindSafeFlightRoute(origin, target, direction, ped, cfg)
    local candidates = GetFlightHeightCandidates(origin, target, cfg)
    local tested = {}
    local fallback = nil

    for _, height in ipairs(candidates) do
        local key = math.floor(height * 100.0)
        if not tested[key] then
            tested[key] = true
            local clear, hitCoords, surfaceNormal = TraceBlinkArc(origin, target, height, ped, cfg)
            if clear then
                return target, height, nil
            end

            local landing, impactPoint = ResolveImpactRoute(
                origin,
                hitCoords,
                surfaceNormal,
                direction,
                ped,
                cfg
            )
            local routePoint = impactPoint or landing
            if routePoint then
                local routeDistance = #(routePoint - origin)
                if routeDistance >= 1.25 and (
                    not fallback or routeDistance < fallback.distance
                ) then
                    fallback = {
                        landing = landing,
                        impactPoint = impactPoint,
                        routePoint = routePoint,
                        distance = routeDistance
                    }
                end
            end
        end
    end

    if fallback then
        tested = {}
        for _, height in ipairs(GetFlightHeightCandidates(origin, fallback.routePoint, cfg)) do
            local key = math.floor(height * 100.0)
            if not tested[key] then
                tested[key] = true
                if TraceBlinkArc(origin, fallback.routePoint, height, ped, cfg) then
                    return fallback.landing, height, fallback.impactPoint
                end
            end
        end
    end

    return nil, nil, nil
end

local function GetAimDestination(ped, charge)
    local cfg = GetBlinkConfig()
    local minDistance = cfg.minDistance or 14.0
    local maxDistance = cfg.maxDistance or cfg.distance or 120.0
    local distance = minDistance + ((maxDistance - minDistance) * charge)
    local origin = GetEntityCoords(ped)

    local ray = Magic.RaycastFromCamera(distance, -1)
    local direction = ray and ray.direction or Normalize(RotationToDirection(GetGameplayCamRot(2)))
    if #(direction) < 0.0001 then
        direction = Normalize(GetEntityForwardVector(ped))
    end

    local target = origin + (direction * distance)
    if ray and ray.hit and ray.coords then
        target = ray.coords - (direction * 0.75)
    end

    local horizontal = vector3(target.x - origin.x, target.y - origin.y, 0.0)
    local travelDirection = Normalize(horizontal)
    if #(travelDirection) < 0.0001 then
        travelDirection = Normalize(vector3(direction.x, direction.y, 0.0))
    end
    if #(travelDirection) < 0.0001 then
        local forward = GetEntityForwardVector(ped)
        travelDirection = Normalize(vector3(forward.x, forward.y, 0.0))
    end

    if #(target - origin) < 1.25 then
        return nil, nil, nil, "blocked"
    end

    local routeTarget, height, impactPoint = FindSafeFlightRoute(
        origin,
        target,
        travelDirection,
        ped,
        cfg
    )
    if not routeTarget or height == nil then
        return nil, nil, nil, "blocked"
    end

    if not impactPoint and not HasLandingSurface(routeTarget, ped) then
        local landing = FindSafeLanding(
            routeTarget,
            origin,
            travelDirection,
            ped,
            cfg
        )
        if not landing then
            return nil, nil, nil, "landing"
        end

        impactPoint = routeTarget
        routeTarget = landing
    end

    return routeTarget, travelDirection, distance, nil, height, impactPoint
end

local function RestorePedAfterBlink(ped, keepInvincible)
    if not DoesEntityExist(ped) then
        return
    end

    if Main and Main.SetLocalWandVisible then
        Main.SetLocalWandVisible(true)
    end

    ClearPedTasksImmediately(ped)
    SetBlinkPedVisible(ped, true)
    SetEntityCollision(ped, true, true)
    SetEntityHasGravity(ped, true)
    SetEntityInvincible(ped, keepInvincible)
    FreezeEntityPosition(ped, false)
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
    SetEntityAngularVelocity(ped, 0.0, 0.0, 0.0)
end

local function LockBlinkControls()
    DisableControlAction(0, 24, true)
    DisableControlAction(0, 25, true)
    DisableControlAction(0, 30, true)
    DisableControlAction(0, 31, true)
    DisableControlAction(0, 22, true)
end

local function PerformBlinkRush(ped, target, direction, charge, height, impactPoint)
    local cfg = GetBlinkConfig()
    local origin = GetEntityCoords(ped)
    local flightTarget = impactPoint or target
    local flightDistance = #(flightTarget - origin)
    local flightDuration = Clamp(
        math.floor((flightDistance / (cfg.flightSpeed or 40.0)) * 1000.0),
        cfg.minFlightMs or 850,
        cfg.maxFlightMs or 2600
    )
    local descentDuration = 0
    if impactPoint then
        local descentDistance = #(target - impactPoint)
        descentDuration = Clamp(
            math.floor((descentDistance / (cfg.descentSpeed or 28.0)) * 1000.0),
            cfg.minImpactDescentMs or 350,
            cfg.maxImpactDescentMs or 3200
        )
    end
    local duration = flightDuration + descentDuration
    height = math.max(0.0, tonumber(height) or 0.0)
    local heading = GetHeadingFromVector_2d(direction.x, direction.y)
    local keepInvincible = LocalPlayer and LocalPlayer.state and LocalPlayer.state.magicInvulneris == true

    TriggerServerEvent("magic:server:blinkVisual", true, charge, duration)

    if Main and Main.SetLocalWandVisible then
        Main.SetLocalWandVisible(false)
    end

    StartScreenEffect("SwitchShortMichaelIn", 0, false)
    SetTimecycleModifier("BarryFadeOut")
    SetTimecycleModifierStrength(0.16 + (charge * 0.12))

    SetEntityHeading(ped, heading)
    SetEntityCollision(ped, false, false)
    SetEntityHasGravity(ped, false)
    SetEntityInvincible(ped, true)
    SetBlinkPedVisible(ped, false)

    if not PlayConfiguredAnim(ped, cfg.flightAnimation, duration + 350) then
        PlayConfiguredAnim(ped, cfg.animation, duration + 350)
    end

    PlayPurpleBurst(origin + vector3(0.0, 0.0, 0.65), 1.0 + charge)
    PlayPenumbraTrail(ped, charge)

    local startedAt = GetGameTimer()
    local nextFx = startedAt + 180

    while GetGameTimer() - startedAt < flightDuration do
        Wait(0)

        LockBlinkControls()

        local progress = (GetGameTimer() - startedAt) / flightDuration
        local t = EaseInOut(progress)
        local arc = math.sin(t * math.pi) * height

        local coords = vector3(
            origin.x + ((flightTarget.x - origin.x) * t),
            origin.y + ((flightTarget.y - origin.y) * t),
            origin.z + ((flightTarget.z - origin.z) * t) + arc
        )

        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
        SetEntityVelocity(ped, 0.0, 0.0, 0.0)

        if GetGameTimer() >= nextFx then
            PlayPenumbraTrail(ped, charge)
            nextFx = GetGameTimer() + 170
        end
    end

    if impactPoint and descentDuration > 0 then
        SetEntityCoordsNoOffset(
            ped,
            impactPoint.x,
            impactPoint.y,
            impactPoint.z,
            false,
            false,
            false
        )
        local descentStartedAt = GetGameTimer()
        local nextSmoke = descentStartedAt

        while GetGameTimer() - descentStartedAt < descentDuration do
            Wait(0)
            LockBlinkControls()

            local progress = (GetGameTimer() - descentStartedAt) / descentDuration
            local t = EaseInOut(progress)
            local coords = vector3(
                impactPoint.x + ((target.x - impactPoint.x) * t),
                impactPoint.y + ((target.y - impactPoint.y) * t),
                impactPoint.z + ((target.z - impactPoint.z) * t)
            )

            SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
            SetEntityVelocity(ped, 0.0, 0.0, 0.0)

            if GetGameTimer() >= nextFx then
                PlayPenumbraTrail(ped, charge)
                nextFx = GetGameTimer() + 170
            end
            if GetGameTimer() >= nextSmoke then
                PlayPurpleBurst(coords + vector3(0.0, 0.0, 0.35), 0.5 + (charge * 0.2))
                nextSmoke = GetGameTimer() + 240
            end
        end
    end

    SetEntityCoordsNoOffset(ped, target.x, target.y, target.z, false, false, false)
    if HasLandingSurface(target, ped) then
        PlayConfiguredAnim(ped, cfg.landingAnimation, cfg.landingAnimation and cfg.landingAnimation.duration or 650)
    end
    PlayPurpleBurst(target + vector3(0.0, 0.0, 0.45), 1.2 + charge)
    Wait(120)

    StopScreenEffect("SwitchShortMichaelIn")
    ClearTimecycleModifier()
    RestorePedAfterBlink(ped, keepInvincible)
    TriggerServerEvent("magic:server:blinkVisual", false)

end

local function CastBlink()
    if blinkCasting then
        return
    end

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) then
        return
    end

    if Main and Main.IsMagicLocked and Main.IsMagicLocked() then
        if Magic.CancelSpellCast then
            Magic.CancelSpellCast("blink")
        end
        return
    end

    blinkCasting = true

    local cfg = GetBlinkConfig()
    local castReleaseDelay = math.max(0, tonumber(cfg.castReleaseDelay) or 1433)

    Magic.PlaySpellAnim(cfg)
    if castReleaseDelay > 0 then
        local releaseAt = GetGameTimer() + castReleaseDelay
        while GetGameTimer() < releaseAt do
            Wait(0)
            LockBlinkControls()

            if Main and Main.IsMagicLocked and Main.IsMagicLocked() then
                ClearPedSecondaryTask(ped)
                if Magic.CancelSpellCast then
                    Magic.CancelSpellCast("blink")
                end
                blinkCasting = false
                return
            end
        end
    end

    local charge = GetChargeValue()
    local target, direction, _, failure, height, impactPoint = GetAimDestination(ped, charge)
    if not target then
        ClearPedSecondaryTask(ped)
        if Magic.CancelSpellCast then
            Magic.CancelSpellCast("blink")
        end
        if Main and Main.Notify then
            Main.Notify(
                "Blink",
                failure == "landing"
                    and "Nao existe um ponto seguro para aterrissar nessa direcao."
                    or "O caminho do Blink esta bloqueado.",
                "error",
                3000
            )
        end
        blinkCasting = false
        return
    end

    PerformBlinkRush(ped, target, direction, charge, height, impactPoint)

    if Magic.ApplyDamageToPlayer and (cfg.selfDamage or 0) > 0 then
        Magic.ApplyDamageToPlayer(cfg.selfDamage)
    end

    if Magic.FinishSpellCooldown then
        Magic.FinishSpellCooldown("blink")
    end

    blinkCasting = false
end

RegisterNetEvent("magic:spells:blink")
AddEventHandler("magic:spells:blink", function()
    CastBlink()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    StopScreenEffect("SwitchShortMichaelIn")
    ClearTimecycleModifier()
    if Magic.CancelSpellCast then
        Magic.CancelSpellCast("blink")
    end
    TriggerServerEvent("magic:server:blinkVisual", false)
    RestorePedAfterBlink(PlayerPedId(), false)
    for sourceId in pairs(remoteBlinkTokens) do
        remoteBlinkTokens[sourceId] = nil
        RestoreRemoteBlink(sourceId, false)
    end
end)
