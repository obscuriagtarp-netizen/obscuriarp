local framework = {}
local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = framework:getPlayerData()
    Wait(2500)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    Device.resetForCharacterLogout()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(jobData)
    PlayerData.job = jobData
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(duty)
    PlayerData.job.onduty = duty
end)

CreateThread(function()
    PlayerData = framework:getPlayerData()
end)

function framework:getPlayerData()
    return QBCore.Functions.GetPlayerData()
end

function framework:getObject()
    return QBCore
end

function framework:getIdentifier()
    return PlayerData.citizenid
end

function framework:getJobName()
    return PlayerData?.job?.name or 'unemployed'
end

function framework:getJobGrade()
    return PlayerData?.job?.grade?.level or 0
end

function framework:getPlayers()
    return QBCore.Functions.GetPlayers()
end

RegisterNetEvent('QBCore:Client:OnGangUpdate', function(gangData)
    PlayerData.gang = gangData
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(newData)
    local oldItems = PlayerData and PlayerData.items
    PlayerData = newData

    if Config.Inventory == 'ox_inventory' then
        return
    end

    local newItems = newData and newData.items
    if oldItems == newItems then
        return
    end

    Device.syncInventory()
end)

if Config.Inventory == 'ox_inventory' then
    AddEventHandler('ox_inventory:updateInventory', function(changes)
        if type(changes) ~= 'table' then
            Device.syncInventory()
            return
        end

        for i = 1, #changes do
            local change = changes[i]
            if type(change) == 'table' then
                local itemName = change.name or (change.metadata and change.metadata.name)
                if ShouldSyncPhoneInventoryOnItemChange(itemName or change) then
                    Device.syncInventory()
                    return
                end
            end
        end
    end)

    RegisterNetEvent('ox_inventory:itemCount', function(itemName)
        if ShouldSyncPhoneInventoryOnItemChange(itemName) then
            Device.syncInventory()
        end
    end)
end

return framework
