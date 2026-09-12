local hypnosisCasting = false
local hypnosisAiming = false
local hypnosisAimSequence = 0
local hypnosisEndsAt = 0
local hypnosisThreadRunning = false
local frozenPlayerVehicles = {}
local npcHypnosis = {}
local headFxStates = {}

local function isHealerFlying()
    local state = LocalPlayer and LocalPlayer.state
    return state and state.obHealerFlight == true
end

local function normalize(value)
    local length = #(value)
    if length < 0.0001 then
        return vector3(0.0, 1.0, 0.0)
    end
    return value / length
end

local function rotationToDirection(rotation)
    local horizontal = math.cos(math.rad(rotation.x))
    return vector3(
        -math.sin(math.rad(rotation.z)) * horizontal,
        math.cos(math.rad(rotation.z)) * horizontal,
        math.sin(math.rad(rotation.x))
    )
end

local function getBeamPath(ped, maxDistance)
    local cameraCoords = GetGameplayCamCoord()
    local ray = ObVampiros.RaycastFromCamera(maxDistance, -1)
    local cameraDirection = ray and ray.direction
        or rotationToDirection(GetGameplayCamRot(2))
    cameraDirection = normalize(cameraDirection)

    local origin = GetPedBoneCoords(ped, 57005, 0.0, 0.0, 0.0)
    if #(origin - GetEntityCoords(ped)) > 2.0 then
        origin = GetEntityCoords(ped) + vector3(0.0, 0.0, 0.65)
    end

    local cameraTarget = cameraCoords + cameraDirection * maxDistance
    local impact = ray and ray.hit and ray.coords or cameraTarget
    local rayEntity = ray and ray.entity or 0
    if rayEntity ~= 0 and DoesEntityExist(rayEntity) and IsEntityAPed(rayEntity) then
        impact = cameraTarget
    end
    local direction = normalize(impact - origin)
    return origin + direction * 0.45, direction, impact
end

local function requestControl(entity, timeoutMs)
    if not DoesEntityExist(entity) or not NetworkGetEntityIsNetworked(entity) then
        return true
    end
    if NetworkHasControlOfEntity(entity) then
        return true
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    local expiresAt = GetGameTimer() + math.max(100, tonumber(timeoutMs) or 1000)
    NetworkRequestControlOfEntity(entity)
    NetworkRequestControlOfNetworkId(netId)
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < expiresAt do
        NetworkRequestControlOfEntity(entity)
        Wait(0)
    end
    return NetworkHasControlOfEntity(entity)
end

local function setParticleColour()
    local color = Config.Hypnosis.beamColor or { 1.0, 0.0, 0.015 }
    SetParticleFxNonLoopedColour(color[1] or 1.0, color[2] or 0.0, color[3] or 0.015)
end

local function emitProjectileFx(coords, scale)
    if not ObVampiros.EnsurePtfx('scr_powerplay') then return end
    UseParticleFxAssetNextCall('scr_powerplay')
    setParticleColour()
    StartParticleFxNonLoopedAtCoord(
        'sp_powerplay_beast_appear_trails',
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        scale, false, false, false
    )
end

local function emitImpactFx(coords)
    local baseScale = math.max(0.1, tonumber(Config.Hypnosis.beamFxScale) or 1.55)
    emitProjectileFx(coords, baseScale * 1.65)
    emitProjectileFx(coords + vector3(0.0, 0.0, 0.18), baseScale * 1.15)
end

local function stopHeadFx(ped, expectedState)
    local state = headFxStates[ped]
    if not state or (expectedState and state ~= expectedState) then return end

    headFxStates[ped] = nil
    for handle in pairs(state.handles or {}) do
        if DoesParticleFxLoopedExist(handle) then
            StopParticleFxLooped(handle, false)
        end
    end
    state.handles = {}
end

