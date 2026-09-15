local activeAuras = {}

local function colorChannel(value)
    return math.floor(math.max(0.0, math.min(1.0, tonumber(value) or 0.0)) * 255.0 + 0.5)
end

local function drawHealingSymbol(x, y, z, size, alpha, colors)
    local visible, screenX, screenY = World3dToScreen2d(x, y, z)
    if not visible then return end

    local main = colors.main or { 0.18, 1.0, 0.42 }
    local soft = colors.soft or main
    local mainR, mainG, mainB = colorChannel(main[1]), colorChannel(main[2]), colorChannel(main[3])
    local softR, softG, softB = colorChannel(soft[1]), colorChannel(soft[2]), colorChannel(soft[3])

    SetTextScale(0.0, size * 1.24)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextCentre(true)
    SetTextColour(mainR, mainG, mainB, math.floor(alpha * 0.4))
    SetTextDropshadow(0, mainR, mainG, mainB, math.floor(alpha * 0.62))
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName('+')
    EndTextCommandDisplayText(screenX, screenY)

    SetTextScale(0.0, size)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextCentre(true)
    SetTextColour(softR, softG, softB, alpha)
    SetTextDropshadow(1, mainR, mainG, mainB, math.floor(alpha * 0.82))
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName('+')
    EndTextCommandDisplayText(screenX, screenY)
end

local function playHealingSymbols(entity, duration, token, colors)
    local config = (Config.TreatmentFx and Config.TreatmentFx.healSymbols) or {}
    local count = math.max(3, math.min(10, math.floor(tonumber(config.count) or 7)))
    local cycle = math.max(900, tonumber(config.riseDuration) or 1900)
    local radius = tonumber(config.radius) or 0.38
    local startOffset = tonumber(config.startOffset) or -0.72
    local riseHeight = tonumber(config.riseHeight) or 2.15
    local baseSize = tonumber(config.size) or 0.14
    local orbitSpeed = tonumber(config.orbitSpeed) or 0.72
    local turnsPerRise = tonumber(config.turnsPerRise) or 0.68
    local drawDistance = math.max(10.0, tonumber(config.drawDistance) or 65.0)
    local startedAt = GetGameTimer()
    local endsAt = startedAt + duration

    CreateThread(function()
        while activeAuras[entity] == token
            and GetGameTimer() < endsAt
            and DoesEntityExist(entity) do
            local coords = GetEntityCoords(entity)
            local viewerCoords = GetEntityCoords(PlayerPedId())

            if #(viewerCoords - coords) <= drawDistance then
                local now = GetGameTimer()
                local elapsed = now - startedAt
                local orbit = (elapsed / 1000.0) * orbitSpeed

                for index = 0, count - 1 do
                    local progress = ((elapsed + ((cycle / count) * index)) % cycle) / cycle
                    local angle = orbit
                        + (index * 2.399963)
                        + (progress * math.pi * 2.0 * turnsPerRise)
                    local drift = radius * (0.8 + (math.sin((progress + index) * math.pi) * 0.16))
                    local fade = math.sin(progress * math.pi)
                    local size = baseSize * (0.84 + (fade * 0.28))
                    local alpha = math.floor(math.max(0.0, fade) ^ 1.25 * 228.0)

                    drawHealingSymbol(
                        coords.x + (math.cos(angle) * drift),
                        coords.y + (math.sin(angle) * drift),
                        coords.z + startOffset + (progress * riseHeight),
                        size,
                        alpha,
                        colors
                    )
                end

                Wait(0)
            else
                Wait(180)
            end
        end
    end)
end

local function palette(kind)
    local palettes = Config.TreatmentFx.palettes or {}
    return palettes[kind] or palettes.heal or {
        main = { 0.18, 1.0, 0.42 },
        soft = { 0.62, 1.0, 0.72 },
    }
end

local function stopFx(handle)
    if handle and handle ~= 0 and DoesParticleFxLoopedExist(handle) then
        StopParticleFxLooped(handle, false)
    end
end

local function applyLoopStyle(handle, color, alpha)
    if not handle or handle == 0 then return end
    SetParticleFxLoopedColour(handle, color[1], color[2], color[3], false)
    SetParticleFxLoopedAlpha(handle, alpha)
