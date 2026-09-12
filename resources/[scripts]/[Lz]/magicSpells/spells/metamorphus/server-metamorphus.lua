local savedSkinData = {}

RegisterNetEvent("magic:server:saveSkinBeforeMetamorph", function(skinData)
    if not skinData then
        return
    end

    savedSkinData[source] = skinData
end)

RegisterNetEvent("magic:server:restoreSkinAfterMetamorph", function()
    local source = source
    local skin = savedSkinData[source]
    if not skin then
        return
    end

    TriggerClientEvent("magic:client:restoreAppearanceNet", -1, source, skin)
    savedSkinData[source] = nil
end)

RegisterNetEvent("magic:server:metamorphPlayer", function(targetSrc, duration)
    local source = source
    if not MagicServer.GetCitizenId(source) then return end
    local validTarget = MagicServer.GetPlayerPedNetId(targetSrc)
    if not validTarget or GetPlayerRoutingBucket(source) ~= GetPlayerRoutingBucket(validTarget) then return end

    TriggerClientEvent("magic:client:metamorphPlayer", validTarget, tonumber(duration) or 20000)
end)

RegisterNetEvent("magic:server:metamorphusFxBroadcast", function(netId, duration)
    if not MagicServer.GetCitizenId(source) or not netId then return end
    local targetSource, _, actualNetId = MagicServer.GetPlayerSourceFromNetId(netId)
    if not targetSource or GetPlayerRoutingBucket(source) ~= GetPlayerRoutingBucket(targetSource) then return end

    TriggerClientEvent("magic:client:metamorphusFx", -1, actualNetId, tonumber(duration) or 20000)
end)
