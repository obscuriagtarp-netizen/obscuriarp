local eloPending = false
local eloChannelToken = 0
local eloChanneling = false
local eloSelecting = false
local eloSelectionToken = 0
local eloRequestToken = 0

local function rotationToDirection(rotation)
    local radiansZ = math.rad(rotation.z)
    local radiansX = math.rad(rotation.x)
    local horizontal = math.abs(math.cos(radiansX))
    return vector3(-math.sin(radiansZ) * horizontal, math.cos(radiansZ) * horizontal, math.sin(radiansX))
end

local function getPlayerUnderCrosshair(maxDistance)
    local magicRay = ObBruxas.RaycastFromCamera(maxDistance, -1)
    local magicEntity = magicRay and magicRay.entity or 0
    if magicEntity ~= 0 and DoesEntityExist(magicEntity) and IsEntityAPed(magicEntity) and IsPedAPlayer(magicEntity) then
        local magicPlayer = NetworkGetPlayerIndexFromPed(magicEntity)
        if magicPlayer ~= -1 and magicPlayer ~= PlayerId() then
            return GetPlayerServerId(magicPlayer), magicEntity
        end
    end

    local cameraCoords = GetGameplayCamCoord()
    local direction = rotationToDirection(GetGameplayCamRot(2))
    local destination = cameraCoords + (direction * maxDistance)
    local ray = StartShapeTestLosProbe(
        cameraCoords.x, cameraCoords.y, cameraCoords.z,
        destination.x, destination.y, destination.z,
        12, PlayerPedId(), 7
    )
    local _, hit, _, _, entity = GetShapeTestResult(ray)

    if hit == 1 and entity and entity ~= 0 and IsEntityAPed(entity) and IsPedAPlayer(entity) then
        local player = NetworkGetPlayerIndexFromPed(entity)
        if player ~= -1 and player ~= PlayerId() then
            return GetPlayerServerId(player), entity
        end
    end

    local bestPlayer, bestPed, bestScreenDistance = nil, nil, 0.075
    local nearbyPlayers = lib.getNearbyPlayers(GetEntityCoords(PlayerPedId()), maxDistance, false) or {}
    for index = 1, #nearbyPlayers do
        local nearby = nearbyPlayers[index]
        local player = tonumber(nearby.id)
        local ped = tonumber(nearby.ped) or (player and GetPlayerPed(player)) or 0
        if player and ped ~= 0 and DoesEntityExist(ped) then
            local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
            local visible, screenX, screenY = World3dToScreen2d(head.x, head.y, head.z)
            if visible and HasEntityClearLosToEntity(PlayerPedId(), ped, 17) then
                local screenDistance = math.sqrt(((screenX - 0.5) ^ 2) + ((screenY - 0.5) ^ 2))
                if screenDistance < bestScreenDistance then
                    bestScreenDistance = screenDistance
                    bestPlayer = GetPlayerServerId(player)
                    bestPed = ped
                end
            end
        end
    end

    return bestPlayer, bestPed
end

local function playEloFx(targetSource, duration)
    local player = GetPlayerFromServerId(tonumber(targetSource) or -1)
    if player == -1 or GetResourceState('magicSpells') ~= 'started' then return end

    local target = GetPlayerPed(player)
    if not DoesEntityExist(target) then return end

    local fx = (Config.EloArcano and Config.EloArcano.fx) or {}
    pcall(function()
        exports.magicSpells:PlayVitaeFxOnEntity(target, duration, fx.palette)
    end)
end

local function stopSelection()
    if not eloSelecting then return end

    eloSelecting = false
    eloSelectionToken = eloSelectionToken + 1
    ObBruxas.SetPowerCrosshair(false)
    ObBruxas.UpdateAbility('elo_arcano', { selected = false })
end

