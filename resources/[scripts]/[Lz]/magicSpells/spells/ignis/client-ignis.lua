local Magic = MagicHelpers
local ignisActive = false

local function EnsureAnimDict(dict, timeoutMs)
    if not dict or dict == "" then
        return false
    end

    if HasAnimDictLoaded(dict) then
        return true
    end

    RequestAnimDict(dict)
    local timeout = GetGameTimer() + (tonumber(timeoutMs) or 3000)
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(0)
    end

    return HasAnimDictLoaded(dict)
end

local function EnsurePtfxAsset(asset)
    if not asset or asset == "" then
        return false
    end

    if HasNamedPtfxAssetLoaded(asset) then
        return true
    end

    RequestNamedPtfxAsset(asset)
    local timeout = GetGameTimer() + 3000
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < timeout do
        Wait(0)
    end

    return HasNamedPtfxAssetLoaded(asset)
end

local function StopLoopedFx(handle)
    if handle and handle ~= 0 then
        StopParticleFxLooped(handle, 0)
    end
end

local function ToVector3(value)
    if type(value) ~= "table" then
        return nil
    end

    local x = tonumber(value.x)
    local y = tonumber(value.y)
    local z = tonumber(value.z)
    if not x or not y or not z then
        return nil
    end

    return vector3(x, y, z)
end

local function PackVector3(value)
    return { x = value.x, y = value.y, z = value.z }
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

local function GetAimResult(distance)
    local range = tonumber(distance) or 50.0
    local ray = Magic.RaycastFromCamera(range, -1)
    local camCoord = GetGameplayCamCoord()
    local direction = (ray and ray.direction) or RotationToDirection(GetGameplayCamRot(2))
    local fallback = camCoord + (direction * range)

    if not ray then
        return {
            hit = false,
            coords = fallback,
            entity = 0
        }
    end

    local coords = ray.coords
    if not coords or #(coords - camCoord) < 0.1 then
        coords = fallback
    end

    return {
        hit = ray.hit == true,
        coords = coords,
        entity = ray.entity or 0
    }
end

local function GetGroundCoordsFromPed(ped)
    local coords = GetEntityCoords(ped)
    local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1.2, false)
    if found then
        return vector3(coords.x, coords.y, groundZ + 0.02)
    end

    return coords
end

local function PlayReleaseAnim(ped, cfg)
    local anim = cfg and cfg.releaseAnimation
    if not anim or not anim.dict or not anim.anim then
        print("[magicSpells][Ignis] Configuracao da animacao de disparo ausente.")
        return 0, nil
    end

    ClearPedSecondaryTask(ped)
    local ok, activeAnim = Magic.PlayAnimation(anim, "Ignis", true)
    if not ok or not activeAnim then
        return 0, nil
    end

    return activeAnim.duration or anim.duration or 4600, {
        dict = activeAnim.dict,
        anim = activeAnim.anim,
        blendOut = activeAnim.blendOut or 2.0
    }
end

local function ApplyParticleColour(colour)
    if not colour then
        return
    end

    SetParticleFxNonLoopedColour(colour.x or colour.r or 1.0, colour.y or colour.g or 1.0, colour.z or colour.b or 1.0)
    SetParticleFxNonLoopedAlpha(colour.w or colour.a or 1.0)
end

local function ApplyLoopedParticleColour(handle, colour)
    if not handle or handle == 0 or not colour then
        return
    end

    SetParticleFxLoopedColour(handle, colour.x or colour.r or 1.0, colour.y or colour.g or 1.0, colour.z or colour.b or 1.0, false)
    SetParticleFxLoopedAlpha(handle, colour.w or colour.a or 1.0)
end

local function SpawnGroundFx(pos)
    local cfg = Config.Spells.ignis_conflagratio and Config.Spells.ignis_conflagratio.groundFx
    if not cfg or not pos or not EnsurePtfxAsset(cfg.asset) then
        return
    end

    UseParticleFxAssetNextCall(cfg.asset)
    ApplyParticleColour(cfg.color)
    StartParticleFxNonLoopedAtCoord(
        cfg.fx,
        pos.x,
        pos.y,
        pos.z + 1.0,
        0.0,
        0.0,
        0.0,
        cfg.scale or 1.0,
        false,
        false,
        false
    )
end