local function startHeadFx(ped, duration)
    if not DoesEntityExist(ped) then return end

    local endsAt = GetGameTimer() + math.max(1000, tonumber(duration) or 10000)
    local existing = headFxStates[ped]
    if existing then
        existing.endsAt = math.max(existing.endsAt, endsAt)
        return
    end
    if not ObVampiros.EnsurePtfx('scr_powerplay') then return end

    local config = Config.Hypnosis.headFx or {}
    local color = Config.Hypnosis.beamColor or { 1.0, 0.0, 0.015 }
    local state = { endsAt = endsAt, handles = {} }
    headFxStates[ped] = state

    CreateThread(function()
        while headFxStates[ped] == state
            and GetGameTimer() < state.endsAt
            and DoesEntityExist(ped)
            and not IsPedDeadOrDying(ped, true) do
            local angle = GetGameTimer() * (config.speed or 0.006)
            local radius = config.radius or 0.32
            local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
            local point = head + vector3(
                math.cos(angle) * radius,
                math.sin(angle) * radius,
                config.height or 0.12
            )
            UseParticleFxAssetNextCall('scr_powerplay')
            local handle = StartParticleFxLoopedAtCoord(
                'sp_powerplay_beast_appear_trails',
                point.x, point.y, point.z,
                0.0, 0.0, math.deg(angle) % 360.0,
                config.scale or 0.42,
                false, false, false, false
            )
            if handle and handle ~= 0 then
                SetParticleFxLoopedColour(
                    handle,
                    color[1] or 1.0, color[2] or 0.0, color[3] or 0.015,
                    false
                )
                SetParticleFxLoopedAlpha(handle, config.alpha or 0.9)
                state.handles[handle] = true
                local pulseHandle = handle
                CreateThread(function()
                    Wait(math.max(120, tonumber(config.pulseLife) or 380))
                    state.handles[pulseHandle] = nil
                    if DoesParticleFxLoopedExist(pulseHandle) then
                        StopParticleFxLooped(pulseHandle, false)
                    end
                end)
            end
            Wait(math.max(40, tonumber(config.pulseInterval) or 65))
        end
        stopHeadFx(ped, state)
    end)
end

ObVampiros.StartRedHeadAura = startHeadFx
ObVampiros.StopRedHeadAura = stopHeadFx

local function dot(left, right)
    return left.x * right.x + left.y * right.y + left.z * right.z
end

local function findPedInBeam(casterPed, from, to, width)
    local segment = to - from
    local length = #(segment)
    if length < 0.2 then return nil end

    local direction = segment / length
    local radius = math.max(0.1, width * 0.5)
    local bestPed, bestAlong, bestPoint = nil, length + 1.0, nil

    for _, entity in ipairs(GetGamePool('CPed')) do
        if entity ~= casterPed and DoesEntityExist(entity)
            and IsPedAPlayer(entity) and not IsPedDeadOrDying(entity, true) then
            local center = GetEntityCoords(entity) + vector3(0.0, 0.0, 0.75)
            local along = dot(center - from, direction)
            if along >= 0.0 and along <= length and along < bestAlong then
                local closest = from + direction * along
                if #(center - closest) <= radius
                    and HasEntityClearLosToEntity(casterPed, entity, 17) then
                    bestPed = entity
                    bestAlong = along
                    bestPoint = closest
                end
            end
        end
    end
    return bestPed, bestPoint
end

