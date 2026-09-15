local handlers = {}
local requestWindows = {}
local serviceCallWindows = {}
local legacyItemIds = {
    ob_pao = 'pao',
    ob_carne = 'carne',
    ob_salad = 'salad',
    ob_batata = 'batata',
    ob_xarope = 'xarope',
    ob_hamburguer = 'hamburguer',
    ob_batata_frita = 'batata_frita',
    ob_refrigerante = 'refrigerante',
    ob_refresco = 'refrigerante',
    ob_combo_box = 'combo_box',
}

local function respond(src, token, payload)
    TriggerClientEvent('ob_restaurantes:client:response', src, token, payload or {})
end

local function cleanText(value, maximum)
    local text = tostring(value or ''):gsub('[%c]', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    text = text:sub(1, maximum or 120)
    return text ~= '' and text or nil
end

local function cleanMultiline(value, maximum)
    local text = tostring(value or ''):gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('[\0-\8\11\12\14-\31\127]', '')
    text = text:sub(1, maximum or 4000):gsub('^%s+', ''):gsub('%s+$', '')
    return text
end

local function boolValue(value, fallback)
    if value == nil then return fallback == true end
    return value == true or value == 1 or value == '1'
end

local function validKey(value, maximum)
    local key = cleanText(value, maximum or 64)
    return key and key:match('^[a-z0-9_%-]+$') and key or nil
end

local function validImage(value)
    local image = cleanText(value, 255)
    if not image then return '' end
    if image:match('^https://[%w]') and not image:find('%s') then return image end
    if image:match('^[%w%._%-%/]+$') and not image:find('../', 1, true) then return image end
    return nil
end

local function restaurantProductItem()
    return validKey((Config.RestaurantProduct or {}).item, 64) or 'produto_restaurante'
end

local function normalizeProductType(value)
    return tostring(value or '') == 'drink' and 'drink' or 'food'
end

local function normalizeProductWeight(value)
    local settings = Config.RestaurantProduct or {}
    local minimum = math.max(0, math.floor(tonumber(settings.minWeight) or 10))
    local maximum = math.max(minimum, math.floor(tonumber(settings.maxWeight) or 5000))
    local fallback = math.max(minimum, math.floor(tonumber(settings.defaultWeight) or 250))
    return math.min(maximum, math.max(minimum, math.floor(tonumber(value) or fallback)))
end

local function restaurantPresentationMap(restaurantId)
    local configured = Config.RestaurantProps or {}
    local merged = {}

    local function mergeScope(scope)
        for mapKey, entry in pairs(type(scope) == 'table' and scope or {}) do
            if type(entry) == 'table' then
                local key = validKey(entry.key or (type(mapKey) == 'string' and mapKey or nil), 64)
                if key then
                    if entry.enabled == false then
                        merged[key] = nil
                    else
                        local animation = type(entry.animation) == 'string' and (Config.RestaurantAnimations or {})[entry.animation] or entry.animation
                        merged[key] = {
                            key = key,
                            label = cleanText(entry.label, 80) or key,
                            image = cleanText(entry.image or entry.photo, 255) or '',
                            type = normalizeProductType(entry.type),
                            animation = cleanText(type(entry.animation) == 'string' and entry.animation or nil, 32) or '',
                            animationLabel = cleanText(type(animation) == 'table' and animation.label or nil, 40) or '',
                            default = entry.default == true
                        }
                    end
                end
            end
        end
    end

    mergeScope(configured['*'])
    mergeScope(configured[tostring(restaurantId or '')])
    return merged
end

local function restaurantPresentationOptions(restaurantId)
    local options = {}
    for _, presentation in pairs(restaurantPresentationMap(restaurantId)) do
        options[#options + 1] = presentation
    end
    table.sort(options, function(left, right)
        if left.type ~= right.type then return left.type < right.type end
        return left.label:lower() < right.label:lower()
    end)
    return options
end

local function normalizePresentationKey(value, restaurantId, productType)
    local raw = cleanText(value, 64)
    if not raw then return '' end
    local key = validKey(raw, 64)
    local presentation = key and restaurantPresentationMap(restaurantId)[key]
    if not presentation or presentation.type ~= normalizeProductType(productType) then return nil end
    return key
end

local function isRateLimited(src, action)
    if src <= 0 then return false end
    local now = GetGameTimer()
    local key = ('%d:%s'):format(src, action)
    local frequentRead = action == 'bootstrap' or action == 'display' or action == 'publicPoints'
    local delay = frequentRead and 250 or 600
    if requestWindows[key] and now - requestWindows[key] < delay then return true end
    requestWindows[key] = now
    return false
end

local function normalizeCraftSteps(value)
    local source = type(value) == 'string' and Restaurant.jsonDecode(value, {}) or value
    local steps = {}
    for _, entry in ipairs(type(source) == 'table' and source or {}) do
        local stepType = cleanText(type(entry) == 'table' and (entry.type or entry.key) or entry, 32)
        if stepType and Config.CraftActions and Config.CraftActions[stepType] then
            steps[#steps + 1] = { type = stepType }
            if #steps >= 8 then break end
        end
    end
    return steps
end

local recipeEffectKeys = { 'hunger', 'thirst', 'stress' }

local function normalizeRecipeEffects(value, strict)
    local source = type(value) == 'string' and Restaurant.jsonDecode(value, {}) or value
    source = type(source) == 'table' and source or {}

    if source[1] ~= nil then
        local mapped = {}
        for _, entry in ipairs(source) do
            if type(entry) == 'table' then
                local key = tostring(entry.key or entry.type or '')
                mapped[key] = entry.amount or entry.value
            end
        end
        source = mapped
    end

    local settings = Config.RecipeEffects or {}
    local maxSelected = math.max(1, math.floor(tonumber(settings.maxSelected) or 2))
    local maxAmount = math.max(1, math.floor(tonumber(settings.maxAmount) or 50))
    local effects, selected = {}, 0

    for _, key in ipairs(recipeEffectKeys) do
        local raw = source[key]
        if type(raw) == 'table' then raw = raw.amount or raw.value end
        if raw ~= nil and raw ~= '' and raw ~= false then
            local amount = tonumber(raw)
            local invalid = not amount or amount ~= amount or amount == math.huge or amount == -math.huge or amount < 0
            if invalid then
                if strict then return nil, 'invalid_recipe_effect' end
            elseif amount > 0 then
                amount = math.floor(amount)
                if amount < 1 or amount > maxAmount then
                    if strict then return nil, 'invalid_recipe_effect' end
                    amount = math.min(maxAmount, math.max(1, amount))
                end
                selected = selected + 1
                if selected > maxSelected then
                    if strict then return nil, 'too_many_recipe_effects' end
                    break
                end
                effects[key] = amount
            end
        end
    end

    return effects
end

local function buildRecipeMetadata(recipe, restaurantId)
    local effects = normalizeRecipeEffects(recipe.effects, false) or {}
    local productType = normalizeProductType(recipe.product_type or recipe.productType)
    local metadata = {
        label = recipe.name,
        description = cleanText(recipe.description, 255),
        type = productType == 'drink' and 'Bebida artesanal' or 'Comida artesanal',
        weight = normalizeProductWeight(recipe.item_weight or recipe.itemWeight),
        restaurant = restaurantId,
        recipe = recipe.name,
        restaurantRecipeId = tonumber(recipe.recipe_id or recipe.id),
        restaurantEffects = effects,
        restaurantProduct = true,
        restaurantProductType = productType
    }

    local presentationKey = validKey(recipe.presentation_key or recipe.presentationKey, 64)
    if presentationKey then metadata.restaurantPresentation = presentationKey end

    local image = validImage(recipe.image)
    if image and image ~= '' then
        if image:match('^https://') then
            metadata.imageurl = image
        else
            local fileName = image:gsub('\\', '/'):match('([^/]+)$') or image
            metadata.image = fileName:gsub('%.png$', '')
        end
    end

    if recipe.is_combo == 1 or recipe.is_combo == true then
        metadata.contents = Restaurant.jsonDecode(recipe.contents, {})
    end
    return metadata
end

local function decodeRows(rows)
    for _, row in ipairs(rows or {}) do
        if row.ingredients ~= nil then row.ingredients = Restaurant.jsonDecode(row.ingredients, {}) end
        if row.contents ~= nil then row.contents = Restaurant.jsonDecode(row.contents, {}) end
        if row.craft_steps ~= nil then row.craft_steps = normalizeCraftSteps(row.craft_steps) end
        if row.effects ~= nil then row.effects = normalizeRecipeEffects(row.effects, false) or {} end
        if row.items ~= nil then row.items = Restaurant.jsonDecode(row.items, {}) end
        if row.coords ~= nil then row.coords = Restaurant.jsonDecode(row.coords, {}) end
        row.enabled = row.enabled == nil or row.enabled == 1 or row.enabled == true
        row.is_combo = row.is_combo == 1 or row.is_combo == true
        row.featured = row.featured == 1 or row.featured == true
    end
    return rows or {}
end

local function ensureColumn(tableName, columnName, definition)
    local exists = MySQL.scalar.await([[
        SELECT COUNT(*) FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?
    ]], { tableName, columnName })
    if tonumber(exists) and tonumber(exists) > 0 then return end
    MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(tableName, columnName, definition))
end

local function migrateLegacyItemIds()
    for legacyId, itemId in pairs(legacyItemIds) do
        MySQL.update.await(
            'UPDATE ob_restaurant_recipes SET output_item = ? WHERE output_item = ?',
            { itemId, legacyId }
        )
        MySQL.update.await([[
            UPDATE ob_restaurant_recipes
            SET ingredients = REPLACE(ingredients, ?, ?), contents = REPLACE(contents, ?, ?)
            WHERE ingredients LIKE ? OR contents LIKE ?
        ]], { legacyId, itemId, legacyId, itemId, ('%%%s%%'):format(legacyId), ('%%%s%%'):format(legacyId) })
    end
end

local function migrate()
    local schema = LoadResourceFile(GetCurrentResourceName(), 'sql/install.sql')
    if not schema then
        print('[ob_restaurantes] sql/install.sql nao encontrado.')
        return
    end

    for statement in schema:gmatch('([^;]+);') do
        local sql = statement:gsub('^%s+', ''):gsub('%s+$', '')
        if sql ~= '' then
            local ok, err = pcall(function() MySQL.query.await(sql) end)
            if not ok then print(('[ob_restaurantes] Falha na migracao: %s'):format(err)) end
        end
    end

    local uniqueCodeIndex = MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM information_schema.statistics
        WHERE table_schema = DATABASE()
          AND table_name = 'ob_restaurant_orders'
          AND index_name = 'uq_ob_order_code'
    ]])
    if tonumber(uniqueCodeIndex) and tonumber(uniqueCodeIndex) > 0 then
        MySQL.query.await('ALTER TABLE ob_restaurant_orders DROP INDEX uq_ob_order_code')
    end

    local regularCodeIndex = MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM information_schema.statistics
        WHERE table_schema = DATABASE()
          AND table_name = 'ob_restaurant_orders'
          AND index_name = 'idx_ob_order_code'
    ]])
    if not tonumber(regularCodeIndex) or tonumber(regularCodeIndex) < 1 then
        MySQL.query.await('CREATE INDEX idx_ob_order_code ON ob_restaurant_orders (restaurant_id, public_code)')
    end

    ensureColumn('ob_restaurant_recipes', 'old_price', 'INT UNSIGNED NULL AFTER `price`')
    ensureColumn('ob_restaurant_recipes', 'menu_badge', "VARCHAR(32) NOT NULL DEFAULT '' AFTER `old_price`")
    ensureColumn('ob_restaurant_recipes', 'featured', 'TINYINT(1) NOT NULL DEFAULT 0 AFTER `menu_badge`')
    ensureColumn('ob_restaurant_recipes', 'product_type', "VARCHAR(16) NOT NULL DEFAULT 'food' AFTER `output_amount`")
    ensureColumn('ob_restaurant_recipes', 'item_weight', 'INT UNSIGNED NOT NULL DEFAULT 250 AFTER `product_type`')
    ensureColumn('ob_restaurant_recipes', 'presentation_key', "VARCHAR(64) NOT NULL DEFAULT '' AFTER `item_weight`")
    ensureColumn('ob_restaurant_recipes', 'craft_steps', 'LONGTEXT NULL AFTER `contents`')
    ensureColumn('ob_restaurant_recipes', 'effects', 'LONGTEXT NULL AFTER `craft_steps`')
    ensureColumn('ob_restaurants', 'is_open', 'TINYINT(1) NOT NULL DEFAULT 1 AFTER `enabled`')
    ensureColumn('ob_restaurants', 'description', "VARCHAR(255) NOT NULL DEFAULT '' AFTER `is_open`")
    ensureColumn('ob_restaurants', 'cover_url', "VARCHAR(255) NOT NULL DEFAULT '' AFTER `description`")
    ensureColumn('ob_restaurants', 'menu_image_url', "VARCHAR(255) NOT NULL DEFAULT '' AFTER `cover_url`")
    ensureColumn('ob_restaurants', 'notes', 'TEXT NULL AFTER `menu_image_url`')
    ensureColumn('ob_restaurants', 'notes_updated_by', 'VARCHAR(96) NULL AFTER `notes`')
    ensureColumn('ob_restaurants', 'notes_updated_at', 'DATETIME NULL AFTER `notes_updated_by`')
    ensureColumn('ob_restaurants', 'feature_menu', 'TINYINT(1) NOT NULL DEFAULT 1 AFTER `notes_updated_at`')
    ensureColumn('ob_restaurants', 'feature_location', 'TINYINT(1) NOT NULL DEFAULT 1 AFTER `feature_menu`')
    ensureColumn('ob_restaurants', 'feature_call', 'TINYINT(1) NOT NULL DEFAULT 1 AFTER `feature_location`')
    ensureColumn('ob_restaurants', 'location_label', "VARCHAR(160) NOT NULL DEFAULT '' AFTER `feature_call`")
    ensureColumn('ob_restaurants', 'call_text', "VARCHAR(255) NOT NULL DEFAULT '' AFTER `location_label`")
    migrateLegacyItemIds()
