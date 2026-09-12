local embraceToken = 0
local activePumaTarget = 0

local function distributedChunk(total, index, ticks)
    total = math.max(0, math.floor((tonumber(total) or 0) + 0.5))
    ticks = math.max(1, math.floor(tonumber(ticks) or 1))
    return math.floor(total * index / ticks) - math.floor(total * (index - 1) / ticks)
end

local function blockEmbraceControls()
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
    DisableControlAction(0, 140, true)
    DisableControlAction(0, 141, true)
    DisableControlAction(0, 142, true)
end

local function waitBlocked(duration)
    local endsAt = GetGameTimer() + math.max(0, tonumber(duration) or 0)
    while GetGameTimer() < endsAt do
        blockEmbraceControls()
        Wait(0)
    end
end

local function playChannelAnimation(ped, role, duration)
    local biteAnimation = ObVampiros.BiteAnimation
    if biteAnimation and biteAnimation.Play(ped, role, duration) then
        return
    end

    local dict, animation
    if role == 'caster' then
        dict, animation = 'misscarsteal4@actor', 'actor_berating_loop'
    else
        dict, animation = 'amb@world_human_bum_standing@drunk@idle_a', 'idle_b'
    end

    if ObVampiros.EnsureAnim(dict) then
        TaskPlayAnim(ped, dict, animation, 3.5, -3.5, duration, 1, 0.0, false, false, false)
    end
end

local function beginLocalEmbrace(role, otherSource, duration, syncedApproachDuration)
    embraceToken = embraceToken + 1
    local token = embraceToken
    local ped = PlayerPedId()
    local playerIndex = GetPlayerFromServerId(tonumber(otherSource) or -1)
    local otherPed = playerIndex ~= -1 and GetPlayerPed(playerIndex) or 0
    duration = math.max(1500, tonumber(duration) or Config.NightEmbrace.channelDuration)

    local biteAnimation = ObVampiros.BiteAnimation
    local approachDuration = biteAnimation
        and biteAnimation.GetApproachDuration(ped, otherPed, syncedApproachDuration)
        or 0
    local alignmentDelay = biteAnimation and biteAnimation.GetAlignmentDelay() or 0
    if role == 'caster' and ObVampiros.StartRedHeadAura then
        ObVampiros.StartRedHeadAura(ped, duration + approachDuration + alignmentDelay)
    end

    CreateThread(function()
        if otherPed ~= 0 and DoesEntityExist(otherPed) then
            if biteAnimation then
                if role == 'caster' then
                    biteAnimation.Approach(ped, otherPed, approachDuration)
                    biteAnimation.Prepare(ped, role, otherPed)
                else
                    biteAnimation.Prepare(ped, role, otherPed)
                    waitBlocked(approachDuration)
                end
            else
                TaskTurnPedToFaceEntity(ped, otherPed, 600)
            end
        end

        FreezeEntityPosition(ped, true)
        waitBlocked(alignmentDelay)
        playChannelAnimation(ped, role, duration)
        local endsAt = GetGameTimer() + duration
        while token == embraceToken and GetGameTimer() < endsAt do
            blockEmbraceControls()
            Wait(0)
        end
        if biteAnimation then
            biteAnimation.Release(PlayerPedId(), role)
        else
            FreezeEntityPosition(PlayerPedId(), false)
            ClearPedTasks(PlayerPedId())
        end
        if role == 'target' and biteAnimation then
            biteAnimation.ApplyAftermath(PlayerPedId())
        end
    end)
end

RegisterNetEvent('ob_vampiros:client:beginEmbrace', beginLocalEmbrace)

RegisterNetEvent('ob_vampiros:client:applyDrainHeal', function(amount)
    amount = math.max(0, math.floor((tonumber(amount) or 0) + 0.5))
    if amount <= 0 then return end

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) then return end

    local health = GetEntityHealth(ped)
    local maximum = GetEntityMaxHealth(ped)
    SetEntityHealth(ped, math.min(maximum, health + amount))
end)

