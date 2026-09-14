--[[
    Hi dear customer or developer, here you can fully configure your server's
    framework or you could even duplicate this file to create your own framework.

    If you do not have much experience, we recommend you download the base version
    of the framework that you use in its latest version and it will work perfectly.
]]

local framework = {}
local QBCore = exports['qb-core']:GetCoreObject()

function framework:getJobsData()
    local data = {}
    for k, v in pairs(QBCore.Shared.Jobs) do
        data[#data + 1] = {
            name = k,
            label = v.label,
            grades = table.map(v.grades, function(grade, index)
                return {
                    label = grade.name,
                    grade = tonumber(index)
                }
            end)
        }
    end
    return data
end

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    if not Config.Phone.requireItem then
        return
    end

    if Config.Inventory == 'ox_inventory' then
        local maxRetries = 10
        local retryDelay = 500
        CreateThread(function()
            for attempt = 1, maxRetries do
                Wait(retryDelay)
                local items = exports['ox_inventory']:GetInventoryItems(src)
                if items and next(items) then
                    SyncCurrentPhoneFromInventory(src, { closeClientOnMissing = true })
                    return
                end
            end
            SyncCurrentPhoneFromInventory(src, { closeClientOnMissing = true })
        end)
        return
    end

    SyncCurrentPhoneFromInventory(src, { closeClientOnMissing = true })
end)

function framework:registerUsableItem(name, cb)
    QBCore.Functions.CreateUseableItem(name, cb)
end

function framework:getPlayerFromId(source)
    return QBCore.Functions.GetPlayer(source)
end

function framework:getSourceFromIdentifier(identifier)
    local player = QBCore.Functions.GetPlayerByCitizenId(identifier)
    if not player then return end
    return player.PlayerData.source
end

function framework:getIdentifier(source)
    local player = self:getPlayerFromId(source)
    if not player then return end
    return player.PlayerData.citizenid
end

function framework:setPhoneNumber(source, phoneNumber)
    -- No need
end

---@param player table
---@return number
local function getBlackMoney(player)
    local items = player.PlayerData.items
    local totalWorth = 0
    for k, v in pairs(items) do
        if v.name == 'markedbills' then
            totalWorth = totalWorth + v.info.worth
        end
    end
    return totalWorth
end

local function removeBlackMoney(player, amount)
    local items = player.PlayerData.items
    local blackMoney = getBlackMoney(player)
    while blackMoney > 0 and amount > 0 do
        Wait(10)
        Debug('blackMoney:', blackMoney, 'removed:', 'amount:', amount)
        for k, v in pairs(items) do
            if v.name ~= 'markedbills' then goto continue end
            if v.info.worth > amount then
                v.info.worth = v.info.worth - amount
                amount = 0
                break
            else
                amount = amount - v.info.worth
                items[k] = nil
                Debug('removed:', v.info.worth, 'amount:', amount)
            end
            ::continue::
        end
    end
    sv_inventory:setInventory(player.PlayerData.source, items)
end

function framework:getAccountMoney(source, account)
    local player = self:getPlayerFromId(source)
    if account == 'money' then account = 'cash' end
    if account == 'black_money' then return getBlackMoney(player) end
    return player.PlayerData.money[account]
end

function framework:removeAccountMoney(source, account, amount)
    local player = self:getPlayerFromId(source)
    if account == 'money' then account = 'cash' end
    if account == 'black_money' then
        removeBlackMoney(player, amount)
        return
    end
    if self:getAccountMoney(source, account) < amount then
        if (account == 'cash' or account == 'bank') and GetResourceState('ob_bank') == 'started' then
            local transactionId = ('PHONE-%s-%s-%06d'):format(os.time(), source, math.random(0, 999999))
            local ok, charged = pcall(function()
                return exports.ob_bank:ChargeCredit(source, amount, 'Loja do celular', 'Compra pelo smartphone', transactionId)
            end)
            if ok and charged == true then return true end
        end
        return false
    end
    return player.Functions.RemoveMoney(account, amount, 'qs_smartphone_purchase') == true