local function SpawnHandFx(ped, duration)
    local cfg = Config.Spells.ignis_conflagratio and Config.Spells.ignis_conflagratio.handFx
    if not cfg or not DoesEntityExist(ped) or not EnsurePtfxAsset(cfg.asset) then
        return
    end

    local handles = {}
    local offset = cfg.offset or vec3(0.08, 0.0, 0.0)
    local bones = cfg.bones or { 57005 }

    for i = 1, #bones do
        UseParticleFxAssetNextCall(cfg.asset)
        local handle = StartParticleFxLoopedOnEntityBone(
            cfg.fx,
            ped,
            offset.x,
            offset.y,
            offset.z,
            0.0,
            0.0,
            0.0,
            GetPedBoneIndex(ped, bones[i]),
            cfg.scale or 0.35,
            false,
            false,
            false
        )

        if handle and handle ~= 0 then
            handles[#handles + 1] = handle
        end
    end

    if #handles == 0 then
        return
    end

    CreateThread(function()
        Wait(duration or cfg.duration or 1200)
        for i = 1, #handles do
            StopLoopedFx(handles[i])
        end
    end)
end

local function StartChargeOrbFx(ped)
    local cfg = Config.Spells.ignis_conflagratio and Config.Spells.ignis_conflagratio.chargeOrbFx
    if not cfg or not DoesEntityExist(ped) or not EnsurePtfxAsset(cfg.asset) then
        return nil, cfg
    end

    UseParticleFxAssetNextCall(cfg.asset)
    local offset = cfg.offset or vec3(0.075, 0.0, 0.0)
    local handle = StartParticleFxLoopedOnEntityBone(
        cfg.fx,
        ped,
        offset.x,
        offset.y,
        offset.z,
        0.0,
        0.0,
        0.0,
        GetPedBoneIndex(ped, cfg.bone or 18905),
        cfg.startScale or 0.12,
        false,
        false,
        false
    )

    if not handle or handle == 0 then
        return nil, cfg
    end

    ApplyLoopedParticleColour(handle, cfg.color)
    SetParticleFxLoopedScale(handle, cfg.startScale or 0.12)
    return handle, cfg
end

local function GrowChargeOrb(handle, cfg, durationMs)
    durationMs = math.max(0, tonumber(durationMs) or 0)
    if durationMs == 0 then
        return
    end

    local startedAt = GetGameTimer()
    local startScale = tonumber(cfg and cfg.startScale) or 0.12
    local endScale = tonumber(cfg and cfg.endScale) or 0.52

    while GetGameTimer() - startedAt < durationMs do
        if handle and handle ~= 0 then
            local progress = math.min(1.0, (GetGameTimer() - startedAt) / durationMs)
            local eased = progress * progress * (3.0 - (2.0 * progress))
            SetParticleFxLoopedScale(handle, startScale + ((endScale - startScale) * eased))
        end
        Wait(0)
    end
end

local function SpawnTrail(fromPos, toPos)
    local cfg = Config.Spells.ignis_conflagratio and Config.Spells.ignis_conflagratio.trail
    if not cfg or not fromPos or not toPos or not EnsurePtfxAsset(cfg.asset) then
        return
    end

    local direction = toPos - fromPos
    local distance = #(direction)
    if distance < 0.2 then
        return
    end

    direction = direction / distance

    local step = tonumber(cfg.step) or 3.0
    local count = math.max(1, math.floor(distance / step))
    count = math.min(count, tonumber(cfg.maxNodes) or 18)

    local travelMs = tonumber(cfg.travelMs) or 0
    local nodeDelay = travelMs > 0 and math.floor(travelMs / count) or 0
    local baseLife = tonumber(cfg.tailMsBase) or 180
    local lastLife = tonumber(cfg.tailMsLast) or 900

    for i = 1, count do
        local t = i / count
        local point = fromPos + (direction * (distance * t))

        UseParticleFxAssetNextCall(cfg.asset)
        local handle = StartParticleFxLoopedAtCoord(
            cfg.fx,
            point.x,
            point.y,
            point.z,
            0.0,
            0.0,
            0.0,
            cfg.scale or 0.8,
            false,
            false,
            false,
            false
        )

        if handle and handle ~= 0 then
            ApplyLoopedParticleColour(handle, cfg.color)

            local life = math.floor(baseLife + ((lastLife - baseLife) * t))
            CreateThread(function()
                Wait(life)
                StopLoopedFx(handle)
            end)
        end

        if nodeDelay > 0 then
            Wait(nodeDelay)
        else
            Wait(0)
        end
    end
end

local function SpawnLoopedAtCoord(cfg, pos)
    if not cfg or not pos or not EnsurePtfxAsset(cfg.asset) then
        return
    end

    UseParticleFxAssetNextCall(cfg.asset)
    local handle = StartParticleFxLoopedAtCoord(
        cfg.fx,
        pos.x,
        pos.y,
        pos.z,
        0.0,
        0.0,
        0.0,
        cfg.scale or 1.0,
        false,
        false,
        false,
        false
    )

    if not handle or handle == 0 then
        return
    end

    CreateThread(function()
        Wait(cfg.duration or 2500)
        StopLoopedFx(handle)
    end)
end

local function SpawnPedHitFx(ped, cfg)
    if not cfg or not DoesEntityExist(ped) or not EnsurePtfxAsset(cfg.asset) then
        return
    end

    local handles = {}
    for _, boneId in ipairs(cfg.bones or {}) do
        UseParticleFxAssetNextCall(cfg.asset)
        local handle = StartParticleFxLoopedOnEntityBone(
            cfg.fx,
            ped,
            0.02,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            GetPedBoneIndex(ped, boneId),
            cfg.scale or 0.75,
            false,
            false,
            false
        )

        if handle and handle ~= 0 then
            handles[#handles + 1] = handle
        end
    end

    if #handles == 0 then
        return
    end

    CreateThread(function()
        Wait(cfg.duration or 2500)
        for i = 1, #handles do
            StopLoopedFx(handles[i])
        end
    end)
end

local function BuildPayload(ped, aim, cfg)
    local fromPos = GetPedBoneCoords(ped, 57005, 0.18, 0.0, 0.0)
    local entity = aim.entity or 0
    local targetNetId = 0
    local targetType = 0
    local targetServerId = 0

    if entity ~= 0 and DoesEntityExist(entity) then
        local entityType = GetEntityType(entity)
        if entityType == 2 then
            targetType = entityType
            targetNetId = NetworkGetNetworkIdFromEntity(entity)
        elseif entityType == 1 and IsPedAPlayer(entity) then
            targetType = entityType
            targetNetId = NetworkGetNetworkIdFromEntity(entity)
            local playerIndex = NetworkGetPlayerIndexFromPed(entity)
            if playerIndex and playerIndex ~= -1 then
                targetServerId = GetPlayerServerId(playerIndex)
            end
        end
    end

    return {
        fromPos = PackVector3(fromPos),
        toPos = PackVector3(aim.coords),
        hitOk = aim.hit == true,
        hitEntNetId = targetNetId,
        targetType = targetType,
        targetServerId = targetServerId,
        syncRadius = cfg.syncRadius or 70.0,
        handMs = (cfg.handFx and cfg.handFx.duration) or 1300
    }
end

local function IsLocalCaster(payload)
    return tonumber(payload and payload.casterSrc) == GetPlayerServerId(PlayerId())
end

local function DoImpact(payload)
    local cfg = Config.Spells.ignis_conflagratio or {}
    local toPos = ToVector3(payload.toPos)
    if not toPos then
        return
    end

    local entity = 0
    if payload.hitEntNetId and payload.hitEntNetId ~= 0 then
        entity = NetworkGetEntityFromNetworkId(payload.hitEntNetId)
    end

    local targetProtected = payload.hitEntNetId and _G.MagicProtectedEntities and _G.MagicProtectedEntities[payload.hitEntNetId]

    if entity ~= 0 and DoesEntityExist(entity) then
        local entityType = GetEntityType(entity)
        if entityType == 1 then
            SpawnPedHitFx(entity, cfg.hitPedFx)
        elseif entityType == 2 then
            if IsLocalCaster(payload) and not targetProtected then
                SetVehicleEngineHealth(entity, math.max(0.0, GetVehicleEngineHealth(entity) - 280.0))
                SetVehiclePetrolTankHealth(entity, math.max(0.0, GetVehiclePetrolTankHealth(entity) - 260.0))
            end
        end
    else
        SpawnLoopedAtCoord(cfg.hitMapFx, toPos)
    end

    local explosion = cfg.impactExplosion
    if explosion and explosion.enabled == true and IsLocalCaster(payload) and not targetProtected then
        AddExplosion(
            toPos.x,
            toPos.y,
            toPos.z,
            explosion.type or 7,
            0.0,
            explosion.audible ~= false,
            explosion.invisible == true,
            explosion.cameraShake or 0.35
        )
    end
end

RegisterNetEvent("magic:client:ignisGroundFx", function(pos)
    SpawnGroundFx(ToVector3(pos))
end)

RegisterNetEvent("magic:client:ignisChargeFx", function(casterSource, durationMs)
    local playerIndex = GetPlayerFromServerId(tonumber(casterSource) or -1)
    if not playerIndex or playerIndex == -1 then
        return
    end

    local casterPed = GetPlayerPed(playerIndex)
    if casterPed == 0 or not DoesEntityExist(casterPed) then
        return
    end

    local handle, cfg = StartChargeOrbFx(casterPed)
    GrowChargeOrb(handle, cfg, durationMs)
    StopLoopedFx(handle)
end)

RegisterNetEvent("magic:client:ignisBurstFx", function(payload)
    if type(payload) ~= "table" then
        return
    end

    local fromPos = ToVector3(payload.fromPos)
    local toPos = ToVector3(payload.toPos)
    if not fromPos or not toPos then
        return
    end

    local casterPed = 0
    if payload.casterSrc then
        local playerIndex = GetPlayerFromServerId(payload.casterSrc)
        if playerIndex and playerIndex ~= -1 then
            casterPed = GetPlayerPed(playerIndex)
        end
    end

    if casterPed ~= 0 and DoesEntityExist(casterPed) then
        SpawnHandFx(casterPed, payload.handMs)
    end

    SpawnTrail(fromPos, toPos)
    DoImpact(payload)
end)

RegisterNetEvent("magic:client:ignisBurnSelf", function(durationMs, tickMs, damagePerTick, casterSource)
    if LocalPlayer and LocalPlayer.state and LocalPlayer.state.magicInvulneris then
        return
    end

    durationMs = tonumber(durationMs) or 8000
    tickMs = tonumber(tickMs) or 500
    damagePerTick = tonumber(damagePerTick) or 4

    local endAt = GetGameTimer() + durationMs
    while GetGameTimer() < endAt do
        Wait(tickMs)

        local ped = PlayerPedId()
        if not DoesEntityExist(ped) or IsEntityDead(ped) then
            break
        end

        if not IsEntityOnFire(ped) then
            StartEntityFire(ped)
        end

        ApplyDamageToPed(ped, damagePerTick, false)
    end

    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        StopEntityFire(ped)
    end
end)

RegisterNetEvent("magic:spells:ignis_conflagratio", function()
    if ignisActive then
        return
    end

    local cfg = Config.Spells.ignis_conflagratio or {}
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then
        return
    end

    local lockedAim = GetAimResult(cfg.distance or 50.0)
    local aimedEntity = lockedAim and lockedAim.entity or 0
    if aimedEntity ~= 0 and DoesEntityExist(aimedEntity)
        and IsEntityAPed(aimedEntity) and not IsPedAPlayer(aimedEntity) then
        Magic.Notify("Ignis", "Esta magia so pode atingir jogadores.", "error", 3500)
        return
    end

    ignisActive = true

    local releaseDuration, releaseAnim = PlayReleaseAnim(ped, cfg)

    local groundPos = GetGroundCoordsFromPed(ped)
    SpawnGroundFx(groundPos)
    TriggerServerEvent("magic:server:ignisGroundFx", PackVector3(groundPos), cfg.syncRadius or 70.0)

    local delay = math.max(0, tonumber(cfg.releaseDelay) or 2800)
    local orbCfg = cfg.chargeOrbFx or {}
    local orbStartDelay = math.min(delay, math.max(0, tonumber(orbCfg.startDelay) or 900))
    if orbStartDelay > 0 then
        Wait(orbStartDelay)
    end

    local orbDuration = math.max(0, delay - orbStartDelay)
    local orbHandle, activeOrbCfg = StartChargeOrbFx(ped)
    TriggerServerEvent("magic:server:ignisChargeFx", orbDuration, cfg.syncRadius or 70.0)
    GrowChargeOrb(orbHandle, activeOrbCfg, orbDuration)
    StopLoopedFx(orbHandle)

    local payload = BuildPayload(ped, lockedAim, cfg)
    payload.casterSrc = GetPlayerServerId(PlayerId())
    TriggerEvent("magic:client:ignisBurstFx", payload)
    TriggerServerEvent("magic:server:ignisBurst", payload)

    if releaseDuration > delay then
        SetTimeout(releaseDuration - delay, function()
            if releaseAnim and DoesEntityExist(ped) and IsEntityPlayingAnim(ped, releaseAnim.dict, releaseAnim.anim, 3) then
                StopAnimTask(ped, releaseAnim.dict, releaseAnim.anim, releaseAnim.blendOut or 2.0)
            end
        end)
    end

    Magic.FinishSpellCooldown("ignis_conflagratio")
    ignisActive = false
end)
