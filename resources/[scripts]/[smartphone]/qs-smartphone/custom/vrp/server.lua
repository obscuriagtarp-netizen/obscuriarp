local framework = {}

local vRP
local vRPclient
local IS_VRP2 = false

--- Load vRP utils.lua into this resource context so module() is available.
local function ensureVRPModule()
    if module then
        return true
    end

    local utils = LoadResourceFile('vrp', 'lib/utils.lua')
    if not utils then
        return false
    end

    local chunk, err = load(utils, '@vrp/lib/utils.lua')
    if not chunk then
        print(('^1[qs-smartphone]^7 Failed to load vRP utils: %s'):format(err or 'unknown'))
        return false
    end

    chunk()
    return module ~= nil
end

local function initVRP()
    if vRP then
        return true
    end

    if not ensureVRPModule() then
        error('[qs-smartphone] vRP resource is required. Ensure "vrp" is started before qs-smartphone.', 0)
    end

    local Proxy = module('vrp', 'lib/Proxy')
    local Tunnel = module('vrp', 'lib/Tunnel')

    vRP = Proxy.getInterface('vRP')
    vRPclient = Tunnel.getInterface('vRP', 'qs-smartphone')

    IS_VRP2 = type(vRP.users_by_source) == 'table'
        or type(vRP.EXT) == 'table'
        or (type(vRP.getUserId) ~= 'function' and type(vRP.users) == 'table')

    print(('^2[qs-smartphone]^7 vRP adapter loaded (%s).'):format(IS_VRP2 and 'vRP 2.x' or 'vRP 1.x'))
    return true
end

initVRP()

---@param source number
---@return number|nil
local function getUserId(source)
    if not source then
        return nil
    end

    if IS_VRP2 then
        local user = vRP.users_by_source and vRP.users_by_source[source]
        if user then
            return user.id
        end
        return nil
    end

    if vRP.getUserId then
        return vRP.getUserId({ source })
    end

    return nil
end

---@param user_id number|string
---@return number|nil
local function getSourceFromUserId(user_id)
    local id = tonumber(user_id)
    if not id then
        return nil
    end

    if IS_VRP2 then
        local user = vRP.users and vRP.users[id]
        return user and user.source or nil
    end

    if vRP.getUserSource then
        return vRP.getUserSource({ id })
    end

    return nil
end

---@param source number
---@return table|nil
local function getVRPUser(source)
    if IS_VRP2 then
        return vRP.users_by_source and vRP.users_by_source[source] or nil
    end

    local user_id = getUserId(source)
    if not user_id then
        return nil
    end

    return {
        source = source,
        user_id = user_id,
        id = user_id,
    }
end

---@param user_id number|string
---@return table|nil
local function getIdentityByUserId(user_id)
    local id = tonumber(user_id)
    if not id then
        return nil
    end

    if IS_VRP2 and vRP.EXT and vRP.EXT.Identity then
        local src = getSourceFromUserId(id)
        if src then
            local user = vRP.users_by_source[src]
            if user and user.cid then
                return vRP.EXT.Identity:getIdentity(user.cid)
            end
        end
        return nil
    end

    if vRP.getUserIdentity then
        local p = promise.new()
        vRP.getUserIdentity({ id, function(identity)
            p:resolve(identity)
        end })
        return Citizen.Await(p)
    end

    local rows = MySQL.query.await(
        'SELECT firstname, name, phone, registration FROM vrp_user_identities WHERE user_id = ? LIMIT 1',
        { id }
    )

    return rows and rows[1] or nil
end

---@param account string
---@return 'wallet'|'bank'
local function normalizeAccount(account)
    if account == 'money' or account == 'cash' or account == 'wallet' then
        return 'wallet'
    end
    return 'bank'
end

--- Sync identifier to client state (same pattern as standalone).
local function syncPlayerState(source)
    local user_id = getUserId(source)
    if user_id then
        Player(source).state:set('identifier', tostring(user_id))
        Player(source).state:set('vrp_user_id', user_id)
        TriggerClientEvent('phone:vrp:syncJob', source, framework:getJobName(source), framework:getJobGrade(source))
    end
end

-- vRP 1.x spawn hook
AddEventHandler('vRP:playerSpawn', function(user_id, player, first_spawn)
    if type(player) == 'number' then
        syncPlayerState(player)
    end
end)

-- vRP 2.x character load
AddEventHandler('characterLoad', function(user)
    if user and user.source then
        syncPlayerState(user.source)
        if not Config.Phone.requireItem then
            return
        end
        SyncCurrentPhoneFromInventory(user.source, { closeClientOnMissing = true })
    end
end)

RegisterNetEvent('phone:playerConnected', function()
    syncPlayerState(source)
end)

function framework:getJobsData()
    return {}
end