end

function framework:addAccountMoney(source, account, amount)
    local player = self:getPlayerFromId(source)
    if account == 'money' then account = 'cash' end
    if account == 'black_money' then
        local info = { worth = amount }
        sfr:addItem(source, 'markedbills', 1, false, info)
        return
    end
    player.Functions.AddMoney(account, amount)
end

function framework:removeItem(source, item, count)
    local player = self:getPlayerFromId(source)
    return player.Functions.RemoveItem(item, count)
end

function framework:addItem(source, item, count, slot, info)
    local player = self:getPlayerFromId(source)
    return player.Functions.AddItem(item, count, slot, info)
end

function framework:getInventory(source)
    local player = self:getPlayerFromId(source)
    return player.PlayerData.items
end

function framework:getItem(source, item)
    local player = self:getPlayerFromId(source)
    local data = player.Functions.GetItemByName(item)
    if not data then
        return {
            count = 0
        }
    end
    data.count = data.amount
    return data
end

function framework:getItemList()
    if Config.QBX then
        return exports['qs-inventory']:GetItemList()
    end
    return QBCore.Shared.Items
end

function framework:getItems()
    local itemList = self:getItemList()
    local items = {}

    for name, item in pairs(itemList) do
        items[#items + 1] = {
            name = name,
            label = item.label or name,
            image = 'nui://ox_inventory/web/images/' .. name .. '.png'
        }
    end

    table.sort(items, function(a, b)
        return a.label < b.label
    end)

    return items
end

function framework:playerIsAdmin(source)
    return QBCore.Functions.HasPermission(source, 'god') or IsPlayerAceAllowed(source, 'command') or QBCore.Functions.HasPermission(source, 'admin')
end

function framework:getUserName(source)
    local player = self:getPlayerFromId(source)
    return player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname
end

function framework:getUserNameFromIdentifier(identifier)
    local result = MySQL.Sync.fetchAll('SELECT charinfo FROM `players` WHERE citizenid = ?', { identifier })
    if not result[1] then
        return '', ''
    end
    result = result[1]
    result = json.decode(result.charinfo)
    return result?.firstname, result?.lastname
end

function framework:getJobName(source)
    local player = self:getPlayerFromId(source)
    return player.PlayerData.job.name
end

function framework:getJobGrade(source)
    local player = self:getPlayerFromId(source)
    return player.PlayerData.job.grade.level
end

---@param source number
---@param job string
---@param grade number
---@return boolean
function framework:setJob(source, job, grade)
    local player = self:getPlayerFromId(source)
    if not player then
        return false
    end
    player.Functions.SetJob(job, grade or 0)
    return true
end

function framework:getPlayers()
    return QBCore.Functions.GetPlayers()
end

function framework:searchPlayers(query)
    return MySQL.query.await('SELECT citizenid, charinfo FROM `players` WHERE LOWER(CONCAT(JSON_EXTRACT(charinfo, "$.firstname"), " ", JSON_EXTRACT(charinfo, "$.lastname"))) LIKE ? OR LOWER(citizenid) LIKE ? LIMIT ?', {
        '%' .. query .. '%',
        '%' .. query .. '%',
        Config.MaxSearchResults
    })
end

function framework:setHouseInside(src, insideId)
    local identifier = self:getIdentifier(src)
    MySQL.update.await('UPDATE players SET crime_house_inside = ? WHERE citizenid = ?', { insideId, identifier })
end

function framework:getMeta()
    local player = self:getPlayerFromId(source)
    return player.PlayerData.metadata
end

-- Used by server/custom/garage (e.g. qs-advancedgarages addToPersistent SQL).
framework.garageTable = 'player_vehicles'
framework.garageIdentifierColumn = 'citizenid'

return framework
