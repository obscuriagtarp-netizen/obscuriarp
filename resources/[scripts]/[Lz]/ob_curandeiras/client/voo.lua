local flight = {
    active = false,
    transitioning = false,
    landing = false,
    controller = 0,
    controllerNetId = 0,
    camera = 0,
    cameraPosition = nil,
    cameraYaw = 0.0,
    cameraPitch = 0.0,
    cameraRoll = 0.0,
    cameraFrontView = false,
    cameraFrontBlend = 0.0,
    motion = nil,
    animationToken = 0,
    takeoffUntil = 0,
    boosting = false,
    diving = false,
    boostHeld = false,
    boostFxHandles = {},
    boostFxToken = 0,
    wingFxHandles = {},
    wingEntity = 0,
    wingMode = nil,
    nextWingAnimationAt = 0,
    nextWingRequirementCheckAt = 0,
    nextWingLandingAttemptAt = 0,
    nextHypnosisLandingAttemptAt = 0,
    nextDiveCheckAt = 0,
    nextGroundSafetyAt = 0,
    nextAnimationCheckAt = 0,
    animationTransitionUntil = 0,
    wasInvincible = false,
}

local remoteFlights = {}
local remoteFxThreadRunning = false
local remoteBoosts = {}
local remoteBoostThreadRunning = false
local remoteDiveStates = {}
local wingConfig = Config.Flight.wing or {}
local wingModels = {}

for _, wing in ipairs(Config.WingCatalogEntries or {}) do
    wingModels[joaat(('mts_fair_v7_%s'):format(wing.color))] = true
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function lerp(from, to, amount)
    return from + ((to - from) * amount)
end

local function normalize(vector)
    local length = #(vector)
    if length <= 0.0001 then
        return vector3(0.0, 0.0, 0.0)
    end
    return vector / length
end

local function normalizeAngle(angle)
    angle = angle % 360.0
    if angle < 0.0 then angle = angle + 360.0 end
    return angle
end

local function lerpAngle(from, to, amount)
    local difference = ((to - from + 180.0) % 360.0) - 180.0
    return normalizeAngle(from + (difference * amount))
end

local function isControlPressed(control)
    control = tonumber(control)
    if not control then return false end

    return IsControlPressed(0, control)
        or IsDisabledControlPressed(0, control)
        or IsControlPressed(2, control)
        or IsDisabledControlPressed(2, control)
end

local function requestModel(modelName)
    local model = joaat(modelName)
    if not IsModelInCdimage(model) or not IsModelValid(model) then return nil end

    RequestModel(model)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(10)
    end

    return HasModelLoaded(model) and model or nil
end

local function raycast(fromCoords, toCoords, ignoreEntity)
    local handle = StartShapeTestRay(
        fromCoords.x, fromCoords.y, fromCoords.z,
        toCoords.x, toCoords.y, toCoords.z,
        1 + 16 + 256,
        ignoreEntity or 0,
        7
    )
    local _, hit, hitCoords = GetShapeTestResult(handle)
    return hit == 1, hitCoords
end

local function groundBelow(coords, distance, allowGroundFallback)
    local fromCoords = coords + vector3(0.0, 0.0, 0.75)
    local toCoords = coords - vector3(0.0, 0.0, distance)
    local hit, hitCoords = raycast(fromCoords, toCoords, flight.controller)
    if hit then
        return true, hitCoords, coords.z - hitCoords.z
    end

    if not allowGroundFallback then
        return false, nil, nil
    end

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 100.0, false)
    if found and coords.z >= groundZ then
        return true, vector3(coords.x, coords.y, groundZ), coords.z - groundZ
    end

    return false, nil, nil
end

local function hasRequiredWing()
    if wingConfig.required == false then return true end

    local resource = tostring(wingConfig.resource or '')
    if resource == '' or GetResourceState(resource) ~= 'started' then
        return false
    end

    local state = LocalPlayer and LocalPlayer.state
    local stateKey = tostring(wingConfig.stateKey or 'activeWingResource')
    return state and state[stateKey] == resource
end

local function isHypnotized()
    local state = LocalPlayer and LocalPlayer.state
    return state and state.obHypnotized == true
end

local function hasFlightInterruptingBlock()
    local state = LocalPlayer and LocalPlayer.state
    return state and (
        state.obscuriaPowerBlocked == true
        or state.magicFauna == true
    )
end

local function findAttachedWing(ped, cachedWing)
    if not DoesEntityExist(ped) then return nil end

    if cachedWing and cachedWing ~= 0
        and DoesEntityExist(cachedWing)
        and wingModels[GetEntityModel(cachedWing)]
        and IsEntityAttachedToEntity(cachedWing, ped) then
        return cachedWing
    end

    for _, object in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(object)
            and wingModels[GetEntityModel(object)]
            and IsEntityAttachedToEntity(object, ped) then
            return object
        end
    end

    return nil
end

local function wingAnimation(mode)
    local animations = wingConfig.animations or {}
    return animations[mode]
end

local function clearWingFlightAnimation(holder)
    local entity = holder.wingEntity
    local animation = holder.wingMode and wingAnimation(holder.wingMode) or nil

    if animation and entity and entity ~= 0 and DoesEntityExist(entity) then
        StopEntityAnim(entity, animation.clip, animation.dict, 1.0)
    end

    holder.wingEntity = 0
    holder.wingMode = nil
    holder.nextWingAnimationAt = 0
end

local function updateWingFlightAnimation(holder, ped, mode, force)
    local animation = wingAnimation(mode)
    if not animation or not DoesEntityExist(ped) then return false end

    local now = GetGameTimer()
    if not force and holder.wingMode == mode and now < (holder.nextWingAnimationAt or 0) then
        return true
    end

    holder.nextWingAnimationAt = now + math.max(
        200,
        tonumber(wingConfig.animationCheckInterval) or 400
    )

    local entity = findAttachedWing(ped, holder.wingEntity)
    if not entity then
        holder.wingEntity = 0
        holder.wingMode = nil
        return false
    end

    local changed = holder.wingEntity ~= entity or holder.wingMode ~= mode
    local playing = not changed
        and IsEntityPlayingAnim(entity, animation.dict, animation.clip, 3)

    if not changed and playing and not force then
        return true
    end

    local previous = holder.wingMode and wingAnimation(holder.wingMode) or nil
    if previous and holder.wingEntity and DoesEntityExist(holder.wingEntity) then
        StopEntityAnim(holder.wingEntity, previous.clip, previous.dict, 1.0)
    end

    if not HasAnimDictLoaded(animation.dict) then
        RequestAnimDict(animation.dict)
        return false
    end

    local played = PlayEntityAnim(
        entity,
        animation.clip,
        animation.dict,
        8.0,
        true,
        true,
        false,
        0.0,
        0
    )
    if played == false then return false end

    SetEntityAnimSpeed(entity, animation.dict, animation.clip, animation.speed or 1.0)
    if ForceEntityAiAndAnimationUpdate then
        ForceEntityAiAndAnimationUpdate(entity)
    end

    holder.wingEntity = entity
    holder.wingMode = mode
    return true
end

local function setWingOpenPose(holder, ped)
    if not holder or not DoesEntityExist(ped) then return end

    CreateThread(function()
        local timeout = GetGameTimer() + 3000
        repeat
            if updateWingFlightAnimation(holder, ped, 'open', true) then
                return
            end
            Wait(100)
        until not DoesEntityExist(ped) or GetGameTimer() >= timeout
    end)
end

local function cameraForward()
    local yaw = math.rad(flight.cameraYaw)
    local pitch = math.rad(flight.cameraPitch)
    return normalize(vector3(
        -math.sin(yaw) * math.cos(pitch),
        math.cos(yaw) * math.cos(pitch),
        math.sin(pitch)
    ))
end

