local Magic = MagicHelpers

local healing = false
local vitaeCastId = 0

local function EnsurePtfx(asset)
    if not asset or asset == "" then
        return false
    end

    if HasNamedPtfxAssetLoaded(asset) then
        return true
    end

    RequestNamedPtfxAsset(asset)
    local timeout = GetGameTimer() + 1800
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < timeout do
        Wait(0)
    end

    return HasNamedPtfxAssetLoaded(asset)
end

local function EnsureNetworked(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return 0
    end

    if not NetworkGetEntityIsNetworked(entity) then
        NetworkRegisterEntityAsNetworked(entity)
        Wait(0)
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId and netId ~= 0 then
        SetNetworkIdCanMigrate(netId, true)
    end

    return netId or 0
end

local function FaceTarget(caster, target)
    if not caster or not target or not DoesEntityExist(target) then
        return
    end

    if caster == target then
        return
    end

    local from = GetEntityCoords(caster)
    local to = GetEntityCoords(target)
    SetEntityHeading(caster, GetHeadingFromVector_2d(to.x - from.x, to.y - from.y))
end

local function StopFx(fx)
    if fx and fx ~= 0 and DoesParticleFxLoopedExist(fx) then
        StopParticleFxLooped(fx, false)
    end
end

local function colorComponent(color, index, named, fallback)
    if type(color) ~= "table" then
        return fallback
    end

    return tonumber(color[index] or color[named]) or fallback
end

local function PlayVitaeFxOnEntity(ent, duration, palette)
    if not ent or not DoesEntityExist(ent) then
        return
    end

    local cfg = Config.Spells.vitae_restituo or {}
    local time = tonumber(duration) or cfg.healDuration or 10000
    local asset = cfg.fxAsset or "scr_powerplay"
    local effect = cfg.fxEffect or "scr_powerplay_beast_vapor"
    local scale = cfg.fxScale or 0.9
    palette = type(palette) == "table" and palette or {}
    local mainColor = palette.main
    local feetColor = palette.feet
    local markerColor = palette.marker
    local pulseColor = palette.pulse
    local fxMain = nil
    local fxFeet = nil

    if EnsurePtfx(asset) then
        UseParticleFxAssetNextCall(asset)
        fxMain = StartParticleFxLoopedOnEntity(
            effect,
            ent,
            0.0, 0.0, 0.78,
            0.0, 0.0, 0.0,
            scale,
            false, false, false
        )
        if fxMain and fxMain ~= 0 then
            SetParticleFxLoopedColour(
                fxMain,
                colorComponent(mainColor, 1, "r", 0.38),
                colorComponent(mainColor, 2, "g", 1.0),
                colorComponent(mainColor, 3, "b", 0.56),
                false
            )
            SetParticleFxLoopedAlpha(fxMain, 0.88)
        end

        UseParticleFxAssetNextCall(asset)
        fxFeet = StartParticleFxLoopedOnEntity(
            effect,
            ent,
            0.0, 0.0, 0.12,
            0.0, 0.0, 0.0,
            scale * 0.52,
            false, false, false
        )
        if fxFeet and fxFeet ~= 0 then
            SetParticleFxLoopedColour(
                fxFeet,
                colorComponent(feetColor, 1, "r", 0.82),
                colorComponent(feetColor, 2, "g", 0.95),
                colorComponent(feetColor, 3, "b", 0.42),
                false
            )
            SetParticleFxLoopedAlpha(fxFeet, 0.72)
        end
    end

    CreateThread(function()
        local startedAt = GetGameTimer()
        local endAt = startedAt + time
        local nextPulse = 0

        while GetGameTimer() < endAt do
            if not DoesEntityExist(ent) then
                break
            end

            local now = GetGameTimer()
            local coords = GetEntityCoords(ent)
            local loop = ((now - startedAt) % 1450) / 1450

            for i = 0, 3 do
                local phase = (loop + (i * 0.25)) % 1.0
                local z = coords.z - 0.88 + (phase * 1.88)
                local size = 0.92 + (phase * 0.5)
                local alpha = math.floor(190 * (1.0 - phase))

                DrawMarker(
                    1,
                    coords.x, coords.y, z,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    size, size, 0.018,
                    colorComponent(markerColor, 1, "r", 72),
                    colorComponent(markerColor, 2, "g", 255),
                    colorComponent(markerColor, 3, "b", 132),
                    alpha,
                    false, false, 2, false, nil, nil, false
                )
            end

            if now >= nextPulse and EnsurePtfx(asset) then
                nextPulse = now + 260
                local zPulse = coords.z - 0.18 + (loop * 1.55)

                UseParticleFxAssetNextCall(asset)
                if pulseColor then
                    SetParticleFxNonLoopedColour(
                        colorComponent(pulseColor, 1, "r", 0.72),
                        colorComponent(pulseColor, 2, "g", 0.25),
                        colorComponent(pulseColor, 3, "b", 1.0)
                    )
                end
                StartParticleFxNonLoopedAtCoord(
                    effect,
                    coords.x, coords.y, zPulse,
                    0.0, 0.0, 0.0,
                    scale * 0.72,
                    false, false, false
                )

                UseParticleFxAssetNextCall(asset)
                if pulseColor then
                    SetParticleFxNonLoopedColour(
                        colorComponent(pulseColor, 1, "r", 0.72),
                        colorComponent(pulseColor, 2, "g", 0.25),
                        colorComponent(pulseColor, 3, "b", 1.0)
                    )
                end
                StartParticleFxNonLoopedAtCoord(
                    effect,
                    coords.x, coords.y, zPulse + 0.42,
                    0.0, 0.0, 0.0,
                    scale * 0.46,
                    false, false, false
                )
            end

            Wait(0)
        end

        StopFx(fxMain)
        StopFx(fxFeet)
    end)
end

exports('PlayVitaeFxOnEntity', function(entity, duration, palette)
    if not entity or not DoesEntityExist(entity) then
        return false
    end

    PlayVitaeFxOnEntity(entity, duration, palette)
    return true
end)

local function ApplyGradualHealToPed(ped, healFraction, duration)
    if not ped or not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then
        return
    end

    local time = tonumber(duration) or 10000
    local fraction = tonumber(healFraction) or 1.0
    local maxHealth = GetEntityMaxHealth(ped)
    local startHealth = GetEntityHealth(ped)
    local healAmount = math.floor(maxHealth * fraction)
    local targetHealth = math.min(maxHealth, startHealth + healAmount)

    if targetHealth <= startHealth then
        return
    end

    CreateThread(function()
        local startedAt = GetGameTimer()
        local endAt = startedAt + time
        local lastHealth = startHealth

        while GetGameTimer() < endAt do
            if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then
                return
            end

            local progress = (GetGameTimer() - startedAt) / time
            local nextHealth = math.floor(startHealth + ((targetHealth - startHealth) * progress))

            if nextHealth > lastHealth then
                SetEntityHealth(ped, math.min(targetHealth, nextHealth))
                lastHealth = nextHealth
            end

            Wait(120)
        end

        if DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
            SetEntityHealth(ped, targetHealth)
        end
    end)
end

RegisterNetEvent("magic:client:vitaeFx", function(netId, duration)
    if not netId then
        return
    end

    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent and DoesEntityExist(ent) then
        PlayVitaeFxOnEntity(ent, duration)
    end
end)

RegisterNetEvent("magic:client:applyVitaeHeal", function(healFraction, duration)
    local ped = PlayerPedId()
    ApplyGradualHealToPed(ped, healFraction or 1.0, duration or 10000)
end)

RegisterNetEvent("magic:client:applyHeal", function(healAmount)
    local ped = PlayerPedId()
    if IsPedDeadOrDying(ped, true) then
        return
    end

    local maxHealth = GetEntityMaxHealth(ped)
    local curHealth = GetEntityHealth(ped)
    SetEntityHealth(ped, math.min(maxHealth, curHealth + (tonumber(healAmount) or 40)))
end)

RegisterCommand("vitae_cancel_target", function()
    if not healing then
        Magic.Notify("Vitae Restituo", "Nenhuma cura esta sendo canalizada.", "inform", 3000)
        return
    end

    healing = false
    vitaeCastId = vitaeCastId + 1

    ClearPedTasks(PlayerPedId())
    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set("Buttons", false, true)
    end

    Magic.HideHints()
    Magic.Notify("Vitae Restituo", "Voce interrompeu a canalizacao vital.", "inform", 4000)
end, false)

RegisterKeyMapping(
    "vitae_cancel_target",
    "Cancelar conjuracao da Vitae Restituo",
    "keyboard",
    "I"
)

local function ApplyVitaeToTarget(targetPed, healFraction, healDuration)
    if not targetPed or not DoesEntityExist(targetPed) or not IsPedAPlayer(targetPed)
        or IsPedDeadOrDying(targetPed, true) then
        return false
    end

    local netId = EnsureNetworked(targetPed)
    if netId == 0 then
        return false
    end

    local playerIndex = NetworkGetPlayerIndexFromPed(targetPed)
    local targetSrc = playerIndex and GetPlayerServerId(playerIndex) or nil
    local mySrc = GetPlayerServerId(PlayerId())

    if targetSrc and targetSrc ~= mySrc then
        TriggerServerEvent("magic:server:healTarget", targetSrc, healFraction, netId, healDuration)
    else
        ApplyGradualHealToPed(PlayerPedId(), healFraction, healDuration)
        TriggerServerEvent("magic:server:vitaeFx", netId, healDuration)
    end

    return true
end

local function CastVitae(targetPed, castMode)
    if healing then
        return
    end

    local cfg = Config.Spells.vitae_restituo or {}
    local ped = PlayerPedId()
    local castTime = tonumber(cfg.castTime) or 2200
    local healDuration = tonumber(cfg.healDuration) or 10000
    local healFraction = 1.0

    if castMode == "self" then
        healFraction = tonumber(cfg.selfHealFraction) or 0.5
    else
        healFraction = tonumber(cfg.targetHealFraction) or 1.0
    end

    if not targetPed or not DoesEntityExist(targetPed) or IsPedDeadOrDying(targetPed, true) then
        Magic.Notify("Vitae Restituo", "Nenhum alvo vivo encontrado.", "error", 3500)
        return
    end

    healing = true
    vitaeCastId = vitaeCastId + 1
    local thisCast = vitaeCastId

    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set("Buttons", true, true)
    end

    FaceTarget(ped, targetPed)
    Magic.PlaySpellAnim(cfg)
    TriggerEvent("Progress", "Canalizando Vitae Restituo", castTime)

    Magic.HideHints()

    CreateThread(function()
        while healing and thisCast == vitaeCastId do
            if IsControlJustPressed(0, 303) or IsControlJustPressed(0, 177) then
                healing = false
                vitaeCastId = vitaeCastId + 1

                if LocalPlayer and LocalPlayer.state then
                    LocalPlayer.state:set("Buttons", false, true)
                end

                ClearPedTasks(ped)
                Magic.HideHints()
                Magic.Notify("Vitae Restituo", "A cura foi cancelada.", "inform", 3500)
                return
            end

            Wait(0)
        end
    end)

    SetTimeout(castTime, function()
        if not healing or thisCast ~= vitaeCastId then
            return
        end

        if LocalPlayer and LocalPlayer.state then
            LocalPlayer.state:set("Buttons", false, true)
        end

        ClearPedSecondaryTask(ped)

        if ApplyVitaeToTarget(targetPed, healFraction, healDuration) then
            Magic.ApplyDamageToPlayer(10)
            Magic.FinishSpellCooldown("vitae_restituo")
            Magic.HideHints()
        else
            Magic.Notify("Vitae Restituo", "Nao foi possivel curar esse alvo.", "error", 3500)
            healing = false
        end

        SetTimeout(healDuration, function()
            if thisCast == vitaeCastId then
                healing = false
            end
        end)
    end)
end

RegisterNetEvent("magic:spells:vitae_restituo", function(castMode)
    if healing then
        return
    end

    local cfg = Config.Spells.vitae_restituo or {}

    if castMode == "self" then
        CastVitae(PlayerPedId(), "self")
        return
    end

    local target = nil
    if Magic.GetPedTargetInFront then
        target = Magic.GetPedTargetInFront(cfg.distance or 15.0)
    end

    if not target or not DoesEntityExist(target) or target == PlayerPedId() then
        Magic.Notify("Vitae Restituo", "Mire em um aliado vivo para curar.", "error", 3500)
        return
    end

    CastVitae(target, "target")
end)
