RegisterNetEvent("magic:server:healTarget", function(targetSrc, healFraction, targetNetId, duration)
    local source = source
    if not MagicServer.GetCitizenId(source) then
        return
    end

    local validTarget, _, actualNetId = MagicServer.GetPlayerPedNetId(targetSrc)
    if not validTarget then return end
    if GetPlayerRoutingBucket(source) ~= GetPlayerRoutingBucket(validTarget) then return end
    targetNetId = math.floor(tonumber(targetNetId) or 0)
    if targetNetId > 0 and targetNetId ~= actualNetId then return end

    local healTime = tonumber(duration) or 10000
    TriggerClientEvent("magic:client:applyVitaeHeal", validTarget, tonumber(healFraction) or 1.0, healTime)

    TriggerClientEvent("magic:client:vitaeFx", -1, actualNetId, healTime)
end)

RegisterNetEvent("magic:server:vitaeFx", function(targetNetId, duration)
    if not MagicServer.GetCitizenId(source) or not targetNetId then
        return
    end

    local _, _, actualNetId = MagicServer.GetPlayerPedNetId(source)
    if actualNetId <= 0 or math.floor(tonumber(targetNetId) or 0) ~= actualNetId then return end

    TriggerClientEvent("magic:client:vitaeFx", -1, actualNetId, tonumber(duration) or 10000)
end)