function framework:registerUsableItem(item, cb)
    if IS_VRP2 then
        -- vRP 2 items are usually defined in extensions; usable hook may not exist globally.
        return
    end

    if vRP.defInventoryItem then
        vRP.defInventoryItem(item, item, '', function(args)
            local player = args[1]
            if player then
                cb(player)
            end
        end, 0.1)
    end
end

function framework:getPlayerFromId(source)
    return getVRPUser(source)
end

function framework:getSourceFromIdentifier(identifier)
    if not identifier then
        return nil
    end
    return getSourceFromUserId(identifier)
end

function framework:getIdentifier(source)
    local user_id = getUserId(source)
    if not user_id then
        return nil
    end
    return tostring(user_id)
end

function framework:setPhoneNumber(source, phoneNumber)
    local user_id = getUserId(source)
    if not user_id then
        return
    end

    MySQL.update.await('UPDATE vrp_user_identities SET phone = ? WHERE user_id = ?', { phoneNumber, user_id })
end

function framework:getAccountMoney(source, account)
    local user_id = getUserId(source)
    if not user_id then
        return 0
    end

    local acc = normalizeAccount(account)

    if IS_VRP2 then
        local user = vRP.users_by_source[source]
        if not user or not user:isReady() then
            return 0
        end
        if acc == 'wallet' then
            return user:getWallet() or 0
        end
        return user:getBank() or 0
    end

    if acc == 'wallet' then
        if vRP.getMoney then
            return vRP.getMoney({ user_id }) or 0
        end
        return 0
    end

    if vRP.getBankMoney then
        return vRP.getBankMoney({ user_id }) or 0
    end

    return 0
end

function framework:removeAccountMoney(source, account, amount)
    if amount <= 0 then
        return true
    end

    local user_id = getUserId(source)
    if not user_id then
        return false
    end

    local acc = normalizeAccount(account)

    if IS_VRP2 then
        local user = vRP.users_by_source[source]
        if not user or not user:isReady() then
            return false
        end
        if acc == 'wallet' then
            return user:tryPayment(amount) == true
        end
        return user:tryWithdraw(amount) == true
    end

    if acc == 'wallet' then
        if vRP.tryPayment then
            return vRP.tryPayment({ user_id, amount }) == true
        end
        return false
    end

    if vRP.tryBankPayment then
        return vRP.tryBankPayment({ user_id, amount }) == true
    end

    if vRP.tryWithdraw then
        return vRP.tryWithdraw({ user_id, amount }) == true
    end

    return false
end

function framework:addAccountMoney(source, account, amount)
    local user_id = getUserId(source)
    if not user_id or amount <= 0 then
        return
    end

    local acc = normalizeAccount(account)

    if IS_VRP2 then
        local user = vRP.users_by_source[source]
        if not user or not user:isReady() then
            return
        end
        if acc == 'wallet' then
            user:giveWallet(amount)
        else
            user:giveBank(amount)
        end
        return
    end

    if acc == 'wallet' then
        if vRP.giveMoney then
            vRP.giveMoney({ user_id, amount })
        end
        return
    end

    if vRP.giveBankMoney then
        vRP.giveBankMoney({ user_id, amount })
    end
end

function framework:removeItem(source, item, count)
    local user_id = getUserId(source)
    if not user_id then
        return false
    end

    if IS_VRP2 then
        local user = vRP.users_by_source[source]
        if not user or not user:isReady() then
            return false
        end
        return user:tryTakeItem(item, count) == true
    end

    if vRP.tryGetInventoryItem then
        return vRP.tryGetInventoryItem({ user_id, item, count, true }) == true
    end

    return false
end

function framework:addItem(source, item, count, slot, info)
    local user_id = getUserId(source)
    if not user_id then
        return false
    end

    if IS_VRP2 then
        local user = vRP.users_by_source[source]
        if not user or not user:isReady() then
            return false
        end
        return user:tryGiveItem(item, count) == true
    end

    if vRP.giveInventoryItem then
        vRP.giveInventoryItem({ user_id, item, count, true })
        return true
    end

    return false
end

function framework:getInventory(source)
    local user_id = getUserId(source)
    if not user_id then
        return {}
    end

    if IS_VRP2 then
        local user = vRP.users_by_source[source]
        if not user or not user:isReady() then
            return {}
        end
        return user:getInventory() or {}
    end

    if vRP.getInventory then
        return vRP.getInventory({ user_id }) or {}
    end

    return {}
end

function framework:getItem(source, item)
    local user_id = getUserId(source)
    if not user_id then
        return { count = 0 }
    end

    if IS_VRP2 then
        local user = vRP.users_by_source[source]
        if not user or not user:isReady() then
            return { count = 0 }
        end
        local amount = user:getItemAmount(item) or 0
        return { name = item, count = amount }
    end

    if vRP.getInventoryItemAmount then
        local amount = vRP.getInventoryItemAmount({ user_id, item }) or 0
        return { name = item, count = amount }
    end

    return { count = 0 }