lib.callback.register('ob_vampiros:client:applyDrainDamage', function(amount, minimumHealth)
    amount = math.max(0, math.floor((tonumber(amount) or 0) + 0.5))
    minimumHealth = math.max(1, math.floor((tonumber(minimumHealth) or 1) + 0.5))
    if amount <= 0 then return 0 end

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) then return 0 end

    local health = GetEntityHealth(ped)
    local drained = math.min(math.max(0, health - minimumHealth), amount)
    if drained <= 0 then return 0 end

    SetEntityHealth(ped, health - drained)
    return drained
end)

local function requestEntityControl(entity)
    if not NetworkGetEntityIsNetworked(entity) or NetworkHasControlOfEntity(entity) then
        return true
    end

    local timeout = GetGameTimer() + (Config.NightEmbrace.npcControlTimeout or 1200)
    NetworkRequestControlOfEntity(entity)
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(entity)
        Wait(0)
    end
    return NetworkHasControlOfEntity(entity)
end

local function gripConfig()
    return Config.NightEmbrace.pumaGrip or {}
end

local function attachPumaForBite(caster, targetPed)
    if not DoesEntityExist(caster) or not ObVampiros.IsFarmPuma(targetPed) then return false end

    local grip = gripConfig()
    local offset = grip.offset or {}
    local rotation = grip.rotation or {}
    local boneId = math.floor(tonumber(grip.bone) or 0)
    local bone = boneId == 0 and 0 or GetPedBoneIndex(caster, boneId)

    SetPedCanRagdoll(targetPed, true)
    FreezeEntityPosition(targetPed, false)
    SetEntityHasGravity(targetPed, true)
    SetEntityCollision(targetPed, false, false)
    SetPedToRagdoll(
        targetPed,
        math.max(1000, tonumber(Config.NightEmbrace.channelDuration) or 7000) + 1000,
        math.max(1000, tonumber(Config.NightEmbrace.channelDuration) or 7000) + 1000,
        0,
        false,
        false,
        false
    )
    Wait(math.max(50, math.floor(tonumber(grip.ragdollDelay) or 180)))

    AttachEntityToEntity(
        targetPed,
        caster,
        bone,
        tonumber(offset.x) or 0.28,
        tonumber(offset.y) or 0.34,
        tonumber(offset.z) or -0.02,
        tonumber(rotation.x) or 0.0,
        tonumber(rotation.y) or 0.0,
        tonumber(rotation.z) or 90.0,
        false,
        false,
        false,
        true,
        2,
        true
    )
    local attached = IsEntityAttachedToEntity(targetPed, caster)
    if not attached and DoesEntityExist(targetPed) then
        SetEntityCollision(targetPed, true, true)
        SetEntityHasGravity(targetPed, true)
        FreezeEntityPosition(targetPed, true)
    end
    return attached
end

local function safePumaDropPosition(caster, targetPed)
    local grip = gripConfig()
    local origin = GetEntityCoords(caster)
    local forward = GetEntityForwardVector(caster)
    local right = vector3(forward.y, -forward.x, 0.0)
    local forwardDistance = math.max(0.8, tonumber(grip.dropForward) or 1.25)
    local sideDistance = tonumber(grip.dropSide) or 0.65
    local x = origin.x + forward.x * forwardDistance + right.x * sideDistance
    local y = origin.y + forward.y * forwardDistance + right.y * sideDistance

    RequestCollisionAtCoord(x, y, origin.z)
    local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, origin.z + 20.0, false)
    if not foundGround then
        groundZ = origin.z
    end

    local minimum = GetModelDimensions(GetEntityModel(targetPed))
    local bottomOffset = minimum and minimum.z and math.max(0.0, -minimum.z) or 0.55
    local clearance = math.max(0.03, tonumber(grip.dropClearance) or 0.08)
    return vector3(x, y, groundZ + bottomOffset + clearance)
end

