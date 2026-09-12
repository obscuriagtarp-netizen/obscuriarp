local Magic = MagicHelpers

local portusCasting = false
local runeMarking = false
local portusStopping = false
local activePortals = {}
local usedPortals = {}
local pendingPortals = {}

local function GetPortusConfig()
    return (Config.Spells and Config.Spells["portus"]) or {}
end

local function EnsurePtfxAsset(asset)
    if HasNamedPtfxAssetLoaded(asset) then
        return true
    end

    RequestNamedPtfxAsset(asset)
    local timeout = GetGameTimer() + 2500
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < timeout do
        Wait(0)
    end

    return HasNamedPtfxAssetLoaded(asset)
end

local function ToVector3(value)
    if type(value) ~= "table" then
        return nil
    end

    local x, y, z = tonumber(value.x), tonumber(value.y), tonumber(value.z)
    if not x or not y or not z then
        return nil
    end

    return vector3(x, y, z)
end

local function PackPortalCenter(coords, heading)
    return { x = coords.x, y = coords.y, z = coords.z, h = heading or 0.0 }
end

local function GetPortalCenterInFront(ped, cfg)
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local distance = cfg.portalForwardOffset or 2.35
    local center = vector3(
        coords.x + (forward.x * distance),
        coords.y + (forward.y * distance),
        coords.z
    )

    local ok, groundZ = GetGroundZFor_3dCoord(center.x, center.y, center.z + 3.0, false)
    if ok then
        center = vector3(center.x, center.y, groundZ + 0.08)
    end

    return center
end

local function StartPortusCastFx()
    StartScreenEffect("SwitchShortMichaelIn", 0, true)
    SetTimecycleModifier("BarryFadeOut")
    SetTimecycleModifierStrength(0.18)
end

local function StopPortusCastFx()
    StopScreenEffect("SwitchShortMichaelIn")
    ClearTimecycleModifier()
end

local function PlayPortusTeleportFx()
    StartScreenEffect("DrugsMichaelAliensFightIn", 0, true)
    StartScreenEffect("SwitchShortMichaelIn", 0, true)
    SetTimecycleModifier("spectator5")
    SetTimecycleModifierStrength(0.72)
    DoScreenFadeOut(450)
    Wait(520)
end

local function TeleportThroughPortus(dest)
    if not dest or not dest.x or not dest.y or not dest.z then
        return
    end

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) then
        return
    end

    PlayPortusTeleportFx()
    SetEntityCoords(ped, dest.x, dest.y, dest.z + 0.15, false, false, false, false)
    SetEntityHeading(ped, dest.h or 0.0)
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
    Wait(120)
    DoScreenFadeIn(760)
    Wait(620)
    StopScreenEffect("SwitchShortMichaelIn")
    StopScreenEffect("DrugsMichaelAliensFightIn")
    ClearTimecycleModifier()
end

local function DeletePortalEntity(entity)
    if not entity or not DoesEntityExist(entity) then
        return
    end

    local cfg = GetPortusConfig()
    local animDict = cfg.portalAnimDict or "anim@portal_anim"
    local animName = cfg.portalAnimName or "portal_anim"

    StopEntityAnim(entity, animName, animDict, -1000.0)
    FreezeEntityPosition(entity, false)
    SetEntityCollision(entity, false, false)
    DetachEntity(entity, true, true)
    SetEntityAsMissionEntity(entity, true, true)
    DeleteObject(entity)

    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end

local function DeletePortalObjects(portal)
    for _, entity in ipairs({ portal.baseObject, portal.animatedObject }) do
        DeletePortalEntity(entity)
    end

    portal.baseObject = nil
    portal.animatedObject = nil
end

local function CleanupOrphanedPortalObjects()
    local portalModels = {
        [GetHashKey("portal_dungeon")] = true,
        [GetHashKey("portal_anim")] = true
    }

    for _, entity in ipairs(GetGamePool("CObject")) do
        if DoesEntityExist(entity) and portalModels[GetEntityModel(entity)] then
            DeletePortalEntity(entity)
        end
    end
end

local function GetPortalAuraPoint(portal, radius, angle, zOffset)
    local heading = math.rad(portal.heading)
    local lateral = math.cos(angle) * radius

    return vector3(
        portal.center.x + (math.cos(heading) * lateral),
        portal.center.y + (math.sin(heading) * lateral),
        portal.center.z + zOffset + (math.sin(angle) * radius)
    )
end

