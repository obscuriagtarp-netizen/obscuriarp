local Magic = MagicHelpers

local invulCasting = false
local invulCastId = 0
local invulMarkedNet = nil
local invulMarkedUntil = 0
local invulLocalEnd = 0
local invulLocalRunning = false
local invulFxByNet = {}
local invulFxToken = 0
local invulRuntimeTxd = nil
local invulRuntimeTexture = nil
local invulTextureRetryAt = 0

_G.MagicProtectedEntities = _G.MagicProtectedEntities or {}

local MARK_TIME = 10000

local function EnsureOrbitTexture(orbit)
    if invulRuntimeTexture then return true end
    if GetGameTimer() < invulTextureRetryAt then return false end

    local dictionary = tostring(orbit.textureDict or "ob_invulneris_runtime")
    local texture = tostring(orbit.textureName or "shield_rune")
    local file = tostring(orbit.textureFile or "html/assets/invulneris-orbit.png")

    if not invulRuntimeTxd then
        invulRuntimeTxd = CreateRuntimeTxd(dictionary)
    end

    local ok, handle = pcall(
        CreateRuntimeTextureFromImage,
        invulRuntimeTxd,
        texture,
        file
    )
    if ok and handle and handle ~= 0 then
        invulRuntimeTexture = handle
        return true
    end

    invulTextureRetryAt = GetGameTimer() + 3000
    return false
end

local function Channel(value, fallback)
    value = tonumber(value)
    if value == nil then value = fallback end
    return math.floor(math.max(0.0, math.min(1.0, value)) * 255.0)
end

local function DrawInvulnerisOrbit(entity, orbit, now)
    local coords = GetEntityCoords(entity)
    local textureReady = EnsureOrbitTexture(orbit)
    local color = orbit.color or vec4(0.72, 0.3, 1.0, 0.9)
    local baseColor = orbit.baseColor or vec4(0.5, 0.16, 0.82, 0.34)
    local count = math.max(3, math.min(10, math.floor(tonumber(orbit.shardCount) or 6)))
    local radius = tonumber(orbit.radius) or 0.84
    local centerZ = coords.z + (tonumber(orbit.centerOffset) or 0.04)
    local wave = tonumber(orbit.verticalWave) or 0.2
    local baseSize = tonumber(orbit.size) or 0.48
    local phase = (now / 1000.0) * (tonumber(orbit.speed) or 1.12)
    local pulse = 0.94 + (math.sin(now * 0.005) * 0.06)

    if textureReady then
        for index = 0, count - 1 do
            local angle = phase + (index * ((math.pi * 2.0) / count))
            local height = math.sin((angle * 2.0) - (phase * 0.55)) * wave
            local size = baseSize * pulse * (index % 2 == 0 and 1.0 or 0.84)

            DrawMarker(
                math.floor(tonumber(orbit.markerType) or 9),
                coords.x + (math.cos(angle) * radius),
                coords.y + (math.sin(angle) * radius),
                centerZ + height,
                0.0, 0.0, 0.0,
                90.0, 0.0, (math.deg(angle) + 90.0) % 360.0,
                size, size, size,
                Channel(color.x, 0.72),
                Channel(color.y, 0.3),
                Channel(color.z, 1.0),
                Channel(color.w, 0.9),
                false, true, 2, true,
                tostring(orbit.textureDict or "ob_invulneris_runtime"),
                tostring(orbit.textureName or "shield_rune"),
                false
            )
        end
    end

    local baseZ = coords.z + (tonumber(orbit.baseOffset) or -1.0)
    local ringSize = tonumber(orbit.baseSize) or 1.24
    local red = Channel(baseColor.x, 0.5)
    local green = Channel(baseColor.y, 0.16)
    local blue = Channel(baseColor.z, 0.82)
    local alpha = Channel(baseColor.w, 0.34)

    DrawMarker(
        1,
        coords.x, coords.y, baseZ,
        0.0, 0.0, 0.0,
        0.0, 0.0, phase * 22.0,
        ringSize, ringSize, 0.018,
        red, green, blue, alpha,
        false, false, 2, true, nil, nil, false
    )
    DrawMarker(
        1,
        coords.x, coords.y, baseZ + 0.012,
        0.0, 0.0, 0.0,
        0.0, 0.0, -phase * 16.0,
        ringSize * 0.76, ringSize * 0.76, 0.012,
        222, 185, 255, math.max(16, math.floor(alpha * 0.72)),
        false, false, 2, true, nil, nil, false
    )
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

