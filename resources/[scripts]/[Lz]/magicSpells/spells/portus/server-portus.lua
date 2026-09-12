local nextPortalId = 0
local activePortals = {}
local runeNames = {
    [1] = "Runa violeta",
    [2] = "Runa azul",
    [3] = "Runa verde"
}

local function Notify(source, title, message, notifyType, duration)
    MagicServer.Notify(source, title or "Portus", message or "", notifyType or "inform", duration or 5000)
end

local function GetTableName()
    return MagicServer.GetPortusTable()
end

local function GetConfig()
    return (Config.Spells and Config.Spells["portus"]) or {}
end

local function DistanceBetween(coords, endpoint)
    local dx = coords.x - endpoint.x
    local dy = coords.y - endpoint.y
    local dz = coords.z - endpoint.z
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

local function TriggerClientEventInBucket(eventName, bucket, ...)
    for _, playerId in ipairs(GetPlayers()) do
        playerId = tonumber(playerId)
        if playerId and GetPlayerRoutingBucket(playerId) == bucket then
            TriggerClientEvent(eventName, playerId, ...)
        end
    end
end

local function GetPortalExit(endpoint)
    local heading = tonumber(endpoint.h) or 0.0
    local radians = math.rad(heading)
    local offset = tonumber(GetConfig().portalExitOffset) or 1.85

    return {
        x = endpoint.x - (math.sin(radians) * offset),
        y = endpoint.y + (math.cos(radians) * offset),
        z = tonumber(endpoint.exitZ) or endpoint.z,
        h = heading
    }
end

local function DenyPortalTraversal(source, portalId, reason)
    TriggerClientEvent("magic:client:portusTraverseDenied", source, portalId, reason)
end

local function GetMaxLocations()
    return math.max(1, math.min(3, tonumber(GetConfig().maxLocations) or 3))
end

local function IsValidSlot(slot)
    slot = tonumber(slot)
    return slot and slot >= 1 and slot <= GetMaxLocations() and slot % 1 == 0
end