local function releaseCaster()
    ObBruxas.SetPowerCrosshair(false)
    ObBruxas.SetCrosshairCharge(false)

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    ClearPedSecondaryTask(ped)

    if GetResourceState('magicSpells') == 'started' then
        pcall(function()
            exports.magicSpells:RefreshCrosshair()
        end)
    end
end

local function requestElo(targetSource)
    if eloPending or eloChanneling then return end

    eloSelecting = false
    eloSelectionToken = eloSelectionToken + 1
    ObBruxas.SetPowerCrosshair(false)

    eloPending = true
    eloRequestToken = eloRequestToken + 1
    local requestToken = eloRequestToken
    local config = Config.EloArcano or {}
    local castTime = math.max(0, tonumber(config.castTime) or 2200)
    local ped = PlayerPedId()
    local targetPlayer = GetPlayerFromServerId(tonumber(targetSource) or -1)

    if targetPlayer ~= -1 and targetPlayer ~= PlayerId() then
        local targetPed = GetPlayerPed(targetPlayer)
        if DoesEntityExist(targetPed) then
            local from = GetEntityCoords(ped)
            local to = GetEntityCoords(targetPed)
            SetEntityHeading(ped, GetHeadingFromVector_2d(to.x - from.x, to.y - from.y))
        end
    end

    FreezeEntityPosition(ped, true)

    local animation = config.animation or {}
    if animation.dict and animation.name and ObBruxas.EnsureAnim(animation.dict) then
        TaskPlayAnim(
            ped,
            animation.dict,
            animation.name,
            4.0, -4.0,
            castTime,
            animation.flag or 33,
            0.0,
            false, false, false
        )
    end

    ObBruxas.SetCrosshairCharge(true, castTime, 'elo_arcano')

    CreateThread(function()
        local castEndsAt = GetGameTimer() + castTime

        while eloPending
            and requestToken == eloRequestToken
            and GetGameTimer() < castEndsAt do
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 75, true)

            if IsEntityDead(ped) or not ObBruxas.IsWitch() or ObBruxas.IsPowerBlocked() then
                eloPending = false
                eloRequestToken = eloRequestToken + 1
                releaseCaster()
                ObBruxas.UpdateAbility('elo_arcano', { selected = false })
                ObBruxas.FailAbility('elo_arcano')
                return
            end

            Wait(0)
        end

        if not eloPending or requestToken ~= eloRequestToken then return end

        ClearPedSecondaryTask(ped)
        FreezeEntityPosition(ped, false)
        ObBruxas.SetCrosshairCharge(false)
        TriggerServerEvent('ob_bruxas:server:startElo', targetSource)

        SetTimeout(3000, function()
            if eloPending and requestToken == eloRequestToken and not eloChanneling then
                eloPending = false
                eloRequestToken = eloRequestToken + 1
                releaseCaster()
                ObBruxas.UpdateAbility('elo_arcano', { selected = false })
                ObBruxas.FailAbility('elo_arcano')
            end
        end)
    end)
end

local function stopChannel(silent)
    releaseCaster()

    if not eloChanneling then
        return
    end

    eloChannelToken = eloChannelToken + 1
    eloChanneling = false
    ObBruxas.UpdateAbility('elo_arcano', { selected = false })

    if not silent then
        ObBruxas.Notify('Elo Arcano', 'A canalizacao foi encerrada.', 'inform', 2500)
    end
end

