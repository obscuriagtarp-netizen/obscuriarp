--[[
    Hi dear customer or developer, here you can fully configure your server's
    framework or you could even duplicate this file to create your own framework.

    If you do not have much experience, we recommend you download the base version
    of the framework that you use in its latest version and it will work perfectly.
]]

local framework = {}

function framework:getJobsData()
    return {}
end

function framework:registerUsableItem(item, cb)
    -- Your registerUsableItem function here
end

function framework:getPlayerFromId(source)
    return {
        source = source,
        identifier = sfr:getIdentifier(source)
    }
end

function framework:getSourceFromIdentifier(identifier)
    if not identifier then
        return nil
    end
    identifier = string.gsub(identifier, ' ', '')
    local players = GetPlayers()
    for k, v in pairs(players) do
        if self:getIdentifier(v) == identifier then
            return v
        end
    end
    return nil
end

function framework:getIdentifier(source)
    for k, v in pairs(GetPlayerIdentifiers(source)) do
        if string.sub(v, 1, string.len('license:')) == 'license:' then
            return v:gsub('license:', '')
        end
    end
    return nil
end

function framework:setPhoneNumber(source, phoneNumber)
    -- your setPhoneNumber function here
end

function framework:getAccountMoney(source, account)
    -- your custom function here
    return 0
end

function framework:removeAccountMoney(source, account, amount)
    -- your custom function here
    if amount <= 0 then return true end
    return false
end

function framework:addAccountMoney(source, account, amount)
    -- your custom function here
end

function framework:removeItem(source, item, count)
    -- your custom function here
    return true
end

function framework:addItem(source, item, count, slot, info)
    -- your custom function here
    return true
end

function framework:getInventory(source)
    -- your custom function here
    return {}
end

function framework:getItem(source, item)
    -- your custom function here
    return {
        name = item,
        count = 99,
    }
end

-- This is a so much expensive function. Be careful with it !
function framework:getItemList()
    -- your custom function here
    return {}
end

-- Get items formatted for UI (ItemAutoComplete)
function framework:getItems()
    -- your custom function here
    return {}
end

function framework:playerIsAdmin(source)
    -- your custom function here
    return IsPlayerAceAllowed(source, 'command.qsphone_admin') == 1
end

function framework:getUserName(source)
    -- your custom function here
    return '', ''
end

function framework:getUserNameFromIdentifier(identifier)
    -- your custom function here
    return '', ''
end

function framework:getJobName(source)
    -- your custom function here
    return 'unemployed'
end

function framework:getJobGrade(source)
    -- your custom function here
    return 0
end

function framework:setJob(source, job, grade)
    -- your custom function here
    return false
end

function framework:getPlayers()
    -- your custom function here
    return GetPlayers()
end

function framework:searchPlayers(query)
    return MySQL.query.await('SELECT identifier, firstname, lastname FROM `users` WHERE LOWER(CONCAT(firstname, " ", lastname)) LIKE ? OR LOWER(identifier) LIKE ? LIMIT ?', {
        '%' .. query .. '%',
        '%' .. query .. '%',
        Config.MaxSearchResults
    })
end

-- Used by server/custom/garage (e.g. qs-advancedgarages addToPersistent SQL).
-- Your custom garage table and identifier column here
framework.garageTable = 'owned_vehicles'
framework.garageIdentifierColumn = 'owner'

RegisterNetEvent('phone:playerConnected', function()
    local src = source
    -- we set the identifier to the player state. so we can use it in client.
    Player(src).state:set('identifier', sfr:getIdentifier(src))
end)


return framework