local function NormalizeLocationSlots(citizenid, rows)
    local used = {}
    local pending = {}

    for _, row in ipairs(rows) do
        local slot = tonumber(row.slot)
        if IsValidSlot(slot) and not used[slot] then
            row.slot = slot
            used[slot] = true
        else
            pending[#pending + 1] = row
        end
    end

    for _, row in ipairs(pending) do
        local available
        for slot = 1, GetMaxLocations() do
            if not used[slot] then
                available = slot
                break
            end
        end

        if not available then
            row.slot = nil
        else
            row.slot = available
            used[available] = true
            MySQL.update.await(
                ("UPDATE `%s` SET `slot` = ? WHERE `id` = ? AND `citizenid` = ?"):format(GetTableName()),
                { available, row.id, citizenid }
            )
        end
    end

    return rows
end

local function GetLocations(citizenid)
    local rows = MySQL.query.await(
        ("SELECT `id`, `slot`, `name`, `x`, `y`, `z`, `heading` FROM `%s` WHERE `citizenid` = ? ORDER BY `id` ASC"):format(GetTableName()),
        { citizenid }
    ) or {}

    NormalizeLocationSlots(citizenid, rows)

    local locations = {}
    for _, row in ipairs(rows) do
        if IsValidSlot(row.slot) then
            locations[#locations + 1] = {
                id = tonumber(row.id),
                slot = tonumber(row.slot),
                name = row.name,
                x = tonumber(row.x),
                y = tonumber(row.y),
                z = tonumber(row.z),
                h = tonumber(row.heading) or 0.0
            }
        end
    end

    table.sort(locations, function(a, b)
        return a.slot < b.slot
    end)

    return locations
end

local function SendPortusLocations(source, citizenid, eraseMode)
    TriggerClientEvent("magic:client:openPortusMenu", source, GetLocations(citizenid), eraseMode == true)
end

local function GetFreeSlot(citizenid)
    local used = {}
    for _, location in ipairs(GetLocations(citizenid)) do
        used[location.slot] = true
    end

    for slot = 1, GetMaxLocations() do
        if not used[slot] then
            return slot
        end
    end

    return nil
end

local function SaveCurrentLocation(source, citizenid, slot, customName)
    slot = tonumber(slot)
    if not IsValidSlot(slot) then
        Notify(source, "Portus", "Runa Portus invalida.", "error", 7000)
        return false
    end

    local occupied = MySQL.scalar.await(
        ("SELECT `id` FROM `%s` WHERE `citizenid` = ? AND `slot` = ? LIMIT 1"):format(GetTableName()),
        { citizenid, slot }
    )
    if occupied then
        Notify(source, "Portus", "Essa runa ja possui um destino marcado.", "error", 7000)
        return false
    end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then
        Notify(source, "Portus", "Nao foi possivel obter seu personagem.", "error", 8000)
        return false
    end

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local name = tostring(customName or runeNames[slot] or ("Runa %s"):format(slot)):sub(1, 60)

    MySQL.insert.await(
        ("INSERT INTO `%s` (`citizenid`, `slot`, `name`, `x`, `y`, `z`, `heading`) VALUES (?, ?, ?, ?, ?, ?, ?)"):format(GetTableName()),
        { citizenid, slot, name, coords.x, coords.y, coords.z, heading }
    )

    Notify(source, "Portus", ("%s vinculada a este local."):format(name), "success", 6000)
    return true
end

RegisterCommand("portus_add", function(source, args)
    if source <= 0 then
        return
    end

    local citizenid = MagicServer.GetCitizenId(source)
    if not citizenid then
        return
    end

    local slot = GetFreeSlot(citizenid)
    if not slot then
        Notify(source, "Portus", "As tres runas ja estao vinculadas.", "error", 8000)
        return
    end

    local customName = table.concat(args or {}, " ")
    SaveCurrentLocation(source, citizenid, slot, customName ~= "" and customName or nil)
end)

RegisterNetEvent("magic:server:requestPortusLocationsForMenu", function(mode)
    local source = source
    local citizenid = MagicServer.GetCitizenId(source)
    if not citizenid then
        return
    end

    local eraseMode = mode == "erase"
    local eraseItem = GetConfig().runeEraseItem
    if eraseMode and not MagicServer.HasItem(source, eraseItem) then
        Notify(source, "Portus", "Voce precisa da cinza de dissolucao.", "error", 7000)
        return
    end

    SendPortusLocations(source, citizenid, eraseMode)
end)

RegisterNetEvent("magic:server:markPortusLocation", function(slot)
    local source = source
    local citizenid = MagicServer.GetCitizenId(source)
    if not citizenid then
        return
    end

    SaveCurrentLocation(source, citizenid, slot)
    SendPortusLocations(source, citizenid, false)
end)

RegisterNetEvent("magic:server:nuiDeletePortusLocation", function(id, slot)
    local source = source
    local citizenid = MagicServer.GetCitizenId(source)
    if not citizenid then
        return
    end

    id = tonumber(id)
    slot = tonumber(slot)
    if not id or not IsValidSlot(slot) then
        return
    end

    local eraseItem = GetConfig().runeEraseItem
    if not MagicServer.HasItem(source, eraseItem) then
        Notify(source, "Portus", "Voce precisa da cinza de dissolucao.", "error", 7000)
        TriggerClientEvent("magic:client:closePortusMenu", source)
        return
    end

    local affected = MySQL.update.await(
        ("DELETE FROM `%s` WHERE `id` = ? AND `slot` = ? AND `citizenid` = ?"):format(GetTableName()),
        { id, slot, citizenid }
    ) or 0

    if affected <= 0 then
        Notify(source, "Portus", "Destino Portus nao encontrado.", "warning", 6000)
    elseif not MagicServer.RemoveItem(source, eraseItem, 1) then
        Notify(source, "Portus", "A runa foi apagada, mas o item nao pode ser consumido.", "warning", 7000)
    else
        Notify(source, "Portus", ("%s foi apagada."):format(runeNames[slot] or "Runa"), "success", 6000)
    end

    TriggerClientEvent("magic:client:closePortusMenu", source)
end)

RegisterNetEvent("magic:server:portusPortalStart", function(center, locationId)
    local source = source
    local citizenid = MagicServer.GetCitizenId(source)
    if not citizenid then
        return
    end

    locationId = tonumber(locationId)
    local centerX = type(center) == "table" and tonumber(center.x) or nil
    local centerY = type(center) == "table" and tonumber(center.y) or nil
    local centerZ = type(center) == "table" and tonumber(center.z) or nil
    if not locationId or not centerX or not centerY or not centerZ then
        return
    end

    local row = MySQL.single.await(
        ("SELECT `slot`, `x`, `y`, `z`, `heading` FROM `%s` WHERE `id` = ? AND `citizenid` = ? LIMIT 1"):format(GetTableName()),
        { locationId, citizenid }
    )
    if not row then
        Notify(source, "Portus", "Destino Portus nao encontrado.", "error", 7000)
        return
    end

    local ped = GetPlayerPed(source)
    local playerCoords = ped and ped ~= 0 and GetEntityCoords(ped) or nil
    if not playerCoords then
        return
    end

    local dx, dy, dz = centerX - playerCoords.x, centerY - playerCoords.y, centerZ - playerCoords.z
    if math.sqrt((dx * dx) + (dy * dy) + (dz * dz)) > 6.0 then
        return
    end

    local cfg = GetConfig()
    local portalCenter = {
        x = centerX,
        y = centerY,
        z = centerZ,
        h = tonumber(center.h) or GetEntityHeading(ped)
    }
    local destinationX = tonumber(row.x)
    local destinationY = tonumber(row.y)
    local destinationGroundZ = tonumber(row.z)
    if not destinationX or not destinationY or not destinationGroundZ then
        Notify(source, "Portus", "As coordenadas dessa runa estao invalidas.", "error", 7000)
        return
    end

    local dest = {
        x = destinationX,
        y = destinationY,
        z = destinationGroundZ + (tonumber(cfg.portalDestinationZOffset) or -1.0),
        exitZ = destinationGroundZ,
        h = tonumber(row.heading) or 0.0
    }
    local runeSlot = tonumber(row.slot) or 1

    nextPortalId = nextPortalId + 1
    local portalId = ("%s:%s:%s"):format(source, os.time(), nextPortalId)
    local duration = tonumber(cfg.portalDuration) or 15000
    local radius = tonumber(cfg.portalRadius) or 1.25
    local bucket = GetPlayerRoutingBucket(source)

    activePortals[portalId] = {
        origin = portalCenter,
        destination = dest,
        radius = radius,
        bucket = bucket,
        expiresAt = GetGameTimer() + duration,
        usedPlayers = {}
    }

    TriggerClientEventInBucket(
        "magic:client:portusPortalStart",
        bucket,
        portalId,
        portalCenter,
        dest,
        radius,
        duration,
        runeSlot
    )
end)

RegisterNetEvent("magic:server:portusTraverse", function(portalId, side)
    local source = source
    portalId = tostring(portalId or "")

    local portal = activePortals[portalId]
    if not portal or GetGameTimer() >= portal.expiresAt then
        activePortals[portalId] = nil
        DenyPortalTraversal(source, portalId, "expired")
        return
    end

    if not MagicServer.GetCitizenId(source) or GetPlayerRoutingBucket(source) ~= portal.bucket then
        DenyPortalTraversal(source, portalId, "invalid")
        return
    end

    if portal.usedPlayers[source] then
        DenyPortalTraversal(source, portalId, "used")
        return
    end

    if side ~= "origin" and side ~= "destination" then
        DenyPortalTraversal(source, portalId, "invalid")
        return
    end

    local ped = GetPlayerPed(source)
    local coords = ped and ped ~= 0 and GetEntityCoords(ped) or nil
    local entrance = portal[side]
    local tolerance = tonumber(GetConfig().portalTraversalTolerance) or 1.0
    if not coords or DistanceBetween(coords, entrance) > (portal.radius + tolerance) then
        DenyPortalTraversal(source, portalId, "distance")
        return
    end

    portal.usedPlayers[source] = true

    local destinationSide = side == "origin" and "destination" or "origin"
    TriggerClientEvent(
        "magic:client:portusTeleport",
        source,
        GetPortalExit(portal[destinationSide]),
        portalId
    )
end)

CreateThread(function()
    while true do
        Wait(1000)

        local now = GetGameTimer()
        for portalId, portal in pairs(activePortals) do
            if now >= portal.expiresAt then
                activePortals[portalId] = nil
            end
        end
    end
end)
