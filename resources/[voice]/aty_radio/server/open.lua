RegisterCallback("radio:finishExam", function(src, data)
    -- You can add your code here
end)

---@param source number The players server id
function GetPlayerNameBySource(source)
    if Utils.Framework == "es_extended" then
        local player = GetPlayer(source)
        return player.getName()
    elseif Utils.Framework == "qb-core" then
        local player = GetPlayer(source)
        return player.PlayerData.charinfo.firstname.." "..player.PlayerData.charinfo.lastname
    else
        return GetPlayerName(source)
    end
end

CreateThread(function()
    while not initialized do
        Wait(100)
    end

    if not Config.ItemSettings.RequireItem then
        return
    end
    
    RegisterItem(Config.ItemSettings.Item, function(src)
        TriggerClientEvent("aty_radio:client:openRadio", src)
    end)
end)