end

local function startEntityFx(entity, effect, offsetZ, scale, color, alpha)
    UseParticleFxAssetNextCall('scr_powerplay')
    local handle = StartParticleFxLoopedOnEntity(
        effect,
        entity,
        0.0, 0.0, offsetZ,
        0.0, 0.0, 0.0,
        scale,
        false, false, false
    )
    applyLoopStyle(handle, color, alpha)
    return handle
end

local function startBoneFx(entity, boneId, scale, color, alpha)
    local bone = GetPedBoneIndex(entity, boneId)
    if bone < 0 then return nil end
    UseParticleFxAssetNextCall('scr_powerplay')
    local handle = StartParticleFxLoopedOnEntityBone(
        'scr_powerplay_beast_vapor',
        entity,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        bone,
        scale,
        false, false, false
    )
    applyLoopStyle(handle, color, alpha)
    return handle
end

function ObCurandeiras.PlayChannel(targetPed, duration, kind)
    local ped = PlayerPedId()
    duration = math.max(800, tonumber(duration) or 3000)
    kind = tostring(kind or 'heal')
    local colors = palette(kind)

    if targetPed and targetPed ~= ped and DoesEntityExist(targetPed) then
        TaskTurnPedToFaceEntity(ped, targetPed, 450)
    end

    local animationLoaded = ObCurandeiras.EnsureAnim(Config.CastAnimation.dict)
    if animationLoaded then
        TaskPlayAnim(
            ped,
            Config.CastAnimation.dict,
            Config.CastAnimation.name,
            3.5,
            -3.5,
            duration,
            Config.CastAnimation.flag,
            0.0,
            false,
            false,
            false
        )
    end

    local handFx = {}
    if ObCurandeiras.EnsurePtfx('scr_powerplay') then
        handFx[1] = startBoneFx(ped, 57005, 0.2, colors.main, 0.82)
        handFx[2] = startBoneFx(ped, 18905, 0.17, colors.soft, 0.68)
    end

    local endsAt = GetGameTimer() + duration
    while GetGameTimer() < endsAt do
        DisablePlayerFiring(PlayerId(), true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        Wait(0)
    end

    for _, handle in ipairs(handFx) do stopFx(handle) end
    if animationLoaded then
        StopAnimTask(ped, Config.CastAnimation.dict, Config.CastAnimation.name, 1.5)
    end
end

function ObCurandeiras.PlayAura(entity, kind, duration)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    duration = math.max(1000, tonumber(duration) or 4000)
    kind = tostring(kind or 'heal')
    local colors = palette(kind)
    local token = (activeAuras[entity] or 0) + 1
    activeAuras[entity] = token

    if kind == 'heal' or kind == 'serenity' or kind == 'bleeding' then
        playHealingSymbols(entity, duration, token, colors)
    end

    CreateThread(function()
        local handles = {}
        if ObCurandeiras.EnsurePtfx('scr_powerplay') then
            handles[#handles + 1] = startEntityFx(
                entity,
                'scr_powerplay_beast_vapor',
                0.72,
                kind == 'serenity' and 0.72 or 0.9,
                colors.main,
                0.88
            )
            handles[#handles + 1] = startEntityFx(
                entity,
                'scr_powerplay_beast_vapor',
                0.06,
                0.5,
                colors.soft,
                0.72
            )
        end

        local startedAt = GetGameTimer()
        local endsAt = startedAt + duration
        local nextPulse = 0
        local interval = math.max(300, tonumber(Config.TreatmentFx.pulseInterval) or 520)

        while activeAuras[entity] == token
            and GetGameTimer() < endsAt
            and DoesEntityExist(entity) do
            local now = GetGameTimer()
            if now >= nextPulse and ObCurandeiras.EnsurePtfx('scr_powerplay') then
                nextPulse = now + interval
                local coords = GetEntityCoords(entity)
                local phase = ((now - startedAt) % 1600) / 1600
                local angle = phase * math.pi * 2.0
                local radius = kind == 'serenity' and 0.28 or 0.42

                for index = 0, 2 do
                    local offsetAngle = angle + (index * ((math.pi * 2.0) / 3.0))
                    local x = coords.x + math.cos(offsetAngle) * radius
                    local y = coords.y + math.sin(offsetAngle) * radius
                    local z = coords.z - 0.45 + (index * 0.42)
                    UseParticleFxAssetNextCall('scr_powerplay')
                    SetParticleFxNonLoopedColour(colors.main[1], colors.main[2], colors.main[3])
                    SetParticleFxNonLoopedAlpha(0.88)
                    StartParticleFxNonLoopedAtCoord(
                        'scr_powerplay_beast_vapor',
                        x, y, z,
                        0.0, 0.0, 0.0,
                        kind == 'bleeding' and 0.38 or 0.48,
                        false, false, false
                    )
                end
            end
            Wait(50)
        end

        for _, handle in ipairs(handles) do stopFx(handle) end
        if activeAuras[entity] == token then activeAuras[entity] = nil end
    end)
end

local function healNpcGradually(ped, duration, fraction)
    local startHealth = GetEntityHealth(ped)
    local maxHealth = GetEntityMaxHealth(ped)
    local targetHealth = math.min(maxHealth, startHealth + math.floor(maxHealth * fraction))
    local startedAt = GetGameTimer()

    CreateThread(function()
        while DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) do
            local progress = math.min(1.0, (GetGameTimer() - startedAt) / duration)
            local intended = math.floor(startHealth + ((targetHealth - startHealth) * progress))
            if GetEntityHealth(ped) < intended then SetEntityHealth(ped, intended) end
            if progress >= 1.0 then break end
            Wait(250)
        end
    end)
