local Magic = MagicHelpers

local SPELL_ID = "petrificus"
local ICE_RESOURCE = "gelo_assets_preview"
local glaciesCasting = false
local activeGlaciesFx = {}
local localFreezeSerial = 0
local frozenLocalPed = 0

local function GetGlaciesConfig()
    return (Config.Spells and Config.Spells[SPELL_ID]) or {}
end

local function Debug(message)
    if Config and Config.Debug then
        print(("[magicSpells:glacies] %s"):format(message))
    end
end

local function GetIceResource(cfg)
    return (cfg.iceFx and cfg.iceFx.resource) or ICE_RESOURCE
end

local function IceResourceReady(cfg)
    local resource = GetIceResource(cfg)
    if GetResourceState(resource) == "started" then
        return true
    end

    Debug(("recurso de efeitos indisponivel: %s"):format(resource))
    return false
end

local function PlayIceAtCoords(cfg, effect, coords, rotation, scale, duration)
    if not IceResourceReady(cfg) then return false end

    local resource = GetIceResource(cfg)
    local ok, handle, reason = pcall(function()
        return exports[resource]:PlayAtCoords(effect, coords, rotation, scale, duration)
    end)

    if not ok or not handle then
        Debug(("falha ao iniciar %s: %s"):format(tostring(effect), tostring(reason or handle)))
        return false
    end

    return handle
end

local function PlayIceOnBone(cfg, effect, ped, bone, scale, duration)
    if not IceResourceReady(cfg) then return false end

    local resource = GetIceResource(cfg)
    local ok, handle, reason = pcall(function()
        return exports[resource]:PlayOnBone(
            effect,
            ped,
            bone,
            vector3(0.0, 0.0, 0.0),
            vector3(0.0, 0.0, 0.0),
            scale,
            duration
        )
    end)

    if not ok or not handle then
        Debug(("falha ao fixar %s no osso %s: %s"):format(tostring(effect), tostring(bone), tostring(reason or handle)))
        return false
    end

    return handle
end

local function StopIceFx(cfg, handle)
    if not handle then return end

    local resource = GetIceResource(cfg)
    if GetResourceState(resource) ~= "started" then return end

    pcall(function()
        exports[resource]:Stop(handle)
    end)
end

local function CleanupGlaciesVisual(key)
    local handles = activeGlaciesFx[key]
    if not handles then return end

    local cfg = GetGlaciesConfig()
    for index = 1, #handles do
        StopIceFx(cfg, handles[index])
    end

    activeGlaciesFx[key] = nil
end

local function DirectionToRotation(direction)
    local length = #(direction)
    if length < 0.001 then
        return vector3(0.0, 0.0, 0.0)
    end

    direction = direction / length
    local pitch = math.deg(math.asin(math.max(-1.0, math.min(1.0, direction.z))))
    local yaw = math.deg(math.atan(-direction.x, direction.y))
    return vector3(pitch, 0.0, yaw)
end

local function PlayGlaciesBeam(fromCoords, toCoords, duration)
    if not fromCoords or not toCoords then return end

    local cfg = GetGlaciesConfig()
    local ice = cfg.iceFx or {}
    local direction = toCoords - fromCoords
    if #(direction) < 0.2 then return end

    PlayIceAtCoords(
        cfg,
        ice.cast or "codex_ice_cast",
        fromCoords,
        DirectionToRotation(direction),
        tonumber(ice.castScale) or 1.05,
        math.max(100, math.min(15000, tonumber(duration) or 700))
    )
end

local function PlayGlaciesImpact(coords)
    if not coords then return end

    local cfg = GetGlaciesConfig()
    local ice = cfg.iceFx or {}
    PlayIceAtCoords(
        cfg,
        ice.impact or "codex_ice_impact",
        coords,
        vector3(0.0, 0.0, 0.0),
        tonumber(ice.impactScale) or 1.15,
        1100
    )
end

