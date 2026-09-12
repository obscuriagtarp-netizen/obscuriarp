local framework = {}
local ESX = exports['es_extended']:getSharedObject()

RegisterNetEvent('esx:playerLoaded', function(playerData)
    PlayerData = playerData
    Wait(2500)
end)

RegisterNetEvent('esx:playerLogout', function()
    Device.resetForCharacterLogout()
end)

function framework:getPlayerData()
    return ESX.GetPlayerData()
end

function framework:getObject()
    return ESX
end

CreateThread(function()
    PlayerData = framework:getPlayerData()
end)

RegisterNetEvent('esx:setJob', function(jobData)
    PlayerData.job = jobData
end)

function framework:getIdentifier()
    return PlayerData?.identifier
end

function framework:getJobName()
    return PlayerData?.job?.name or 'unemployed'
end

function framework:getJobGrade()
    return PlayerData?.job?.grade or 0
end

function framework:getPlayers()
    return ESX.Game.GetPlayers()
end

RegisterNetEvent('esx:removeInventoryItem', function(item)
    if ShouldSyncPhoneInventoryOnItemChange(item) then
        Device.syncInventory()
    end
end)

RegisterNetEvent('esx:addInventoryItem', function(item)
    if ShouldSyncPhoneInventoryOnItemChange(item) then
        Device.syncInventory()
    end
end)

return framework