local function playBeamTrace(from, to)
    if not ObVampiros.EnsurePtfx('scr_powerplay') then return end

    local segment = to - from
    local length = #(segment)
    if length < 0.2 then return end

    local direction = segment / length
    local step = math.max(0.5, tonumber(Config.Hypnosis.beamStep) or 0.85)
    local scale = math.max(0.1, tonumber(Config.Hypnosis.beamFxScale) or 1.55)
    local life = math.max(100, tonumber(Config.Hypnosis.beamFxLife) or 320)
    local alpha = math.min(1.0, math.max(0.05, tonumber(Config.Hypnosis.beamAlpha) or 0.8))
    local color = Config.Hypnosis.beamColor or { 1.0, 0.0, 0.015 }
    local handles = {}
    local traveled = step * 0.45

    while traveled < length do
        local point = from + direction * traveled
        UseParticleFxAssetNextCall('scr_powerplay')
        local handle = StartParticleFxLoopedAtCoord(
            'sp_powerplay_beast_appear_trails',
            point.x, point.y, point.z,
            0.0, 0.0, 0.0,
            scale, false, false, false, false
        )
        if handle and handle ~= 0 then
            SetParticleFxLoopedColour(
                handle,
                color[1] or 1.0, color[2] or 0.0, color[3] or 0.015,
                false
            )
            SetParticleFxLoopedAlpha(handle, alpha)
            handles[#handles + 1] = handle
        end
        traveled = traveled + step
    end

    CreateThread(function()
        Wait(life)
        for i = 1, #handles do
            local handle = handles[i]
            if DoesParticleFxLoopedExist(handle) then
                StopParticleFxLooped(handle, false)
            end
        end
    end)
end

local function playCast(ped, target)
    TaskTurnPedToFaceCoord(ped, target.x, target.y, target.z, 350)
    if ObVampiros.EnsureAnim('misscarsteal4@actor') then
        TaskPlayAnim(
            ped, 'misscarsteal4@actor', 'actor_berating_loop',
            3.5, -3.5, math.max(650, Config.Hypnosis.castTime or 850),
            48, 0.0, false, false, false
        )
    end

    local coords = GetPedBoneCoords(ped, 57005, 0.0, 0.0, 0.0)
    emitProjectileFx(coords, (Config.Hypnosis.beamFxScale or 1.55) * 0.9)
end

local function applyNpcHypnosis(targetPed, duration)
    if not DoesEntityExist(targetPed) or IsPedDeadOrDying(targetPed, true) then
        return false
    end

    requestControl(targetPed, Config.Hypnosis.npcControlTimeout)
    local vehicle = GetVehiclePedIsIn(targetPed, false)
    if vehicle ~= 0 then
        requestControl(vehicle, Config.Hypnosis.npcControlTimeout)
        FreezeEntityPosition(vehicle, true)
    end

    local now = GetGameTimer()
    local state = npcHypnosis[targetPed]
    local alreadyActive = state ~= nil
    if state then
        state.endsAt = math.max(
            state.endsAt,
            now + math.max(1000, tonumber(duration) or 10000)
        )
        if vehicle ~= 0 then state.vehicle = vehicle end
    else
        state = {
            endsAt = now + math.max(1000, tonumber(duration) or 10000),
            vehicle = vehicle,
        }
        npcHypnosis[targetPed] = state
    end

    ClearPedTasksImmediately(targetPed)
    SetBlockingOfNonTemporaryEvents(targetPed, true)
    TaskStandStill(targetPed, -1)
    FreezeEntityPosition(targetPed, true)
    startHeadFx(targetPed, duration)

    if alreadyActive then return true end

    CreateThread(function()
        while npcHypnosis[targetPed]
            and GetGameTimer() < npcHypnosis[targetPed].endsAt
            and DoesEntityExist(targetPed)
            and not IsPedDeadOrDying(targetPed, true) do
            FreezeEntityPosition(targetPed, true)
            Wait(100)
        end

        local finalState = npcHypnosis[targetPed]
        npcHypnosis[targetPed] = nil
        stopHeadFx(targetPed)
        if DoesEntityExist(targetPed) then
            FreezeEntityPosition(targetPed, false)
            SetBlockingOfNonTemporaryEvents(targetPed, false)
            ClearPedTasks(targetPed)
        end
        local finalVehicle = finalState and finalState.vehicle or 0
        if finalVehicle ~= 0 and DoesEntityExist(finalVehicle) then
            FreezeEntityPosition(finalVehicle, false)
        end
    end)
    return true
end

local function resolvePedHit(targetPed, castResult)
    local token = castResult.token
    local duration = math.max(1000, tonumber(castResult.duration) or Config.Hypnosis.duration or 10000)
    if not IsPedAPlayer(targetPed) then
        TriggerServerEvent('ob_vampiros:server:finishHypnosis', token)
        return false, 'A hipnose so pode atingir outro jogador.'
    end

    local playerIndex = NetworkGetPlayerIndexFromPed(targetPed)
    if playerIndex == -1 then
        TriggerServerEvent('ob_vampiros:server:finishHypnosis', token)
        return false, 'O alvo nao esta disponivel.'
    end

    local ok, result = pcall(function()
        return lib.callback.await(
            'ob_vampiros:server:hitHypnosis', false,
            token, GetPlayerServerId(playerIndex)
        )
    end)
    if not ok or type(result) ~= 'table' then
        return false, 'A hipnose se dissipou antes de atingir o alvo.'
    end
    return result.success == true, result.message
end

local function clearAimUi()
    ObVampiros.SetPowerCrosshair(false)
    ObVampiros.UpdateAbility('hipnose', { selected = false })
end

local function cancelHypnosisAim()
    hypnosisAimSequence = hypnosisAimSequence + 1
    hypnosisAiming = false
    clearAimUi()
end

local function executeHypnosisCast(origin, impact)
    local ok, result = pcall(function()
        return lib.callback.await('ob_vampiros:server:beginHypnosis', false)
    end)
    if not ok or type(result) ~= 'table' or result.success ~= true then
        ObVampiros.FailAbility('hipnose', type(result) == 'table' and result.message or nil)
        clearAimUi()
        hypnosisCasting = false
        return
    end

    local ped = PlayerPedId()
    local castTime = math.max(0, tonumber(Config.Hypnosis.castTime) or 850)
    ObVampiros.StartCooldown('hipnose', Config.Hypnosis.cooldown)
    playCast(ped, impact)

    local castEndsAt = GetGameTimer() + castTime
    while GetGameTimer() < castEndsAt and DoesEntityExist(ped) and not IsEntityDead(ped) do
        DisablePlayerFiring(PlayerId(), true)
        DisableControlAction(0, 21, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        Wait(0)
    end

    if not DoesEntityExist(ped) or IsEntityDead(ped) then
        TriggerServerEvent('ob_vampiros:server:finishHypnosis', result.token)
        clearAimUi()
        hypnosisCasting = false
        return
    end

    local targetPed, hitPoint = findPedInBeam(
        ped, origin, impact,
        math.max(0.1, tonumber(Config.Hypnosis.beamWidth) or 5.0)
    )
    local visualEnd = hitPoint or impact
    playBeamTrace(origin, visualEnd)

    if targetPed then
        emitImpactFx(GetEntityCoords(targetPed) + vector3(0.0, 0.0, 0.75))
        local applied, failureMessage = resolvePedHit(targetPed, result)
        if not applied then
            ObVampiros.FailAbility('hipnose', failureMessage)
        end
    else
        emitImpactFx(visualEnd)
        TriggerServerEvent('ob_vampiros:server:finishHypnosis', result.token)
    end

    clearAimUi()
    hypnosisCasting = false
end

local function clearPlayerHypnosis()
    hypnosisEndsAt = 0
    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        FreezeEntityPosition(ped, false)
        if isHealerFlying() then
            SetEntityCollision(ped, false, false)
            SetEntityHasGravity(ped, false)
            SetPedCanRagdoll(ped, false)
        else
            SetPedCanRagdoll(ped, true)
        end
    end
    stopHeadFx(ped)
    for vehicle in pairs(frozenPlayerVehicles) do
        if DoesEntityExist(vehicle) then
            FreezeEntityPosition(vehicle, false)
        end
    end
    frozenPlayerVehicles = {}
    AnimpostfxStop('DrugsTrevorClownsFight')
    TriggerScreenblurFadeOut(350.0)
    ClearTimecycleModifier()
end

RegisterNetEvent('ob_vampiros:client:hipnose', function()
    if hypnosisAiming then
        cancelHypnosisAim()
        return
    end

    if hypnosisCasting or not ObVampiros.IsVampire() or ObVampiros.IsPowerBlocked()
        or IsEntityDead(PlayerPedId()) or IsPedInAnyVehicle(PlayerPedId(), false) then
        ObVampiros.FailAbility('hipnose')
        return
    end

    hypnosisAimSequence = hypnosisAimSequence + 1
    local sequence = hypnosisAimSequence
    hypnosisAiming = true
    ObVampiros.UpdateAbility('hipnose', { selected = true })
    ObVampiros.SetPowerCrosshair(true, {
        distance = math.max(1.0, tonumber(Config.Hypnosis.distance) or 40.0),
        label = 'CLIQUE PARA HIPNOTIZAR',
        targetLabel = 'ALVO HIPNOTICO',
    })

    CreateThread(function()
        while hypnosisAiming and sequence == hypnosisAimSequence do
            local ped = PlayerPedId()
            if not ObVampiros.IsVampire() or ObVampiros.IsPowerBlocked()
                or IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then
                cancelHypnosisAim()
                return
            end

            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)

            if IsDisabledControlJustReleased(0, 25) or IsControlJustReleased(0, 177) then
                cancelHypnosisAim()
                return
            end

            if IsDisabledControlJustReleased(0, 24) then
                local distance = math.max(1.0, tonumber(Config.Hypnosis.distance) or 40.0)
                local origin, _, impact = getBeamPath(ped, distance)
                hypnosisAiming = false
                hypnosisCasting = true
                executeHypnosisCast(origin, impact)
                return
            end

            Wait(0)
        end
    end)
end)

RegisterNetEvent('ob_vampiros:client:applyHypnosis', function(duration)
    duration = math.max(1000, tonumber(duration) or 10000)
    hypnosisEndsAt = math.max(hypnosisEndsAt, GetGameTimer() + duration)

    local ped = PlayerPedId()
    if isHealerFlying() then
        FreezeEntityPosition(ped, false)
        SetPedCanRagdoll(ped, false)
    else
        ClearPedTasksImmediately(ped)
        TaskStandStill(ped, duration)
    end
    startHeadFx(ped, duration)

    if hypnosisThreadRunning then return end
    hypnosisThreadRunning = true
    AnimpostfxStop('DrugsTrevorClownsFight')
    AnimpostfxPlay('DrugsTrevorClownsFight', 0, true)
    TriggerScreenblurFadeIn(300.0)
    SetTimecycleModifier('spectator5')
    SetTimecycleModifierStrength(
        math.min(1.0, math.max(0.0, tonumber(Config.Hypnosis.blurStrength) or 0.62))
    )

    CreateThread(function()
        while GetGameTimer() < hypnosisEndsAt do
            local currentPed = PlayerPedId()
            if not DoesEntityExist(currentPed) or IsEntityDead(currentPed) then break end

            local healerFlying = isHealerFlying()
            FreezeEntityPosition(currentPed, not healerFlying)
            SetPedCanRagdoll(currentPed, false)
            local vehicle = GetVehiclePedIsIn(currentPed, false)
            if vehicle ~= 0 then
                frozenPlayerVehicles[vehicle] = true
                FreezeEntityPosition(vehicle, true)
            end

            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            EnableControlAction(0, 200, true)
            EnableControlAction(0, 245, true)
            Wait(0)
        end

        clearPlayerHypnosis()
        hypnosisThreadRunning = false
    end)
end)

RegisterNetEvent('ob_vampiros:client:showHypnosisHeadFx', function(targetSource, duration)
    local playerIndex = GetPlayerFromServerId(tonumber(targetSource) or -1)
    if playerIndex == -1 then return end

    local targetPed = GetPlayerPed(playerIndex)
    if targetPed ~= 0 and DoesEntityExist(targetPed) then
        startHeadFx(targetPed, duration)
    end
end)

RegisterNetEvent('ob_vampiros:client:showRedHeadAura', function(targetSource, duration)
    local playerIndex = GetPlayerFromServerId(tonumber(targetSource) or -1)
    if playerIndex == -1 then return end

    local targetPed = GetPlayerPed(playerIndex)
    if targetPed ~= 0 and DoesEntityExist(targetPed) then
        startHeadFx(targetPed, duration)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    hypnosisAimSequence = hypnosisAimSequence + 1
    hypnosisAiming = false
    hypnosisCasting = false
    ObVampiros.SetPowerCrosshair(false)
    ObVampiros.UpdateAbility('hipnose', { selected = false })
    clearPlayerHypnosis()
    for ped, state in pairs(npcHypnosis) do
        if DoesEntityExist(ped) then
            FreezeEntityPosition(ped, false)
            SetBlockingOfNonTemporaryEvents(ped, false)
        end
        local vehicle = state.vehicle or 0
        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            FreezeEntityPosition(vehicle, false)
        end
    end
    npcHypnosis = {}
    local trackedPeds = {}
    for ped in pairs(headFxStates) do
        trackedPeds[#trackedPeds + 1] = ped
    end
    for i = 1, #trackedPeds do
        stopHeadFx(trackedPeds[i])
    end
end)