local function GetPortalColor(runeSlot)
    local colors = GetPortusConfig().portalRuneColors or {}
    return colors[tonumber(runeSlot)] or colors[1] or {
        particle = { 0.76, 0.12, 1.0 },
        light = { 175, 48, 255 }
    }
end

local function GetPortalFx(runeSlot)
    local cfg = GetPortusConfig()
    local effects = cfg.portalRuneFx or {}
    return effects[tonumber(runeSlot)] or effects[1] or {
        asset = cfg.portalAuraAsset or "ob_fogo_roxo",
        effect = cfg.portalAuraEffect or "ob_fogo_roxo"
    }
end

local function SpawnPortalAura(portal, cfg, radius, angle, scale, alpha)
    local zOffset = cfg.portalVisualZOffset or 1.28
    local point = GetPortalAuraPoint(portal, radius, angle, zOffset)
    local particleColor = portal.color.particle

    UseParticleFxAssetNextCall(portal.auraAsset or cfg.portalAuraAsset or "ob_fogo_roxo")
    SetParticleFxNonLoopedColour(particleColor[1], particleColor[2], particleColor[3])
    SetParticleFxNonLoopedAlpha(alpha)
    StartParticleFxNonLoopedAtCoord(
        portal.auraEffect or cfg.portalAuraEffect or "ob_fogo_roxo",
        point.x, point.y, point.z,
        0.0, 0.0, portal.heading,
        scale,
        false, false, false
    )
end

local function DrawPortalVisual(portal)
    if portusStopping then
        return
    end

    local cfg = GetPortusConfig()
    local now = GetGameTimer()
    local centerZ = portal.center.z + (cfg.portalVisualZOffset or 1.28)
    local pulse = 0.42 + ((math.sin(now / 260.0) + 1.0) * 0.08)
    local lightColor = portal.color.light
    DrawLightWithRange(
        portal.center.x, portal.center.y, centerZ,
        lightColor[1], lightColor[2], lightColor[3],
        cfg.portalGlowRange or 4.0,
        pulse
    )

    local auraAsset = portal.auraAsset or cfg.portalAuraAsset or "ob_fogo_roxo"
    if now >= (portal.nextAuraFx or 0) and EnsurePtfxAsset(auraAsset) then
        portal.nextAuraFx = now + (cfg.portalAuraInterval or 180)
        portal.auraAngle = (portal.auraAngle or 0.0) + 0.3

        local outerRadius = cfg.portalAuraRadius or 1.24
        local middleRadius = cfg.portalAuraMiddleRadius or 1.05
        local innerRadius = cfg.portalAuraInnerRadius or 0.88
        local outerScale = cfg.portalAuraScale or 0.22
        local middleScale = cfg.portalAuraMiddleScale or 0.18
        local innerScale = cfg.portalAuraInnerScale or 0.14

        for index = 0, 4 do
            SpawnPortalAura(portal, cfg, outerRadius, portal.auraAngle + (((math.pi * 2.0) / 5.0) * index), outerScale, 0.5)
        end

        for index = 0, 3 do
            SpawnPortalAura(portal, cfg, middleRadius, (-portal.auraAngle * 1.2) + ((math.pi * 0.5) * index), middleScale, 0.4)
        end

        for index = 0, 2 do
            SpawnPortalAura(portal, cfg, innerRadius, (portal.auraAngle * 1.45) + (((math.pi * 2.0) / 3.0) * index), innerScale, 0.32)
        end
    end
end

local function CreatePortalEndpoint(side, center, radius, pedCoords, color, fx)
    local portalCenter = ToVector3(center)
    if not portalCenter then
        return nil
    end

    return {
        side = side,
        center = portalCenter,
        heading = tonumber(center.h) or 0.0,
        color = color,
        auraAsset = fx.asset,
        auraEffect = fx.effect,
        radius = radius,
        nextAuraFx = 0,
        auraAngle = 0.0,
        wasInside = pedCoords and #(pedCoords - portalCenter) <= radius or false
    }
end

local function DeletePortalPair(pair)
    for _, portal in pairs(pair.endpoints or {}) do
        DeletePortalObjects(portal)
    end
end