end

function framework:getItemList()
    if IS_VRP2 and vRP.EXT and vRP.EXT.Inventory and vRP.EXT.Inventory.items then
        return vRP.EXT.Inventory.items
    end

    if vRP.items then
        return vRP.items
    end

    return {}
end

function framework:getItems()
    local itemList = self:getItemList()
    local items = {}

    for name, item in pairs(itemList) do
        local label = name
        if type(item) == 'table' then
            label = item.label or item[1] or item.name or name
        elseif type(item) == 'string' then
            label = item
        end

        items[#items + 1] = {
            name = name,
            label = label,
            image = 'nui://ox_inventory/web/images/' .. name .. '.png'
        }
    end

    table.sort(items, function(a, b)
        return a.label < b.label
    end)

    return items
end

function framework:playerIsAdmin(source)
    local user_id = getUserId(source)
    if not user_id then
        return IsPlayerAceAllowed(source, 'command.qsphone_admin') == 1
    end

    if IS_VRP2 then
        local user = vRP.users_by_source[source]
        if user and user:isReady() then
            if user.hasGroup and user:hasGroup('superadmin') then
                return true
            end
            if user.hasGroup and user:hasGroup('admin') then
                return true
            end
            if user.hasPermission and user:hasPermission('admin.tickets') then
                return true
            end
        end
        return IsPlayerAceAllowed(source, 'command.qsphone_admin') == 1
    end

    if vRP.hasPermission then
        if vRP.hasPermission({ user_id, 'admin.tickets' }) then
            return true
        end
        if vRP.hasPermission({ user_id, 'admin.menu' }) then
            return true
        end
    end

    if vRP.hasGroup then
        if vRP.hasGroup({ user_id, 'superadmin' }) then
            return true
        end
        if vRP.hasGroup({ user_id, 'admin' }) then
            return true
        end
    end

    return IsPlayerAceAllowed(source, 'command.qsphone_admin') == 1
end

function framework:getUserName(source)
    local user_id = getUserId(source)
    if not user_id then
        return '', ''
    end

    local identity = getIdentityByUserId(user_id)
    if not identity then
        return '', ''
    end

    local first = identity.firstname or identity.firstName or ''
    local last = identity.name or identity.lastname or identity.lastName or ''
    return first, last
end

function framework:getUserNameFromIdentifier(identifier)
    local identity = getIdentityByUserId(identifier)
    if not identity then
        return '', ''
    end

    local first = identity.firstname or identity.firstName or ''
    local last = identity.name or identity.lastname or identity.lastName or ''
    return first, last
end

function framework:getJobName(source)
    local user_id = getUserId(source)
    if not user_id then
        return 'unemployed'
    end

    if IS_VRP2 then
        local user = vRP.users_by_source[source]
        if user and user:isReady() and user.getGroupByType then
            return user:getGroupByType('job') or 'unemployed'
        end
        return 'unemployed'
    end

    if vRP.getUserGroupByType then
        return vRP.getUserGroupByType({ user_id, 'job' }) or 'unemployed'
    end

    return 'unemployed'
end

function framework:getJobGrade(source)
    return 0
end

function framework:setJob(source, job, grade)
    local user_id = getUserId(source)
    if not user_id or not job then
        return false
    end

    if IS_VRP2 then
        local user = vRP.users_by_source[source]
        if not user or not user:isReady() then
            return false
        end
        local current = user:getGroupByType('job')
        if current and user.removeGroup then
            user:removeGroup(current)
        end
        user:addGroup(job)
        return true
    end

    if vRP.getUserGroupByType and vRP.removeUserGroup and vRP.addUserGroup then
        local current = vRP.getUserGroupByType({ user_id, 'job' })
        if current then
            vRP.removeUserGroup({ user_id, current })
        end
        vRP.addUserGroup({ user_id, job })
        return true
    end

    return false
end

function framework:getPlayers()
    local players = {}

    if IS_VRP2 and vRP.users_by_source then
        for src in pairs(vRP.users_by_source) do
            players[#players + 1] = src
        end
        return players
    end

    if vRP.getUsers then
        for _, src in pairs(vRP.getUsers()) do
            players[#players + 1] = src
        end
        return players
    end

    return GetPlayers()
end

function framework:searchPlayers(query)
    return MySQL.query.await([[
        SELECT user_id AS identifier, firstname, name AS lastname
        FROM vrp_user_identities
        WHERE LOWER(CONCAT(firstname, ' ', name)) LIKE ?
           OR CAST(user_id AS CHAR) LIKE ?
        LIMIT ?
    ]], {
        '%' .. query .. '%',
        '%' .. query .. '%',
        Config.MaxSearchResults
    }) or {}
end

-- Adjust if your garage script uses different table/column names.
framework.garageTable = 'vrp_user_vehicles'
framework.garageIdentifierColumn = 'user_id'

return framework