end

local function seed()
    for _, restaurantId in ipairs(Config.DisabledRestaurants or {}) do
        MySQL.update.await('UPDATE ob_restaurants SET enabled = 0 WHERE id = ?', { tostring(restaurantId) })
    end

    for _, restaurant in ipairs(Config.Restaurants or {}) do
        MySQL.update.await([[
            INSERT INTO ob_restaurants
                (id, label, job, manager_grade, commission_rate, theme, enabled, description, location_label, call_text)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE job = VALUES(job), enabled = VALUES(enabled)
        ]], {
            restaurant.id, restaurant.label, restaurant.job,
            restaurant.managerGrade or Config.ManagerGrade,
            restaurant.commissionRate or Config.CommissionRate,
            restaurant.theme or 'obscuria', restaurant.enabled == false and 0 or 1,
            restaurant.description or '', restaurant.locationLabel or '', restaurant.callText or ''
        })

        MySQL.update.await('INSERT IGNORE INTO ob_restaurant_accounts (restaurant_id, balance) VALUES (?, 0)', { restaurant.id })

        for _, category in ipairs(Config.SeedCategories or {}) do
            MySQL.update.await([[
                INSERT IGNORE INTO ob_restaurant_categories
                    (restaurant_id, category_key, label, icon, sort_order, enabled)
                VALUES (?, ?, ?, ?, ?, 1)
            ]], { restaurant.id, category.key, category.label, category.icon or 'utensils', category.sortOrder or 0 })
        end

        for _, recipe in ipairs(Config.SeedRecipes or {}) do
            MySQL.update.await([[
                INSERT IGNORE INTO ob_restaurant_recipes
                    (restaurant_id, recipe_key, category_key, name, description, image, icon, price,
                     prep_time, output_item, output_amount, product_type, item_weight, presentation_key, is_combo, ingredients, contents, craft_steps, effects, enabled)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
            ]], {
                restaurant.id, recipe.key, recipe.category, recipe.name, recipe.description or '', recipe.image or '',
                recipe.icon or 'utensils', math.max(0, math.floor(recipe.price or 0)),
                math.max(1, math.floor(recipe.prepTime or 5)), recipe.outputItem,
                math.max(1, math.floor(recipe.outputAmount or 1)), normalizeProductType(recipe.productType),
                normalizeProductWeight(recipe.itemWeight),
                normalizePresentationKey(recipe.presentationKey, restaurant.id, recipe.productType) or '',
                recipe.isCombo and 1 or 0,
                Restaurant.jsonEncode(recipe.ingredients), Restaurant.jsonEncode(recipe.contents or {}),
                Restaurant.jsonEncode(normalizeCraftSteps(recipe.craftSteps or {})),
                Restaurant.jsonEncode(normalizeRecipeEffects(recipe.effects, false) or {})
            })
            MySQL.update.await([[
                UPDATE ob_restaurant_recipes SET craft_steps = ?
                WHERE restaurant_id = ? AND recipe_key = ? AND (craft_steps IS NULL OR craft_steps = '')
            ]], { Restaurant.jsonEncode(normalizeCraftSteps(recipe.craftSteps or {})), restaurant.id, recipe.key })
            MySQL.update.await([[
                UPDATE ob_restaurant_recipes SET effects = ?
                WHERE restaurant_id = ? AND recipe_key = ? AND (effects IS NULL OR effects = '')
            ]], { Restaurant.jsonEncode(normalizeRecipeEffects(recipe.effects, false) or {}), restaurant.id, recipe.key })
        end
    end
end

local function loadCatalog(restaurantId)
    local categories = decodeRows(MySQL.query.await([[
        SELECT id, category_key, label, icon, sort_order, enabled
        FROM ob_restaurant_categories WHERE restaurant_id = ? ORDER BY sort_order, id
    ]], { restaurantId }) or {})

    local recipes = decodeRows(MySQL.query.await([[
        SELECT * FROM ob_restaurant_recipes WHERE restaurant_id = ? AND enabled = 1 ORDER BY category_key, name
    ]], { restaurantId }) or {})

    return categories, recipes
end