end

RegisterNetEvent('ob_curandeiras:client:applyGradualHeal', function(duration, fraction)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then return end
    healNpcGradually(
        ped,
        math.max(1000, tonumber(duration) or 10000),
        math.max(0.0, math.min(1.0, tonumber(fraction) or 1.0))
    )
end)

function ObCurandeiras.ApplyNpcAbility(abilityId, targetPed)
    if not targetPed or not DoesEntityExist(targetPed) or IsPedDeadOrDying(targetPed, true) then
        return false
    end

    local config, auraKind, auraDuration
    if abilityId == 'cura_vital' then
        config = Config.VitalHeal
        auraKind = 'heal'
        auraDuration = config.channelDuration + config.healDuration
    elseif abilityId == 'serenidade' then
        config = Config.Serenity
        auraKind = 'serenity'
        auraDuration = config.channelDuration + math.min(config.effectDuration, 10000)
    elseif abilityId == 'estancar' then
        config = Config.StopBleeding
        auraKind = 'bleeding'
        auraDuration = config.channelDuration + config.effectDuration
    else
        return false
    end

    ObCurandeiras.PlayAura(targetPed, auraKind, auraDuration)
    ObCurandeiras.PlayChannel(targetPed, config.channelDuration, auraKind)
    if not DoesEntityExist(targetPed) or IsPedDeadOrDying(targetPed, true) then return false end

    if abilityId == 'cura_vital' then
        healNpcGradually(targetPed, config.healDuration, config.healFraction)
    elseif abilityId == 'serenidade' then
        ClearPedTasks(targetPed)
        SetBlockingOfNonTemporaryEvents(targetPed, true)
        TaskStandStill(targetPed, math.min(config.effectDuration, 10000))
        SetTimeout(config.effectDuration, function()
            if DoesEntityExist(targetPed) then
                SetBlockingOfNonTemporaryEvents(targetPed, false)
            end
        end)
    else
        ClearPedBloodDamage(targetPed)
        ClearPedLastDamageBone(targetPed)
        healNpcGradually(targetPed, config.healDuration, config.healFraction)
    end
    return true
end

