--[[
    Hi dear customer or developer, here you can fully configure your server's
    framework or you could even duplicate this file to create your own framework.

    If you do not have much experience, we recommend you download the base version
    of the framework that you use in its latest version and it will work perfectly.
]]

local framework = {}
local ESX = exports['es_extended']:getSharedObject()

function framework:getJobsData()
    local jobs = ESX.GetJobs()
    local data = {}
    for k, v in pairs(jobs) do
        data[#data + 1] = {
            name = v.name,
            label = v.label,
            grades = table.map(v.grades, function(grade)
                return {
                    id = grade.id,
                    name = grade.name,
                    label = grade.label,
                    grade = grade.grade
                }
            end)
        }
    end
    return data
end

RegisterNetEvent('esx:playerLoaded', function(id, data)
    Debug('Loaded player:', id)
    if not Config.Phone.requireItem then
        return
    end

    SyncCurrentPhoneFromInventory(id, { closeClientOnMissing = true })
end)

function framework:registerUsableItem(item, cb)
    ESX.RegisterUsableItem(item, cb)
end

function framework:getPlayerFromId(source)
    return ESX.GetPlayerFromId(source)
end

function framework:getSourceFromIdentifier(identifier)
    local player = ESX.GetPlayerFromIdentifier(identifier)
    if not player then return end
    return player.source
end

function framework:getIdentifier(source)
    local player = self:getPlayerFromId(source)
    if not player then return end
    return player?.identifier
end

function framework:setPhoneNumber(source, phoneNumber)
    local player = self:getPlayerFromId(source)
    if not player then
        return
    end

    local num = Core.trim(Core.asString(phoneNumber))
    if num == '' then
        return
    end

    MySQL.update('UPDATE users SET phone_number = ? WHERE identifier = ?', { num, player.identifier })

    if type(PhoneNumberDb) == 'table' and type(PhoneNumberDb.syncOwnerNumber) == 'function' then
        local scopeId = nil
        if type(PhoneManager) == 'table' and type(PhoneManager.getIdentifier) == 'function' then
            scopeId = PhoneManager.getIdentifier(source)
        end
        PhoneNumberDb.syncOwnerNumber(num, player.identifier, scopeId)
    end
end

function framework:getAccountMoney(source, account)
    local player = self:getPlayerFromId(source)
    return player.getAccount(account).money
end

function framework:removeAccountMoney(source, account, amount)
    if amount <= 0 then return true end
    local player = self:getPlayerFromId(source)
    if self:getAccountMoney(source, account) < amount then
        return false
    end
    player.removeAccountMoney(account, amount)
    return true
end

function framework:addAccountMoney(source, account, amount)
    local player = self:getPlayerFromId(source)
    player.addAccountMoney(account, amount)
end

function framework:removeItem(source, item, count)
    local player = self:getPlayerFromId(source)
    if not player then return false end
    local data = player.getInventoryItem(item)
    if not data then return false end
    if data.count < count then return false end
    player.removeInventoryItem(item, count)
    return true
end

function framework:addItem(source, item, count, slot, info)
    local player = self:getPlayerFromId(source)
    if player.canCarryItem(item, count) then
        player.addInventoryItem(item, count, info, slot)
        return true
    end
    return false
end

function framework:getInventory(source)
    local player = self:getPlayerFromId(source)
    return player.getInventory()
end

function framework:getItem(source, item)
    local player = self:getPlayerFromId(source)
    local data = player.getInventoryItem(item)
    if not data then
        return {
            count = 0
        }
    end
    return data
end

-- This is a so much expensive function. Be careful with it !
function framework:getItemList()
    ESX = exports['es_extended']:getSharedObject()
    return ESX.Items
end

-- Get items formatted for UI (ItemAutoComplete)
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
    local player = self:getPlayerFromId(source)
    return player.getGroup() == 'admin' or player.getGroup() == 'superadmin'
end

function framework:getUserName(source)
    local xPlayer = self:getPlayerFromId(source)
    if not xPlayer then
        return 'Unknown', ''
    end

    local firstName, lastName
    if xPlayer.get and xPlayer.get('firstName') and xPlayer.get('lastName') then
        firstName = xPlayer.get('firstName')
        lastName = xPlayer.get('lastName')
    else
        if type(xPlayer.identifier) ~= 'string' or xPlayer.identifier == '' then
            return 'Unknown', ''
        end
        local name = MySQL.Sync.fetchAll('SELECT firstname, lastname FROM users WHERE identifier = ?', { xPlayer.identifier })
        firstName, lastName = name[1]?.firstname or '', name[1]?.lastname or ''
    end

    return firstName, lastName
end

function framework:getUserNameFromIdentifier(identifier)
    local name = MySQL.Sync.fetchAll('SELECT `firstname`, `lastname` FROM `users` WHERE `identifier`=@identifier', { ['@identifier'] = identifier })
    return name[1]?.firstname or '', name[1]?.lastname or ''
end

function framework:getJobName(source)
    local xPlayer = self:getPlayerFromId(source)
    return xPlayer.getJob().name
end

function framework:getJobGrade(source)
    local xPlayer = self:getPlayerFromId(source)
    return xPlayer.getJob().grade
end

function framework:setJob(source, job, grade)
    local xPlayer = self:getPlayerFromId(source)
    if not xPlayer then
        return false
    end
    xPlayer.setJob(job, grade or 0)
    return true
end

function framework:getPlayers()
    return ESX.GetPlayers()
end

function framework:searchPlayers(query)
    return MySQL.query.await('SELECT identifier, firstname, lastname FROM `users` WHERE LOWER(CONCAT(firstname, " ", lastname)) LIKE ? OR LOWER(identifier) LIKE ? LIMIT ?', {
        '%' .. query .. '%',
        '%' .. query .. '%',
        Config.MaxSearchResults
    })
end

-- Used by server/custom/garage (e.g. qs-advancedgarages addToPersistent SQL).
framework.garageTable = 'owned_vehicles'
framework.garageIdentifierColumn = 'owner'

return framework