local function AddPortalPair(portalId, origin, destination, radius, duration, runeSlot)
    if portusStopping then
        return
    end

    if not portalId or not origin or not destination then
        return
    end

    local cfg = GetPortusConfig()
    radius = tonumber(radius) or (cfg.portalRadius or 1.25)

    local ped = PlayerPedId()
    local pedCoords = DoesEntityExist(ped) and GetEntityCoords(ped) or nil
    local color = GetPortalColor(runeSlot)
    local fx = GetPortalFx(runeSlot)
    local originEndpoint = CreatePortalEndpoint("origin", origin, radius, pedCoords, color, fx)
    local destinationEndpoint = CreatePortalEndpoint("destination", destination, radius, pedCoords, color, fx)
    if not originEndpoint or not destinationEndpoint then
        return
    end

    activePortals[tostring(portalId)] = {
        id = tostring(portalId),
        endsAt = GetGameTimer() + (tonumber(duration) or (cfg.portalDuration or 15000)),
        endpoints = {
            origin = originEndpoint,
            destination = destinationEndpoint
        }
    }
end

RegisterNetEvent("magic:client:portusTeleport", function(dest, portalId)
    portalId = tostring(portalId or "")
    pendingPortals[portalId] = nil
    usedPortals[portalId] = true

    CreateThread(function()
        TeleportThroughPortus(dest)
    end)
end)

RegisterNetEvent("magic:client:portusTraverseDenied", function(portalId, reason)
    portalId = tostring(portalId or "")
    pendingPortals[portalId] = nil

    if reason == "used" then
        usedPortals[portalId] = true
    end
end)

RegisterNetEvent("magic:client:portusPortalStart", function(portalId, origin, destination, radius, duration, runeSlot)
    AddPortalPair(portalId, origin, destination, radius, duration, runeSlot)
end)

CreateThread(function()
    while true do
        if not next(activePortals) then
            Wait(1000)
        else
            local now = GetGameTimer()
            local ped = PlayerPedId()
            local pedCoords = DoesEntityExist(ped) and GetEntityCoords(ped) or nil
            local renderDistance = tonumber(GetPortusConfig().portalRenderDistance) or 80.0
            local waitTime = 250

            for id, portal in pairs(activePortals) do
                if now >= portal.endsAt then
                    DeletePortalPair(portal)
                    activePortals[id] = nil
                    usedPortals[id] = nil
                    pendingPortals[id] = nil
                else
                    for _, endpoint in pairs(portal.endpoints) do
                        local dist = pedCoords and #(pedCoords - endpoint.center) or math.huge
                        if dist <= renderDistance then
                            waitTime = 0
                            DrawPortalVisual(endpoint)
                        elseif dist <= renderDistance + 40.0 then
                            waitTime = math.min(waitTime, 100)
                        end

                        local isInside = dist <= (endpoint.radius or 1.25)
                        if isInside
                            and not endpoint.wasInside
                            and not usedPortals[id]
                            and not pendingPortals[id]
                            and not IsPedDeadOrDying(ped, true)
                        then
                            pendingPortals[id] = true
                            TriggerServerEvent("magic:server:portusTraverse", id, endpoint.side)
                        end

                        endpoint.wasInside = isInside
                    end
                end
            end

            Wait(waitTime)
        end
    end
end)

local function StartRuneMarking(slot)
    slot = tonumber(slot)
    if portusStopping or runeMarking or portusCasting or not slot or slot < 1 or slot > 3 then
        return
    end

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) then
        return
    end

    local cfg = GetPortusConfig()
    local duration = cfg.runeMarkDuration or 2200
    local coords = GetEntityCoords(ped)
    local ok, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 2.0, false)
    if ok then
        coords = vector3(coords.x, coords.y, groundZ + 0.08)
    end

    runeMarking = true
    StartPortusCastFx()
    StartScreenEffect("DrugsMichaelAliensFightIn", duration, false)
    Magic.PlaySpellAnim(cfg)

    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set("Buttons", true, true)
    end

    local startedAt = GetGameTimer()
    local nextFx = 0
    while GetGameTimer() - startedAt < duration do
        Wait(0)
        DisableControlAction(0, 21, true)
        DisableControlAction(0, 22, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)

        local now = GetGameTimer()
        if now >= nextFx and EnsurePtfxAsset(cfg.portalFxAsset or "scr_powerplay") then
            nextFx = now + 120
            local progress = (now - startedAt) / duration
            local angle = progress * math.pi * 8.0
            local radius = 0.82 * (1.0 - (progress * 0.35))
            local fxX = coords.x + math.cos(angle) * radius
            local fxY = coords.y + math.sin(angle) * radius

            UseParticleFxAssetNextCall(cfg.portalFxAsset or "scr_powerplay")
            SetParticleFxNonLoopedColour(0.5, 0.08, 0.92)
            SetParticleFxNonLoopedAlpha(0.9)
            StartParticleFxNonLoopedAtCoord(
                cfg.portalFxEffect or "sp_powerplay_beast_appear_trails",
                fxX, fxY, coords.z + (progress * 0.7),
                0.0, 0.0, math.deg(angle),
                0.8,
                false, false, false
            )
        end
    end

    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set("Buttons", false, true)
    end

    ClearPedTasks(ped)
    StopScreenEffect("DrugsMichaelAliensFightIn")
    StopPortusCastFx()
    runeMarking = false
    TriggerServerEvent("magic:server:markPortusLocation", slot)
