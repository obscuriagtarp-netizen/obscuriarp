RegisterNetEvent("magic:server:machinaRepairFx", function(vehNetId)
    if not MagicServer.GetCitizenId(source) then
        return
    end

    if not vehNetId then
        return
    end

    TriggerClientEvent("magic:client:machinaRepairFx", -1, vehNetId)
end)