RegisterNetEvent('ob_bruxas:client:eloArcano', function()
    if eloSelecting then
        stopSelection()
        return
    end

    if eloPending or eloChanneling or not ObBruxas.IsWitch() or ObBruxas.IsPowerBlocked() then
        ObBruxas.SetPowerCrosshair(false)
        ObBruxas.ClearSelection()
        ObBruxas.FailAbility('elo_arcano')
        return
    end

    eloSelecting = true
    eloSelectionToken = eloSelectionToken + 1
    local selectionToken = eloSelectionToken
    ObBruxas.UpdateAbility('elo_arcano', { selected = true })
    ObBruxas.SetPowerCrosshair(true, {
        distance = Config.EloArcano.targetDistance,
        label = 'ESQ: ALIADO | DIR: VOCE',
        targetLabel = 'ESQ: CANALIZAR ALIADO',
    })

    CreateThread(function()
        local expiresAt = GetGameTimer() + 12000

        while eloSelecting
            and selectionToken == eloSelectionToken
            and GetGameTimer() < expiresAt do
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 142, true)

            if IsDisabledControlJustPressed(0, 25) then
                requestElo(GetPlayerServerId(PlayerId()))
                return
            end

            if IsDisabledControlJustPressed(0, 24) then
                local targetSource = getPlayerUnderCrosshair(Config.EloArcano.targetDistance)
                if targetSource then
                    requestElo(targetSource)
                    return
                end

                ObBruxas.FailAbility('elo_arcano')
            elseif IsControlJustPressed(0, 177) then
                stopSelection()
                return
            end

            if not ObBruxas.IsWitch() or ObBruxas.IsPowerBlocked() then
                stopSelection()
                return
            end

            Wait(0)
        end

        if eloSelecting and selectionToken == eloSelectionToken then
            stopSelection()
        end
    end)
end)

RegisterNetEvent('ob_bruxas:client:eloDenied', function(message)
    eloPending = false
    eloRequestToken = eloRequestToken + 1
    releaseCaster()
    ObBruxas.UpdateAbility('elo_arcano', { selected = false })
    ObBruxas.FailAbility('elo_arcano')
    if message then
        ObBruxas.Notify('Elo Arcano', message, 'error')
    end
end)

RegisterNetEvent('ob_bruxas:client:eloStarted', function(targetSource, duration, isSelf)
    eloPending = false
    eloRequestToken = eloRequestToken + 1
    eloSelecting = false
    eloSelectionToken = eloSelectionToken + 1
    eloChannelToken = eloChannelToken + 1
    local token = eloChannelToken
    eloChanneling = true
    ObBruxas.SetPowerCrosshair(false)

    local ped = PlayerPedId()
    local targetPlayer = GetPlayerFromServerId(tonumber(targetSource) or -1)
    if targetPlayer ~= -1 and targetPlayer ~= PlayerId() then
        local targetPed = GetPlayerPed(targetPlayer)
        local from = GetEntityCoords(ped)
        local to = GetEntityCoords(targetPed)
        SetEntityHeading(ped, GetHeadingFromVector_2d(to.x - from.x, to.y - from.y))
    end

    FreezeEntityPosition(ped, false)
    ObBruxas.StartCooldown('elo_arcano', Config.EloArcano.cooldown)
    ObBruxas.Notify(
        'Elo Arcano',
        isSelf and 'Permaneca imovel para restaurar sua mana.' or 'Permaneca imovel para fortalecer a recuperacao do aliado.',
        'success'
    )

    CreateThread(function()
        local endAt = GetGameTimer() + duration
        while eloChanneling and token == eloChannelToken and GetGameTimer() < endAt do
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)

            if IsEntityDead(PlayerPedId()) then
                TriggerServerEvent('ob_bruxas:server:cancelElo')
                stopChannel(true)
                return
            end
            Wait(0)
        end

        if token == eloChannelToken then
            stopChannel(true)
        end
    end)
end)

RegisterNetEvent('ob_bruxas:client:eloFx', function(targetSource, duration)
    playEloFx(targetSource, duration)
end)

RegisterNetEvent('ob_bruxas:client:eloStopped', function(message)
    eloPending = false
    eloRequestToken = eloRequestToken + 1
    stopChannel(true)
    if message then
        ObBruxas.Notify('Elo Arcano', message, 'warning', 3000)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        eloSelecting = false
        eloSelectionToken = eloSelectionToken + 1
        eloPending = false
        eloRequestToken = eloRequestToken + 1
        eloChanneling = false
        eloChannelToken = eloChannelToken + 1
        releaseCaster()
    end
end)