local function releasePumaAfterBite(caster, targetPed, biteAnimation, resumeAi)
    if not targetPed or targetPed == 0 or not DoesEntityExist(targetPed) then return end

    local dropPosition = safePumaDropPosition(caster, targetPed)
    SetEntityCollision(targetPed, false, false)
    FreezeEntityPosition(targetPed, true)
    SetEntityHasGravity(targetPed, false)
    DetachEntity(targetPed, true, true)
    SetEntityCoordsNoOffset(
        targetPed,
        dropPosition.x,
        dropPosition.y,
        dropPosition.z,
        false,
        false,
        false
    )
    SetEntityHeading(targetPed, (GetEntityHeading(caster) + 90.0) % 360.0)
    SetEntityVelocity(targetPed, 0.0, 0.0, 0.0)

    if biteAnimation then
        biteAnimation.Release(targetPed, 'target')
    else
        DetachEntity(targetPed, true, true)
        FreezeEntityPosition(targetPed, false)
        SetEntityCollision(targetPed, true, true)
        SetEntityHasGravity(targetPed, true)
        SetPedCanRagdoll(targetPed, true)
    end

    if IsPedDeadOrDying(targetPed, true) then return end

    local releaseDuration = math.max(400, math.floor(tonumber(gripConfig().releaseRagdoll) or 1400))
    SetEntityVelocity(targetPed, 0.0, 0.0, -0.15)
    SetPedToRagdoll(targetPed, releaseDuration, releaseDuration, 0, false, false, false)
    if resumeAi ~= true then return end

    CreateThread(function()
        Wait(releaseDuration)
        if DoesEntityExist(targetPed) and not IsPedDeadOrDying(targetPed, true) then
            ClearPedTasks(targetPed)
            TaskWanderStandard(targetPed, 10.0, 10)
        end
    end)
end

local function drainPuma(targetPed, session)
    if not ObVampiros.IsFarmPuma(targetPed) or IsPedDeadOrDying(targetPed, true)
        or not requestEntityControl(targetPed) then
        return false
    end

    local caster = PlayerPedId()
    local duration = math.max(1500, tonumber(session.duration) or 6000)
    local ticks = math.max(1, math.floor(tonumber(session.ticks) or 10))
    local interval = math.max(100, math.floor(duration / ticks))
    local completedTicks = 0
    activePumaTarget = targetPed
    FreezeEntityPosition(targetPed, true)

    local biteAnimation = ObVampiros.BiteAnimation
    if biteAnimation then
        local approachDuration = biteAnimation.GetApproachDuration(caster, targetPed)
        biteAnimation.Prepare(targetPed, 'target', caster)
        if ObVampiros.StartRedHeadAura then
            ObVampiros.StartRedHeadAura(
                caster,
                duration + approachDuration + biteAnimation.GetAlignmentDelay()
            )
        end
        biteAnimation.Approach(caster, targetPed, approachDuration, { keepAboveGround = true })
        biteAnimation.Prepare(caster, 'caster', targetPed)
    else
        TaskTurnPedToFaceEntity(caster, targetPed, 600)
        if ObVampiros.StartRedHeadAura then
            ObVampiros.StartRedHeadAura(caster, duration)
        end
    end
    FreezeEntityPosition(caster, true)
    if biteAnimation then
        waitBlocked(biteAnimation.GetAlignmentDelay())
    end
    attachPumaForBite(caster, targetPed)
    playChannelAnimation(caster, 'caster', duration)
    local nextTickAt = GetGameTimer() + interval
    local endsAt = GetGameTimer() + duration + 500

    while completedTicks < ticks and GetGameTimer() < endsAt
        and ObVampiros.IsFarmPuma(targetPed) and not IsPedDeadOrDying(targetPed, true) do
        blockEmbraceControls()

        if GetGameTimer() >= nextTickAt then
            local tick = completedTicks + 1
            local health = GetEntityHealth(targetPed)
            local damage = distributedChunk(
                tonumber(session.drainAmount) or Config.NightEmbrace.drainAmount,
                tick,
                ticks
            )
            local drained = math.min(math.max(0, health - 1), damage)
            if drained <= 0 then break end

            SetEntityHealth(targetPed, health - drained)
            local ok, result = pcall(function()
                return lib.callback.await(
                    'ob_vampiros:server:pumaEmbraceTick', false,
                    session.token, tick
                )
            end)
            if not ok or type(result) ~= 'table' or result.success ~= true then break end

            completedTicks = tick
            nextTickAt = nextTickAt + interval
        end
        Wait(0)
    end

    TriggerServerEvent('ob_vampiros:server:finishPumaEmbrace', session.token)
    if biteAnimation then
        biteAnimation.Release(caster, 'caster')
    else
        FreezeEntityPosition(caster, false)
        ClearPedTasks(caster)
    end
    if DoesEntityExist(targetPed) then
        releasePumaAfterBite(caster, targetPed, biteAnimation, true)
    end
    activePumaTarget = 0
    return completedTicks > 0
