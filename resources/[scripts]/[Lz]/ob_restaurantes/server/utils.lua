Restaurant = Restaurant or {}

local function trim(value)
    local text = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
    return text ~= '' and text or nil
end

local function callExport(resource, exportName, ...)
    if not resource or resource == '' or not exportName or exportName == '' then return nil, false end
    if GetResourceState(resource) ~= 'started' then return nil, false end

    local args = { ... }
    local ok, result = pcall(function()
        local provider = exports[resource]
        return provider[exportName](provider, table.unpack(args))
    end)

    return result, ok
end

function Restaurant.debug(...)
    if Config.Debug then
        print('[ob_restaurantes]', ...)
    end
end

function Restaurant.jsonDecode(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, result = pcall(json.decode, value)
    return ok and result or fallback
end

function Restaurant.jsonEncode(value)
    local ok, result = pcall(json.encode, value or {})
    return ok and result or '{}'
end

function Restaurant.getPlayer(src)
    src = tonumber(src)
    if not src then return nil end
    local player = callExport('qbx_core', 'GetPlayer', src)
    return player
end

function Restaurant.getPlayerByCitizenId(citizenId)
    local player = callExport('qbx_core', 'GetPlayerByCitizenId', tostring(citizenId or ''))
    return player
end

function Restaurant.getJobDefinition(jobName)
    local job = callExport('qbx_core', 'GetJob', tostring(jobName or ''))
    return type(job) == 'table' and job or nil
end

function Restaurant.addPlayerToJob(citizenId, jobName, grade)
    local result, ok = callExport('qbx_core', 'AddPlayerToJob', tostring(citizenId or ''), tostring(jobName or ''), tonumber(grade) or 0)
    return ok and result == true
end

function Restaurant.removePlayerFromJob(citizenId, jobName)
    local result, ok = callExport('qbx_core', 'RemovePlayerFromJob', tostring(citizenId or ''), tostring(jobName or ''))
    return ok and result == true
end

function Restaurant.getIdentifier(src)
    local player = Restaurant.getPlayer(src)
    local data = player and player.PlayerData or {}
    return trim(data.citizenid) or trim(data.citizenId) or trim(data.license) or tostring(src)
end

function Restaurant.getName(src)
    local player = Restaurant.getPlayer(src)
    local data = player and player.PlayerData or {}
    local charinfo = type(data.charinfo) == 'table' and data.charinfo or {}
    local first = trim(charinfo.firstname) or trim(charinfo.name)
    local last = trim(charinfo.lastname) or trim(charinfo.lastName)
    if first and last then return first .. ' ' .. last end
    return first or last or GetPlayerName(tonumber(src) or 0) or ('Cidadao ' .. tostring(src))
end

function Restaurant.getJob(src)
    local player = Restaurant.getPlayer(src)
    local data = player and player.PlayerData or {}
    local job = type(data.job) == 'table' and data.job or {}
    local grade = type(job.grade) == 'table' and job.grade or {}
    return {
        name = trim(job.name) or 'unemployed',
        label = trim(job.label) or trim(job.name) or 'Desempregado',
        grade = tonumber(grade.level) or tonumber(grade.grade) or tonumber(job.grade) or 0,
        isBoss = job.isboss == true or job.isBoss == true or grade.isboss == true or grade.isBoss == true,
        onDuty = job.onduty ~= false
    }
end

function Restaurant.getMembership(src, jobName)
    jobName = trim(jobName)
    if not jobName then return { member = false, grade = 0, isBoss = false, onDuty = false } end

    local player = Restaurant.getPlayer(src)
    local data = player and player.PlayerData or {}
    local primary = Restaurant.getJob(src)
    local jobs = type(data.jobs) == 'table' and data.jobs or {}
    local heldGrade = jobs[jobName]

    if heldGrade == nil and primary.name == jobName then heldGrade = primary.grade end
    if heldGrade == nil then return { member = false, grade = 0, isBoss = false, onDuty = false } end

    local grade = math.max(0, math.floor(tonumber(heldGrade) or 0))
    local definition = Restaurant.getJobDefinition(jobName) or {}
    local gradeDefinition = type(definition.grades) == 'table' and (definition.grades[grade] or definition.grades[tostring(grade)]) or {}

    return {
        member = true,
        grade = grade,
        label = trim(gradeDefinition.name) or trim(gradeDefinition.label) or ('Grau ' .. grade),
        isBoss = primary.name == jobName and primary.isBoss == true
            or gradeDefinition.isboss == true
            or gradeDefinition.isBoss == true,
        onDuty = primary.name == jobName and primary.onDuty == true
    }
end

function Restaurant.isAdmin(src)
    if src == 0 then return true end
    if Config.AdminAce and IsPlayerAceAllowed(src, Config.AdminAce) then return true end

    for _, permission in ipairs(Config.AdminPermissions or {}) do
        local result, ok = callExport('qbx_core', 'HasPermission', src, permission)
        if ok and result == true then return true end
        if IsPlayerAceAllowed(src, permission) then return true end
    end

    return false
end

function Restaurant.getRestaurant(restaurantId)
    if not restaurantId then return nil end
    return MySQL.single.await('SELECT * FROM ob_restaurants WHERE id = ? AND enabled = 1', { tostring(restaurantId) })
end

function Restaurant.getRestaurantForSource(src)
    local restaurants = MySQL.query.await('SELECT * FROM ob_restaurants WHERE enabled = 1 ORDER BY label') or {}
    for _, restaurant in ipairs(restaurants) do
        if Restaurant.getMembership(src, restaurant.job).member then return restaurant end
    end
    return nil
end

function Restaurant.canWork(src, restaurant)
    if not restaurant then return false end
    if Restaurant.isAdmin(src) then return true end
    local membership = Restaurant.getMembership(src, restaurant.job)
    return membership.member and membership.onDuty
end

function Restaurant.canManage(src, restaurant)
    if not restaurant then return false end
    if Restaurant.isAdmin(src) then return true end
    local membership = Restaurant.getMembership(src, restaurant.job)
    return membership.member and (
        membership.isBoss or membership.grade >= tonumber(restaurant.manager_grade or Config.ManagerGrade or 4)
    )
end

function Restaurant.isBossOf(src, restaurant)
    if not restaurant then return false end
    return Restaurant.getMembership(src, restaurant.job).isBoss == true
end

function Restaurant.canAdminister(src, restaurant)
    return restaurant ~= nil and (Restaurant.isAdmin(src) or Restaurant.isBossOf(src, restaurant))
end

function Restaurant.getMoney(src, account)
    local player = Restaurant.getPlayer(src)
    if player and player.Functions and player.Functions.GetMoney then
        return math.floor(tonumber(player.Functions.GetMoney(account or 'cash')) or 0)
    end
    return 0
end

function Restaurant.addMoney(src, account, amount, reason)
    local player = Restaurant.getPlayer(src)
    amount = math.floor(math.abs(tonumber(amount) or 0))
    if not player or amount < 1 then return false end
    if player.Functions and player.Functions.AddMoney then
        return player.Functions.AddMoney(account or 'bank', amount, reason or 'ob_restaurantes') ~= false
    end
    return false
end

function Restaurant.removeMoney(src, account, amount, reason)
    amount = math.floor(math.abs(tonumber(amount) or 0))
    if amount < 1 or not Config.AllowedPaymentAccounts[account] then return false end
    local player = Restaurant.getPlayer(src)
    if not player then return false end
    if Restaurant.getMoney(src, account) < amount then
        if account ~= 'cash' and account ~= 'bank' then return false end
        if GetResourceState('ob_bank') ~= 'started' then return false end
        local ok, allowed = pcall(function() return exports.ob_bank:CanChargeCredit(src, amount) end)
        if not ok or allowed ~= true then return false end
    end
    if player.Functions and player.Functions.RemoveMoney then
        return player.Functions.RemoveMoney(account, amount, reason or 'ob_restaurantes') == true
    end
    return false
end

function Restaurant.inventoryCount(src, item)
    local ok, result = pcall(function()
        return exports.ox_inventory:Search(src, 'count', item)
    end)
    return ok and math.floor(tonumber(result) or 0) or 0
end

function Restaurant.canCarry(src, item, amount, metadata)
    local ok, result = pcall(function()
        return exports.ox_inventory:CanCarryItem(src, item, amount, metadata)
    end)
    return ok and result == true
end

function Restaurant.addItem(src, item, amount, metadata)
    local ok, result = pcall(function()
        return exports.ox_inventory:AddItem(src, item, amount, metadata)
    end)
    return ok and result ~= false
end

function Restaurant.removeItem(src, item, amount)
    local ok, result = pcall(function()
        return exports.ox_inventory:RemoveItem(src, item, amount)
    end)
    return ok and result ~= false
end

function Restaurant.itemExists(item)
    item = trim(item)
    if not item then return false end
    local result, ok = callExport('ox_inventory', 'Items', item)
    return ok and type(result) == 'table' and result.name ~= nil
end

function Restaurant.audit(src, restaurantId, action, details)
    local ok, err = pcall(function()
        MySQL.insert.await([[
            INSERT INTO ob_restaurant_audit
                (restaurant_id, actor_identifier, actor_name, action, details)
            VALUES (?, ?, ?, ?, ?)
        ]], {
            tostring(restaurantId or ''),
            Restaurant.getIdentifier(src),
            Restaurant.getName(src),
            tostring(action or 'unknown'):sub(1, 48),
            Restaurant.jsonEncode(details or {})
        })
    end)

    if not ok then
        print(('[ob_restaurantes] Falha ao registrar auditoria: %s'):format(err))
    end
end

function Restaurant.takeIngredients(src, ingredients)
    local removed = {}
    for _, ingredient in ipairs(ingredients or {}) do
        local item = trim(ingredient.item)
        local amount = math.max(1, math.floor(tonumber(ingredient.amount) or 1))
        if not item or Restaurant.inventoryCount(src, item) < amount then
            return false, removed, item
        end
    end

    for _, ingredient in ipairs(ingredients or {}) do
        local item = trim(ingredient.item)
        local amount = math.max(1, math.floor(tonumber(ingredient.amount) or 1))
        if not Restaurant.removeItem(src, item, amount) then
            for _, rollback in ipairs(removed) do
                Restaurant.addItem(src, rollback.item, rollback.amount)
            end
            return false, {}, item
        end
        removed[#removed + 1] = { item = item, amount = amount }
    end

    return true, removed
end

function Restaurant.restoreIngredients(src, ingredients)
    for _, ingredient in ipairs(ingredients or {}) do
        Restaurant.addItem(src, ingredient.item, ingredient.amount)
    end
end

function Restaurant.depositCompany(restaurantId, amount, reason)
    amount = math.floor(math.abs(tonumber(amount) or 0))
    if amount < 1 then return true end

    MySQL.update.await([[
        INSERT INTO ob_restaurant_accounts (restaurant_id, balance)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE balance = balance + VALUES(balance)
    ]], { restaurantId, amount })

    return Restaurant.creditCompanyProvider(restaurantId, amount, reason)
end

function Restaurant.creditCompanyProvider(restaurantId, amount, reason)
    amount = math.floor(math.abs(tonumber(amount) or 0))
    if amount < 1 then return true end

    local bank = Config.CompanyBank or {}
    if bank.provider == 'internal' then return true end

    local account = tostring(bank.accountPrefix or 'restaurant_') .. restaurantId
    if bank.provider == 'renewed' then
        callExport(bank.resource ~= '' and bank.resource or 'Renewed-Banking', 'addAccountMoney', account, amount, reason)
    elseif bank.provider == 'qb-management' then
        callExport(bank.resource ~= '' and bank.resource or 'qb-management', 'AddMoney', account, amount)
    elseif bank.provider == 'custom' then
        callExport(bank.resource, bank.export, account, amount, reason)
    end

    return true
end

local commissionLocks = {}

function Restaurant.settleCommission(src)
    local identifier = Restaurant.getIdentifier(src)
    if commissionLocks[identifier] then return 0 end
    commissionLocks[identifier] = true

    local ok, paid = pcall(function()
        local pending = MySQL.query.await([[
            SELECT id, amount FROM ob_restaurant_commissions
            WHERE employee_identifier = ? AND status = 'pending'
            ORDER BY id ASC LIMIT 50
        ]], { identifier }) or {}

        local total, ids = 0, {}
        for _, row in ipairs(pending) do
            total = total + math.floor(tonumber(row.amount) or 0)
            ids[#ids + 1] = tonumber(row.id)
        end

        if total < 1 or not Restaurant.addMoney(src, 'bank', total, 'comissao-restaurante') then return 0 end

        for _, id in ipairs(ids) do
            MySQL.update.await("UPDATE ob_restaurant_commissions SET status = 'paid', paid_at = NOW() WHERE id = ? AND status = 'pending'", { id })
        end
        return total
    end)
    commissionLocks[identifier] = nil
    if not ok then
        print(('[ob_restaurantes] Falha ao liquidar comissao de %s: %s'):format(identifier, paid))
        return 0
    end
    return paid
end

function Restaurant.isNearPoint(src, pointId, expectedType)
    pointId = tonumber(pointId)
    if not pointId then return false end
    local point = MySQL.single.await('SELECT * FROM ob_restaurant_points WHERE id = ? AND enabled = 1', { pointId })
    if not point or (expectedType and point.type ~= expectedType) then return false end

    local ped = GetPlayerPed(src)
    if ped <= 0 then return false end
    local playerCoords = GetEntityCoords(ped)
    local coords = Restaurant.jsonDecode(point.coords, {})
    if not coords.x or not coords.y or not coords.z then return false end
    local pointCoords = vector3(tonumber(coords.x) + 0.0, tonumber(coords.y) + 0.0, tonumber(coords.z) + 0.0)
    return #(playerCoords - pointCoords) <= math.max(4.0, tonumber(Config.InteractionDistance) + 2.0), point
end

local callCounters = {}

function Restaurant.publicCode(restaurant)
    local restaurantId = tostring(restaurant and restaurant.id or 'restaurant')
    local configuredPrefix

    for _, entry in ipairs(Config.Restaurants or {}) do
        if tostring(entry.id) == restaurantId then
            configuredPrefix = entry.callPrefix
            break
        end
    end

    local prefix = tostring(configuredPrefix or (restaurant and restaurant.label) or 'R')
        :upper()
        :match('[A-Z0-9]') or 'R'
    local nextNumber = (callCounters[restaurantId] or 0) + 1
    if nextNumber > 999 then nextNumber = 1 end
    callCounters[restaurantId] = nextNumber

    return ('%s%02d'):format(prefix, nextNumber)
end