local function loadPopularRecipeIds(restaurantId)
    local rows = decodeRows(MySQL.query.await([[
        SELECT items FROM ob_restaurant_orders
        WHERE restaurant_id = ? AND status <> 'cancelled'
          AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
        ORDER BY id DESC LIMIT 500
    ]], { restaurantId }) or {})
    local totals = {}
    for _, row in ipairs(rows) do
        for _, item in ipairs(row.items or {}) do
            local recipeId = tonumber(item.recipeId or item.id)
            if recipeId then
                totals[recipeId] = (totals[recipeId] or 0) + math.max(1, math.floor(tonumber(item.amount) or 1))
            end
        end
    end

    local ranked = {}
    for recipeId, amount in pairs(totals) do ranked[#ranked + 1] = { id = recipeId, amount = amount } end
    table.sort(ranked, function(left, right) return left.amount > right.amount end)

    local popular = {}
    for index = 1, math.min(3, #ranked) do popular[index] = ranked[index].id end
    return popular
end

local function loadOrders(restaurantId, includeClosed)
    local where = includeClosed and '' or "AND status NOT IN ('delivered', 'cancelled')"
    return decodeRows(MySQL.query.await(([[
        SELECT * FROM ob_restaurant_orders
        WHERE restaurant_id = ? %s
        ORDER BY FIELD(status, 'ready', 'preparing', 'queued', 'awaiting_payment'), created_at ASC
        LIMIT 100
    ]]):format(where), { restaurantId }) or {})
end

local function loadPayments(restaurantId, src, canWork)
    MySQL.update.await("UPDATE ob_restaurant_payments SET status = 'expired' WHERE status = 'pending' AND expires_at <= NOW()")
    local identifier = Restaurant.getIdentifier(src)
    local customerFilter = canWork and '' or [[
        AND (
            p.customer_source IS NULL
            OR p.customer_source = ?
            OR (p.customer_identifier IS NOT NULL AND p.customer_identifier = ?)
        )
    ]]
    local parameters = canWork and { restaurantId } or { restaurantId, src, identifier }
    return decodeRows(MySQL.query.await(([[
        SELECT p.*, o.public_code, o.customer_name, o.items, o.notes, o.subtotal, o.total,
               r.label AS restaurant_label
        FROM ob_restaurant_payments p
        LEFT JOIN ob_restaurant_orders o ON o.id = p.order_id
        INNER JOIN ob_restaurants r ON r.id = p.restaurant_id
        WHERE p.restaurant_id = ? AND p.status = 'pending'
          %s
        ORDER BY p.created_at DESC LIMIT 30
    ]]):format(customerFilter), parameters) or {})
end

local function loadProductions(restaurantId, src)
    local identifier = Restaurant.getIdentifier(src)
    return MySQL.query.await([[
        SELECT p.*, r.name AS recipe_name, r.output_item, r.output_amount, r.icon
        FROM ob_restaurant_productions p
        INNER JOIN ob_restaurant_recipes r ON r.id = p.recipe_id
        WHERE p.restaurant_id = ? AND p.employee_identifier = ? AND p.status = 'preparing'
        ORDER BY p.created_at DESC LIMIT 20
    ]], { restaurantId, identifier }) or {}
end

local function dashboard(restaurantId)
    local account = MySQL.single.await('SELECT balance FROM ob_restaurant_accounts WHERE restaurant_id = ?', { restaurantId }) or { balance = 0 }
    local totals = MySQL.single.await([[
        SELECT
            COALESCE(SUM(CASE WHEN DATE(created_at) = CURDATE() THEN gross ELSE 0 END), 0) AS today_gross,
            COALESCE(SUM(CASE WHEN created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) THEN gross ELSE 0 END), 0) AS week_gross,
            COALESCE(SUM(CASE WHEN created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY) THEN gross ELSE 0 END), 0) AS month_gross,
            COALESCE(SUM(CASE WHEN DATE(created_at) = CURDATE() THEN commission ELSE 0 END), 0) AS today_commission,
            COUNT(CASE WHEN DATE(created_at) = CURDATE() THEN 1 END) AS today_sales
        FROM ob_restaurant_sales WHERE restaurant_id = ?
    ]], { restaurantId }) or {}

    local team = MySQL.query.await([[
        SELECT employee_identifier, employee_name, COUNT(*) AS sales,
               COALESCE(SUM(gross), 0) AS gross, COALESCE(SUM(commission), 0) AS commission
        FROM ob_restaurant_sales
        WHERE restaurant_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
        GROUP BY employee_identifier, employee_name
        ORDER BY gross DESC LIMIT 20
    ]], { restaurantId }) or {}

    local recentRows = decodeRows(MySQL.query.await([[
        SELECT items FROM ob_restaurant_orders
        WHERE restaurant_id = ? AND status IN ('queued', 'preparing', 'ready', 'delivered')
          AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
        ORDER BY id DESC LIMIT 500
    ]], { restaurantId }) or {})
    local productMap = {}
    for _, row in ipairs(recentRows) do
        for _, item in ipairs(row.items or {}) do
            local key = tostring(item.recipeId or item.id or item.name)
            local entry = productMap[key] or { name = item.name or 'Item', amount = 0, revenue = 0 }
            entry.amount = entry.amount + math.max(1, math.floor(tonumber(item.amount) or 1))
            entry.revenue = entry.revenue + math.max(0, math.floor(tonumber(item.total) or 0))
            productMap[key] = entry
        end
    end
    local products = {}
    for _, item in pairs(productMap) do products[#products + 1] = item end
    table.sort(products, function(a, b) return a.amount > b.amount end)
    while #products > 8 do table.remove(products) end

    return {
        accountBalance = math.floor(tonumber(account.balance) or 0),
        totals = totals,
        team = team,
        products = products
    }
end

local function jobGrades(restaurant)
    local definition = Restaurant.getJobDefinition(restaurant.job) or {}
    local grades = {}
    for key, grade in pairs(type(definition.grades) == 'table' and definition.grades or {}) do
        local level = tonumber(key) or tonumber(grade.level) or tonumber(grade.grade)
        if level then
            grades[#grades + 1] = {
                grade = math.floor(level),
                label = cleanText(grade.name or grade.label, 80) or ('Grau ' .. math.floor(level)),
                isBoss = grade.isboss == true or grade.isBoss == true
            }
        end
    end
    table.sort(grades, function(left, right) return left.grade < right.grade end)
    return grades
end

local function memberName(row)
    local charinfo = Restaurant.jsonDecode(row.charinfo, {})
    local first = cleanText(charinfo.firstname or charinfo.name, 48)
    local last = cleanText(charinfo.lastname or charinfo.lastName, 48)
    if first and last then return first .. ' ' .. last end
    return first or last or cleanText(row.player_name, 96) or tostring(row.citizenid)
end

local function loadMembers(restaurant)
    local rows = MySQL.query.await([[
        SELECT pg.citizenid, pg.grade, p.charinfo, p.name AS player_name
        FROM player_groups pg
        LEFT JOIN players p ON p.citizenid = pg.citizenid
        WHERE pg.type = 'job' AND pg.`group` = ?
        ORDER BY pg.grade DESC, p.name ASC
    ]], { restaurant.job }) or {}
    local grades, gradeMap = jobGrades(restaurant), {}
    for _, grade in ipairs(grades) do gradeMap[grade.grade] = grade end

    local members = {}
    for _, row in ipairs(rows) do
        local grade = math.max(0, math.floor(tonumber(row.grade) or 0))
        local gradeInfo = gradeMap[grade] or { label = 'Grau ' .. grade, isBoss = false }
        local onlinePlayer = Restaurant.getPlayerByCitizenId(row.citizenid)
        local onlineData = onlinePlayer and onlinePlayer.PlayerData or nil
        members[#members + 1] = {
            id = tostring(row.citizenid),
            citizenId = tostring(row.citizenid),
            source = onlineData and tonumber(onlineData.source) or nil,
            name = onlineData and Restaurant.getName(onlineData.source) or memberName(row),
            role = gradeInfo.label,
            grade = grade,
            isBoss = gradeInfo.isBoss == true,
            online = onlineData ~= nil
        }
    end
    return members, grades
end

local inventoryItemOptions

local function loadInventoryItemOptions()
    if inventoryItemOptions then return inventoryItemOptions end

    local ok, registeredItems = pcall(function()
        return exports.ox_inventory:Items()
    end)
    local options = {}

    if ok and type(registeredItems) == 'table' then
        local productItem = restaurantProductItem()
        for name, item in pairs(registeredItems) do
            if name ~= productItem and type(item) == 'table' and item.weapon ~= true then
                options[#options + 1] = {
                    name = tostring(name),
                    label = cleanText(item.label, 80) or tostring(name)
                }
            end
        end
        table.sort(options, function(left, right)
            return left.label:lower() < right.label:lower()
        end)
    end

    inventoryItemOptions = options
    return inventoryItemOptions
end

local function restaurantPayload(src, restaurant, mode)
    local categories, recipes = loadCatalog(restaurant.id)
    local canWork = Restaurant.canWork(src, restaurant)
    local canManage = Restaurant.canManage(src, restaurant)
    local payload = {
        ok = true,
        mode = mode,
        restaurant = restaurant,
        player = {
            source = src,
            identifier = Restaurant.getIdentifier(src),
            name = Restaurant.getName(src),
            job = Restaurant.getJob(src)
        },
        permissions = { work = canWork, manage = canManage, admin = Restaurant.isAdmin(src) },
        categories = categories,
        recipes = recipes,
        menu = { popularRecipeIds = mode == 'menu' and loadPopularRecipeIds(restaurant.id) or {} },
        commissionRate = tonumber(restaurant.commission_rate) or Config.CommissionRate,
        recipeEffects = {
            maxSelected = math.max(1, math.floor(tonumber((Config.RecipeEffects or {}).maxSelected) or 2)),
            maxAmount = math.max(1, math.floor(tonumber((Config.RecipeEffects or {}).maxAmount) or 50)),
            defaultAmount = math.max(1, math.floor(tonumber((Config.RecipeEffects or {}).defaultAmount) or 20))
        }
    }

    if canWork then
        payload.orders = loadOrders(restaurant.id, false)
        payload.productions = loadProductions(restaurant.id, src)
    end

    if mode == 'terminal' then
        payload.customerTerminal = true
        payload.payments = loadPayments(restaurant.id, src, false)
    end
    if canManage then
        payload.points = decodeRows(MySQL.query.await('SELECT * FROM ob_restaurant_points WHERE restaurant_id = ? ORDER BY type, id', { restaurant.id }) or {})
        payload.dashboard = dashboard(restaurant.id)
        payload.members, payload.jobGrades = loadMembers(restaurant)
        payload.inventoryItems = loadInventoryItemOptions()
        payload.presentations = restaurantPresentationOptions(restaurant.id)
    end
    return payload
end

local function findRestaurant(src, requestedId)
    local restaurant = requestedId and Restaurant.getRestaurant(requestedId) or Restaurant.getRestaurantForSource(src)
    if not restaurant and Restaurant.isAdmin(src) then
        restaurant = MySQL.single.await('SELECT * FROM ob_restaurants WHERE enabled = 1 ORDER BY label LIMIT 1')
    end
    return restaurant
end

local function notifyClients(restaurantId, action, payload)
    TriggerClientEvent('ob_restaurantes:client:update', -1, restaurantId, action, payload or {})
end

local function announcementPoints(restaurantId)
    local rows = MySQL.query.await([[
        SELECT coords FROM ob_restaurant_points
        WHERE restaurant_id = ? AND type = 'display' AND enabled = 1 ORDER BY id
    ]], { restaurantId }) or {}
    local points = {}
    for _, row in ipairs(rows) do
        local coords = Restaurant.jsonDecode(row.coords, nil)
        if coords and coords.x then points[#points + 1] = coords end
    end
    return points
end

local function emitAnnouncement(announcementId, restaurantId, orderId, message, startAt, audioUrl)
    local points = announcementPoints(restaurantId)

    TriggerClientEvent('ob_restaurantes:client:announcement', -1, {
        id = announcementId,
        restaurantId = restaurantId,
        orderId = orderId,
        message = message,
        startAt = startAt,
        coords = points[1],
        points = points,
        audioUrl = audioUrl,
        tts = Config.TTS
    })
end

local function broadcastAnnouncement(restaurantId, orderId, message, audioUrl)
    local startAt = os.time() * 1000 + 1000
    local announcementId = MySQL.insert.await([[
        INSERT INTO ob_restaurant_announcements (restaurant_id, order_id, message, start_at)
        VALUES (?, ?, ?, ?)
    ]], { restaurantId, orderId, message, startAt })
    emitAnnouncement(announcementId, restaurantId, orderId, message, startAt, audioUrl)
end

local function announceReady(restaurantId, order)
    local message = ('Pedido de %s finalizado. Venha ao balcão recolher.'):format(cleanText(order.customer_name, 70))
    local external = Config.TTS and Config.TTS.external or {}
    if not external.enabled or not external.url or external.url == '' then
        broadcastAnnouncement(restaurantId, order.id, message, nil)
        return
    end

    local headers = { ['Content-Type'] = 'application/json' }
    local key = GetConvar(external.apiKeyConvar or 'ob_restaurant_tts_key', '')
    if external.provider == 'murf' and key == '' then
        broadcastAnnouncement(restaurantId, order.id, message, nil)
        return
    end
    if key ~= '' then
        headers[external.authorizationHeader or 'Authorization'] = (external.authorizationPrefix or 'Bearer ') .. key
    end

    local requestBody = { text = message, language = Config.TTS.language or 'pt-BR' }
    if external.provider == 'murf' then
        requestBody = {
            text = message,
            voiceId = external.voiceId or 'pt-BR-isadora',
            locale = external.locale or Config.TTS.language or 'pt-BR',
            format = external.format or 'MP3',
            channelType = 'MONO',
            sampleRate = math.floor(tonumber(external.sampleRate) or 24000),
            modelVersion = 'GEN2'
        }
        if external.style and external.style ~= '' then requestBody.style = external.style end
    end

    PerformHttpRequest(external.url, function(status, body)
        local response = Restaurant.jsonDecode(body, {})
        local audioUrl = status >= 200 and status < 300 and cleanText(response.audioUrl or response.audioFile, 500) or nil
        broadcastAnnouncement(restaurantId, order.id, message, audioUrl)
    end, 'POST', Restaurant.jsonEncode(requestBody), headers)
end

handlers.publicPoints = function()
    local points = decodeRows(MySQL.query.await([[
        SELECT p.*, r.label AS restaurant_label, r.job AS restaurant_job
        FROM ob_restaurant_points p
        INNER JOIN ob_restaurants r ON r.id = p.restaurant_id
        WHERE p.enabled = 1 AND r.enabled = 1 ORDER BY p.id
    ]]) or {})
    return { ok = true, points = points, types = Config.PointTypes }
end

handlers.bootstrap = function(src, data)
    Restaurant.settleCommission(src)
    local mode = cleanText(data.mode, 24) or 'pos'
    local restaurant = findRestaurant(src, cleanText(data.restaurantId, 64))
    if not restaurant then return { ok = false, error = 'restaurant_not_found' } end

    if mode ~= 'terminal' and mode ~= 'display' and mode ~= 'menu' and not Restaurant.canWork(src, restaurant) then
        return { ok = false, error = 'not_employee' }
    end
    if mode == 'admin' and not Restaurant.canManage(src, restaurant) then
        return { ok = false, error = 'not_manager' }
    end
    return restaurantPayload(src, restaurant, mode)
end

handlers.nearbyCustomers = function(src)
    local ped = GetPlayerPed(src)
    if ped <= 0 then return { ok = true, customers = {} } end
    local coords = GetEntityCoords(ped)
    local customers = {}
    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        if target and target ~= src then
            local targetPed = GetPlayerPed(target)
            if targetPed > 0 and #(coords - GetEntityCoords(targetPed)) <= Config.NearbyCustomerDistance then
                customers[#customers + 1] = { source = target, name = Restaurant.getName(target) }
            end
        end
    end
    table.sort(customers, function(a, b) return a.name < b.name end)
    return { ok = true, customers = customers }
end

handlers.createOrder = function(src, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not Restaurant.canWork(src, restaurant) then return { ok = false, error = 'not_employee' } end
    if restaurant.is_open == 0 or restaurant.is_open == false then return { ok = false, error = 'restaurant_closed' } end

    local account = cleanText(data.account, 16)
    if not account or not Config.AllowedPaymentAccounts[account] then
        return { ok = false, error = 'invalid_payment_method' }
    end

    local requestedItems = type(data.items) == 'table' and data.items or {}
    if #requestedItems < 1 or #requestedItems > 30 then return { ok = false, error = 'invalid_items' } end

    local recipeRows = MySQL.query.await([[
        SELECT id, name, price
        FROM ob_restaurant_recipes
        WHERE restaurant_id = ? AND enabled = 1
    ]], { restaurant.id }) or {}
    local recipeMap = {}
    for _, recipe in ipairs(recipeRows) do recipeMap[tonumber(recipe.id)] = recipe end

    local items, total = {}, 0
    for _, requested in ipairs(requestedItems) do
        local recipe = recipeMap[tonumber(requested.recipeId)]
        local amount = math.min(20, math.max(1, math.floor(tonumber(requested.amount) or 1)))
        if recipe then
            local lineTotal = math.floor(tonumber(recipe.price) or 0) * amount
            total = total + lineTotal
            items[#items + 1] = {
                recipeId = tonumber(recipe.id), name = recipe.name, amount = amount,
                unitPrice = math.floor(tonumber(recipe.price) or 0), total = lineTotal
            }
        end
    end
    if #items < 1 or total < 1 or total > 10000000 then return { ok = false, error = 'invalid_total' } end

    local customerSource = tonumber(data.customerSource)
    local customerIdentifier, customerName
    if customerSource then
        local employeePed, customerPed = GetPlayerPed(src), GetPlayerPed(customerSource)
        if customerPed <= 0 or employeePed <= 0 or #(GetEntityCoords(employeePed) - GetEntityCoords(customerPed)) > Config.NearbyCustomerDistance + 1.5 then
            return { ok = false, error = 'customer_not_nearby' }
        end
        customerIdentifier = Restaurant.getIdentifier(customerSource)
        customerName = Restaurant.getName(customerSource)
    else
        customerName = cleanText(data.customerName, 70)
        if not customerName then return { ok = false, error = 'customer_required' } end
    end

    local employeeIdentifier, employeeName = Restaurant.getIdentifier(src), Restaurant.getName(src)
    local orderId = MySQL.insert.await([[
        INSERT INTO ob_restaurant_orders
            (public_code, restaurant_id, customer_identifier, customer_source, customer_name,
             employee_identifier, employee_source, employee_name, items, notes, subtotal, total, status)
        VALUES ('PENDENTE', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'awaiting_payment')
    ]], {
        restaurant.id, customerIdentifier, customerSource, customerName,
        employeeIdentifier, src, employeeName, Restaurant.jsonEncode(items),
        cleanText(data.notes, 500) or '', total, total
    })
    if not orderId then return { ok = false, error = 'create_failed' } end

    local code = Restaurant.publicCode(restaurant)
    MySQL.update.await('UPDATE ob_restaurant_orders SET public_code = ? WHERE id = ?', { code, orderId })
    local paymentId = MySQL.insert.await([[
        INSERT INTO ob_restaurant_payments
            (restaurant_id, order_id, employee_identifier, employee_source, employee_name,
            customer_identifier, customer_source, amount, account, status, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], {
        restaurant.id, orderId, employeeIdentifier, src, employeeName,
        customerIdentifier, customerSource, total, account, Config.PaymentExpiryMinutes
    })
    MySQL.update.await('UPDATE ob_restaurant_orders SET payment_id = ? WHERE id = ?', { paymentId, orderId })
    notifyClients(restaurant.id, 'orderCreated', { orderId = orderId, paymentId = paymentId })
    return { ok = true, orderId = orderId, publicCode = code, paymentId = paymentId, total = total, account = account }
end

handlers.createManualPayment = function(src, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not Restaurant.canWork(src, restaurant) then return { ok = false, error = 'not_employee' } end
    if restaurant.is_open == 0 or restaurant.is_open == false then return { ok = false, error = 'restaurant_closed' } end
    local amount = math.floor(tonumber(data.amount) or 0)
    if amount < 1 or amount > 10000000 then return { ok = false, error = 'invalid_total' } end
    local account = cleanText(data.account, 16)
    if not account or not Config.AllowedPaymentAccounts[account] then
        return { ok = false, error = 'invalid_payment_method' }
    end

    local customerSource = tonumber(data.customerSource)
    if not customerSource then return { ok = false, error = 'customer_required' } end
    local employeePed, customerPed = GetPlayerPed(src), GetPlayerPed(customerSource)
    if employeePed <= 0 or customerPed <= 0 or #(GetEntityCoords(employeePed) - GetEntityCoords(customerPed)) > Config.NearbyCustomerDistance + 1.5 then
        return { ok = false, error = 'customer_not_nearby' }
    end

    local paymentId = MySQL.insert.await([[
        INSERT INTO ob_restaurant_payments
            (restaurant_id, employee_identifier, employee_source, employee_name,
            customer_identifier, customer_source, amount, account, status, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], {
        restaurant.id, Restaurant.getIdentifier(src), src, Restaurant.getName(src),
        Restaurant.getIdentifier(customerSource), customerSource, amount, account, Config.PaymentExpiryMinutes
    })
    notifyClients(restaurant.id, 'paymentCreated', { paymentId = paymentId })
    return { ok = true, paymentId = paymentId, amount = amount, account = account }
end

handlers.getPayments = function(src, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not restaurant then return { ok = false, error = 'restaurant_not_found' } end
    return { ok = true, payments = loadPayments(restaurant.id, src, false) }
end

handlers.pay = function(src, data)
    local paymentId = tonumber(data.paymentId)
    if not paymentId then return { ok = false, error = 'invalid_payment' } end

    local payment = MySQL.single.await('SELECT * FROM ob_restaurant_payments WHERE id = ?', { paymentId })
    if not payment or payment.status ~= 'pending' then return { ok = false, error = 'payment_unavailable' } end
    local account = cleanText(payment.account, 16) or 'bank'
    if not Config.AllowedPaymentAccounts[account] then return { ok = false, error = 'invalid_payment_method' } end
    if payment.customer_source and tonumber(payment.customer_source) ~= src then return { ok = false, error = 'wrong_customer' } end
    if payment.customer_identifier and tostring(payment.customer_identifier) ~= Restaurant.getIdentifier(src) then
        return { ok = false, error = 'wrong_customer' }
    end
    local near = Restaurant.isNearPoint(src, data.pointId, 'terminal')
    if not near then return { ok = false, error = 'terminal_too_far' } end

    local locked = MySQL.update.await([[
        UPDATE ob_restaurant_payments SET status = 'processing'
        WHERE id = ? AND status = 'pending' AND expires_at > NOW()
    ]], { paymentId })
    if tonumber(locked) ~= 1 then return { ok = false, error = 'payment_unavailable' } end

    local amount = math.floor(tonumber(payment.amount) or 0)
    if not Restaurant.removeMoney(src, account, amount, 'pagamento-restaurante') then
        MySQL.update.await("UPDATE ob_restaurant_payments SET status = 'pending' WHERE id = ? AND status = 'processing'", { paymentId })
        return { ok = false, error = 'insufficient_money' }
    end

    local restaurant = Restaurant.getRestaurant(payment.restaurant_id)
    local rate = tonumber(restaurant and restaurant.commission_rate) or Config.CommissionRate
    local commission = math.floor(amount * rate)
    local companyNet = amount - commission
    local transaction = {
        {
            query = "UPDATE ob_restaurant_payments SET status = 'paid', paid_at = NOW() WHERE id = ? AND status = 'processing'",
            values = { paymentId }
        }
    }
    if payment.order_id then
        transaction[#transaction + 1] = {
            query = "UPDATE ob_restaurant_orders SET status = 'queued', customer_identifier = ?, customer_source = ? WHERE id = ?",
            values = { Restaurant.getIdentifier(src), src, payment.order_id }
        }
    end
    transaction[#transaction + 1] = {
        query = [[
            INSERT INTO ob_restaurant_sales
                (restaurant_id, order_id, payment_id, employee_identifier, employee_name, gross, commission, company_net)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ]],
        values = {
            payment.restaurant_id, payment.order_id, paymentId, payment.employee_identifier,
            payment.employee_name, amount, commission, companyNet
        }
    }
    if commission > 0 then
        transaction[#transaction + 1] = {
            query = [[
                INSERT IGNORE INTO ob_restaurant_commissions (sale_id, employee_identifier, amount)
                SELECT id, ?, ? FROM ob_restaurant_sales WHERE payment_id = ?
            ]],
            values = { payment.employee_identifier, commission, paymentId }
        }
    end
    transaction[#transaction + 1] = {
        query = [[
            INSERT INTO ob_restaurant_accounts (restaurant_id, balance)
            VALUES (?, ?)
            ON DUPLICATE KEY UPDATE balance = balance + VALUES(balance)
        ]],
        values = { payment.restaurant_id, companyNet }
    }

    if not MySQL.transaction.await(transaction) then
        Restaurant.addMoney(src, account, amount, 'estorno-pagamento-restaurante')
        MySQL.update.await("UPDATE ob_restaurant_payments SET status = 'pending' WHERE id = ? AND status = 'processing'", { paymentId })
        return { ok = false, error = 'payment_processing_failed' }
    end
    Restaurant.creditCompanyProvider(payment.restaurant_id, companyNet, 'venda-restaurante')
    if commission > 0 then
        local employeeSource = tonumber(payment.employee_source)
        if employeeSource and GetPlayerName(employeeSource) then Restaurant.settleCommission(employeeSource) end
    end
    notifyClients(payment.restaurant_id, 'paymentPaid', { paymentId = paymentId, orderId = payment.order_id })
    return { ok = true, amount = amount, commission = commission, companyNet = companyNet }
end

handlers.getOrders = function(src, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not Restaurant.canWork(src, restaurant) then return { ok = false, error = 'not_employee' } end
    return { ok = true, orders = loadOrders(restaurant.id, data.includeClosed == true) }
end

handlers.setOrderStatus = function(src, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not Restaurant.canWork(src, restaurant) then return { ok = false, error = 'not_employee' } end
    local orderId = tonumber(data.orderId)
    local status = cleanText(data.status, 24)
    local allowed = { preparing = true, ready = true, delivered = true, cancelled = true }
    if not orderId or not allowed[status] then return { ok = false, error = 'invalid_status' } end

    local order = MySQL.single.await('SELECT * FROM ob_restaurant_orders WHERE id = ? AND restaurant_id = ?', { orderId, restaurant.id })
    if not order then return { ok = false, error = 'order_not_found' } end
    local transitions = {
        queued = { preparing = true, cancelled = true },
        preparing = { ready = true, cancelled = true },
        ready = { delivered = true }
    }
    if not (transitions[order.status] and transitions[order.status][status]) then return { ok = false, error = 'invalid_transition' } end

    MySQL.update.await('UPDATE ob_restaurant_orders SET status = ? WHERE id = ?', { status, orderId })
    notifyClients(restaurant.id, 'orderStatus', { orderId = orderId, status = status })
    if status == 'ready' then announceReady(restaurant.id, order) end
    return { ok = true }
end

handlers.startProduction = function(src, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not Restaurant.canWork(src, restaurant) then return { ok = false, error = 'not_employee' } end
    local recipe = MySQL.single.await('SELECT * FROM ob_restaurant_recipes WHERE id = ? AND restaurant_id = ? AND enabled = 1', {
        tonumber(data.recipeId), restaurant.id
    })
    if not recipe then return { ok = false, error = 'recipe_not_found' } end

    local ingredients = Restaurant.jsonDecode(recipe.ingredients, {})
    local success, removed, missing = Restaurant.takeIngredients(src, ingredients)
    if not success then return { ok = false, error = 'missing_ingredient', item = missing } end

    local prepTime = math.max(1, math.min(300, math.floor(tonumber(recipe.prep_time) or 5)))
    local productionId = MySQL.insert.await([[
        INSERT INTO ob_restaurant_productions
            (restaurant_id, recipe_id, employee_identifier, employee_source, status, ready_at)
        VALUES (?, ?, ?, ?, 'preparing', TIMESTAMPADD(SECOND, ?, NOW()))
    ]], { restaurant.id, recipe.id, Restaurant.getIdentifier(src), src, prepTime })
    if not productionId then
        Restaurant.restoreIngredients(src, removed)
        return { ok = false, error = 'create_failed' }
    end
    return { ok = true, productionId = productionId, prepTime = prepTime, readyAt = os.time() * 1000 + prepTime * 1000 }
end

handlers.collectProduction = function(src, data)
    local productionId = tonumber(data.productionId)
    local production = MySQL.single.await([[
        SELECT p.*, r.name, r.description, r.image, r.output_item, r.output_amount,
               r.product_type, r.item_weight, r.presentation_key, r.is_combo, r.contents, r.effects
        FROM ob_restaurant_productions p
        INNER JOIN ob_restaurant_recipes r ON r.id = p.recipe_id
        WHERE p.id = ? AND p.employee_identifier = ? AND p.status = 'preparing'
    ]], { productionId, Restaurant.getIdentifier(src) })
    if not production then return { ok = false, error = 'production_not_found' } end

    local locked = MySQL.update.await([[
        UPDATE ob_restaurant_productions SET status = 'collecting'
        WHERE id = ? AND status = 'preparing' AND ready_at <= NOW()
    ]], { productionId })
    if tonumber(locked) ~= 1 then return { ok = false, error = 'not_ready' } end

    local metadata = buildRecipeMetadata(production, production.restaurant_id)
    local amount = math.max(1, math.floor(tonumber(production.output_amount) or 1))
    if not Restaurant.canCarry(src, production.output_item, amount, metadata) or not Restaurant.addItem(src, production.output_item, amount, metadata) then
        MySQL.update.await("UPDATE ob_restaurant_productions SET status = 'preparing' WHERE id = ? AND status = 'collecting'", { productionId })
        return { ok = false, error = 'inventory_full' }
    end
    MySQL.update.await("UPDATE ob_restaurant_productions SET status = 'collected', collected_at = NOW() WHERE id = ?", { productionId })
    return { ok = true, item = production.output_item, amount = amount }
end

handlers.getProductions = function(src, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not Restaurant.canWork(src, restaurant) then return { ok = false, error = 'not_employee' } end
    return { ok = true, productions = loadProductions(restaurant.id, src) }
end

handlers.saveRecipe = function(src, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not Restaurant.canManage(src, restaurant) then return { ok = false, error = 'not_manager' } end
    local recipe = type(data.recipe) == 'table' and data.recipe or {}
    local limits = Config.ManagementLimits or {}
    local name = cleanText(recipe.name, 96)
    local outputItem = restaurantProductItem()
    local categoryKey = validKey(recipe.categoryKey or recipe.category_key, 48)
    if not name or not outputItem or not categoryKey then return { ok = false, error = 'invalid_recipe' } end
    if not Restaurant.itemExists(outputItem) then return { ok = false, error = 'restaurant_product_item_missing', item = outputItem } end

    local categoryExists = MySQL.scalar.await([[
        SELECT COUNT(*) FROM ob_restaurant_categories
        WHERE restaurant_id = ? AND category_key = ? AND enabled = 1
    ]], { restaurant.id, categoryKey })
    if not tonumber(categoryExists) or tonumber(categoryExists) < 1 then
        return { ok = false, error = 'category_not_found' }
    end

    local ingredients = {}
    for _, ingredient in ipairs(type(recipe.ingredients) == 'table' and recipe.ingredients or {}) do
        local rawItem = cleanText(ingredient.item, 64)
        local item = validKey(ingredient.item, 64)
        if rawItem and not item then return { ok = false, error = 'invalid_inventory_item', item = rawItem } end
        if item then
            if not Restaurant.itemExists(item) then return { ok = false, error = 'unknown_inventory_item', item = item } end
            ingredients[#ingredients + 1] = {
                item = item,
                label = cleanText(ingredient.label, 80) or item,
                amount = math.min(math.floor(tonumber(limits.maxAmountPerIngredient) or 1000), math.max(1, math.floor(tonumber(ingredient.amount) or 1)))
            }
            if #ingredients >= math.floor(tonumber(limits.maxIngredients) or 24) then break end
        end
    end
    if #ingredients < 1 then return { ok = false, error = 'ingredients_required' } end

    local contents = {}
    for _, content in ipairs(type(recipe.contents) == 'table' and recipe.contents or {}) do
        local rawItem = cleanText(content.item, 64)
        local item = validKey(content.item, 64)
        if rawItem and not item then return { ok = false, error = 'invalid_inventory_item', item = rawItem } end
        if item then
            if not Restaurant.itemExists(item) then return { ok = false, error = 'unknown_inventory_item', item = item } end
            contents[#contents + 1] = {
                item = item,
                label = cleanText(content.label, 80) or item,
                amount = math.min(math.floor(tonumber(limits.maxAmountPerIngredient) or 1000), math.max(1, math.floor(tonumber(content.amount) or 1)))
            }
            if #contents >= math.floor(tonumber(limits.maxContents) or 24) then break end
        end
    end
    local craftSteps = normalizeCraftSteps(recipe.craftSteps or recipe.craft_steps)
    local effects, effectError = normalizeRecipeEffects(recipe.effects, true)
    if not effects then return { ok = false, error = effectError } end

    local recipeId = tonumber(recipe.id)
    local image = validImage(recipe.image)
    if image == nil then return { ok = false, error = 'invalid_image' } end
    local price = math.min(math.floor(tonumber(limits.maxPrice) or 1000000), math.max(0, math.floor(tonumber(recipe.price) or 0)))
    local oldPrice = math.min(math.floor(tonumber(limits.maxPrice) or 1000000), math.max(0, math.floor(tonumber(recipe.oldPrice or recipe.old_price) or 0)))
    if oldPrice <= price then oldPrice = nil end
    local menuBadge = cleanText(recipe.menuBadge or recipe.menu_badge, 32) or ''
    local featured = (recipe.featured == true or recipe.featured == 1) and 1 or 0
    local productType = normalizeProductType(recipe.productType or recipe.product_type)
    local itemWeight = normalizeProductWeight(recipe.itemWeight or recipe.item_weight)
    local presentationKey = normalizePresentationKey(recipe.presentationKey or recipe.presentation_key, restaurant.id, productType)
    if presentationKey == nil then return { ok = false, error = 'invalid_presentation' } end
    if recipeId then
        local changed = MySQL.update.await([[
            UPDATE ob_restaurant_recipes SET category_key = ?, name = ?, description = ?, image = ?, icon = ?,
                price = ?, old_price = ?, menu_badge = ?, featured = ?, prep_time = ?, output_item = ?,
                output_amount = ?, product_type = ?, item_weight = ?, presentation_key = ?, is_combo = ?, ingredients = ?, contents = ?,
                craft_steps = ?, effects = ?, enabled = ?
            WHERE id = ? AND restaurant_id = ?
        ]], {
            categoryKey, name, cleanText(recipe.description, 255) or '', image,
            cleanText(recipe.icon, 48) or 'utensils', price, oldPrice, menuBadge, featured,
            math.min(math.floor(tonumber(limits.maxPrepSeconds) or 1800), math.max(1, math.floor(tonumber(recipe.prepTime or recipe.prep_time) or 5))), outputItem,
            math.min(math.floor(tonumber(limits.maxOutputAmount) or 100), math.max(1, math.floor(tonumber(recipe.outputAmount or recipe.output_amount) or 1))),
            productType, itemWeight, presentationKey,
            (recipe.isCombo == true or recipe.is_combo == true or recipe.is_combo == 1) and 1 or 0,
            Restaurant.jsonEncode(ingredients), Restaurant.jsonEncode(contents), Restaurant.jsonEncode(craftSteps), Restaurant.jsonEncode(effects),
            recipe.enabled == false and 0 or 1,
            recipeId, restaurant.id
        })
        if tonumber(changed) ~= 1 then return { ok = false, error = 'recipe_not_found' } end
    else
        local recipeKey = validKey(recipe.key or recipe.recipe_key, 64) or ('recipe_' .. os.time() .. '_' .. math.random(100, 999))
        recipeId = MySQL.insert.await([[
            INSERT INTO ob_restaurant_recipes
                (restaurant_id, recipe_key, category_key, name, description, image, icon, price, old_price,
                 menu_badge, featured, prep_time, output_item, output_amount, product_type, item_weight, presentation_key, is_combo,
                 ingredients, contents, craft_steps, effects, enabled)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            restaurant.id, recipeKey, categoryKey, name, cleanText(recipe.description, 255) or '',
            image, cleanText(recipe.icon, 48) or 'utensils',
            price, oldPrice, menuBadge, featured,
            math.min(math.floor(tonumber(limits.maxPrepSeconds) or 1800), math.max(1, math.floor(tonumber(recipe.prepTime) or 5))),
            outputItem, math.min(math.floor(tonumber(limits.maxOutputAmount) or 100), math.max(1, math.floor(tonumber(recipe.outputAmount) or 1))),
            productType, itemWeight, presentationKey, recipe.isCombo and 1 or 0,
            Restaurant.jsonEncode(ingredients), Restaurant.jsonEncode(contents), Restaurant.jsonEncode(craftSteps), Restaurant.jsonEncode(effects),
            recipe.enabled == false and 0 or 1
        })
    end
    Restaurant.audit(src, restaurant.id, recipe.id and 'recipe_updated' or 'recipe_created', { recipeId = recipeId, name = name, effects = effects })
    notifyClients(restaurant.id, 'catalogChanged', {})
    return { ok = true, recipeId = recipeId }
end

handlers.deleteRecipe = function(src, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not Restaurant.canManage(src, restaurant) then return { ok = false, error = 'not_manager' } end
    local recipeId = tonumber(data.recipeId)
    if not recipeId then return { ok = false, error = 'invalid_recipe' } end
    local changed = MySQL.update.await('UPDATE ob_restaurant_recipes SET enabled = 0 WHERE id = ? AND restaurant_id = ? AND enabled = 1', { recipeId, restaurant.id })
    if tonumber(changed) ~= 1 then return { ok = false, error = 'recipe_not_found' } end
    Restaurant.audit(src, restaurant.id, 'recipe_deleted', { recipeId = recipeId })
    notifyClients(restaurant.id, 'catalogChanged', {})
    return { ok = true }
end

handlers.saveCategory = function(src, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not Restaurant.canManage(src, restaurant) then return { ok = false, error = 'not_manager' } end
    local category = type(data.category) == 'table' and data.category or {}
    local key, label = validKey(category.key or category.category_key, 48), cleanText(category.label, 80)
    if not key or not label then return { ok = false, error = 'invalid_category' } end
    MySQL.update.await([[
        INSERT INTO ob_restaurant_categories (restaurant_id, category_key, label, icon, sort_order, enabled)
        VALUES (?, ?, ?, ?, ?, 1)
        ON DUPLICATE KEY UPDATE label = VALUES(label), icon = VALUES(icon), sort_order = VALUES(sort_order), enabled = 1
    ]], { restaurant.id, key, label, cleanText(category.icon, 48) or 'utensils', math.floor(tonumber(category.sortOrder or category.sort_order) or 0) })
    Restaurant.audit(src, restaurant.id, 'category_saved', { categoryKey = key, label = label })
    notifyClients(restaurant.id, 'catalogChanged', {})
    return { ok = true }
end

handlers.deleteCategory = function(src, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not Restaurant.canManage(src, restaurant) then return { ok = false, error = 'not_manager' } end
    local categoryKey = validKey(data.categoryKey or data.category_key, 48)
    if not categoryKey then return { ok = false, error = 'invalid_category' } end

    local category = MySQL.single.await([[
        SELECT id FROM ob_restaurant_categories
        WHERE restaurant_id = ? AND category_key = ? AND enabled = 1
    ]], { restaurant.id, categoryKey })
    if not category then return { ok = false, error = 'category_not_found' } end

    MySQL.update.await([[
        UPDATE ob_restaurant_categories SET enabled = 0
        WHERE restaurant_id = ? AND category_key = ?
    ]], { restaurant.id, categoryKey })
    local affectedRecipes = MySQL.update.await([[
        UPDATE ob_restaurant_recipes SET enabled = 0
        WHERE restaurant_id = ? AND category_key = ? AND enabled = 1
    ]], { restaurant.id, categoryKey })
    Restaurant.audit(src, restaurant.id, 'category_deleted', { categoryKey = categoryKey, affectedRecipes = tonumber(affectedRecipes) or 0 })
    notifyClients(restaurant.id, 'catalogChanged', {})
    return { ok = true, affectedRecipes = tonumber(affectedRecipes) or 0 }
end

handlers.savePoint = function(src, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not Restaurant.canManage(src, restaurant) then return { ok = false, error = 'not_manager' } end
    local point = type(data.point) == 'table' and data.point or {}
    local pointType = cleanText(point.type, 24)
    if not pointType or not Config.PointTypes[pointType] then return { ok = false, error = 'invalid_point' } end
    local ped = GetPlayerPed(src)
    if ped <= 0 then return { ok = false, error = 'player_position_unavailable' } end
    local coords = GetEntityCoords(ped)
    local encoded = Restaurant.jsonEncode({ x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0, h = GetEntityHeading(ped) + 0.0 })
    local pointId = tonumber(point.id)
    if pointId then
        local changed = MySQL.update.await([[
            UPDATE ob_restaurant_points SET type = ?, label = ?, coords = ?, enabled = ?
            WHERE id = ? AND restaurant_id = ?
        ]], { pointType, cleanText(point.label, 96) or Config.PointTypes[pointType].label, encoded, point.enabled == false and 0 or 1, pointId, restaurant.id })
        if tonumber(changed) ~= 1 then return { ok = false, error = 'point_not_found' } end
    else
        pointId = MySQL.insert.await([[
            INSERT INTO ob_restaurant_points (restaurant_id, type, label, coords, enabled)
            VALUES (?, ?, ?, ?, 1)
        ]], { restaurant.id, pointType, cleanText(point.label, 96) or Config.PointTypes[pointType].label, encoded })
    end
    Restaurant.audit(src, restaurant.id, point.id and 'point_repositioned' or 'point_created', { pointId = pointId, type = pointType, label = cleanText(point.label, 96) })
    TriggerClientEvent('ob_restaurantes:client:reloadPoints', -1)
    return { ok = true, pointId = pointId }
end

handlers.deletePoint = function(src, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not Restaurant.canManage(src, restaurant) then return { ok = false, error = 'not_manager' } end
    local pointId = tonumber(data.pointId)
    if not pointId then return { ok = false, error = 'invalid_point' } end
    local changed = MySQL.update.await('DELETE FROM ob_restaurant_points WHERE id = ? AND restaurant_id = ?', { pointId, restaurant.id })
    if tonumber(changed) ~= 1 then return { ok = false, error = 'point_not_found' } end
    Restaurant.audit(src, restaurant.id, 'point_deleted', { pointId = pointId })
    TriggerClientEvent('ob_restaurantes:client:reloadPoints', -1)
    return { ok = true }
end

handlers.saveRestaurant = function(src, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not Restaurant.canAdminister(src, restaurant) then return { ok = false, error = 'not_owner' } end
    local settings = type(data.settings) == 'table' and data.settings or {}
    local label = cleanText(settings.label, 96)
    if not label then return { ok = false, error = 'invalid_restaurant' } end
    local commissionRate = math.max(0, math.min(0.9, tonumber(settings.commissionRate) or tonumber(restaurant.commission_rate)))
    local managerGrade = math.max(0, math.min(20, math.floor(tonumber(settings.managerGrade) or tonumber(restaurant.manager_grade))))
    local theme = validKey(settings.theme, 32) or restaurant.theme
    MySQL.update.await([[
        UPDATE ob_restaurants SET label = ?, commission_rate = ?, manager_grade = ?, theme = ? WHERE id = ?
    ]], {
        label, commissionRate, managerGrade, theme, restaurant.id
    })
    Restaurant.audit(src, restaurant.id, 'restaurant_updated', {
        label = label, commissionRate = commissionRate, managerGrade = managerGrade, theme = theme
    })
    notifyClients(restaurant.id, 'restaurantChanged', {})
    return { ok = true }
end

handlers.saveProfile = function(src, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not Restaurant.canAdminister(src, restaurant) then return { ok = false, error = 'not_owner' } end
    local profile = type(data.profile) == 'table' and data.profile or {}
    local isAdmin = Restaurant.isAdmin(src)

    if not isAdmin and (profile.description ~= nil or profile.locationLabel ~= nil or profile.callText ~= nil or profile.features ~= nil) then
        return { ok = false, error = 'staff_required' }
    end

    local coverUrl = profile.coverUrl ~= nil and validImage(profile.coverUrl) or restaurant.cover_url
    local menuImageUrl = profile.menuImageUrl ~= nil and validImage(profile.menuImageUrl) or restaurant.menu_image_url
    if coverUrl == nil or menuImageUrl == nil then return { ok = false, error = 'invalid_image' } end

    local notesChanged = profile.notes ~= nil
    local description = profile.description ~= nil and (cleanText(profile.description, 255) or '') or restaurant.description
    local notes = notesChanged and cleanMultiline(profile.notes, 4000) or (restaurant.notes or '')
    local locationLabel = profile.locationLabel ~= nil and (cleanText(profile.locationLabel, 160) or '') or restaurant.location_label
    local callText = profile.callText ~= nil and (cleanText(profile.callText, 255) or '') or restaurant.call_text
    local features = type(profile.features) == 'table' and profile.features or {}
    local featureMenu = isAdmin and profile.features ~= nil and boolValue(features.menu, false) or boolValue(restaurant.feature_menu, true)
    local featureLocation = isAdmin and profile.features ~= nil and boolValue(features.location, false) or boolValue(restaurant.feature_location, true)
    local featureCall = isAdmin and profile.features ~= nil and boolValue(features.call, false) or boolValue(restaurant.feature_call, true)

    MySQL.update.await([[
        UPDATE ob_restaurants
        SET description = ?, cover_url = ?, menu_image_url = ?, notes = ?,
            notes_updated_by = ?, notes_updated_at = ?, feature_menu = ?,
            feature_location = ?, feature_call = ?, location_label = ?, call_text = ?
        WHERE id = ?
    ]], {
        description, coverUrl or '', menuImageUrl or '', notes,
        notesChanged and Restaurant.getName(src) or restaurant.notes_updated_by,
        notesChanged and os.date('%Y-%m-%d %H:%M:%S') or restaurant.notes_updated_at,
        featureMenu and 1 or 0, featureLocation and 1 or 0, featureCall and 1 or 0,
        locationLabel, callText, restaurant.id
    })
    Restaurant.audit(src, restaurant.id, 'profile_updated', {
        notesChanged = notesChanged,
        coverChanged = profile.coverUrl ~= nil,
        menuImageChanged = profile.menuImageUrl ~= nil,
        featuresChanged = profile.features ~= nil
    })
    notifyClients(restaurant.id, 'restaurantChanged', {})
    return { ok = true }
end

handlers.hireMember = function(src, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not Restaurant.canAdminister(src, restaurant) then return { ok = false, error = 'not_owner' } end
    local targetSource = tonumber(data.playerId or data.source)
    local target = targetSource and Restaurant.getPlayer(targetSource) or nil
    local targetData = target and target.PlayerData or nil
    local citizenId = targetData and tostring(targetData.citizenid or '') or ''
    if citizenId == '' then return { ok = false, error = 'target_player_not_found' } end
    if not Restaurant.addPlayerToJob(citizenId, restaurant.job, 0) then return { ok = false, error = 'job_update_failed' } end

    Restaurant.audit(src, restaurant.id, 'member_hired', { citizenId = citizenId, targetSource = targetSource, grade = 0 })
    pcall(function() exports.qbx_core:Notify(targetSource, ('Você foi contratado por %s.'):format(restaurant.label), 'success') end)
    local members, grades = loadMembers(restaurant)
    return { ok = true, members = members, jobGrades = grades }
end

handlers.changeMemberGrade = function(src, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not Restaurant.canAdminister(src, restaurant) then return { ok = false, error = 'not_owner' } end
    local citizenId = cleanText(data.citizenId, 50)
    local direction = data.direction == 'down' and -1 or data.direction == 'up' and 1 or 0
    if not citizenId or direction == 0 then return { ok = false, error = 'invalid_member' } end

    local row = MySQL.single.await("SELECT grade FROM player_groups WHERE citizenid = ? AND type = 'job' AND `group` = ?", { citizenId, restaurant.job })
    if not row then return { ok = false, error = 'member_not_found' } end
    local currentGrade = math.max(0, math.floor(tonumber(row.grade) or 0))
    local newGrade = currentGrade + direction
    local definition = Restaurant.getJobDefinition(restaurant.job) or {}
    local gradeDefinition = type(definition.grades) == 'table' and (definition.grades[newGrade] or definition.grades[tostring(newGrade)]) or nil
    if not gradeDefinition then return { ok = false, error = direction > 0 and 'maximum_grade' or 'minimum_grade' } end

    if not Restaurant.isAdmin(src) then
        local actor = Restaurant.getMembership(src, restaurant.job)
        if citizenId == Restaurant.getIdentifier(src) or currentGrade >= actor.grade or newGrade >= actor.grade then
            return { ok = false, error = 'member_rank_protected' }
        end
    end
    if not Restaurant.addPlayerToJob(citizenId, restaurant.job, newGrade) then return { ok = false, error = 'job_update_failed' } end

    Restaurant.audit(src, restaurant.id, 'member_grade_changed', { citizenId = citizenId, from = currentGrade, to = newGrade })
    local target = Restaurant.getPlayerByCitizenId(citizenId)
    if target and target.PlayerData and target.PlayerData.source then
        pcall(function() exports.qbx_core:Notify(target.PlayerData.source, ('Seu cargo em %s foi atualizado.'):format(restaurant.label), 'inform') end)
    end
    local members, grades = loadMembers(restaurant)
    return { ok = true, members = members, jobGrades = grades }
end

handlers.fireMember = function(src, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not Restaurant.canAdminister(src, restaurant) then return { ok = false, error = 'not_owner' } end
    local citizenId = cleanText(data.citizenId, 50)
    if not citizenId then return { ok = false, error = 'invalid_member' } end
    local row = MySQL.single.await("SELECT grade FROM player_groups WHERE citizenid = ? AND type = 'job' AND `group` = ?", { citizenId, restaurant.job })
    if not row then return { ok = false, error = 'member_not_found' } end

    if not Restaurant.isAdmin(src) then
        local actor = Restaurant.getMembership(src, restaurant.job)
        local targetGrade = math.max(0, math.floor(tonumber(row.grade) or 0))
        if citizenId == Restaurant.getIdentifier(src) or targetGrade >= actor.grade then return { ok = false, error = 'member_rank_protected' } end
    end
    if not Restaurant.removePlayerFromJob(citizenId, restaurant.job) then return { ok = false, error = 'job_update_failed' } end

    Restaurant.audit(src, restaurant.id, 'member_fired', { citizenId = citizenId })
    local target = Restaurant.getPlayerByCitizenId(citizenId)
    if target and target.PlayerData and target.PlayerData.source then
        pcall(function() exports.qbx_core:Notify(target.PlayerData.source, ('Você foi desligado de %s.'):format(restaurant.label), 'inform') end)
    end
    local members, grades = loadMembers(restaurant)
    return { ok = true, members = members, jobGrades = grades }
end

handlers.getDashboard = function(src, data)
    local restaurant = findRestaurant(src, cleanText(data.restaurantId, 64))
    if not Restaurant.canManage(src, restaurant) then return { ok = false, error = 'not_manager' } end
    return { ok = true, restaurant = restaurant, dashboard = dashboard(restaurant.id) }
end

handlers.withdrawCompany = function(src, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not Restaurant.canAdminister(src, restaurant) then return { ok = false, error = 'not_owner' } end
    local amount = math.floor(tonumber(data.amount) or 0)
    local maximum = math.floor(tonumber((Config.ManagementLimits or {}).maxWithdrawal) or 100000000)
    if amount < 1 or amount > maximum then return { ok = false, error = 'invalid_total' } end
    local changed = MySQL.update.await([[
        UPDATE ob_restaurant_accounts SET balance = balance - ? WHERE restaurant_id = ? AND balance >= ?
    ]], { amount, restaurant.id, amount })
    if tonumber(changed) ~= 1 then return { ok = false, error = 'insufficient_company_balance' } end
    if not Restaurant.addMoney(src, 'bank', amount, 'saque-caixa-restaurante') then
        Restaurant.depositCompany(restaurant.id, amount, 'estorno-saque')
        return { ok = false, error = 'withdraw_failed' }
    end
    Restaurant.audit(src, restaurant.id, 'company_withdrawal', { amount = amount })
    return { ok = true, amount = amount }
end

handlers.display = function(_, data)
    local restaurant = Restaurant.getRestaurant(cleanText(data.restaurantId, 64))
    if not restaurant then return { ok = false, error = 'restaurant_not_found' } end
    local queuedExpiry = math.max(1, math.floor(tonumber(Config.DisplayQueuedExpiryMinutes) or 15))
    local orders = decodeRows(MySQL.query.await([[
        SELECT id, public_code, customer_name, status, updated_at
        FROM ob_restaurant_orders
        WHERE restaurant_id = ?
          AND (
            status IN ('preparing', 'ready')
            OR (status = 'queued' AND updated_at >= DATE_SUB(NOW(), INTERVAL ? MINUTE))
          )
        ORDER BY FIELD(status, 'ready', 'preparing', 'queued'), updated_at ASC LIMIT 24
    ]], { restaurant.id, queuedExpiry }) or {})
    return {
        ok = true,
        visible = #orders > 0,
        restaurant = { id = restaurant.id, label = restaurant.label },
        orders = orders
    }
end

RegisterNetEvent('ob_restaurantes:server:request', function(token, action, payload)
    local src = source
    token = tonumber(token)
    action = tostring(action or '')
    if not token or not handlers[action] then
        respond(src, token, { ok = false, error = 'unknown_action' })
        return
    end
    if isRateLimited(src, action) then
        respond(src, token, { ok = false, error = 'rate_limited' })
        return
    end

    local ok, result = pcall(handlers[action], src, type(payload) == 'table' and payload or {})
    if not ok then
        print(('[ob_restaurantes] Erro em %s: %s'):format(action, result))
        respond(src, token, { ok = false, error = 'server_error' })
        return
    end
    respond(src, token, result or { ok = true })
end)

AddEventHandler('playerDropped', function()
    local prefix = ('%d:'):format(source)
    for key in pairs(requestWindows) do
        if key:sub(1, #prefix) == prefix then requestWindows[key] = nil end
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    CreateThread(function()
        migrate()
        seed()
        MySQL.update.await("UPDATE ob_restaurant_payments SET status = 'expired' WHERE status IN ('pending', 'processing') AND expires_at <= NOW()")
        Wait(2500)
        local recent = MySQL.query.await([[
            SELECT id, restaurant_id, order_id, message
            FROM ob_restaurant_announcements
            WHERE created_at >= DATE_SUB(NOW(), INTERVAL 90 SECOND)
            ORDER BY id ASC LIMIT 10
        ]]) or {}
        for index, item in ipairs(recent) do
            emitAnnouncement(item.id, item.restaurant_id, item.order_id, item.message, os.time() * 1000 + 900 + index * 350, nil)
        end
        print('[ob_restaurantes] Banco, catalogo e integracoes carregados.')
    end)
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local src = type(player) == 'table' and player.PlayerData and player.PlayerData.source or source
    if src then CreateThread(function() Restaurant.settleCommission(tonumber(src)) end) end
end)

AddEventHandler('ox_inventory:usedItem', function(src, itemName, _, metadata)
    src = tonumber(src)
    local isRestaurantProduct = tostring(itemName or '') == restaurantProductItem()
    local itemSettings = ((Config.RecipeEffects or {}).items or {})[tostring(itemName or '')]
    if not src or (not isRestaurantProduct and not itemSettings) then return end
    if isRestaurantProduct and (type(metadata) ~= 'table' or metadata.restaurantProduct ~= true) then return end

    local hasRecipeMetadata = type(metadata) == 'table' and metadata.restaurantEffects ~= nil
    local rawEffects = hasRecipeMetadata and metadata.restaurantEffects or (itemSettings and itemSettings.fallback)
    local effects = normalizeRecipeEffects(rawEffects, false)
    if not effects or not next(effects) then return end

    local player = Restaurant.getPlayer(src)
    local playerData = player and player.PlayerData or nil
    local current = playerData and playerData.metadata or nil
    if not current or not player.Functions or not player.Functions.SetMetaData then return end

    if effects.hunger then
        player.Functions.SetMetaData('hunger', math.min(100, (tonumber(current.hunger) or 0) + effects.hunger))
    end
    if effects.thirst then
        player.Functions.SetMetaData('thirst', math.min(100, (tonumber(current.thirst) or 0) + effects.thirst))
    end
    if effects.stress then
        player.Functions.SetMetaData('stress', math.max(0, (tonumber(current.stress) or 0) - effects.stress))
    end
end)

exports('GetCommerceDashboard', function(src, restaurantId)
    src = tonumber(src)
    local restaurant = findRestaurant(src, restaurantId)
    if not restaurant or not Restaurant.canManage(src, restaurant) then return { ok = false, error = 'not_manager' } end
    return { ok = true, restaurant = restaurant, dashboard = dashboard(restaurant.id) }
end)

exports('GetRestaurantAdminPayload', function(src, restaurantId)
    src = tonumber(src)
    local restaurant = Restaurant.getRestaurant(restaurantId)
    if not restaurant then return { ok = false, error = 'restaurant_not_found' } end
    if not Restaurant.canAdminister(src, restaurant) then return { ok = false, error = 'not_owner' } end
    return restaurantPayload(src, restaurant, 'admin')
end)

local managementActions = {
    saveRecipe = true,
    deleteRecipe = true,
    saveCategory = true,
    deleteCategory = true,
    savePoint = true,
    deletePoint = true,
    saveRestaurant = true,
    withdrawCompany = true,
    saveProfile = true,
    hireMember = true,
    changeMemberGrade = true,
    fireMember = true
}

exports('RunRestaurantManagementAction', function(src, action, payload)
    src = tonumber(src)
    action = tostring(action or '')
    payload = type(payload) == 'table' and payload or {}

    if not managementActions[action] or not handlers[action] then
        return { ok = false, error = 'unknown_action' }
    end

    local restaurant = Restaurant.getRestaurant(cleanText(payload.restaurantId, 64))
    if not restaurant then return { ok = false, error = 'restaurant_not_found' } end
    if not Restaurant.canAdminister(src, restaurant) then return { ok = false, error = 'not_owner' } end

    local ok, result = pcall(handlers[action], src, payload)
    if not ok then
        print(('[ob_restaurantes] Erro na gestao integrada (%s): %s'):format(action, result))
        return { ok = false, error = 'server_error' }
    end

    return result or { ok = true }
end)

exports('GetRestaurantsForSource', function(src)
    src = tonumber(src)
    if Restaurant.isAdmin(src) then
        return MySQL.query.await('SELECT * FROM ob_restaurants WHERE enabled = 1 ORDER BY label') or {}
    end
    local restaurant = Restaurant.getRestaurantForSource(src)
    return restaurant and { restaurant } or {}
end)

exports('GetEstablishmentDirectory', function(src)
    src = tonumber(src)
    local rows = MySQL.query.await([[
        SELECT id, label, job, manager_grade, commission_rate, theme, enabled, is_open,
               description, cover_url, menu_image_url, notes, notes_updated_by, notes_updated_at,
               feature_menu, feature_location, feature_call, location_label, call_text
        FROM ob_restaurants
        WHERE enabled = 1
        ORDER BY label ASC
    ]]) or {}

    local categoryRows = MySQL.query.await([[
        SELECT restaurant_id, category_key, label, icon, sort_order
        FROM ob_restaurant_categories
        WHERE enabled = 1
        ORDER BY restaurant_id, sort_order, id
    ]]) or {}
    local recipeRows = MySQL.query.await([[
        SELECT id, restaurant_id, category_key, name, description, image, icon,
               price, old_price, menu_badge, featured, is_combo
        FROM ob_restaurant_recipes
        WHERE enabled = 1
        ORDER BY restaurant_id, featured DESC, category_key, name
    ]]) or {}
    local pointRows = decodeRows(MySQL.query.await([[
        SELECT restaurant_id, type, coords
        FROM ob_restaurant_points
        WHERE enabled = 1 AND type IN ('menu', 'terminal', 'pos')
        ORDER BY restaurant_id, FIELD(type, 'menu', 'terminal', 'pos'), id
    ]]) or {})

    local categoriesByRestaurant, recipesByRestaurant, locationsByRestaurant = {}, {}, {}
    for _, category in ipairs(categoryRows) do
        local id = tostring(category.restaurant_id)
        categoriesByRestaurant[id] = categoriesByRestaurant[id] or {}
        categoriesByRestaurant[id][#categoriesByRestaurant[id] + 1] = {
            key = category.category_key,
            label = category.label,
            icon = category.icon,
            sortOrder = tonumber(category.sort_order) or 0
        }
    end
    for _, recipe in ipairs(recipeRows) do
        local id = tostring(recipe.restaurant_id)
        recipesByRestaurant[id] = recipesByRestaurant[id] or {}
        recipesByRestaurant[id][#recipesByRestaurant[id] + 1] = {
            id = tonumber(recipe.id),
            categoryKey = recipe.category_key,
            name = recipe.name,
            description = recipe.description,
            image = recipe.image,
            icon = recipe.icon,
            price = math.floor(tonumber(recipe.price) or 0),
            oldPrice = tonumber(recipe.old_price) and math.floor(tonumber(recipe.old_price)) or nil,
            badge = recipe.menu_badge,
            featured = recipe.featured == 1 or recipe.featured == true,
            isCombo = recipe.is_combo == 1 or recipe.is_combo == true
        }
    end
    for _, point in ipairs(pointRows) do
        local id = tostring(point.restaurant_id)
        if not locationsByRestaurant[id] and type(point.coords) == 'table' and point.coords.x then
            locationsByRestaurant[id] = {
                x = tonumber(point.coords.x),
                y = tonumber(point.coords.y),
                z = tonumber(point.coords.z)
            }
        end
    end

    local restaurants = {}
    for _, restaurant in ipairs(rows) do
        local id = tostring(restaurant.id)
        local canAdminister = Restaurant.canAdminister(src, restaurant)
        local membership = Restaurant.getMembership(src, restaurant.job)
        restaurants[#restaurants + 1] = {
            id = id,
            label = restaurant.label,
            job = restaurant.job,
            theme = restaurant.theme,
            isOpen = restaurant.is_open == nil or restaurant.is_open == 1 or restaurant.is_open == true,
            canWork = Restaurant.canWork(src, restaurant),
            canManage = canAdminister,
            isBoss = Restaurant.isBossOf(src, restaurant),
            isMember = membership.member == true,
            description = restaurant.description or '',
            coverUrl = restaurant.cover_url or '',
            menuImageUrl = restaurant.menu_image_url or '',
            notes = {
                text = restaurant.notes or '',
                updatedBy = restaurant.notes_updated_by or '',
                updatedAt = restaurant.notes_updated_at
            },
            features = {
                menu = boolValue(restaurant.feature_menu, true),
                location = boolValue(restaurant.feature_location, true),
                call = boolValue(restaurant.feature_call, true)
            },
            locationLabel = restaurant.location_label or '',
            callText = restaurant.call_text or '',
            location = locationsByRestaurant[id],
            menu = {
                categories = categoriesByRestaurant[id] or {},
                recipes = recipesByRestaurant[id] or {}
            }
        }
    end

    return {
        restaurants = restaurants,
        isAdmin = Restaurant.isAdmin(src),
        profile = {
            id = Restaurant.getIdentifier(src),
            source = src,
            name = Restaurant.getName(src)
        }
    }
end)

exports('SetEstablishmentAvailability', function(src, restaurantId, isOpen)
    src = tonumber(src)
    local restaurant = Restaurant.getRestaurant(restaurantId)
    if not restaurant then return { ok = false, error = 'restaurant_not_found' } end
    if not Restaurant.canManage(src, restaurant) then return { ok = false, error = 'not_manager' } end

    MySQL.update.await('UPDATE ob_restaurants SET is_open = ? WHERE id = ?', {
        isOpen == true and 1 or 0,
        restaurant.id
    })
    Restaurant.audit(src, restaurant.id, 'availability_changed', { isOpen = isOpen == true })
    notifyClients(restaurant.id, 'restaurantAvailability', { isOpen = isOpen == true })
    return { ok = true, isOpen = isOpen == true }
end)

exports('CallEstablishment', function(src, restaurantId)
    src = tonumber(src)
    local restaurant = Restaurant.getRestaurant(restaurantId)
    if not restaurant then return { ok = false, error = 'restaurant_not_found' } end
    if not boolValue(restaurant.feature_call, true) then return { ok = false, error = 'service_disabled' } end
    if not boolValue(restaurant.is_open, true) then return { ok = false, error = 'restaurant_closed' } end

    local callerId = Restaurant.getIdentifier(src)
    local key = tostring(restaurant.id) .. ':' .. callerId
    local now = os.time()
    local cooldown = math.max(10, math.floor(tonumber(Config.ServiceCallCooldownSeconds) or 60))
    if serviceCallWindows[key] and now - serviceCallWindows[key] < cooldown then
        return { ok = false, error = 'call_cooldown', retryAfter = cooldown - (now - serviceCallWindows[key]) }
    end

    local ped = GetPlayerPed(src)
    if ped <= 0 then return { ok = false, error = 'player_position_unavailable' } end
    local coords = GetEntityCoords(ped)
    local payload = {
        restaurantId = restaurant.id,
        restaurantLabel = restaurant.label,
        callerSource = src,
        callerName = Restaurant.getName(src),
        coords = { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 },
        expiresIn = math.max(30, math.floor(tonumber(Config.ServiceCallBlipSeconds) or 90))
    }

    local recipients = 0
    local members = loadMembers(restaurant)
    for _, member in ipairs(members) do
        if member.source and member.source ~= src and Restaurant.getMembership(member.source, restaurant.job).onDuty then
            recipients = recipients + 1
            TriggerClientEvent('ob_restaurantes:client:serviceCall', member.source, payload)
        end
    end
    if recipients < 1 then return { ok = false, error = 'no_staff_online' } end

    serviceCallWindows[key] = now
    Restaurant.audit(src, restaurant.id, 'service_call_created', { recipients = recipients })
    return { ok = true, recipients = recipients }
end)

exports('OpenAdmin', function(src, restaurantId)
    TriggerClientEvent('ob_restaurantes:client:open', tonumber(src), 'admin', restaurantId)
end)

exports('ValidateCraftPoint', function(src, restaurantId, pointId, stationType)
    src = tonumber(src)
    local near, point = Restaurant.isNearPoint(src, pointId, tostring(stationType or ''))
    return near == true and point and tostring(point.restaurant_id) == tostring(restaurantId)
end)

exports('GetCraftCatalog', function(src, restaurantId)
    src = tonumber(src)
    local restaurant = Restaurant.getRestaurant(restaurantId)
    if not restaurant then return { ok = false, error = 'restaurant_not_found' } end
    if not Restaurant.canWork(src, restaurant) then return { ok = false, error = 'not_employee' } end

    local _, recipes = loadCatalog(restaurant.id)
    local catalog = {}
    for _, recipe in ipairs(recipes or {}) do
        if recipe.enabled == nil or recipe.enabled == true or tonumber(recipe.enabled) == 1 then
            catalog[#catalog + 1] = {
                id = tonumber(recipe.id),
                recipe_key = recipe.recipe_key,
                category_key = recipe.category_key,
                name = recipe.name,
                description = recipe.description,
                image = recipe.image,
                prep_time = recipe.prep_time,
                output_item = recipe.output_item,
                output_amount = recipe.output_amount,
                ingredients = type(recipe.ingredients) == 'table' and recipe.ingredients or Restaurant.jsonDecode(recipe.ingredients, {}),
                craft_steps = normalizeCraftSteps(recipe.craft_steps),
                effects = normalizeRecipeEffects(recipe.effects, false) or {}
            }
        end
    end

    return {
        ok = true,
        restaurant = { id = restaurant.id, label = restaurant.label, job = restaurant.job },
        recipes = catalog
    }
end)

exports('CompleteCraftRecipe', function(src, restaurantId, recipeId, requestedQuantity)
    src = tonumber(src)
    local quantity = math.max(1, math.min(math.floor(tonumber(Config.CraftMaxQuantity) or 20), math.floor(tonumber(requestedQuantity) or 1)))
    local restaurant = Restaurant.getRestaurant(restaurantId)
    if not restaurant then return { ok = false, error = 'restaurant_not_found' } end
    if not Restaurant.canWork(src, restaurant) then return { ok = false, error = 'not_employee' } end

    local recipe = MySQL.single.await([[
        SELECT * FROM ob_restaurant_recipes
        WHERE id = ? AND restaurant_id = ? AND enabled = 1
    ]], { tonumber(recipeId), restaurant.id })
    if not recipe then return { ok = false, error = 'recipe_not_found' } end

    local ingredients = {}
    for _, ingredient in ipairs(Restaurant.jsonDecode(recipe.ingredients, {})) do
        ingredients[#ingredients + 1] = {
            item = ingredient.item,
            label = ingredient.label,
            amount = math.max(1, math.floor(tonumber(ingredient.amount) or 1)) * quantity
        }
    end
    local metadata = buildRecipeMetadata(recipe, restaurant.id)
    local amount = math.max(1, math.floor(tonumber(recipe.output_amount) or 1)) * quantity

    if not Restaurant.canCarry(src, recipe.output_item, amount, metadata) then
        return { ok = false, error = 'inventory_full' }
    end

    local success, removed, missing = Restaurant.takeIngredients(src, ingredients)
    if not success then return { ok = false, error = 'missing_ingredient', item = missing } end
    if not Restaurant.addItem(src, recipe.output_item, amount, metadata) then
        Restaurant.restoreIngredients(src, removed)
        return { ok = false, error = 'inventory_full' }
    end

    MySQL.insert.await([[
        INSERT INTO ob_restaurant_productions
            (restaurant_id, recipe_id, employee_identifier, employee_source, status, ready_at, collected_at)
        VALUES (?, ?, ?, ?, 'collected', NOW(), NOW())
    ]], { restaurant.id, recipe.id, Restaurant.getIdentifier(src), src })

    return { ok = true, item = recipe.output_item, amount = amount, label = recipe.name }
end)