end

local function usePumaEmbrace(targetPed)
    if Config.NightEmbrace.allowFarmPumaTarget ~= true
        or not ObVampiros.IsFarmPuma(targetPed) or IsPedDeadOrDying(targetPed, true)
        or not requestEntityControl(targetPed) then
        ObVampiros.FailAbility('abraco_noite', 'A habilidade 4 so pode atingir jogadores ou oncas do farm.')
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(targetPed)
    if not netId or netId <= 0 then
        ObVampiros.FailAbility('abraco_noite', 'Nao foi possivel identificar esta onca.')
        return
    end

    local ok, session = pcall(function()
        return lib.callback.await('ob_vampiros:server:beginPumaEmbrace', false, netId)
    end)
    if not ok or type(session) ~= 'table' or session.success ~= true then
        ObVampiros.FailAbility('abraco_noite')
        return
    end

    ObVampiros.StartCooldown('abraco_noite', Config.NightEmbrace.cooldown)
    if not drainPuma(targetPed, session) then
        ObVampiros.FailAbility('abraco_noite')
    end
end

local function usePlayerEmbrace(targetSource, mode)
    local ok, result = pcall(function()
        return lib.callback.await('ob_vampiros:server:useEmbrace', false, targetSource, mode or 'drain')
    end)
    if not ok or type(result) ~= 'table' or result.success ~= true then
        ObVampiros.FailAbility('abraco_noite')
        return
    end
    ObVampiros.StartCooldown('abraco_noite', Config.NightEmbrace.cooldown)
end

RegisterNetEvent('ob_vampiros:client:abracoNoite', function()
    if not ObVampiros.IsVampire() or ObVampiros.IsPowerBlocked() then
        ObVampiros.FailAbility('abraco_noite')
        return
    end

    CreateThread(function()
        local targetSource, targetPed = ObVampiros.AwaitTarget(
            'abraco_noite', 'DRENAR', Config.NightEmbrace.distance, 10000
        )
        if not targetSource then
            ObVampiros.FailAbility('abraco_noite')
            return
        end

        if targetSource == 0 then
            usePumaEmbrace(targetPed)
        elseif not Config.NightEmbrace.transformationEnabled then
            usePlayerEmbrace(targetSource, 'drain')
        else
            lib.registerContext({
                id = 'ob_vampiros_embrace',
                title = 'Abraco da Noite',
                options = {
                    {
                        title = 'Drenar energia vital',
                        icon = 'droplet',
                        onSelect = function()
                            CreateThread(function() usePlayerEmbrace(targetSource, 'drain') end)
                        end,
                    },
                    {
                        title = 'Transformar em vampiro',
                        description = 'Acao de lore protegida por permissao ACE.',
                        icon = 'moon',
                        onSelect = function()
                            CreateThread(function() usePlayerEmbrace(targetSource, 'transform') end)
                        end,
                    },
                },
            })
            lib.showContext('ob_vampiros_embrace')
        end
    end)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    embraceToken = embraceToken + 1
    local ped = PlayerPedId()
    if ObVampiros.BiteAnimation then
        ObVampiros.BiteAnimation.Release(ped, 'target')
        ObVampiros.BiteAnimation.StopAllApproachFx()
    else
        FreezeEntityPosition(ped, false)
        ClearPedTasks(ped)
    end
    if activePumaTarget ~= 0 and DoesEntityExist(activePumaTarget) then
        releasePumaAfterBite(PlayerPedId(), activePumaTarget, ObVampiros.BiteAnimation, false)
    end
    activePumaTarget = 0
end)
