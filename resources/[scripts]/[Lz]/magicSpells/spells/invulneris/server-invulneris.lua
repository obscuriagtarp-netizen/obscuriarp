
RegisterNetEvent("magic:server:invulnerisPlayer", function(targetSrc, duration, targetNet)
    local src = source
    duration  = tonumber(duration) or 120000

    if not MagicServer.GetCitizenId(src) then
        return
    end

    local validTarget, _, actualNet = MagicServer.GetPlayerPedNetId(targetSrc)
    if not validTarget then return end
    if GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(validTarget) then return end
    targetNet = math.floor(tonumber(targetNet) or 0)
    if targetNet > 0 and targetNet ~= actualNet then return end

    TriggerClientEvent("magic:client:applyInvulneris", validTarget, duration)
    TriggerClientEvent("magic:client:startInvulnerisFx", -1, actualNet, duration)
end)

RegisterNetEvent("magic:server:invulnerisFxBroadcast", function(targetNet, duration)
    if not MagicServer.GetCitizenId(source) then
        return
    end

    duration = tonumber(duration) or 120000
    if not targetNet then return end

    local _, _, actualNet = MagicServer.GetPlayerPedNetId(source)
    if actualNet <= 0 or math.floor(tonumber(targetNet) or 0) ~= actualNet then return end

    TriggerClientEvent("magic:client:startInvulnerisFx", -1, actualNet, duration)
end)