local function normalizedEffectColor(color)
    if type(color) ~= 'table' then return nil end

    local red = tonumber(color[1] or color['1'] or color.r)
    local green = tonumber(color[2] or color['2'] or color.g)
    local blue = tonumber(color[3] or color['3'] or color.b)
    if not red or not green or not blue then return nil end

    return {
        clamp(red, 0.0, 1.0),
        clamp(green, 0.0, 1.0),
        clamp(blue, 0.0, 1.0),
    }
end

local function sameEffectColor(first, second)
    if not first or not second then return first == second end
    return math.abs(first[1] - second[1]) < 0.001
        and math.abs(first[2] - second[2]) < 0.001
        and math.abs(first[3] - second[3]) < 0.001
end

local function wingEffectColor(ped, fallback, syncedColor)
    fallback = fallback or { 0.35, 0.9, 0.55 }
    if not DoesEntityExist(ped) then return fallback end

    local explicitColor = normalizedEffectColor(syncedColor)
    if explicitColor then return explicitColor end

    if ped == PlayerPedId() and type(ObCurandeiras.WingEffectColor) == 'table' then
        return {
            clamp(tonumber(ObCurandeiras.WingEffectColor[1]) or fallback[1], 0.0, 1.0),
            clamp(tonumber(ObCurandeiras.WingEffectColor[2]) or fallback[2], 0.0, 1.0),
            clamp(tonumber(ObCurandeiras.WingEffectColor[3]) or fallback[3], 0.0, 1.0),
        }
    end

    local playerIndex = NetworkGetPlayerIndexFromPed(ped)
    if playerIndex == -1 or not NetworkIsPlayerActive(playerIndex) then return fallback end
    local state = Player(playerIndex).state
    if not state then return fallback end

    local key = wingConfig.colorStateKey or 'obCurandeiraWingFx'
    local red = tonumber(state[('%sR'):format(key)])
    local green = tonumber(state[('%sG'):format(key)])
    local blue = tonumber(state[('%sB'):format(key)])

    if red and green and blue then
        return {
            clamp(red, 0.0, 1.0),
            clamp(green, 0.0, 1.0),
            clamp(blue, 0.0, 1.0),
        }
    end

    local color = state[key]
    if type(color) == 'string' then
        red, green, blue = color:match('^([^,]+),([^,]+),([^,]+)$')
        red, green, blue = tonumber(red), tonumber(green), tonumber(blue)
        if red and green and blue then
            return {
                clamp(red, 0.0, 1.0),
                clamp(green, 0.0, 1.0),
                clamp(blue, 0.0, 1.0),
            }
        end
    end

    if type(color) ~= 'table' then return fallback end

    return {
        clamp(tonumber(color[1] or color['1'] or color.r) or fallback[1], 0.0, 1.0),
        clamp(tonumber(color[2] or color['2'] or color.g) or fallback[2], 0.0, 1.0),
        clamp(tonumber(color[3] or color['3'] or color.b) or fallback[3], 0.0, 1.0),
    }
end