end

RegisterNetEvent("magic:client:openPortusMenu", function(locations, eraseMode)
    SendNUIMessage({
        action = "openPortusMenu",
        locations = locations or {},
        eraseMode = eraseMode == true
    })

    SetNuiFocus(true, true)
end)

RegisterNetEvent("magic:client:closePortusMenu", function()
    SendNUIMessage({ action = "closePortusMenu" })
    SetNuiFocus(false, false)
end)

RegisterNetEvent("magic:client:usePortusRuneEraser", function()
    TriggerServerEvent("magic:server:requestPortusLocationsForMenu", "erase")
end)

exports("OpenPortusRuneEraser", function()
    TriggerServerEvent("magic:server:requestPortusLocationsForMenu", "erase")
end)

local function StartPortusPortal(locationId)
    if portusStopping or portusCasting then
        return
    end

    locationId = tonumber(locationId)
    if not locationId then
        Magic.Notify("Negado", "Destino Portus invalido.", "error", 6000)
        return
    end

    local cfg = GetPortusConfig()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) then
        return
    end

    portusCasting = true

    local castTime = cfg.castTime or 4000
    local portalDuration = cfg.portalDuration or 15000
    local center = GetPortalCenterInFront(ped, cfg)
    local heading = GetEntityHeading(ped)

    StartPortusCastFx()

    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set("Buttons", true, true)
    end

    Magic.PlaySpellAnim(cfg)
    TriggerEvent("Progress", "Abrindo Portus", castTime)
    Magic.ShowHints("Portus", {
        "Abrindo portal Portus a sua frente.",
        ("O portal ficara ativo por %.0f segundos."):format(portalDuration / 1000),
        "Cada pessoa podera atravessar este par uma unica vez."
    })

    local startedAt = GetGameTimer()
    while GetGameTimer() - startedAt < castTime do
        Wait(0)
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        DisableControlAction(0, 21, true)
        DisableControlAction(0, 22, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
    end

    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set("Buttons", false, true)
    end

    ClearPedTasks(ped)
    StopPortusCastFx()
    Magic.HideHints()

    TriggerServerEvent(
        "magic:server:portusPortalStart",
        PackPortalCenter(center, heading),
        locationId
    )

    Magic.Notify("Portus", "Portal aberto. Atravesse para viajar.", "success", 5000)
    Magic.ApplyDamageToPlayer(10)
    Magic.FinishSpellCooldown("portus")
    portusCasting = false
end

RegisterNetEvent("magic:spells:portus", function()
    if portusCasting then
        return
    end

    TriggerServerEvent("magic:server:requestPortusLocationsForMenu", "open")
end)

RegisterNUICallback("portus_close", function(_, cb)
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNUICallback("portus_mark", function(data, cb)
    SetNuiFocus(false, false)
    StartRuneMarking(data and data.slot)
    cb({})
end)

RegisterNUICallback("portus_delete", function(data, cb)
    local id = tonumber(data.id)
    local slot = tonumber(data.slot)
    SetNuiFocus(false, false)
    if id and slot then
        TriggerServerEvent("magic:server:nuiDeletePortusLocation", id, slot)
    end
    cb({})
end)

RegisterNUICallback("portus_select", function(data, cb)
    SetNuiFocus(false, false)

    local locationId = data and tonumber(data.id)
    if locationId then
        StartPortusPortal(locationId)
    else
        Magic.Notify("Negado", "Destino Portus invalido.", "error", 7000)
    end

    cb({})
end)

AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    portusStopping = false
    CleanupOrphanedPortalObjects()
end)

local function HandlePortusResourceStop(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if portusStopping then
        return
    end

    portusStopping = true

    for _, portal in pairs(activePortals) do
        DeletePortalPair(portal)
    end

    CleanupOrphanedPortalObjects()

    activePortals = {}
    usedPortals = {}
    pendingPortals = {}
    runeMarking = false
    StopPortusCastFx()
    StopScreenEffect("DrugsMichaelAliensFightIn")
    SetNuiFocus(false, false)
end

AddEventHandler("onResourceStop", HandlePortusResourceStop)
AddEventHandler("onClientResourceStop", HandlePortusResourceStop)