local function StopInvulnerisFx(targetNet, token)
    local entry = invulFxByNet[targetNet]
    if not entry then
        return
    end
    if token and entry.token ~= token then return end

    if entry.handle and entry.handle ~= 0 then
        StopParticleFxLooped(entry.handle, 0)
    end

    invulFxByNet[targetNet] = nil
    _G.MagicProtectedEntities[targetNet] = nil
end

local function StartInvulnerisFxOnNet(targetNet, duration)
    targetNet = tonumber(targetNet) or 0
    if targetNet <= 0 then
        return
    end

    StopInvulnerisFx(targetNet)

    local cfg = Config.Spells.invulneris or {}
    local orbit = cfg.orbit or cfg.dome or {}
    local endAt = GetGameTimer() + (tonumber(duration) or cfg.duration or 120000)
    invulFxToken = invulFxToken + 1
    local token = invulFxToken

    invulFxByNet[targetNet] = { token = token, endAt = endAt }
    _G.MagicProtectedEntities[targetNet] = true

    CreateThread(function()
        local resolveUntil = GetGameTimer() + 2500
        local entity = 0
        repeat
            entity = NetToPed(targetNet)
            if entity and entity ~= 0 and DoesEntityExist(entity) then break end
            Wait(50)
        until GetGameTimer() >= resolveUntil

        while invulFxByNet[targetNet]
            and invulFxByNet[targetNet].token == token
            and GetGameTimer() < endAt do
            local entity = NetToPed(targetNet)
            if not entity or entity == 0 or not DoesEntityExist(entity) then
                break
            end

            local coords = GetEntityCoords(entity)
            local viewerCoords = GetEntityCoords(PlayerPedId())
            if #(viewerCoords - coords) <= (tonumber(orbit.drawDistance) or 80.0) then
                DrawInvulnerisOrbit(entity, orbit, GetGameTimer())
                Wait(0)
            else
                Wait(180)
            end
        end

        StopInvulnerisFx(targetNet, token)
    end)
end

RegisterNetEvent("magic:client:startInvulnerisFx", function(targetNet, duration)
    StartInvulnerisFxOnNet(targetNet, duration)
end)

local function ApplyProofsToPed(ped, enabled)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return
    end

    if enabled then
        SetEntityInvincible(ped, false)
        SetEntityProofs(ped, true, true, true, false, true, true, true, false)
        return
    end

    SetEntityProofs(ped, false, false, false, false, false, false, false, false)
end

local function StartLocalInvulneris(duration)
    invulLocalEnd = math.max(invulLocalEnd, GetGameTimer() + (tonumber(duration) or 120000))

    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set("magicInvulneris", true, true)
    end

    if invulLocalRunning then
        return
    end

    invulLocalRunning = true

    CreateThread(function()
        while GetGameTimer() < invulLocalEnd do
            ApplyProofsToPed(PlayerPedId(), true)
            Wait(250)
        end

        ApplyProofsToPed(PlayerPedId(), false)

        if LocalPlayer and LocalPlayer.state then
            LocalPlayer.state:set("magicInvulneris", false, true)
        end

        invulLocalRunning = false
        Magic.Notify("Invulneris", "O domo arcano se dissipa.", "inform", 4500)
    end)
end

RegisterNetEvent("magic:client:applyInvulneris", function(duration)
    Magic.Notify("Invulneris", "Um domo arcano envolve seu corpo.", "inform", 5000)
    StartLocalInvulneris(duration or 120000)
end)

local function GetMarkedPed()
    if not invulMarkedNet or GetGameTimer() > invulMarkedUntil then
        invulMarkedNet = nil
        return nil
    end

    local ped = NetToPed(invulMarkedNet)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        invulMarkedNet = nil
        return nil
    end

    return ped
end

local function StartMarkPreview(targetNet)
    local token = targetNet
    CreateThread(function()
        while invulMarkedNet == token and GetGameTimer() < invulMarkedUntil do
            local ped = NetToPed(token)
            if not ped or ped == 0 or not DoesEntityExist(ped) then
                break
            end

            local coords = GetEntityCoords(ped)
            DrawMarker(
                1,
                coords.x, coords.y, coords.z - 0.92,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                1.35, 1.35, 0.025,
                95, 238, 255, 120,
                false, false, 2, false, nil, nil, false
            )

            Wait(0)
        end
    end)
end