function ObCurandeiras.CastTreatment(options)
    options = options or {}
    if not ObCurandeiras.IsHealer() or ObCurandeiras.IsPowerBlocked() then return end

    CreateThread(function()
        local abilityId = tostring(options.abilityId or '')
        local config = options.config or {}
        local targetSource, targetPed = ObCurandeiras.AwaitTarget(
            abilityId,
            tostring(options.targetLabel or 'TRATAR'),
            tonumber(config.distance) or 12.0,
            tonumber(options.timeout) or 9000
        )
        if not targetSource then return end

        if options.requireInjured
            and GetEntityHealth(targetPed) >= GetEntityMaxHealth(targetPed) then
            ObCurandeiras.Notify(options.title, 'A vitalidade deste alvo já está completa.', 'inform')
            return
        end

        if targetSource == 0 then
            if not ObCurandeiras.AuthorizeNpcAbility(abilityId) then return end
            ObCurandeiras.StartCooldown(abilityId, config.cooldown)
            ObCurandeiras.Notify(options.title, options.successMessage, 'success')
            ObCurandeiras.ApplyNpcAbility(abilityId, targetPed)
            return
        end

        local ok, result = pcall(function()
            return lib.callback.await(
                'ob_curandeiras:server:useTargetAbility',
                false,
                abilityId,
                targetSource
            )
        end)
        if not ok or type(result) ~= 'table' or result.success ~= true then
            ObCurandeiras.Notify(
                options.title,
                result and result.message or options.failureMessage or 'O tratamento falhou.',
                'error'
            )
            return
        end

        ObCurandeiras.StartCooldown(abilityId, config.cooldown)
        ObCurandeiras.Notify(options.title, options.successMessage, 'success')
        ObCurandeiras.PlayChannel(targetPed, config.channelDuration, options.auraKind)
    end)
end

RegisterNetEvent('ob_curandeiras:client:targetFx', function(netId, kind, duration, targetSource)
    netId = tonumber(netId) or 0
    targetSource = tonumber(targetSource)

    CreateThread(function()
        local expiresAt = GetGameTimer() + 2500
        repeat
            local entity = 0
            if netId > 0 and NetworkDoesNetworkIdExist(netId) then
                entity = NetworkGetEntityFromNetworkId(netId)
            end
            if (not entity or entity == 0) and targetSource then
                local playerIndex = GetPlayerFromServerId(targetSource)
                if playerIndex ~= -1 then entity = GetPlayerPed(playerIndex) end
            end
            if entity and entity ~= 0 and DoesEntityExist(entity) then
                ObCurandeiras.PlayAura(entity, kind, duration)
                return
            end
            Wait(50)
        until GetGameTimer() >= expiresAt
    end)
end)

RegisterNetEvent('ob_curandeiras:client:serenityApplied', function(_, restoredMana)
    if source ~= 65535 then return end
    -- Atualiza o estado local antes de avisar HUDs que ainda usam o evento legado.
    LocalPlayer.state:set(Config.Compatibility.stressStateKey or 'stress', 0, true)
    for _, eventName in ipairs(Config.Compatibility.stressClientEvents or {}) do
        TriggerEvent(eventName, 0)
    end
    StopGameplayCamShaking(true)
    ObCurandeiras.Notify(
        'Serenidade',
        (tonumber(restoredMana) or 0) > 0
            and ('Sua mente se acalma e %d de mana são restaurados.'):format(restoredMana)
            or 'A tensão abandona seu corpo e sua mente se acalma.',
        'success',
        6000
    )
end)

RegisterNetEvent('ob_curandeiras:client:bleedingStopped', function()
    if source ~= 65535 then return end
    local medicalResource = Config.Compatibility.medicalResource or 'qbx_medical'
    local ok = false
    if GetResourceState(medicalResource) == 'started' then
        ok = pcall(function()
            exports[medicalResource]:RemoveBleed(4)
        end)
    end
    if not ok then
        print(('[ob_curandeiras] Falha ao estancar sangramento: verifique %s e o export RemoveBleed.'):format(medicalResource))
        ObCurandeiras.Notify('Estancar Sangramento', 'O medical nao conseguiu concluir o tratamento.', 'error')
        return
    end
    local ped = PlayerPedId()
    ClearPedBloodDamage(ped)
    ClearPedLastDamageBone(ped)
    ObCurandeiras.Notify(
        'Estancar Sangramento',
        'A regeneração dos tecidos interrompeu a hemorragia.',
        'success'
    )
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        FreezeEntityPosition(PlayerPedId(), false)
        ClearTimecycleModifier()
    end
end)