local function PlayGlaciesFrost(ped, key, duration)
    if not ped or not DoesEntityExist(ped) then return end

    local cfg = GetGlaciesConfig()
    local ice = cfg.iceFx or {}
    local effect = ice.frost or "codex_ice_frost"
    local scale = tonumber(ice.frostScale) or 0.72
    local bones = ice.frostBones or { 31086, 24818, 57005, 18905, 58271, 51826 }
    local safeDuration = math.max(100, math.min(15000, tonumber(duration) or 7000))

    CleanupGlaciesVisual(key)
    local handles = {}

    for index = 1, #bones do
        local handle = PlayIceOnBone(cfg, effect, ped, bones[index], scale, safeDuration)
        if handle then
            handles[#handles + 1] = handle
        end
    end

    if #handles > 0 then
        activeGlaciesFx[key] = handles
        SetTimeout(safeDuration + 100, function()
            if activeGlaciesFx[key] == handles then
                CleanupGlaciesVisual(key)
            end
        end)
    end
end

local function RotationToDirection(rotation)
    local pitch = math.rad(rotation.x)
    local yaw = math.rad(rotation.z)

    return vector3(
        -math.sin(yaw) * math.cos(pitch),
        math.cos(yaw) * math.cos(pitch),
        math.sin(pitch)
    )
end

local function GetGlaciesAim(maxDistance)
    local distance = maxDistance or 28.0
    local ray = Magic.RaycastFromCamera(distance, -1)
    local cameraCoords = GetGameplayCamCoord()
    local direction = (ray and ray.direction) or RotationToDirection(GetGameplayCamRot(2))
    local endPoint = cameraCoords + (direction * distance)
    local impact = (ray and ray.hit and ray.coords) and ray.coords or endPoint
    local hitEntity = ray and ray.entity or 0
    local targetPed, targetSource = nil, nil

    if hitEntity ~= 0
        and DoesEntityExist(hitEntity)
        and IsEntityAPed(hitEntity)
        and IsPedAPlayer(hitEntity)
        and not IsPedDeadOrDying(hitEntity, true)
    then
        targetPed = hitEntity

        if IsPedAPlayer(targetPed) then
            local player = NetworkGetPlayerIndexFromPed(targetPed)
            if player and player ~= -1 then
                targetSource = GetPlayerServerId(player)
            end
        end
    end

    return {
        impact = impact,
        endPoint = endPoint,
        targetPed = targetPed,
        targetSource = targetSource
    }
end

local function GetHandCoords(ped)
    return GetPedBoneCoords(ped, 57005, 0.12, 0.02, 0.02)
end

local function SetGlaciesState(active)
    if not LocalPlayer or not LocalPlayer.state then return end
    LocalPlayer.state:set("magicGlaciesFrozen", active == true, true)
    LocalPlayer.state:set("Buttons", active == true, true)
end

local function LockLocalPlayerAsIce(duration)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    localFreezeSerial = localFreezeSerial + 1
    local freezeToken = localFreezeSerial
    local endsAt = GetGameTimer() + math.max(1000, tonumber(duration) or 7000)
    frozenLocalPed = ped

    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, true)
    SetGlaciesState(true)

    CreateThread(function()
        while freezeToken == localFreezeSerial and GetGameTimer() < endsAt do
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            FreezeEntityPosition(ped, true)
            Wait(0)
        end

        if freezeToken ~= localFreezeSerial then return end

        if DoesEntityExist(ped) then
            FreezeEntityPosition(ped, false)
        end
        frozenLocalPed = 0
        SetGlaciesState(false)
    end)
end

RegisterNetEvent("magic:client:glaciesBeamFx", function(sourceId, fromCoords, toCoords, duration)
    if tonumber(sourceId) == GetPlayerServerId(PlayerId()) then return end
    if type(fromCoords) ~= "table" or type(toCoords) ~= "table" then return end

    PlayGlaciesBeam(
        vector3(tonumber(fromCoords.x) or 0.0, tonumber(fromCoords.y) or 0.0, tonumber(fromCoords.z) or 0.0),
        vector3(tonumber(toCoords.x) or 0.0, tonumber(toCoords.y) or 0.0, tonumber(toCoords.z) or 0.0),
        duration
    )
end)

