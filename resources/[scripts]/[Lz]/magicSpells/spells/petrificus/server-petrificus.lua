local SPELL_ID = "petrificus"
local glaciesFxRateLimits = {}

local function GetGlaciesConfig()
    return (Config.Spells and Config.Spells[SPELL_ID]) or {}
end

local function NormalizeCoords(coords)
    if type(coords) ~= "table" then return nil end

    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)
    if not x or not y or not z then return nil end
    return vector3(x, y, z)
end

local function ValidGlaciesDistance(source, targetEntity, extraDistance)
    local sourcePed = GetPlayerPed(source)
    if sourcePed == 0 or targetEntity == 0 then return false end

    local maximum = tonumber(GetGlaciesConfig().distance) or 28.0
    return #(GetEntityCoords(sourcePed) - GetEntityCoords(targetEntity))
        <= maximum + (tonumber(extraDistance) or 3.0)
end

local function HasInvulneris(playerSource, entity)
    if playerSource then
        local player = Player(playerSource)
        if player and player.state and player.state.magicInvulneris == true then
            return true
        end
    end

    if entity and entity ~= 0 then
        local state = Entity(entity).state
        return state and state.magicInvulneris == true
    end

    return false
end

RegisterNetEvent("magic:server:glaciesPlayer", function(targetSource, duration, targetNetId)
    local source = source
    targetSource = tonumber(targetSource)
    if not MagicServer.HasPendingCast(source, SPELL_ID) then return end
    if not MagicServer.IsValidPlayer(targetSource) then return end
    if not MagicServer.GetCitizenId(source) then return end
    if GetPlayerRoutingBucket(source) ~= GetPlayerRoutingBucket(targetSource) then return end

    local targetPed = GetPlayerPed(targetSource)
    if targetPed == 0 or not ValidGlaciesDistance(source, targetPed, 4.0) then return end

    if HasInvulneris(targetSource, targetPed) then
        TriggerClientEvent("magic:client:glaciesBlocked", source)
        return
    end

    local cfg = GetGlaciesConfig()
    local safeDuration = math.max(1000, math.min(15000, tonumber(duration) or cfg.freezeDuration or 7000))
    local actualNetId = NetworkGetNetworkIdFromEntity(targetPed)
    if actualNetId == 0 then return end

    targetNetId = tonumber(targetNetId)
    if targetNetId and targetNetId ~= actualNetId then return end

    TriggerClientEvent("magic:client:applyGlacies", targetSource, safeDuration)
    TriggerClientEvent("magic:client:glaciesIceVisual", -1, actualNetId, safeDuration)
end)

RegisterNetEvent("magic:server:glaciesFx", function(targetNetId, duration)
    local source = source
    if not MagicServer.HasPendingCast(source, SPELL_ID) then return end
    if not MagicServer.GetCitizenId(source) then return end

    targetNetId = tonumber(targetNetId)
    if not targetNetId then return end

    local targetEntity = NetworkGetEntityFromNetworkId(targetNetId)
    if targetEntity == 0 or GetEntityType(targetEntity) ~= 1 then return end
    local targetSource = MagicServer.GetPlayerSourceFromPed(targetEntity)
    if not targetSource or GetPlayerRoutingBucket(source) ~= GetPlayerRoutingBucket(targetSource) then return end
    if not ValidGlaciesDistance(source, targetEntity, 4.0) then return end
    if HasInvulneris(nil, targetEntity) then return end

    local cfg = GetGlaciesConfig()
    local safeDuration = math.max(1000, math.min(15000, tonumber(duration) or cfg.freezeDuration or 7000))
    TriggerClientEvent("magic:client:glaciesIceVisual", -1, targetNetId, safeDuration)
end)

RegisterNetEvent("magic:server:glaciesBeamFx", function(fromCoords, toCoords, duration)
    local source = source
    if not MagicServer.HasPendingCast(source, SPELL_ID) then return end
    if not MagicServer.GetCitizenId(source) then return end

    local now = GetGameTimer()
    if glaciesFxRateLimits[source] and now - glaciesFxRateLimits[source] < 500 then return end
    glaciesFxRateLimits[source] = now

    local from = NormalizeCoords(fromCoords)
    local to = NormalizeCoords(toCoords)
    if not from or not to then return end

    local sourcePed = GetPlayerPed(source)
    if sourcePed == 0 or #(GetEntityCoords(sourcePed) - from) > 5.0 then return end

    local maximum = tonumber(GetGlaciesConfig().distance) or 28.0
    if #(to - from) > maximum + 4.0 then return end

    TriggerClientEvent(
        "magic:client:glaciesBeamFx",
        -1,
        source,
        { x = from.x, y = from.y, z = from.z },
        { x = to.x, y = to.y, z = to.z },
        math.max(100, math.min(15000, tonumber(duration) or 700))
    )
end)

AddEventHandler("playerDropped", function()
    glaciesFxRateLimits[source] = nil
end)
