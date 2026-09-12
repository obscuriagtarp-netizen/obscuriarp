local function ToVector3(value)
    if type(value) ~= "table" then
        return nil
    end

    local x = tonumber(value.x)
    local y = tonumber(value.y)
    local z = tonumber(value.z)
    if not x or not y or not z then
        return nil
    end

    return vector3(x, y, z)
end

local function GetNearbyPlayerSources(source, radius, includeSource)
    radius = tonumber(radius) or 70.0

    local casterPed = GetPlayerPed(source)
    if not casterPed or casterPed == 0 then
        return {}
    end

    local casterCoords = GetEntityCoords(casterPed)
    local casterBucket = GetPlayerRoutingBucket(source)
    local nearby = {}
    local seen = {}

    local function addPlayer(playerSource)
        playerSource = tonumber(playerSource)
        if includeSource == false and playerSource == source then
            return
        end

        if playerSource and not seen[playerSource] and GetPlayerRoutingBucket(playerSource) == casterBucket then
            seen[playerSource] = true
            nearby[#nearby + 1] = playerSource
        end
    end

    if includeSource ~= false then
        addPlayer(source)
    end

    local players = lib.getNearbyPlayers(casterCoords, radius) or {}
    for i = 1, #players do
        addPlayer(players[i].id)
    end

    return nearby
end

RegisterNetEvent("magic:server:ignisGroundFx", function(pos, radius)
    local source = source
    if not MagicServer.GetCitizenId(source) then
        return
    end

    local coords = ToVector3(pos)
    if not coords then
        return
    end

    for _, playerSource in ipairs(GetNearbyPlayerSources(source, radius or 70.0, false)) do
        TriggerClientEvent("magic:client:ignisGroundFx", playerSource, {
            x = coords.x,
            y = coords.y,
            z = coords.z
        })
    end
end)

RegisterNetEvent("magic:server:ignisChargeFx", function(durationMs, radius)
    local source = source
    if not MagicServer.GetCitizenId(source) then
        return
    end

    local cfg = (Config.Spells and Config.Spells.ignis_conflagratio) or {}
    local duration = math.min(3000, math.max(0, tonumber(durationMs) or 0))
    local syncRadius = math.min(100.0, math.max(5.0, tonumber(radius or cfg.syncRadius) or 70.0))

    for _, playerSource in ipairs(GetNearbyPlayerSources(source, syncRadius, false)) do
        TriggerClientEvent("magic:client:ignisChargeFx", playerSource, source, duration)
    end
end)

RegisterNetEvent("magic:server:ignisBurst", function(payload)
    local source = source
    if not MagicServer.GetCitizenId(source) or type(payload) ~= "table" then
        return
    end

    local fromPos = ToVector3(payload.fromPos)
    local toPos = ToVector3(payload.toPos)
    if not fromPos or not toPos then
        return
    end

    local cfg = (Config.Spells and Config.Spells.ignis_conflagratio) or {}
    local radius = tonumber(payload.syncRadius or cfg.syncRadius) or 70.0

    local casterPed = GetPlayerPed(source)
    if casterPed and casterPed ~= 0 then
        local casterCoords = GetEntityCoords(casterPed)
        if #(casterCoords - fromPos) > 8.0 or #(casterCoords - toPos) > ((cfg.distance or 50.0) + 12.0) then
            return
        end
    end

    payload.casterSrc = source
    payload.fromPos = { x = fromPos.x, y = fromPos.y, z = fromPos.z }
    payload.toPos = { x = toPos.x, y = toPos.y, z = toPos.z }
    payload.hitEntNetId = tonumber(payload.hitEntNetId) or 0
    payload.targetType = tonumber(payload.targetType) or 0
    payload.targetServerId = tonumber(payload.targetServerId) or 0

    if payload.targetType == 1 then
        local validTarget, _, actualNetId = MagicServer.GetPlayerPedNetId(payload.targetServerId)
        if not validTarget or GetPlayerRoutingBucket(validTarget) ~= GetPlayerRoutingBucket(source)
            or actualNetId ~= payload.hitEntNetId then
            payload.hitEntNetId = 0
            payload.targetType = 0
            payload.targetServerId = 0
        end
    end

    local nearby = GetNearbyPlayerSources(source, radius, false)
    for _, playerSource in ipairs(nearby) do
        TriggerClientEvent("magic:client:ignisBurstFx", playerSource, payload)
    end

    if payload.targetServerId > 0 and MagicServer.IsValidPlayer(payload.targetServerId) then
        if GetPlayerRoutingBucket(payload.targetServerId) == GetPlayerRoutingBucket(source) then
            TriggerClientEvent(
                "magic:client:ignisBurnSelf",
                payload.targetServerId,
                tonumber(cfg.burnDuration) or 8000,
                tonumber(cfg.burnTick) or 500,
                tonumber(cfg.burnDamage) or 4,
                source
            )
        end

        return
    end

end)