RegisterNetEvent("magic:client:glaciesIceVisual", function(netId, duration)
    if not netId then return end

    if _G.MagicProtectedEntities and _G.MagicProtectedEntities[netId] then
        return
    end

    CreateThread(function()
        local timeout = GetGameTimer() + 1800
        local ped = NetworkGetEntityFromNetworkId(netId)
        while (ped == 0 or not DoesEntityExist(ped)) and GetGameTimer() < timeout do
            Wait(50)
            ped = NetworkGetEntityFromNetworkId(netId)
        end

        if ped ~= 0 and DoesEntityExist(ped) and IsEntityAPed(ped) then
            PlayGlaciesFrost(ped, tostring(netId), duration)
        end
    end)
end)

RegisterNetEvent("magic:client:applyGlacies", function(duration)
    if LocalPlayer and LocalPlayer.state and LocalPlayer.state.magicInvulneris then
        Magic.Notify("Invulneris", "O domo arcano bloqueia Glacies.", "inform", 3500)
        return
    end

    LockLocalPlayerAsIce(duration or 7000)
end)

RegisterNetEvent("magic:client:glaciesBlocked", function()
    Magic.Notify("Invulneris", "O domo arcano bloqueia Glacies.", "inform", 3500)
end)

RegisterNetEvent("magic:spells:petrificus", function()
    if glaciesCasting then return end

    local cfg = GetGlaciesConfig()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) then return end

    glaciesCasting = true

    local castTime = math.max(1600, tonumber(cfg.castTime) or 2200)
    local releaseDelay = math.min(castTime - 100, math.max(0, tonumber(cfg.castReleaseDelay) or 1433))
    local beamDuration = math.max(100, math.min(15000, tonumber(cfg.beamDuration) or 700))
    local aim
    local beamStarted = false

    Magic.PlaySpellAnim(cfg)

    local startedAt = GetGameTimer()
    while GetGameTimer() - startedAt < castTime do
        Wait(0)

        if Main and Main.IsMagicLocked and Main.IsMagicLocked() then
            ClearPedSecondaryTask(ped)
            Magic.CancelSpellCast(SPELL_ID)
            glaciesCasting = false
            return
        end

        if not beamStarted and GetGameTimer() - startedAt >= releaseDelay then
            beamStarted = true
            aim = GetGlaciesAim(cfg.distance or 28.0)

            local from = GetHandCoords(ped)
            local to = aim.impact or aim.endPoint
            PlayGlaciesBeam(from, to, beamDuration)
            TriggerServerEvent(
                "magic:server:glaciesBeamFx",
                { x = from.x, y = from.y, z = from.z },
                { x = to.x, y = to.y, z = to.z },
                beamDuration
            )
        end
    end

    ClearPedSecondaryTask(ped)

    aim = aim or GetGlaciesAim(cfg.distance or 28.0)
    local impactCoords = aim.impact or aim.endPoint
    local targetPed = aim.targetPed
    local targetSource = aim.targetSource
    local duration = tonumber(cfg.freezeDuration) or 7000

    PlayGlaciesImpact(impactCoords)

    local targetNetId = 0
    if targetPed and DoesEntityExist(targetPed) then
        targetNetId = NetworkGetNetworkIdFromEntity(targetPed)
    end

    if targetNetId ~= 0 and _G.MagicProtectedEntities and _G.MagicProtectedEntities[targetNetId] then
        Magic.Notify("Invulneris", "O domo arcano bloqueia Glacies.", "inform", 3500)
        Magic.FinishSpellCooldown(SPELL_ID)
        glaciesCasting = false
        return
    end

    if targetPed and DoesEntityExist(targetPed) then
        if targetSource and targetNetId ~= 0 then
            SetNetworkIdCanMigrate(targetNetId, true)
            TriggerServerEvent("magic:server:glaciesPlayer", targetSource, duration, targetNetId)
        end
    end

    Magic.FinishSpellCooldown(SPELL_ID)
    glaciesCasting = false
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for key in pairs(activeGlaciesFx) do
        CleanupGlaciesVisual(key)
    end

    localFreezeSerial = localFreezeSerial + 1
    if frozenLocalPed ~= 0 and DoesEntityExist(frozenLocalPed) then
        FreezeEntityPosition(frozenLocalPed, false)
    end
    frozenLocalPed = 0
    SetGlaciesState(false)
end)