local function MarkTarget(dist)
    local target = nil
    if Magic.GetPedTargetInFront then
        target = Magic.GetPedTargetInFront(dist or 12.0)
    end

    if not target or not DoesEntityExist(target) or not IsPedAPlayer(target)
        or IsPedDeadOrDying(target, true) then
        Magic.Notify("Invulneris", "Nenhum alvo valido na mira.", "error", 3500)
        return false
    end

    local netId = EnsureNetworked(target)
    if netId == 0 then
        Magic.Notify("Invulneris", "Nao foi possivel marcar esse alvo.", "error", 3500)
        return false
    end

    invulMarkedNet = netId
    invulMarkedUntil = GetGameTimer() + MARK_TIME

    Magic.ShowHints("Invulneris", {
        "Alvo marcado pelo domo arcano.",
        "Mouse esquerdo - proteger alvo marcado",
        "Mouse direito - proteger a si mesmo"
    })

    Magic.Notify("Invulneris", "Alvo marcado. Clique esquerdo novamente para proteger.", "inform", 3500)
    StartMarkPreview(netId)
    return true
end

local function FaceTarget(caster, target)
    if not caster or not target or not DoesEntityExist(target) then
        return
    end

    local from = GetEntityCoords(caster)
    local to = GetEntityCoords(target)
    SetEntityHeading(caster, GetHeadingFromVector_2d(to.x - from.x, to.y - from.y))
end

local function ProtectNpc(targetPed, duration)
    ApplyProofsToPed(targetPed, true)
    SetTimeout(duration, function()
        ApplyProofsToPed(targetPed, false)
    end)
end

local function ApplyInvulnerisToTarget(targetPed, duration)
    if not targetPed or not DoesEntityExist(targetPed) or not IsPedAPlayer(targetPed) then
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
        TriggerServerEvent("magic:server:invulnerisPlayer", targetSrc, duration, netId)
    else
        StartLocalInvulneris(duration)
        TriggerServerEvent("magic:server:invulnerisFxBroadcast", netId, duration)
    end

    return true
end

local function CastInvulneris(targetPed, castMode)
    if invulCasting then
        return
    end

    local cfg = Config.Spells.invulneris or {}
    local ped = PlayerPedId()
    local castTime = tonumber(cfg.castTime) or 1800
    local duration
    if castMode == "self" then
        duration = tonumber(cfg.selfDuration or cfg.duration) or 45000
    else
        duration = tonumber(cfg.targetDuration or cfg.duration) or 120000
    end

    if not targetPed or not DoesEntityExist(targetPed) then
        Magic.Notify("Invulneris", "O alvo marcado desapareceu.", "error", 3500)
        return
    end

    invulCasting = true
    invulCastId = invulCastId + 1
    local thisCast = invulCastId

    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set("Buttons", true, true)
    end

    FaceTarget(ped, targetPed)
    Magic.PlaySpellAnim(cfg)
    TriggerEvent("Progress", "Conjurando Invulneris", castTime)

    SetTimeout(castTime, function()
        if not invulCasting or thisCast ~= invulCastId then
            return
        end

        invulCasting = false

        if LocalPlayer and LocalPlayer.state then
            LocalPlayer.state:set("Buttons", false, true)
        end

        ClearPedSecondaryTask(ped)

        if ApplyInvulnerisToTarget(targetPed, duration) then
            invulMarkedNet = nil
            Magic.HideHints()
            Magic.Notify("Invulneris", "O domo arcano protege o alvo.", "success", 4500)
            Magic.FinishSpellCooldown("invulneris")
        else
            Magic.Notify("Invulneris", "Nao foi possivel proteger esse alvo.", "error", 3500)
        end
    end)
end

RegisterNetEvent("magic:spells:invulneris", function(castMode)
    if invulCasting then
        return
    end

    local cfg = Config.Spells.invulneris or {}

    if castMode == "self" then
        invulMarkedNet = nil
        Magic.HideHints()
        CastInvulneris(PlayerPedId(), "self")
        return
    end

    local markedPed = GetMarkedPed()
    if markedPed then
        CastInvulneris(markedPed, "target")
        return
    end

    MarkTarget(cfg.distance or 12.0)
end)

CreateThread(function()
    local cfg = Config.Spells.invulneris or {}
    local orbit = cfg.orbit or {}
    local command = tostring(orbit.previewCommand or "")
    if command == "" then return end

    RegisterCommand(command, function()
        local netId = EnsureNetworked(PlayerPedId())
        if netId == 0 then
            Magic.Notify("Invulneris", "Não foi possível iniciar a prévia.", "error", 3000)
            return
        end

        StartInvulnerisFxOnNet(netId, tonumber(orbit.previewDuration) or 25000)
        Magic.Notify("Invulneris", "Prévia visual iniciada.", "inform", 3000)
    end, false)
end)