local function createWingFx(ped, syncedColor)
    local handles = {}
    local fx = Config.Flight.fx
    if not DoesEntityExist(ped) or not ObCurandeiras.EnsurePtfx(fx.asset) then
        return handles
    end

    local color = wingEffectColor(ped, fx.color, syncedColor)
    local bone = GetPedBoneIndex(ped, 24818)
    for _, side in ipairs({ -1.0, 1.0 }) do
        UseParticleFxAssetNextCall(fx.asset)
        local handle = StartParticleFxLoopedOnEntityBone(
            fx.effect,
            ped,
            0.22 * side, -0.22, 0.18,
            0.0, 28.0 * side, 12.0 * side,
            bone,
            fx.scale,
            false, false, false
        )

        if handle and handle ~= 0 then
            SetParticleFxLoopedColour(handle, color[1], color[2], color[3], false)
            SetParticleFxLoopedAlpha(handle, 0.82)
            handles[#handles + 1] = handle
        end
    end

    return handles
end

local function stopParticleHandles(handles)
    for index = 1, #(handles or {}) do
        local handle = handles[index]
        if handle and handle ~= 0 then
            StopParticleFxLooped(handle, true)
            RemoveParticleFx(handle, true)
        end
    end
    return {}
end

local function playBoostSmokeBurst(ped, syncedColor)
    local smoke = Config.Flight.boostFx and Config.Flight.boostFx.smoke
    if not smoke or not DoesEntityExist(ped) or not ObCurandeiras.EnsurePtfx(smoke.asset) then
        return
    end

    local color = wingEffectColor(
        ped,
        smoke.color or { 0.08, 0.86, 0.24 },
        syncedColor
    )
    for _, boneId in ipairs(smoke.bones or { 24818, 23553 }) do
        UseParticleFxAssetNextCall(smoke.asset)
        SetParticleFxNonLoopedColour(color[1], color[2], color[3])
        SetParticleFxNonLoopedAlpha(smoke.alpha or 0.46)
        StartParticleFxNonLoopedOnPedBone(
            smoke.effect,
            ped,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            boneId,
            smoke.scale or 6.0,
            false, false, false
        )
    end
end

local function createBoostDistortion(ped)
    local handles = {}
    local distortion = Config.Flight.boostFx and Config.Flight.boostFx.distortion
    if not distortion or not DoesEntityExist(ped)
        or not ObCurandeiras.EnsurePtfx(distortion.asset) then
        return handles
    end

    local bones = distortion.bones or { 24818 }
    for index, boneId in ipairs(bones) do
        if index > 1 then
            Wait(math.max(0, tonumber(distortion.boneDelay) or 50))
        end

        UseParticleFxAssetNextCall(distortion.asset)
        local handle = StartParticleFxLoopedOnEntityBone(
            distortion.effect,
            ped,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            boneId,
            distortion.scale or 1.0,
            false, false, false
        )

        if handle and handle ~= 0 then
            handles[#handles + 1] = handle
        end
    end

    return handles
end

local function stopBoostDistortion()
    flight.boostFxToken = flight.boostFxToken + 1
    flight.boostFxHandles = stopParticleHandles(flight.boostFxHandles)
end

local function startBoostDistortion(ped)
    stopBoostDistortion()
    local token = flight.boostFxToken
    local handles = createBoostDistortion(ped)

    if token ~= flight.boostFxToken or not flight.active or not flight.boosting then
        stopParticleHandles(handles)
        return
    end

    flight.boostFxHandles = handles
end

local function stopRemoteBoost(serverId)
    local entry = remoteBoosts[serverId]
    if not entry then return end

    entry.handles = stopParticleHandles(entry.handles)
    remoteBoosts[serverId] = nil
end

local function ensureRemoteBoostThread()
    if remoteBoostThreadRunning or not next(remoteBoosts) then return end

    remoteBoostThreadRunning = true
    CreateThread(function()
        while next(remoteBoosts) do
            local now = GetGameTimer()

            for serverId, entry in pairs(remoteBoosts) do
                local playerIndex = GetPlayerFromServerId(serverId)
                local ped = playerIndex ~= -1 and GetPlayerPed(playerIndex) or 0
                local flightEntry = remoteFlights[serverId]
                local allowEffects = flightEntry and flightEntry.effectsEnabled == true

                if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then
                    entry.handles = stopParticleHandles(entry.handles)
                    entry.ped = 0
                    entry.burstPlayed = false
                elseif not allowEffects then
                    entry.handles = stopParticleHandles(entry.handles)
                    entry.ped = ped
                    entry.burstPlayed = false
                elseif entry.ped ~= ped or (#entry.handles == 0 and now >= (entry.retryAt or 0)) then
                    entry.handles = stopParticleHandles(entry.handles)
                    entry.ped = ped
                    local handles = createBoostDistortion(ped)
                    if remoteBoosts[serverId] == entry
                        and remoteFlights[serverId]
                        and remoteFlights[serverId].effectsEnabled == true then
                        entry.handles = handles
                    else
                        stopParticleHandles(handles)
                    end
                    entry.retryAt = now + math.max(
                        500,
                        tonumber(Config.Flight.boostFx.retryInterval) or 1500
                    )
                end

                if allowEffects and ped ~= 0 and DoesEntityExist(ped)
                    and not IsEntityDead(ped) and entry.burstPlayed ~= true then
                    playBoostSmokeBurst(ped, entry.effectColor)
                    entry.burstPlayed = true
                end
            end

            Wait(math.max(
                100,
                tonumber(Config.Flight.boostFx.remotePollInterval) or 250
            ))
        end

        remoteBoostThreadRunning = false
    end)
end

local function setRemoteBoost(serverId, active, effectColor)
    serverId = tonumber(serverId)
    if not serverId or serverId == GetPlayerServerId(PlayerId()) then return end

    if active ~= true then
        stopRemoteBoost(serverId)
        return
    end

    local entry = remoteBoosts[serverId]
    if not entry then
        entry = {
            ped = 0,
            handles = {},
            retryAt = 0,
            burstPlayed = false,
            effectColor = normalizedEffectColor(effectColor),
        }
        remoteBoosts[serverId] = entry
    else
        entry.effectColor = normalizedEffectColor(effectColor) or entry.effectColor
    end

    ensureRemoteBoostThread()
end

local function publishBoostState(active)
    TriggerServerEvent('ob_curandeiras:server:flightBoostState', active == true)
end

local function setRemoteDive(serverId, active)
    serverId = tonumber(serverId)
    if not serverId or serverId == GetPlayerServerId(PlayerId()) then return end

    active = active == true
    remoteDiveStates[serverId] = active or nil

    local entry = remoteFlights[serverId]
    if not entry then return end

    entry.diving = active
    local playerIndex = GetPlayerFromServerId(serverId)
    local ped = playerIndex ~= -1 and GetPlayerPed(playerIndex) or 0
    if ped ~= 0 and DoesEntityExist(ped) then
        updateWingFlightAnimation(
            entry,
            ped,
            active and 'dive' or 'normal',
            true
        )
    end
end

local function publishDiveState(active)
    TriggerServerEvent('ob_curandeiras:server:flightDiveState', active == true)
end

local function clearAllRemoteBoosts()
    local ids = {}
    for serverId in pairs(remoteBoosts) do
        ids[#ids + 1] = serverId
    end
    for index = 1, #ids do
        stopRemoteBoost(ids[index])
    end
end

local function setBoosting(active, ped)
    active = active == true
    if flight.boosting == active then
        if not active and #(flight.boostFxHandles or {}) > 0 then
            stopBoostDistortion()
        end
        return
    end

    flight.boosting = active
    if active then
        startBoostDistortion(ped)
        playBoostSmokeBurst(ped)
        publishBoostState(true)
    else
        stopBoostDistortion()
        publishBoostState(false)
    end
end

local function setDiving(active, ped)
    active = active == true
    if flight.diving == active then return end

    flight.diving = active
    updateWingFlightAnimation(
        flight,
        ped,
        active and 'dive' or 'normal',
        true
    )
    publishDiveState(active)
end

local function animationEntry(name)
    return Config.Flight.animations and Config.Flight.animations[name]
end

local function preloadFlightAnimations()
    local requested = {}
    local idle = animationEntry('idle')
    if not idle or not idle.dict then return false end

    for _, animation in pairs(Config.Flight.animations or {}) do
        if type(animation) == 'table' and animation.dict and not requested[animation.dict] then
            requested[animation.dict] = true
            RequestAnimDict(animation.dict)
        end
    end

    for _, animation in pairs(wingConfig.animations or {}) do
        if type(animation) == 'table' and animation.dict and not requested[animation.dict] then
            requested[animation.dict] = true
            RequestAnimDict(animation.dict)
        end
    end

    local timeout = GetGameTimer() + 5000
    while GetGameTimer() < timeout do
        local loaded = true
        for dict in pairs(requested) do
            if not HasAnimDictLoaded(dict) then
                loaded = false
                break
            end
        end

        if loaded then return true end
        Wait(10)
    end

    return false
end

local function playAnimation(name, duration, speed)
    local entry = animationEntry(name)
    local ped = PlayerPedId()
    if not entry then return false end
    if not HasAnimDictLoaded(entry.dict) then
        RequestAnimDict(entry.dict)
        return false
    end

    TaskPlayAnim(
        ped,
        entry.dict,
        entry.name,
        8.0,
        -8.0,
        duration or -1,
        1,
        0.0,
        false, false, false
    )
    local playbackSpeed = speed or 1.0
    if math.abs(playbackSpeed - 1.0) > 0.001 then
        SetEntityAnimSpeed(ped, entry.dict, entry.name, playbackSpeed)
    end
    return true
end

local function playLoopAnimation(name, speed)
    local entry = animationEntry(name)
    local ped = PlayerPedId()
    if not entry then return end

    if not IsEntityPlayingAnim(ped, entry.dict, entry.name, 3) then
        playAnimation(name, -1, speed)
    elseif math.abs((speed or 1.0) - 1.0) > 0.001 then
        SetEntityAnimSpeed(ped, entry.dict, entry.name, speed)
    end
end

local function updateFlightAnimation(boosting, diving)
    if GetGameTimer() < flight.takeoffUntil then return end

    local now = GetGameTimer()
    local desired = diving and 'dive' or (boosting and 'boost' or 'idle')
    if desired == flight.motion then
        if now < (flight.animationTransitionUntil or 0) then return end
        if now < flight.nextAnimationCheckAt then return end
        flight.nextAnimationCheckAt = now + math.max(
            100,
            tonumber(Config.Flight.animationCheckInterval) or 250
        )

        if desired == 'idle' then
            playLoopAnimation('idle', 1.0)
        elseif desired == 'dive' then
            playLoopAnimation('diveMoving', 1.16)
        else
            playLoopAnimation('moving', 1.16)
        end
        return
    end

    local previousMotion = flight.motion
    flight.motion = desired
    flight.nextAnimationCheckAt = now + math.max(
        100,
        tonumber(Config.Flight.animationCheckInterval) or 250
    )
    flight.animationToken = flight.animationToken + 1
    local token = flight.animationToken
    local transitionDuration = tonumber(Config.Flight.animations.transitionDuration) or 780
    flight.animationTransitionUntil = now + transitionDuration

    if desired == 'idle' then
        playAnimation('fastToIdle', transitionDuration, 1.0)
        CreateThread(function()
            Wait(transitionDuration)
            if flight.active and token == flight.animationToken and flight.motion == 'idle' then
                flight.animationTransitionUntil = 0
                playLoopAnimation('idle', 1.0)
            end
        end)
        return
    end

    if desired == 'dive' then
        flight.animationTransitionUntil = 0
        playLoopAnimation('diveMoving', 1.16)
        return
    end

    if previousMotion == 'dive' then
        flight.animationTransitionUntil = 0
        playLoopAnimation('moving', 1.16)
        return
    end

    playAnimation(
        'idleToMove',
        transitionDuration,
        tonumber(Config.Flight.animations.transitionSpeed) or 1.5
    )
    CreateThread(function()
        Wait(transitionDuration)
        if flight.active and token == flight.animationToken and flight.motion == 'boost' then
            flight.animationTransitionUntil = 0
            playLoopAnimation('moving', 1.16)
        end
    end)
end

local function startCamera()
    local cameraConfig = Config.Flight.camera
    local renderedRotation = GetFinalRenderedCamRot(2)

    flight.cameraYaw = renderedRotation.z
    flight.cameraPitch = clamp(
        renderedRotation.x,
        cameraConfig.minPitch,
        cameraConfig.maxPitch
    )
    flight.cameraRoll = 0.0
    flight.cameraFrontView = false
    flight.cameraFrontBlend = 0.0
    flight.cameraPosition = GetFinalRenderedCamCoord()
    flight.camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)

    SetCamCoord(
        flight.camera,
        flight.cameraPosition.x,
        flight.cameraPosition.y,
        flight.cameraPosition.z
    )
    SetCamRot(flight.camera, flight.cameraPitch, 0.0, flight.cameraYaw, 2)
    SetCamFov(flight.camera, cameraConfig.normalFov)
    SetCamActive(flight.camera, true)
    RenderScriptCams(true, true, 650, true, true)
end

local function stopCamera()
    if flight.camera ~= 0 and DoesCamExist(flight.camera) then
        RenderScriptCams(false, true, 650, true, true)
        DestroyCam(flight.camera, false)
    end

    flight.camera = 0
    flight.cameraPosition = nil
    flight.cameraFrontView = false
    flight.cameraFrontBlend = 0.0
    ClearFocus()
end

local function updateCamera(boosting)
    if flight.camera == 0 or not DoesCamExist(flight.camera)
        or flight.controller == 0 or not DoesEntityExist(flight.controller) then
        return
    end

    local config = Config.Flight.camera
    local controls = Config.Flight.controls or {}
    local frontView = isControlPressed(controls.frontView or 26)
    local frontBlendSpeed = clamp(tonumber(config.frontViewBlendSpeed) or 0.16, 0.01, 1.0)

    flight.cameraFrontView = frontView
    flight.cameraFrontBlend = lerp(
        flight.cameraFrontBlend or 0.0,
        frontView and 1.0 or 0.0,
        frontBlendSpeed
    )

    -- A visao frontal apenas reposiciona a camera; a direcao do voo fica intacta.
    if not frontView then
        local mouseX = GetDisabledControlNormal(0, 1)
        local mouseY = GetDisabledControlNormal(0, 2)
        flight.cameraYaw = normalizeAngle(flight.cameraYaw - (mouseX * config.yawSpeed))
        flight.cameraPitch = clamp(
            flight.cameraPitch - (mouseY * config.pitchSpeed),
            config.minPitch,
            config.maxPitch
        )
    end

    local forward = cameraForward()
    local right = normalize(vector3(forward.y, -forward.x, 0.0))
    local coords = GetEntityCoords(flight.controller)
    local velocity = GetEntityVelocity(flight.controller)
    local rearPosition = coords - (forward * config.distance)
        + vector3(0.0, 0.0, config.height)
    local horizontalForward = normalize(vector3(forward.x, forward.y, 0.0))
    if #(horizontalForward) <= 0.0001 then
        horizontalForward = GetEntityForwardVector(flight.controller)
    end

    local frontBlend = flight.cameraFrontBlend
    local rearOffset = rearPosition - coords
    local rearDistance = math.sqrt(
        (rearOffset.x * rearOffset.x) + (rearOffset.y * rearOffset.y)
    )
    local frontDistance = tonumber(config.frontViewDistance) or 5.0
    local orbitAngle = math.pi * frontBlend
    local orbitDirection = (horizontalForward * -math.cos(orbitAngle))
        + (right * math.sin(orbitAngle))
    local orbitDistance = lerp(rearDistance, frontDistance, frontBlend)
    local orbitHeight = lerp(
        rearOffset.z,
        tonumber(config.frontViewHeight) or 1.55,
        frontBlend
    )
    local desiredPosition = coords + (orbitDirection * orbitDistance)
        + vector3(0.0, 0.0, orbitHeight)

    flight.cameraPosition = vector3(
        lerp(flight.cameraPosition.x, desiredPosition.x, 0.22),
        lerp(flight.cameraPosition.y, desiredPosition.y, 0.22),
        lerp(flight.cameraPosition.z, desiredPosition.z, 0.22)
    )

    local lateralVelocity = (velocity.x * right.x) + (velocity.y * right.y)
    local targetRoll = clamp(lateralVelocity * 1.8, -24.0, 24.0)
    flight.cameraRoll = lerp(flight.cameraRoll, targetRoll, 0.08)

    local lookTarget = coords
        + vector3(0.0, 0.0, tonumber(config.frontViewLookHeight) or 1.45)
    local lookDirection = lookTarget - flight.cameraPosition
    local lookHorizontal = math.sqrt(
        (lookDirection.x * lookDirection.x) + (lookDirection.y * lookDirection.y)
    )
    local frontPitch = math.deg(math.atan(lookDirection.z, math.max(lookHorizontal, 0.0001)))
    local frontYaw = normalizeAngle(math.deg(math.atan(-lookDirection.x, lookDirection.y)))
    local displayPitch = lerp(flight.cameraPitch, frontPitch, frontBlend)
    local displayYaw = lerpAngle(flight.cameraYaw, frontYaw, frontBlend)
    local displayRoll = lerp(flight.cameraRoll, 0.0, frontBlend)

    SetCamCoord(
        flight.camera,
        flight.cameraPosition.x,
        flight.cameraPosition.y,
        flight.cameraPosition.z
    )
    SetCamRot(
        flight.camera,
        displayPitch,
        displayRoll,
        displayYaw,
        2
    )

    local currentFov = GetCamFov(flight.camera)
    local flightFov = boosting and config.boostFov or config.normalFov
    local desiredFov = lerp(
        flightFov,
        tonumber(config.frontViewFov) or 48.0,
        frontBlend
    )
    SetCamFov(flight.camera, lerp(currentFov, desiredFov, 0.08))
    SetFocusPosAndVel(coords.x, coords.y, coords.z, velocity.x, velocity.y, velocity.z)
end

local function createController()
    local config = Config.Flight
    local model = requestModel(config.controllerModel)
    if not model then return nil end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local controller = CreateObjectNoOffset(
        model,
        coords.x,
        coords.y,
        coords.z + 0.15,
        true, true, false
    )
    SetModelAsNoLongerNeeded(model)
    if controller == 0 or not DoesEntityExist(controller) then return nil end

    SetEntityAsMissionEntity(controller, true, true)
    local controllerNetId = NetworkGetNetworkIdFromEntity(controller)
    if not controllerNetId or controllerNetId == 0 then
        DeleteEntity(controller)
        return nil
    end

    flight.controllerNetId = controllerNetId
    SetNetworkIdCanMigrate(controllerNetId, false)
    SetNetworkIdExistsOnAllMachines(controllerNetId, true)

    local controlTimeout = GetGameTimer() + 750
    while not NetworkHasControlOfEntity(controller) and GetGameTimer() < controlTimeout do
        NetworkRequestControlOfEntity(controller)
        Wait(0)
    end

    if not NetworkHasControlOfEntity(controller) then
        DeleteEntity(controller)
        flight.controllerNetId = 0
        return nil
    end

    SetEntityVisible(controller, false, false)
    SetEntityAlpha(controller, 0, false)
    SetEntityCollision(controller, true, true)
    SetEntityDynamic(controller, true)
    ActivatePhysics(controller)
    SetEntityHasGravity(controller, false)
    SetEntityInvincible(controller, true)
    FreezeEntityPosition(controller, false)
    SetEntityHeading(controller, GetEntityHeading(ped))

    flight.wasInvincible = GetPlayerInvincible(PlayerId())
    ClearPedTasksImmediately(ped)
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
    SetEntityAngularVelocity(ped, 0.0, 0.0, 0.0)
    SetEntityCollision(ped, false, false)
    SetEntityHasGravity(ped, false)
    SetPedCanRagdoll(ped, false)
    SetEntityInvincible(ped, true)

    for attempt = 1, 5 do
        AttachEntityToEntity(
            ped,
            controller,
            -1,
            0.0, 0.0, config.pedOffsetZ,
            0.0, 0.0, 0.0,
            false, false, false, true, 2, true
        )
        Wait(0)

        if IsEntityAttachedToEntity(ped, controller) then
            return controller
        end

        local controllerCoords = GetEntityCoords(controller)
        SetEntityCoordsNoOffset(
            ped,
            controllerCoords.x,
            controllerCoords.y,
            controllerCoords.z + config.pedOffsetZ,
            false, false, false
        )
    end

    SetEntityCollision(ped, true, true)
    SetEntityHasGravity(ped, true)
    SetPedCanRagdoll(ped, true)
    SetEntityInvincible(ped, flight.wasInvincible)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityCollision(controller, false, false)
    DeleteEntity(controller)
    flight.controllerNetId = 0

    return nil
end

local function setFlightAbilities(active)
    ObCurandeiras.UpdateAbility('voo', { enabled = true, selected = active })
    ObCurandeiras.UpdateAbility('cura_vital', { enabled = not active })
    ObCurandeiras.UpdateAbility('serenidade', { enabled = not active })
    ObCurandeiras.UpdateAbility('estancar', { enabled = not active })
end

local function restorePed(landingCoords)
    local ped = PlayerPedId()
    DetachEntity(ped, true, true)
    SetEntityCollision(ped, true, true)
    SetEntityHasGravity(ped, true)
    SetPedCanRagdoll(ped, true)
    SetEntityInvincible(ped, flight.wasInvincible)
    FreezeEntityPosition(ped, false)
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
    SetEntityAngularVelocity(ped, 0.0, 0.0, 0.0)

    if landingCoords then
        SetEntityCoordsNoOffset(
            ped,
            landingCoords.x,
            landingCoords.y,
            landingCoords.z + (Config.Flight.landingZOffset or 1.0),
            false, false, false
        )
    end

    ClearPedTasksImmediately(ped)
end

local function deleteController()
    if flight.controller ~= 0 and DoesEntityExist(flight.controller) then
        SetEntityCollision(flight.controller, false, false)
        DeleteEntity(flight.controller)
    end
    flight.controller = 0
    flight.controllerNetId = 0
end

local function finishFlight(silent, landingCoords)
    if not flight.active and flight.controller == 0 then
        stopBoostDistortion()
        return
    end

    setDiving(false, PlayerPedId())
    setBoosting(false, PlayerPedId())
    stopBoostDistortion()
    flight.active = false
    flight.transitioning = false
    flight.landing = false
    flight.animationToken = flight.animationToken + 1
    flight.motion = nil
    flight.takeoffUntil = 0
    flight.boosting = false
    flight.diving = false
    flight.boostHeld = false
    flight.nextGroundSafetyAt = 0
    flight.nextAnimationCheckAt = 0
    flight.animationTransitionUntil = 0
    flight.nextWingRequirementCheckAt = 0
    flight.nextWingLandingAttemptAt = 0
    flight.nextHypnosisLandingAttemptAt = 0
    flight.nextDiveCheckAt = 0
    flight.wingFxHandles = stopParticleHandles(flight.wingFxHandles)
    clearWingFlightAnimation(flight)

    stopCamera()
    restorePed(landingCoords)
    deleteController()
    setWingOpenPose(flight, PlayerPedId())

    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set('obHealerFlight', false, true)
        LocalPlayer.state:set('obHealerFlightController', 0, true)
    end

    setFlightAbilities(false)
    TriggerServerEvent('ob_curandeiras:server:flightEnded')
    ObCurandeiras.StartCooldown('voo', Config.Flight.cooldown)

    if not silent then
        ObCurandeiras.Notify('Voo', 'Voce retornou ao solo.', 'inform')
    end
end

local function beginLanding(silentNoGround, reason)
    if not flight.active or flight.transitioning or flight.landing then return end
    if flight.controller == 0 or not DoesEntityExist(flight.controller) then
        finishFlight(true)
        return
    end

    local controllerCoords = GetEntityCoords(flight.controller)
    local found, groundCoords, distance = groundBelow(
        controllerCoords,
        Config.Flight.groundScanDistance,
        true
    )
    if not found then
        if not silentNoGround then
            ObCurandeiras.Notify(
                'Voo',
                'Aproxime-se de uma superficie para pousar com seguranca.',
                'warning'
            )
        end
        return
    end

    flight.transitioning = true
    flight.landing = true
    setDiving(false, PlayerPedId())
    setBoosting(false, PlayerPedId())
    flight.motion = 'idle'
    flight.animationToken = flight.animationToken + 1
    playLoopAnimation('idle', 1.0)
    updateWingFlightAnimation(flight, PlayerPedId(), 'normal', true)
    SetEntityCollision(flight.controller, false, false)

    CreateThread(function()
        local startCoords = GetEntityCoords(flight.controller)
        local targetZ = groundCoords.z
            - Config.Flight.pedOffsetZ
            + (Config.Flight.landingZOffset or 1.0)
        local targetCoords = vector3(groundCoords.x, groundCoords.y, targetZ)
        local duration
        if reason == 'hypnosis' then
            local descentSpeed = math.max(0.5, tonumber(Config.Flight.hypnosisDescentSpeed) or 8.0)
            duration = clamp(
                math.floor(((distance or 5.0) / descentSpeed) * 1000.0),
                tonumber(Config.Flight.hypnosisLandingMinDuration) or 1800,
                tonumber(Config.Flight.hypnosisLandingMaxDuration) or 9000
            )
        else
            duration = clamp(
                math.floor((distance or 5.0) * 150.0),
                Config.Flight.landingMinDuration,
                Config.Flight.landingMaxDuration
            )
        end
        local startedAt = GetGameTimer()

        while flight.active and flight.landing and DoesEntityExist(flight.controller) do
            local progress = clamp((GetGameTimer() - startedAt) / duration, 0.0, 1.0)
            local smooth = progress * progress * (3.0 - (2.0 * progress))
            local current = vector3(
                lerp(startCoords.x, targetCoords.x, smooth),
                lerp(startCoords.y, targetCoords.y, smooth),
                lerp(startCoords.z, targetCoords.z, smooth)
            )

            SetEntityCoordsNoOffset(
                flight.controller,
                current.x,
                current.y,
                current.z,
                false, false, false
            )
            SetEntityVelocity(flight.controller, 0.0, 0.0, 0.0)
            SetEntityAngularVelocity(flight.controller, 0.0, 0.0, 0.0)
            playLoopAnimation('idle', 1.0)
            updateWingFlightAnimation(flight, PlayerPedId(), 'normal', false)

            if progress >= 1.0 then break end
            Wait(0)
        end

        if flight.active and flight.landing then
            finishFlight(false, groundCoords)
        end
    end)
end

local function capVelocity(maximum)
    if flight.controller == 0 or not DoesEntityExist(flight.controller) then return end
    local velocity = GetEntityVelocity(flight.controller)
    local speed = #(velocity)
    if speed > maximum then
        local limited = normalize(velocity) * maximum
        SetEntityVelocity(flight.controller, limited.x, limited.y, limited.z)
    end
end

local function applyGroundSafety()
    if flight.controller == 0 or not DoesEntityExist(flight.controller) then return end

    local now = GetGameTimer()
    if now < flight.nextGroundSafetyAt then return end
    flight.nextGroundSafetyAt = now + math.max(
        50,
        tonumber(Config.Flight.groundSafetyInterval) or 90
    )

    local coords = GetEntityCoords(flight.controller)
    local found, _, distance = groundBelow(
        coords,
        Config.Flight.groundSafetyDistance + 0.8,
        false
    )
    if not found or not distance or distance > Config.Flight.groundSafetyDistance then return end

    local velocity = GetEntityVelocity(flight.controller)
    if velocity.z < 0.15 then
        SetEntityVelocity(
            flight.controller,
            velocity.x * 0.96,
            velocity.y * 0.96,
            0.15
        )
    end
end

local function updateDiveMode(movingForward, boosting, ped)
    local config = Config.Flight.dive or {}
    local now = GetGameTimer()
    if now < flight.nextDiveCheckAt then
        return flight.diving
    end

    flight.nextDiveCheckAt = now + math.max(
        75,
        tonumber(config.checkInterval) or 150
    )

    local downwardIntent = movingForward
        and boosting
        and flight.cameraPitch <= (tonumber(config.cameraPitchThreshold) or -35.0)

    if not downwardIntent then
        setDiving(false, ped)
        return false
    end

    local coords = GetEntityCoords(flight.controller)
    local found, _, distance = groundBelow(
        coords,
        tonumber(config.groundScanDistance) or 180.0,
        true
    )
    local requiredHeight = flight.diving
        and (tonumber(config.exitHeight) or 6.0)
        or (tonumber(config.minimumHeight) or 12.0)
    local active = found and distance and distance >= requiredHeight

    setDiving(active, ped)
    return active
end

local function updateMovement()
    local controls = Config.Flight.controls or {}
    local forward = cameraForward()
    local right = normalize(vector3(forward.y, -forward.x, 0.0))
    local direction = vector3(0.0, 0.0, 0.0)

    local movingForward = isControlPressed(32)
    local movingBackward = isControlPressed(33)
    local movingLeft = isControlPressed(34)
    local movingRight = isControlPressed(35)
    local descending = isControlPressed(controls.descend or 22)

    if movingForward then direction = direction + forward end
    if movingBackward then direction = direction - forward end
    if movingLeft then direction = direction - right end
    if movingRight then direction = direction + right end
    if descending then
        direction = direction - vector3(0.0, 0.0, Config.Flight.verticalAcceleration)
    end
    if isControlPressed(controls.ascend or 36) then
        direction = direction + vector3(0.0, 0.0, Config.Flight.verticalAcceleration)
    end

    local moving = #(direction) > 0.001
    local boosting = movingForward
        and not movingBackward
        and (flight.boostHeld or isControlPressed(controls.boost or 21))
    local velocity = GetEntityVelocity(flight.controller)
    local ped = PlayerPedId()
    local diving = updateDiveMode(movingForward, boosting, ped)

    setBoosting(boosting, ped)
    updateWingFlightAnimation(
        flight,
        ped,
        diving and 'dive' or 'normal',
        false
    )

    if moving then
        local movementMultiplier = 1.0
        if movingBackward and not movingForward then
            movementMultiplier = Config.Flight.backwardMultiplier or 0.62
        end
        local speedMultiplier = 1.0
        if boosting then
            speedMultiplier = math.max(
                speedMultiplier,
                tonumber(Config.Flight.boostMultiplier) or 1.0
            )
        end
        if diving then
            speedMultiplier = math.max(
                speedMultiplier,
                tonumber(Config.Flight.dive and Config.Flight.dive.speedMultiplier) or 1.0
            )
        end
        local multiplier = speedMultiplier * movementMultiplier
        local force = normalize(direction) * (Config.Flight.acceleration * multiplier)
        ApplyForceToEntityCenterOfMass(
            flight.controller,
            1,
            force.x, force.y, force.z,
            0,
            false,
            true,
            true
        )
    else
        SetEntityVelocity(
            flight.controller,
            velocity.x * Config.Flight.idleDrag,
            velocity.y * Config.Flight.idleDrag,
            velocity.z * Config.Flight.idleDrag
        )
    end

    local maximumSpeed = tonumber(Config.Flight.maxSpeed) or 10.0
    if diving then
        maximumSpeed = math.max(
            maximumSpeed,
            tonumber(Config.Flight.dive and Config.Flight.dive.maxSpeed) or 22.0
        )
    end
    if boosting then
        maximumSpeed = math.max(
            maximumSpeed,
            tonumber(Config.Flight.maxBoostSpeed) or 25.0
        )
    end
    capVelocity(maximumSpeed)
    applyGroundSafety()

    local safePitch = clamp(flight.cameraPitch, -20.0, 28.0)
    SetEntityRotation(
        flight.controller,
        (boosting or diving) and safePitch or 0.0,
        (boosting or diving) and flight.cameraRoll or 0.0,
        flight.cameraYaw,
        2,
        true
    )
    SetEntityAngularVelocity(flight.controller, 0.0, 0.0, 0.0)
    updateFlightAnimation(boosting, diving)
    return boosting, diving
end

local function flightLoop()
    CreateThread(function()
        local nextSyncAt = 0
        local controls = Config.Flight.controls or {}

        while flight.active do
            local ped = PlayerPedId()
            local now = GetGameTimer()

            if flight.controller == 0
                or not DoesEntityExist(flight.controller)
                or not IsEntityAttachedToEntity(ped, flight.controller) then
                finishFlight(true)
                ObCurandeiras.Notify(
                    'Voo',
                    'O vinculo com suas asas foi interrompido.',
                    'error'
                )
                return
            end

            local hypnotized = isHypnotized()
            if hypnotized and not flight.landing and not flight.transitioning
                and now >= flight.nextHypnosisLandingAttemptAt then
                flight.nextHypnosisLandingAttemptAt = now + 250
                beginLanding(true, 'hypnosis')
            end

            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, controls.frontView or 26, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 75, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)

            local boosting = false
            local diving = false
            if not flight.landing and not hypnotized then
                boosting, diving = updateMovement()
            elseif hypnotized and not flight.landing then
                setDiving(false, ped)
                setBoosting(false, ped)
                updateFlightAnimation(false, false)
                updateWingFlightAnimation(flight, ped, 'normal', false)

                local velocity = GetEntityVelocity(flight.controller)
                local descentSpeed = math.max(
                    0.5,
                    tonumber(Config.Flight.hypnosisFallbackDescentSpeed) or 2.0
                )
                SetEntityVelocity(
                    flight.controller,
                    velocity.x * 0.84,
                    velocity.y * 0.84,
                    math.max(-descentSpeed, math.min(-0.35, velocity.z))
                )
            end
            updateCamera(boosting or diving)

            if GetGameTimer() >= nextSyncAt
                and flight.controller ~= 0
                and DoesEntityExist(flight.controller) then
                nextSyncAt = GetGameTimer() + math.max(
                    35,
                    tonumber(Config.Flight.syncInterval) or 50
                )

                local coords = GetEntityCoords(flight.controller)
                local rotation = GetEntityRotation(flight.controller, 2)
                local velocity = GetEntityVelocity(flight.controller)
                TriggerServerEvent('ob_curandeiras:server:flightTransform', {
                    coords = { x = coords.x, y = coords.y, z = coords.z },
                    rotation = { x = rotation.x, y = rotation.y, z = rotation.z },
                    velocity = { x = velocity.x, y = velocity.y, z = velocity.z },
                })
            end

            if now >= flight.nextWingRequirementCheckAt then
                flight.nextWingRequirementCheckAt = now + 500
                if not hasRequiredWing()
                    and not flight.landing
                    and now >= flight.nextWingLandingAttemptAt then
                    flight.nextWingLandingAttemptAt = now + 1000
                    beginLanding(true)
                end
            end

            if IsEntityDead(ped)
                or not ObCurandeiras.IsHealer()
                or hasFlightInterruptingBlock()
                or IsEntityInWater(ped)
                or IsPedSwimming(ped) then
                finishFlight(true)
                return
            end

            Wait(0)
        end
    end)
end

local function startFlight()
    if flight.transitioning or flight.active
        or not ObCurandeiras.IsHealer()
        or ObCurandeiras.IsPowerBlocked() then
        return
    end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        ObCurandeiras.Notify('Voo', 'Saia do veiculo antes de manifestar suas asas.', 'warning')
        return
    end
    if not hasRequiredWing() then
        ObCurandeiras.Notify(
            'Voo',
            'Equipe suas asas antes de tentar voar.',
            'warning'
        )
        return
    end
    if not preloadFlightAnimations() then
        ObCurandeiras.Notify(
            'Voo',
            'A animacao de voo nao foi carregada. Reinicie o Seatingposepack.',
            'error'
        )
        return
    end
    if not ObCurandeiras.Authorize('voo') then return end

    flight.transitioning = true
    flight.controller = createController() or 0
    if flight.controller == 0 then
        flight.transitioning = false
        TriggerServerEvent('ob_curandeiras:server:flightAborted')
        ObCurandeiras.Notify('Voo', 'Nao foi possivel iniciar o voo.', 'error')
        return
    end

    flight.active = true
    flight.landing = false
    flight.boosting = false
    flight.diving = false
    flight.boostHeld = false
    flight.motion = 'idle'
    flight.takeoffUntil = GetGameTimer() + Config.Flight.animations.transitionDuration
    flight.nextGroundSafetyAt = 0
    flight.nextAnimationCheckAt = 0
    flight.animationTransitionUntil = 0
    flight.nextWingRequirementCheckAt = 0
    flight.nextWingLandingAttemptAt = 0
    flight.nextHypnosisLandingAttemptAt = 0
    flight.nextDiveCheckAt = 0
    SetEntityVelocity(flight.controller, 0.0, 0.0, Config.Flight.takeoffVelocity)
    startCamera()

    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set('obHealerFlight', true, true)
        LocalPlayer.state:set('obHealerFlightController', flight.controllerNetId, true)
    end

    setFlightAbilities(true)
    TriggerServerEvent('ob_curandeiras:server:flightFx', true, flight.controllerNetId)
    flight.transitioning = false
    flightLoop()

    CreateThread(function()
        if flight.active then
            playLoopAnimation('idle', 1.0)
        end
    end)

    CreateThread(function()
        if not flight.active then return end
        clearWingFlightAnimation(flight)
        updateWingFlightAnimation(flight, ped, 'normal', true)
        flight.wingFxHandles = stopParticleHandles(flight.wingFxHandles)
        flight.wingFxHandles = createWingFx(ped)
    end)

    ObCurandeiras.Notify(
        'Voo',
        'Voo iniciado. Use o poder novamente para pousar.',
        'success'
    )
end

RegisterNetEvent('ob_curandeiras:client:toggleFlight', function()
    if flight.active then
        beginLanding()
    else
        startFlight()
    end
end)

RegisterNetEvent('ob_curandeiras:client:flightEssenceDepleted', function()
    if not flight.active then return end

    ObCurandeiras.Notify(
        'Voo',
        'Sua essencia se esgotou. As asas estao conduzindo voce ao solo.',
        'warning',
        3200
    )
    beginLanding()
end)

RegisterNetEvent('ob_curandeiras:client:forceStopFlight', function()
    if flight.active or flight.controller ~= 0 then
        finishFlight(true)
        return
    end

    flight.wingFxHandles = stopParticleHandles(flight.wingFxHandles)
    clearWingFlightAnimation(flight)
    stopBoostDistortion()
    stopCamera()
    deleteController()
    setFlightAbilities(false)

    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set('obHealerFlight', false, true)
        LocalPlayer.state:set('obHealerFlightController', 0, true)
    end
end)

local function refreshRemoteFlightLod()
    local lod = Config.Flight.lod or {}
    local maximumEffects = math.max(1, math.floor(tonumber(lod.maxCustomSyncFlights) or 8))
    local effectsDistance = math.max(10.0, tonumber(lod.effectsDistance) or 70.0)
    local closeDistance = math.max(5.0, tonumber(lod.closeDistance) or 40.0)
    local mediumDistance = math.max(closeDistance, tonumber(lod.mediumDistance) or 90.0)
    local closeInterval = math.max(16, tonumber(lod.closeRenderInterval) or 33)
    local mediumInterval = math.max(closeInterval, tonumber(lod.mediumRenderInterval) or 66)
    local farInterval = math.max(mediumInterval, tonumber(lod.farRenderInterval) or 125)
    local origin = GetEntityCoords(PlayerPedId())
    local candidates = {}

    for serverId, entry in pairs(remoteFlights) do
        local playerIndex = GetPlayerFromServerId(serverId)
        local ped = playerIndex ~= -1 and GetPlayerPed(playerIndex) or 0
        local distance = math.huge
        if ped ~= 0 and DoesEntityExist(ped) then
            distance = #(GetEntityCoords(ped) - origin)
        end

        entry.distance = distance
        entry.renderInterval = farInterval
        if distance <= closeDistance then
            entry.renderInterval = closeInterval
        elseif distance <= mediumDistance then
            entry.renderInterval = mediumInterval
        end

        candidates[#candidates + 1] = {
            entry = entry,
            distance = distance,
        }
    end

    table.sort(candidates, function(first, second)
        return first.distance < second.distance
    end)

    for index, candidate in ipairs(candidates) do
        local entry = candidate.entry
        local effectsEnabled = index <= maximumEffects and candidate.distance <= effectsDistance
        if entry.effectsEnabled ~= effectsEnabled then
            entry.effectsEnabled = effectsEnabled
            if not effectsEnabled then
                entry.wingFxHandles = stopParticleHandles(entry.wingFxHandles)
            end
        end
    end
end

local function ensureRemoteFlightFxThread()
    if remoteFxThreadRunning or not next(remoteFlights) then return end

    remoteFxThreadRunning = true
    CreateThread(function()
        local nextLodRefreshAt = 0

        while next(remoteFlights) do
            local now = GetGameTimer()
            if now >= nextLodRefreshAt then
                refreshRemoteFlightLod()
                nextLodRefreshAt = now + math.max(
                    500,
                    tonumber(Config.Flight.lod and Config.Flight.lod.refreshInterval) or 750
                )
            end

            for serverId, entry in pairs(remoteFlights) do
                if now >= (entry.nextRenderAt or 0) then
                    entry.nextRenderAt = now + math.max(
                        16,
                        tonumber(entry.renderInterval) or tonumber(Config.Flight.remoteRenderInterval) or 33
                    )

                    local playerIndex = GetPlayerFromServerId(serverId)
                    local ped = playerIndex ~= -1 and GetPlayerPed(playerIndex) or 0
                    if ped ~= 0 and DoesEntityExist(ped) then
                        local controllerNetId = tonumber(entry.controllerNetId) or 0
                        local controller = controllerNetId > 0
                            and NetworkGetEntityFromNetworkId(controllerNetId) or 0

                        if controller ~= 0 and DoesEntityExist(controller) then
                            local setupChanged = entry.ped ~= ped or entry.controller ~= controller

                            if setupChanged then
                                entry.wingFxHandles = stopParticleHandles(entry.wingFxHandles)
                                clearWingFlightAnimation(entry)
                                entry.ped = ped
                                entry.controller = controller
                                entry.nextAttachCheckAt = 0

                                SetEntityVisible(controller, false, false)
                                SetEntityAlpha(controller, 0, false)
                                SetEntityCollision(controller, false, false)
                                SetEntityHasGravity(controller, false)

                                SetEntityCollision(ped, false, false)
                                SetEntityHasGravity(ped, false)
                                SetPedCanRagdoll(ped, false)
                            end

                            if entry.effectsEnabled == true and #(entry.wingFxHandles or {}) == 0 then
                                entry.wingFxHandles = createWingFx(ped, entry.effectColor)
                            elseif entry.effectsEnabled ~= true and #(entry.wingFxHandles or {}) > 0 then
                                entry.wingFxHandles = stopParticleHandles(entry.wingFxHandles)
                            end

                            updateWingFlightAnimation(
                                entry,
                                ped,
                                entry.diving == true and 'dive' or 'normal',
                                setupChanged
                            )

                            local transform = entry.transform
                            if transform then
                                local age = math.min(
                                    tonumber(Config.Flight.syncMaxPrediction) or 0.16,
                                    math.max(0.0, (now - transform.receivedAt) / 1000.0)
                                )
                                local predicted = transform.coords + (transform.velocity * age)
                                local current = GetEntityCoords(controller)
                                local distance = #(predicted - current)
                                local amount = distance > 12.0 and 1.0
                                    or math.max(
                                        0.05,
                                        math.min(1.0, tonumber(Config.Flight.syncInterpolation) or 0.42)
                                    )
                                local rendered = vector3(
                                    lerp(current.x, predicted.x, amount),
                                    lerp(current.y, predicted.y, amount),
                                    lerp(current.z, predicted.z, amount)
                                )

                                SetEntityCoordsNoOffset(
                                    controller,
                                    rendered.x, rendered.y, rendered.z,
                                    false, false, false
                                )
                                SetEntityRotation(
                                    controller,
                                    transform.rotation.x,
                                    transform.rotation.y,
                                    transform.rotation.z,
                                    2,
                                    true
                                )
                                SetEntityVelocity(
                                    controller,
                                    transform.velocity.x,
                                    transform.velocity.y,
                                    transform.velocity.z
                                )
                            end

                            if setupChanged or now >= (entry.nextAttachCheckAt or 0) then
                                entry.nextAttachCheckAt = now + 500
                                if not IsEntityAttachedToEntity(ped, controller) then
                                    AttachEntityToEntity(
                                        ped,
                                        controller,
                                        -1,
                                        0.0, 0.0, Config.Flight.pedOffsetZ,
                                        0.0, 0.0, 0.0,
                                        false, false, false, true, 2, true
                                    )
                                end
                            end
                        end
                    else
                        entry.wingFxHandles = stopParticleHandles(entry.wingFxHandles)
                        entry.ped = 0
                        entry.controller = 0
                    end
                end
            end

            Wait(math.max(
                16,
                tonumber(Config.Flight.lod and Config.Flight.lod.closeRenderInterval)
                    or tonumber(Config.Flight.remoteRenderInterval)
                    or 33
            ))
        end
        remoteFxThreadRunning = false
    end)
end

RegisterNetEvent('ob_curandeiras:client:remoteFlightTransform', function(serverId, data)
    serverId = tonumber(serverId)
    if not serverId or serverId == GetPlayerServerId(PlayerId()) or type(data) ~= 'table' then
        return
    end

    local coords = data.coords
    local rotation = data.rotation
    local velocity = data.velocity
    if type(coords) ~= 'table' or type(rotation) ~= 'table' or type(velocity) ~= 'table' then
        return
    end

    local entry = remoteFlights[serverId]
    if not entry then return end

    entry.transform = {
        coords = vector3(
            tonumber(coords.x) or 0.0,
            tonumber(coords.y) or 0.0,
            tonumber(coords.z) or 0.0
        ),
        rotation = vector3(
            tonumber(rotation.x) or 0.0,
            tonumber(rotation.y) or 0.0,
            tonumber(rotation.z) or 0.0
        ),
        velocity = vector3(
            tonumber(velocity.x) or 0.0,
            tonumber(velocity.y) or 0.0,
            tonumber(velocity.z) or 0.0
        ),
        receivedAt = GetGameTimer(),
    }
end)

local function detachRemoteFlight(serverId)
    local entry = remoteFlights[serverId]
    if not entry then return end
    remoteDiveStates[serverId] = nil
    entry.wingFxHandles = stopParticleHandles(entry.wingFxHandles)
    clearWingFlightAnimation(entry)

    local playerIndex = GetPlayerFromServerId(serverId)
    local ped = playerIndex ~= -1 and GetPlayerPed(playerIndex) or 0
    local controllerNetId = math.max(0, math.floor(tonumber(entry.controllerNetId) or 0))
    local controller = controllerNetId > 0
        and NetworkGetEntityFromNetworkId(controllerNetId) or 0

    if ped ~= 0 and DoesEntityExist(ped)
        and controller ~= 0 and DoesEntityExist(controller)
        and IsEntityAttachedToEntity(ped, controller) then
        DetachEntity(ped, true, true)
    end

    if ped ~= 0 and DoesEntityExist(ped) then
        SetEntityCollision(ped, true, true)
        SetEntityHasGravity(ped, true)
        SetPedCanRagdoll(ped, true)
        setWingOpenPose(entry, ped)
    end
end

RegisterNetEvent('ob_curandeiras:client:remoteFlightFx', function(serverId, active, controllerNetId, effectColor)
    serverId = tonumber(serverId)
    if not serverId or serverId == GetPlayerServerId(PlayerId()) then return end

    if active == true then
        local networkId = math.max(0, math.floor(tonumber(controllerNetId) or 0))
        local syncedColor = normalizedEffectColor(effectColor)
        local entry = remoteFlights[serverId]

        if entry then
            if entry.controllerNetId ~= networkId then
                entry.wingFxHandles = stopParticleHandles(entry.wingFxHandles)
                entry.controller = 0
                entry.transform = nil
            end
            if syncedColor and not sameEffectColor(entry.effectColor, syncedColor) then
                entry.wingFxHandles = stopParticleHandles(entry.wingFxHandles)
            end
            entry.controllerNetId = networkId
            entry.effectColor = syncedColor or entry.effectColor
            entry.nextRenderAt = 0
        else
            remoteFlights[serverId] = {
                controllerNetId = networkId,
                diving = remoteDiveStates[serverId] == true,
                effectColor = syncedColor,
            }
        end
    else
        detachRemoteFlight(serverId)
        remoteFlights[serverId] = nil
    end

    if active == true then
        ensureRemoteFlightFxThread()
    else
        stopRemoteBoost(serverId)
    end
end)

RegisterNetEvent('ob_curandeiras:client:remoteFlightBoostState', function(serverId, active, effectColor)
    setRemoteBoost(serverId, active, effectColor)
end)

RegisterNetEvent('ob_curandeiras:client:remoteFlightDiveState', function(serverId, active)
    setRemoteDive(serverId, active)
end)

CreateThread(function()
    Wait(1800)
    local ok, active = pcall(function()
        return lib.callback.await('ob_curandeiras:server:getActiveFlights', false)
    end)
    if ok and type(active) == 'table' then
        for _, entry in ipairs(active) do
            local serverId = tonumber(type(entry) == 'table' and entry.source or entry)
            if serverId and serverId ~= GetPlayerServerId(PlayerId()) then
                remoteFlights[serverId] = {
                    controllerNetId = math.max(
                        0,
                        math.floor(tonumber(type(entry) == 'table' and entry.controllerNetId) or 0)
                    ),
                    diving = false,
                    effectColor = normalizedEffectColor(
                        type(entry) == 'table' and entry.effectColor
                    ),
                }
            end
        end
        ensureRemoteFlightFxThread()
    end

    local boostsOk, boosts = pcall(function()
        return lib.callback.await('ob_curandeiras:server:getActiveFlightBoosts', false)
    end)
    if boostsOk and type(boosts) == 'table' then
        for _, entry in ipairs(boosts) do
            local serverId = tonumber(type(entry) == 'table' and entry.source or entry)
            if serverId then
                setRemoteBoost(
                    serverId,
                    true,
                    type(entry) == 'table' and entry.effectColor
                )
            end
        end
    end

    local divesOk, dives = pcall(function()
        return lib.callback.await('ob_curandeiras:server:getActiveFlightDives', false)
    end)
    if divesOk and type(dives) == 'table' then
        for _, serverId in ipairs(dives) do
            setRemoteDive(serverId, true)
        end
    end
end)

exports('IsFlying', function()
    return flight.active
end)

RegisterCommand('+ob_curandeiras_flight_boost', function()
    flight.boostHeld = true
end, false)

RegisterCommand('-ob_curandeiras_flight_boost', function()
    flight.boostHeld = false
end, false)

RegisterKeyMapping(
    '+ob_curandeiras_flight_boost',
    'Aceleracao do voo da curandeira',
    'keyboard',
    'LSHIFT'
)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    if flight.active or flight.controller ~= 0 then
        finishFlight(true)
    else
        stopCamera()
        stopBoostDistortion()
        deleteController()
    end
    clearAllRemoteBoosts()
    remoteDiveStates = {}
    for serverId in pairs(remoteFlights) do
        detachRemoteFlight(serverId)
        remoteFlights[serverId] = nil
    end
end)
