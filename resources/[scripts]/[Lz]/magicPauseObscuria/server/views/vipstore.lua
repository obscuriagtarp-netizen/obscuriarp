local oxmysql = exports.oxmysql
local vipStoreReady = false
local characterSlotOrdersRepaired = false
local pixCreateCooldown = {}
local pixStatusCooldown = {}
local appearanceVoucherCooldown = {}

local function now()
    return os.time()
end

local function query(sql, params)
    return oxmysql:executeSync(sql, params or {}) or {}
end

local function single(sql, params)
    return oxmysql:singleSync(sql, params or {})
end

local function insert(sql, params)
    return oxmysql:insertSync(sql, params or {}) or 0
end

local function update(sql, params)
    local ok, result = pcall(function()
        return oxmysql:updateSync(sql, params or {})
    end)
    if ok and result ~= nil then return tonumber(result) or 0 end
    result = oxmysql:executeSync(sql, params or {}) or 0
    if type(result) == "number" then return result end
    if type(result) == "table" then return tonumber(result.affectedRows or result.affected_rows) or 0 end
    return 0
end

local function ensureColumn(tableName, columnName, definition)
    if not tostring(tableName):match("^[%w_]+$") or not tostring(columnName):match("^[%w_]+$") then return end
    local exists = single([[
        SELECT COLUMN_NAME
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?
        LIMIT 1
    ]], { tableName, columnName })
    if not exists then
        query(("ALTER TABLE `%s` ADD COLUMN `%s` %s"):format(tableName, columnName, definition))
    end
end

local function ensureIndex(tableName, indexName, columns)
    if not tostring(tableName):match("^[%w_]+$") or not tostring(indexName):match("^[%w_]+$") then return end
    local exists = single([[
        SELECT INDEX_NAME
        FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?
        LIMIT 1
    ]], { tableName, indexName })
    if not exists then
        query(("ALTER TABLE `%s` ADD INDEX `%s` (%s)"):format(tableName, indexName, columns))
    end
end

local function respond(src, token, ok, message, extra)
    local payload = extra or {}
    payload.ok = ok == true
    payload.message = message or (payload.ok and "Ação concluída." or "Não foi possível concluir.")
    TriggerClientEvent("MagicPause:client:serverResponse", src, token, payload)
end

local function ensureVipStore()
    if vipStoreReady then return end
    query([[
        CREATE TABLE IF NOT EXISTS `magic_pause_vip_orders` (
            `id` BIGINT NOT NULL AUTO_INCREMENT,
            `passport` VARCHAR(80) NOT NULL,
            `player_name` VARCHAR(120) NOT NULL,
            `product_id` VARCHAR(80) NOT NULL,
            `product_title` VARCHAR(120) NOT NULL,
            `payment_method` VARCHAR(20) NOT NULL,
            `status` VARCHAR(24) NOT NULL DEFAULT 'pending',
            `external_id` VARCHAR(120) DEFAULT NULL,
            `amount` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
            `currency` VARCHAR(16) NOT NULL DEFAULT 'runes',
            `metadata` LONGTEXT DEFAULT NULL,
            `delivered` TINYINT(1) NOT NULL DEFAULT 0,
            `delivery_token` VARCHAR(96) DEFAULT NULL,
            `delivery_started_at` BIGINT DEFAULT NULL,
            `created_at` BIGINT NOT NULL,
            `paid_at` BIGINT DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `passport_created` (`passport`, `created_at`),
            KEY `status_created` (`status`, `created_at`),
            KEY `passport_payment_status` (`passport`, `payment_method`, `status`, `created_at`),
            KEY `external_id` (`external_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    ensureColumn("magic_pause_vip_orders", "delivery_token", "VARCHAR(96) DEFAULT NULL AFTER `delivered`")
    ensureColumn("magic_pause_vip_orders", "delivery_started_at", "BIGINT DEFAULT NULL AFTER `delivery_token`")
    ensureIndex("magic_pause_vip_orders", "status_created", "`status`, `created_at`")
    ensureIndex("magic_pause_vip_orders", "passport_payment_status", "`passport`, `payment_method`, `status`, `created_at`")
    query([[
        CREATE TABLE IF NOT EXISTS `magic_pause_vip_coupons` (
            `code` VARCHAR(40) NOT NULL,
            `enabled` TINYINT(1) NOT NULL DEFAULT 1,
            `percent` DECIMAL(6,2) DEFAULT NULL,
            `amount` DECIMAL(10,2) DEFAULT NULL,
            `min_runes` INT NOT NULL DEFAULT 0,
            `max_discount` DECIMAL(10,2) DEFAULT NULL,
            `description` VARCHAR(180) NOT NULL DEFAULT '',
            `created_by` VARCHAR(80) DEFAULT NULL,
            `created_at` BIGINT NOT NULL,
            `updated_at` BIGINT NOT NULL,
            PRIMARY KEY (`code`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    query([[
        CREATE TABLE IF NOT EXISTS `magic_pause_account_benefits` (
            `order_id` BIGINT NOT NULL,
            `identifier` VARCHAR(100) NOT NULL,
            `benefit` VARCHAR(64) NOT NULL,
            `amount` INT NOT NULL DEFAULT 1,
            `created_at` BIGINT NOT NULL,
            PRIMARY KEY (`order_id`, `benefit`),
            KEY `identifier_benefit` (`identifier`, `benefit`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    vipStoreReady = true
end

local function findProduct(productId)
    productId = tostring(productId or "")
    for _, product in ipairs((Config.VipStore or {}).products or {}) do
        if tostring(product.id) == productId then return product end
    end
    return nil
end

local function characterSlotAmount(productId)
    local product = findProduct(productId)
    local amount = 0

    for _, delivery in ipairs(product and product.deliveries or {}) do
        if tostring(delivery.type or ""):lower() == "character_slot" then
            amount = amount + math.max(1, math.floor(tonumber(delivery.amount) or 1))
        end
    end

    return amount
end

local function repairPaidCharacterSlotOrders()
    if characterSlotOrdersRepaired then return end

    local orders = query([[
        SELECT orders.id, orders.product_id, players.license
        FROM magic_pause_vip_orders orders
        INNER JOIN players ON players.citizenid = orders.passport
        WHERE orders.status = 'paid'
    ]])

    for _, order in ipairs(orders) do
        local amount = characterSlotAmount(order.product_id)
        local identifier = tostring(order.license or "")

        if amount > 0 and identifier ~= "" then
            update([[
                INSERT INTO magic_pause_account_benefits
                    (`order_id`, `identifier`, `benefit`, `amount`, `created_at`)
                VALUES (?, ?, 'character_slot', ?, ?)
                ON DUPLICATE KEY UPDATE
                    `identifier` = VALUES(`identifier`),
                    `amount` = GREATEST(`amount`, VALUES(`amount`))
            ]], { order.id, identifier, amount, now() })

            local saved = single([[
                SELECT `amount`
                FROM magic_pause_account_benefits
                WHERE `order_id` = ? AND `benefit` = 'character_slot' AND `identifier` = ?
                LIMIT 1
            ]], { order.id, identifier })

            if saved and math.max(0, math.floor(tonumber(saved.amount) or 0)) >= amount then
                update([[
                    UPDATE magic_pause_vip_orders
                    SET delivered = 1, delivery_token = NULL, delivery_started_at = NULL
                    WHERE id = ? AND status = 'paid'
                ]], { order.id })
            end
        end
    end

    characterSlotOrdersRepaired = true
end

local function accountIdentifiers(sourceOrLicense, fallbackLicense)
    if type(sourceOrLicense) == "number" then
        return GetPlayerIdentifierByType(sourceOrLicense, "license2") or "",
            GetPlayerIdentifierByType(sourceOrLicense, "license") or ""
    end

    return tostring(sourceOrLicense or ""), tostring(fallbackLicense or "")
end

local function getExtraCharacterSlots(sourceOrLicense, fallbackLicense)
    ensureVipStore()
    repairPaidCharacterSlotOrders()
    local license2, license = accountIdentifiers(sourceOrLicense, fallbackLicense)
    if license2 == "" and license == "" then return 0 end

    local row = single([[
        SELECT COALESCE(SUM(`amount`), 0) AS total
        FROM `magic_pause_account_benefits`
        WHERE `benefit` = 'character_slot' AND (`identifier` = ? OR `identifier` = ?)
    ]], { license2, license }) or {}

    return math.max(0, math.floor(tonumber(row.total) or 0))
end

local function grantCharacterSlot(src, orderId, amount)
    local license2, license = accountIdentifiers(src)
    local identifier = license2 ~= "" and license2 or license
    if identifier == "" then return false end

    orderId = math.floor(tonumber(orderId) or 0)
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    if orderId <= 0 then return false end

    local existing = single([[
        SELECT `identifier`, `amount`
        FROM `magic_pause_account_benefits`
        WHERE `order_id` = ? AND `benefit` = 'character_slot'
        LIMIT 1
    ]], { orderId })
    if existing then
        return tostring(existing.identifier or "") == identifier
    end

    local maximum = math.max(1, math.floor(tonumber((Config.VipStore or {}).maxExtraCharacterSlots) or 8))
    if getExtraCharacterSlots(license2, license) + amount > maximum then return false end

    update([[
        INSERT IGNORE INTO `magic_pause_account_benefits`
            (`order_id`, `identifier`, `benefit`, `amount`, `created_at`)
        VALUES (?, ?, 'character_slot', ?, ?)
    ]], { orderId, identifier, amount, now() })

    local saved = single([[
        SELECT `identifier`, `amount`
        FROM `magic_pause_account_benefits`
        WHERE `order_id` = ? AND `benefit` = 'character_slot'
        LIMIT 1
    ]], { orderId })

    return saved ~= nil
        and tostring(saved.identifier or "") == identifier
        and math.max(0, math.floor(tonumber(saved.amount) or 0)) >= amount
end

local function decodeJson(value)
    if not value or value == "" then return nil end
    local ok, decoded = pcall(json.decode, value)
    return ok and decoded or nil
end

local function couponCode(value)
    value = tostring(value or ""):upper():gsub("%s+", "")
    return value ~= "" and value or nil
end

local function isEnabledValue(value)
    return value == true or value == 1 or value == "1"
end

local function getCoupon(code)
    ensureVipStore()
    code = couponCode(code)
    if not code then return nil end
    local saved = single("SELECT * FROM magic_pause_vip_coupons WHERE code = ? LIMIT 1", { code })
    if saved then
        if not isEnabledValue(saved.enabled) then return nil end
        return {
            code = code,
            percent = tonumber(saved.percent),
            amount = tonumber(saved.amount),
            minRunes = tonumber(saved.min_runes) or 0,
            maxDiscount = tonumber(saved.max_discount),
            description = saved.description or "Cupom aplicado"
        }
    end

    return nil
end

local function startOfDay()
    local date = os.date("*t", now())
    date.hour, date.min, date.sec = 0, 0, 0
    return os.time(date)
end

local function startOfMonth()
    local date = os.date("*t", now())
    date.day, date.hour, date.min, date.sec = 1, 0, 0, 0
    return os.time(date)
end

local function moneyStats(whereSql, params)
    local row = single(([[
        SELECT COUNT(*) as count, COALESCE(SUM(amount), 0) as total
        FROM magic_pause_vip_orders
        WHERE status = 'paid' AND currency = 'BRL' %s
    ]]):format(whereSql or ""), params or {}) or {}
    return {
        count = tonumber(row.count) or 0,
        total = tonumber(row.total) or 0
    }
end

local function couponPayload(row, source, usage)
    return {
        code = row.code,
        enabled = isEnabledValue(row.enabled),
        percent = tonumber(row.percent),
        amount = tonumber(row.amount),
        minRunes = tonumber(row.min_runes or row.minRunes) or 0,
        maxDiscount = tonumber(row.max_discount or row.maxDiscount),
        description = row.description or "Cupom aplicado",
        source = source or "database",
        usage = usage or { count = 0, total = 0, discount = 0, runes = 0 }
    }
end

local function listCoupons(usageMap)
    ensureVipStore()
    local list = {}
    local used = {}

    for _, row in ipairs(query("SELECT * FROM magic_pause_vip_coupons ORDER BY updated_at DESC, code ASC")) do
        local code = tostring(row.code)
        list[#list + 1] = couponPayload(row, "database", usageMap and usageMap[code])
        used[code] = true
    end

    return list
end

local function couponUsagePayload()
    local usage = {}
    local rows = query([[
        SELECT amount, metadata
        FROM magic_pause_vip_orders
        WHERE status = 'paid' AND metadata IS NOT NULL AND metadata != ''
    ]], {})

    for _, row in ipairs(rows) do
        local metadata = decodeJson(row.metadata) or {}
        local coupon = metadata.coupon
        local code = type(coupon) == "table" and couponCode(coupon.code) or nil
        if code then
            local data = usage[code] or { count = 0, total = 0, discount = 0, runes = 0 }
            data.count = data.count + 1
            data.total = data.total + (tonumber(row.amount) or 0)
            data.discount = data.discount + (tonumber(metadata.discount) or 0)
            data.runes = data.runes + (tonumber(metadata.runes) or 0)
            usage[code] = data
        end
    end

    return usage
end

local function orderDashboardRow(row)
    local metadata = decodeJson(row.metadata) or {}
    local coupon = metadata.coupon
    return {
        id = row.id,
        passport = row.passport,
        playerName = row.player_name,
        title = row.product_title,
        method = row.payment_method,
        status = row.status,
        amount = tonumber(row.amount) or 0,
        currency = row.currency,
        runes = tonumber(metadata.runes) or 0,
        original = tonumber(metadata.original) or nil,
        discount = tonumber(metadata.discount) or 0,
        coupon = type(coupon) == "table" and coupon.code or nil,
        createdAt = tonumber(row.created_at) or 0,
        paidAt = tonumber(row.paid_at) or 0
    }
end

local function buildDashboardPayload()
    ensureVipStore()
    local today = startOfDay()
    local month = startOfMonth()
    local pending = single("SELECT COUNT(*) as count FROM magic_pause_vip_orders WHERE status = 'pending'", {}) or {}
    local couponsUsed = single([[
        SELECT COUNT(*) as count
        FROM magic_pause_vip_orders
        WHERE metadata LIKE '%"coupon"%'
    ]], {}) or {}

    local payments = {}
    for _, row in ipairs(query([[
        SELECT id, passport, player_name, product_title, payment_method, status, amount, currency, metadata, created_at, paid_at
        FROM magic_pause_vip_orders
        ORDER BY id DESC
        LIMIT 80
    ]], {})) do
        payments[#payments + 1] = orderDashboardRow(row)
    end

    local couponUsage = couponUsagePayload()

    return {
        stats = {
            today = moneyStats("AND paid_at >= ?", { today }),
            month = moneyStats("AND paid_at >= ?", { month }),
            total = moneyStats("", {}),
            pending = tonumber(pending.count) or 0,
            couponsUsed = tonumber(couponsUsed.count) or 0
        },
        coupons = listCoupons(couponUsage),
        payments = payments
    }
end

local function runeDepositConfig()
    local cfg = (Config.VipStore or {}).runeDeposit or {}
    return {
        enabled = cfg.enabled ~= false,
        runesPerReal = math.max(1, tonumber(cfg.runesPerReal) or 10),
        minimum = math.max(1, math.floor(tonumber(cfg.minimum) or 10)),
        maximum = math.max(1, math.floor(tonumber(cfg.maximum) or 50000)),
        step = math.max(1, math.floor(tonumber(cfg.step) or 10)),
        presets = cfg.presets or { 100, 250, 500, 1000, 2500, 5000 }
    }
end

local function calculateRuneDeposit(amount, code)
    local cfg = runeDepositConfig()
    local runes = math.floor(tonumber(amount) or 0)
    runes = math.floor(runes / cfg.step) * cfg.step
    if runes < cfg.minimum then return nil, "Quantidade mínima: " .. tostring(cfg.minimum) .. " Runas." end
    if runes > cfg.maximum then return nil, "Quantidade máxima: " .. tostring(cfg.maximum) .. " Runas." end

    local original = runes / cfg.runesPerReal
    local discount = 0.0
    local applied = nil
    local coupon = getCoupon(code)
    if coupon then
        local minRunes = math.floor(tonumber(coupon.minRunes) or 0)
        if runes < minRunes then
            return nil, ("Cupom disponível a partir de %s Runas."):format(minRunes)
        end
        local couponPercent = tonumber(coupon.percent) or 0
        local couponAmount = tonumber(coupon.amount) or 0
        if couponPercent > 0 then
            discount = original * (couponPercent / 100)
        elseif couponAmount > 0 then
            discount = couponAmount
        end
        local maxDiscount = tonumber(coupon.maxDiscount)
        if maxDiscount and maxDiscount > 0 then discount = math.min(discount, maxDiscount) end
        discount = math.max(0, discount)
        applied = {
            code = coupon.code,
            description = coupon.description or "Cupom aplicado",
            discount = tonumber(("%.2f"):format(discount))
        }
    elseif couponCode(code) then
        return nil, "Cupom inválido."
    end

    local final = math.max(0.0, original - discount)
    return {
        runes = runes,
        original = tonumber(("%.2f"):format(original)),
        final = tonumber(("%.2f"):format(final)),
        discount = tonumber(("%.2f"):format(discount)),
        coupon = applied,
        runesPerReal = cfg.runesPerReal
    }
end

local function productPayload(product)
    return {
        id = product.id,
        category = product.category or "featured",
        title = product.title or product.id,
        subtitle = product.subtitle or "",
        description = product.description or "",
        image = product.image or "",
        template = product.template or "",
        layout = product.layout or "portrait",
        icon = product.icon or "fa-solid fa-gem",
        badge = product.badge or "",
        features = product.features or {},
        priceRunes = tonumber(product.priceRunes) or 0,
        pricePix = tonumber(product.pricePix) or 0,
        payment = product.payment or { runes = true, pix = false }
    }
end

local function historyPayload(src)
    ensureVipStore()
    local passport = Utils.getPassport(src)
    local limit = tonumber((Config.VipStore or {}).historyLimit) or 8
    local rows = query([[
        SELECT id, product_title, payment_method, status, amount, currency, created_at, paid_at
        FROM magic_pause_vip_orders
        WHERE passport = ?
        ORDER BY id DESC
        LIMIT ?
    ]], { passport, limit })

    local list = {}
    for _, row in ipairs(rows) do
        list[#list + 1] = {
            id = row.id,
            title = row.product_title,
            method = row.payment_method,
            status = row.status,
            amount = tonumber(row.amount) or 0,
            currency = row.currency,
            createdAt = tonumber(row.created_at) or 0,
            paidAt = tonumber(row.paid_at) or 0
        }
    end
    return list
end

local function buildPayload(src)
    ensureVipStore()
    local cfg = Config.VipStore or {}
    local products = {}
    for _, product in ipairs(cfg.products or {}) do
        products[#products + 1] = productPayload(product)
    end

    local vip = { active = false, memberships = {}, benefits = {}, vehicleChoices = {} }
    if GetResourceState("ob_vip") == "started" then
        local ok, result = pcall(function() return exports.ob_vip:GetStoreState(src) end)
        if ok and type(result) == "table" then vip = result end
    end

    return {
        enabled = cfg.enabled == true,
        title = cfg.title or "Loja VIP",
        subtitle = cfg.subtitle or "",
        currencyLabel = cfg.currencyLabel or "Runas",
        productTemplate = cfg.productTemplate or "",
        balance = Utils.getRunes(src),
        runeDeposit = runeDepositConfig(),
        pix = {
            enabled = cfg.pix and cfg.pix.enabled == true and tostring(cfg.pix.apiUrl or "") ~= "",
            label = "Pix"
        },
        isAdmin = Utils.isStaff(src),
        categories = cfg.categories or {},
        products = products,
        history = historyPayload(src),
        vip = vip
    }
end

local function runCommandTemplate(src, passport, product, action)
    local command = tostring(action.command or "")
    if command == "" then return false end
    command = command:gsub("{source}", tostring(src))
    command = command:gsub("{passport}", tostring(passport))
    command = command:gsub("{product}", tostring(product.id or ""))
    ExecuteCommand(command)
    return true
end

local function deliverProduct(src, product, orderId)
    local passport = Utils.getPassport(src)
    local deliveryReason = ("vip_store:%s:%s"):format(tostring(product.id or "product"), tostring(orderId))
    if Config.OnVipStorePurchase then
        local ok = Config.OnVipStorePurchase(src, passport, product, orderId)
        if ok ~= nil then return ok ~= false end
    end

    local delivered = true
    for _, action in ipairs(product.deliveries or {}) do
        local kind = tostring(action.type or ""):lower()
        local amount = tonumber(action.amount) or 1

        if kind == "item" then
            delivered = Utils.giveItem(src, action.item, amount, action.metadata) and delivered
        elseif kind == "money" or kind == "cash" then
            delivered = Utils.addMoney(src, "cash", amount, deliveryReason) and delivered
        elseif kind == "bank" then
            delivered = Utils.addMoney(src, "bank", amount, deliveryReason) and delivered
        elseif kind == "runes" then
            delivered = Utils.addRunes(src, amount, deliveryReason) and delivered
        elseif kind == "vip" then
            if GetResourceState("ob_vip") ~= "started" then
                delivered = false
            else
                local ok, success = pcall(function()
                    return exports.ob_vip:AddVip(passport, action.vip, tonumber(action.days) or 30, {
                        grantedBy = "magicPauseObscuria",
                        reason = deliveryReason,
                        metadata = { orderId = orderId, productId = product.id }
                    })
                end)
                delivered = ok and success == true and delivered
            end
        elseif kind == "character_slot" then
            delivered = grantCharacterSlot(src, orderId, amount) and delivered
        elseif kind == "command" then
            delivered = runCommandTemplate(src, passport, product, action) and delivered
        elseif kind == "server_event" and action.event then
            TriggerEvent(action.event, src, passport, product, action)
        elseif kind == "client_event" and action.event then
            TriggerClientEvent(action.event, src, product, action)
        end
    end

    return delivered
end

exports("GetExtraCharacterSlots", function(sourceOrLicense, fallbackLicense)
    return getExtraCharacterSlots(sourceOrLicense, fallbackLicense)
end)

local function productFromOrder(order)
    if not order then return nil end
    local product = findProduct(order.product_id)
    if product then return product end

    if tostring(order.product_id) == "rune_deposit" then
        local metadata = decodeJson(order.metadata) or {}
        local runes = math.max(0, math.floor(tonumber(metadata.runes) or 0))
        return {
            id = "rune_deposit",
            title = "Depósito de Runas",
            deliveries = {
                { type = "runes", amount = runes }
            }
        }
    end

    return nil
end

local function markDelivered(src, orderId, product)
    local security = (((Config.VipStore or {}).pix or {}).security or {})
    local claimTimeout = math.max(30, tonumber(security.deliveryClaimTimeoutSeconds) or 120)
    local claimToken = ("%s:%s:%s:%s"):format(tostring(orderId), tostring(src), tostring(now()), tostring(math.random(100000, 999999)))
    local claimed = update([[
        UPDATE magic_pause_vip_orders
        SET delivered = 2, delivery_token = ?, delivery_started_at = ?
        WHERE id = ? AND (
            delivered = 0 OR
            (delivered = 2 AND COALESCE(delivery_started_at, 0) < ?)
        )
    ]], { claimToken, now(), orderId, now() - claimTimeout })

    if claimed <= 0 then
        local order = single("SELECT delivered FROM magic_pause_vip_orders WHERE id = ? LIMIT 1", { orderId })
        if order and tonumber(order.delivered) == 1 then return true, "delivered" end
        return false, "processing"
    end

    local safeCall, delivered = pcall(deliverProduct, src, product, orderId)
    if safeCall and delivered then
        local completed = update([[
            UPDATE magic_pause_vip_orders
            SET delivered = 1, delivery_token = NULL, delivery_started_at = NULL,
                status = 'paid', paid_at = COALESCE(paid_at, ?)
            WHERE id = ? AND delivered = 2 AND delivery_token = ?
        ]], { now(), orderId, claimToken })
        if completed > 0 then return true, "delivered" end
        print(("[MagicPause:VipStore] A entrega %s perdeu a reserva exclusiva antes da confirmação."):format(tostring(orderId)))
        return false, "processing"
    end

    update([[
        UPDATE magic_pause_vip_orders
        SET delivered = 0, delivery_token = NULL, delivery_started_at = NULL
        WHERE id = ? AND delivered = 2 AND delivery_token = ?
    ]], { orderId, claimToken })
    if not safeCall then
        print(("[MagicPause:VipStore] Falha interna ao entregar o pedido %s: %s"):format(tostring(orderId), tostring(delivered)))
    end
    return false, "failed"
end

local function normalizeStatus(value)
    value = tostring(value or ""):lower()
    if value == "approved" or value == "paid" or value == "confirmed" or value == "completed" then return "paid" end
    if value == "cancelled" or value == "canceled" or value == "expired" or value == "refused" then return "cancelled" end
    return "pending"
end

local function pixUrl(path)
    local cfg = (Config.VipStore or {}).pix or {}
    local base = tostring(cfg.apiUrl or ""):gsub("/+$", "")
    path = tostring(path or "")
    if path:sub(1, 1) ~= "/" then path = "/" .. path end
    return base .. path
end

local function pixHeaders()
    local cfg = (Config.VipStore or {}).pix or {}
    local headers = { ["Content-Type"] = "application/json" }
    local convarName = tostring(cfg.apiTokenConvar or "magicpause_pix_api_token")
    local apiToken = convarName ~= "" and tostring(GetConvar(convarName, "")) or ""
    if apiToken == "" then apiToken = tostring(cfg.apiToken or "") end
    if apiToken ~= "" then
        headers["Authorization"] = "Bearer " .. apiToken
    end
    return headers
end

local function pixApiTokenConfigured()
    return tostring(pixHeaders()["Authorization"] or "") ~= ""
end

local function apiErrorMessage(statusCode)
    statusCode = tonumber(statusCode) or 0
    if statusCode == 401 or statusCode == 403 then
        return "a autenticação do pagamento precisa ser revisada pela equipe"
    end
    if statusCode == 429 then
        return "há muitas solicitações ao mesmo tempo; aguarde alguns segundos"
    end
    if statusCode == 0 or statusCode == 408 or statusCode == 504 then
        return "a conexão com o pagamento demorou para responder"
    end
    if statusCode >= 500 then
        return "o serviço de pagamento está temporariamente indisponível"
    end
    return "o pedido foi recusado pelo serviço de pagamento"
end

local function logPixFailure(operation, statusCode, orderId, decoded)
    local code = type(decoded) == "table" and tostring(decoded.code or "") or ""
    print(("[MagicPause:VipStore] %s falhou. pedido=%s http=%s codigo=%s"):format(
        tostring(operation), tostring(orderId), tostring(statusCode or 0), code:sub(1, 80)
    ))
end

local function amountCents(value)
    local number = tonumber(value)
    if not number then return nil end
    return math.floor((number * 100) + 0.5)
end

local function validatePixResponse(decoded, orderId, expectedAmount)
    if type(decoded) ~= "table" or decoded.ok ~= true then return false end
    if tostring(decoded.id or "") ~= tostring(orderId) then return false end
    local reference = decoded.external_reference or decoded.externalReference
    if tostring(reference or "") ~= tostring(orderId) then return false end
    if amountCents(decoded.amount) ~= amountCents(expectedAmount) then return false end
    if tostring(decoded.currency or ""):upper() ~= "BRL" then return false end
    return true
end

local function beginOrderCreation(src)
    local passport = tostring(Utils.getPassport(src) or "")
    if passport == "" then return nil, "Não foi possível identificar seu personagem." end
    local security = (((Config.VipStore or {}).pix or {}).security or {})
    local current = now()
    local cooldown = math.max(1, tonumber(security.createCooldownSeconds) or 8)
    local previous = tonumber(pixCreateCooldown[passport]) or 0
    if current - previous < cooldown then
        return nil, ("Aguarde %s segundos antes de gerar outro Pix."):format(cooldown - (current - previous))
    end

    pixCreateCooldown[passport] = current
    return passport
end

local function beginPixCreation(src)
    local passport, creationError = beginOrderCreation(src)
    if not passport then return nil, creationError end
    local security = (((Config.VipStore or {}).pix or {}).security or {})
    local current = now()

    local pendingLifetime = math.max(5, tonumber(security.pendingLifetimeMinutes) or 30) * 60
    update([[
        UPDATE magic_pause_vip_orders
        SET status = 'expired'
        WHERE passport = ? AND payment_method = 'pix' AND status = 'pending' AND created_at < ?
    ]], { passport, current - pendingLifetime })

    local pending = single([[
        SELECT COUNT(*) AS total
        FROM magic_pause_vip_orders
        WHERE passport = ? AND payment_method = 'pix' AND status = 'pending'
    ]], { passport })
    local maxPending = math.max(1, tonumber(security.maxPendingPerPlayer) or 3)
    if (tonumber(pending and pending.total) or 0) >= maxPending then
        return nil, ("Você já possui %s pedidos Pix aguardando pagamento."):format(maxPending)
    end

    return passport
end

local function canCheckPixStatus(passport)
    passport = tostring(passport or "")
    local security = (((Config.VipStore or {}).pix or {}).security or {})
    local cooldown = math.max(1, tonumber(security.statusCooldownSeconds) or 2)
    local current = now()
    local previous = tonumber(pixStatusCooldown[passport]) or 0
    if current - previous < cooldown then return false end
    pixStatusCooldown[passport] = current
    return true
end

local function respondPaidDelivery(src, token, orderId, product, successMessage)
    local delivered, state = markDelivered(src, orderId, product)
    if delivered then
        return respond(src, token, true, successMessage or "Pagamento aprovado e produto entregue.", {
            status = "paid",
            history = historyPayload(src),
            balance = Utils.getRunes(src)
        })
    end
    if state == "processing" then
        return respond(src, token, true, "Pagamento confirmado. A entrega já está sendo processada.", {
            status = "processing"
        })
    end
    return respond(src, token, false, "Pagamento confirmado, mas a entrega não foi concluída. Tente consultar novamente ou chame a equipe.", {
        status = "delivery_failed"
    })
end

RegisterNetEvent("MagicPause:server:getVipStore", function(token)
    local src = source
    TriggerClientEvent("MagicPause:client:serverResponse", src, token, buildPayload(src))
end)

RegisterNetEvent("MagicPause:server:useAppearanceVoucher", function()
    local src = source
    local current = now()
    if current - (appearanceVoucherCooldown[src] or 0) < 5 then return end
    appearanceVoucherCooldown[src] = current

    if GetResourceState("illenium-appearance") ~= "started" then
        exports.qbx_core:Notify(src, "A personalizacao nao esta disponivel agora.", "error", 5000)
        return
    end
    if GetResourceState("ox_inventory") ~= "started" then
        exports.qbx_core:Notify(src, "O inventario nao esta disponivel agora.", "error", 5000)
        return
    end
    if exports.ox_inventory:GetItemCount(src, "refazer_personagem") < 1 then
        exports.qbx_core:Notify(src, "Voce nao possui o selo para refazer o personagem.", "error", 5000)
        return
    end
    if exports.ox_inventory:RemoveItem(src, "refazer_personagem", 1) ~= true then
        exports.qbx_core:Notify(src, "Nao foi possivel consumir o selo.", "error", 5000)
        return
    end

    TriggerClientEvent("MagicPause:client:openAppearanceVoucher", src)
end)

AddEventHandler("playerDropped", function()
    appearanceVoucherCooldown[source] = nil
end)

RegisterNetEvent("MagicPause:server:redeemVipVehicle", function(token, data)
    local src = source
    if GetResourceState("ob_vip") ~= "started" then
        return respond(src, token, false, "O sistema VIP nao esta disponivel agora.")
    end

    local ok, success, result = pcall(function()
        return exports.ob_vip:RedeemVehicle(src, data and data.entitlementId, data and data.model)
    end)
    if not ok then
        print(("[MagicPause:VipStore] Falha ao resgatar veiculo: %s"):format(tostring(success)))
        return respond(src, token, false, "Nao foi possivel processar o resgate.")
    end
    if success ~= true then return respond(src, token, false, tostring(result or "Resgate recusado.")) end

    respond(src, token, true, ("%s foi enviado para a garagem."):format(result.label or result.model), {
        vehicle = result,
        store = buildPayload(src)
    })
end)

RegisterNetEvent("MagicPause:server:getVipDashboard", function(token)
    local src = source
    ensureVipStore()
    if not Utils.isStaff(src) then
        return respond(src, token, false, "Você não tem permissão para acessar este painel.")
    end

    respond(src, token, true, "Dashboard carregado.", { dashboard = buildDashboardPayload() })
end)

RegisterNetEvent("MagicPause:server:saveVipCoupon", function(token, data)
    local src = source
    ensureVipStore()
    if not Utils.isStaff(src) then
        return respond(src, token, false, "Você não tem permissão para criar cupons.")
    end

    local code = couponCode(data and data.code)
    if not code or #code < 3 then
        return respond(src, token, false, "Código do cupom inválido.")
    end

    local discountType = tostring((data and data.discountType) or "percent")
    local percent = 0
    local amount = 0
    if discountType == "amount" then
        amount = tonumber(data and data.amount) or 0
        if amount <= 0 then return respond(src, token, false, "Informe um desconto fixo válido.") end
    else
        percent = tonumber(data and data.percent) or 0
        if percent <= 0 or percent > 100 then return respond(src, token, false, "Informe uma porcentagem entre 1 e 100.") end
    end

    local minRunes = math.max(0, math.floor(tonumber(data and data.minRunes) or 0))
    local maxDiscount = tonumber(data and data.maxDiscount) or 0
    if maxDiscount < 0 then maxDiscount = 0 end
    local description = tostring((data and data.description) or "")
    if description == "" then description = "Cupom " .. code end

    query([[
        INSERT INTO magic_pause_vip_coupons(code, enabled, percent, amount, min_runes, max_discount, description, created_by, created_at, updated_at)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            enabled = VALUES(enabled),
            percent = VALUES(percent),
            amount = VALUES(amount),
            min_runes = VALUES(min_runes),
            max_discount = VALUES(max_discount),
            description = VALUES(description),
            updated_at = VALUES(updated_at)
    ]], {
        code,
        data and data.enabled == false and 0 or 1,
        percent,
        amount,
        minRunes,
        maxDiscount,
        description,
        Utils.getPassport(src),
        now(),
        now()
    })

    respond(src, token, true, "Cupom salvo com sucesso.", { dashboard = buildDashboardPayload() })
end)

RegisterNetEvent("MagicPause:server:setVipCouponEnabled", function(token, data)
    local src = source
    ensureVipStore()
    if not Utils.isStaff(src) then
        return respond(src, token, false, "Você não tem permissão para alterar cupons.")
    end

    local code = couponCode(data and data.code)
    if not code then return respond(src, token, false, "Cupom inválido.") end
    local affected = update("UPDATE magic_pause_vip_coupons SET enabled = ?, updated_at = ? WHERE code = ?", {
        data and data.enabled == true and 1 or 0,
        now(),
        code
    })
    if affected <= 0 then
        return respond(src, token, false, "Apenas cupons criados pelo dashboard podem ser ativados ou desativados por aqui.")
    end

    respond(src, token, true, "Cupom atualizado.", { dashboard = buildDashboardPayload() })
end)

RegisterNetEvent("MagicPause:server:buyVipProductRunes", function(token, data)
    local src = source
    ensureVipStore()

    local product = findProduct(data and data.productId)
    if not product then return respond(src, token, false, "Produto inválido.") end
    if product.payment and product.payment.runes == false then return respond(src, token, false, "Este produto não aceita Runas.") end

    local price = math.floor(tonumber(product.priceRunes) or 0)
    if price <= 0 then return respond(src, token, false, "Produto sem valor configurado.") end
    local passport, creationError = beginOrderCreation(src)
    if not passport then return respond(src, token, false, creationError) end
    if Utils.getRunes(src) < price then
        return respond(src, token, false, "Você não possui Runas suficientes.", { balance = Utils.getRunes(src) })
    end
    if not Utils.removeRunes(src, price, "vip_store:" .. tostring(product.id)) then
        return respond(src, token, false, "Você não possui Runas suficientes.", { balance = Utils.getRunes(src) })
    end

    local orderId = insert([[
        INSERT INTO magic_pause_vip_orders(passport, player_name, product_id, product_title, payment_method, status, amount, currency, delivered, created_at, paid_at)
        VALUES(?, ?, ?, ?, 'runes', 'paid', ?, 'runes', 0, ?, ?)
    ]], { passport, Utils.getName(src), product.id, product.title or product.id, price, now(), now() })

    if orderId <= 0 then
        Utils.addRunes(src, price, "vip_store_refund:" .. tostring(product.id))
        return respond(src, token, false, "A compra não foi registrada e as Runas foram devolvidas.", {
            balance = Utils.getRunes(src)
        })
    end

    local delivered = markDelivered(src, orderId, product)
    if not delivered then
        return respond(src, token, false, "Compra registrada, mas a entrega falhou. Chame a equipe.", { balance = Utils.getRunes(src) })
    end

    local successMessage = characterSlotAmount(product.id) > 0
        and "Vaga adicional liberada. Ela aparecerá ao retornar à seleção de personagens."
        or "Compra entregue com sucesso."

    respond(src, token, true, successMessage, {
        balance = Utils.getRunes(src),
        history = historyPayload(src)
    })
end)

RegisterNetEvent("MagicPause:server:createVipPixOrder", function(token, data)
    local src = source
    ensureVipStore()
    local cfg = Config.VipStore or {}
    local pix = cfg.pix or {}
    if pix.enabled ~= true or tostring(pix.apiUrl or "") == "" then
        return respond(src, token, false, "Pix ainda não está configurado nesta loja.")
    end
    if pix.productPayments ~= true then
        return respond(src, token, false, "Pix disponível apenas para depósito de Runas.")
    end

    local product = findProduct(data and data.productId)
    if not product then return respond(src, token, false, "Produto inválido.") end
    if product.payment and product.payment.pix == false then return respond(src, token, false, "Este produto não aceita Pix.") end
    local price = tonumber(product.pricePix) or 0
    if price <= 0 then return respond(src, token, false, "Produto sem valor Pix configurado.") end
    if not pixApiTokenConfigured() then
        return respond(src, token, false, "A autenticação do Pix ainda não foi configurada pela equipe.")
    end

    local passport, creationError = beginPixCreation(src)
    if not passport then return respond(src, token, false, creationError) end
    local orderId = insert([[
        INSERT INTO magic_pause_vip_orders(passport, player_name, product_id, product_title, payment_method, status, amount, currency, delivered, created_at)
        VALUES(?, ?, ?, ?, 'pix', 'pending', ?, 'BRL', 0, ?)
    ]], { passport, Utils.getName(src), product.id, product.title or product.id, price, now() })

    local body = json.encode({
        order_id = tostring(orderId),
        resource = GetCurrentResourceName(),
        player = {
            source = src,
            passport = passport,
            name = Utils.getName(src)
        },
        product = productPayload(product),
        amount = price,
        currency = "BRL"
    })

    local createUrl = pixUrl(pix.createPath or "/orders")
    PerformHttpRequest(createUrl, function(statusCode, responseText)
        statusCode = tonumber(statusCode) or 0
        local decoded = {}
        if responseText and responseText ~= "" then
            local ok, result = pcall(json.decode, responseText)
            if ok and type(result) == "table" then decoded = result end
        end

        if statusCode < 200 or statusCode >= 300 or decoded.ok ~= true then
            logPixFailure("criação de Pix", statusCode, orderId, decoded)
            update("UPDATE magic_pause_vip_orders SET status = 'failed' WHERE id = ?", { orderId })
            return respond(src, token, false, "Não foi possível gerar o Pix agora: " .. apiErrorMessage(statusCode))
        end

        if not validatePixResponse(decoded, orderId, price) then
            logPixFailure("validação da criação", statusCode, orderId, { code = "response_mismatch" })
            update("UPDATE magic_pause_vip_orders SET status = 'failed' WHERE id = ?", { orderId })
            return respond(src, token, false, "O serviço retornou dados divergentes. Nenhum produto será entregue; a equipe foi avisada.")
        end

        local externalId = tostring(decoded.external_id or decoded.externalId or "")
        if externalId == "" then
            update("UPDATE magic_pause_vip_orders SET status = 'failed' WHERE id = ?", { orderId })
            return respond(src, token, false, "O serviço de pagamento não retornou um identificador válido.")
        end
        update("UPDATE magic_pause_vip_orders SET external_id = ? WHERE id = ?", { externalId, orderId })
        respond(src, token, true, "Pix gerado. Aguardando pagamento.", {
            order = {
                id = orderId,
                externalId = externalId,
                status = normalizeStatus(decoded.status),
                qrCode = decoded.qr_code or decoded.qrCode or decoded.pix_qr_code or decoded.pixQrCode or "",
                copyPaste = decoded.copy_paste or decoded.copyPaste or decoded.pix_copy_paste or decoded.pixCopyPaste or "",
                expiresAt = decoded.expires_at or decoded.expiresAt
            }
        })
    end, "POST", body, pixHeaders())
end)

RegisterNetEvent("MagicPause:server:validateRuneCoupon", function(token, data)
    local src = source
    local result, err = calculateRuneDeposit(data and data.runes, data and data.coupon)
    if not result then return respond(src, token, false, err or "Cupom inválido.") end
    respond(src, token, true, "Cupom aplicado.", result)
end)

RegisterNetEvent("MagicPause:server:createRuneDepositOrder", function(token, data)
    local src = source
    ensureVipStore()
    local cfg = Config.VipStore or {}
    local pix = cfg.pix or {}
    local depositCfg = runeDepositConfig()
    if depositCfg.enabled ~= true then return respond(src, token, false, "Depósito de Runas indisponível.") end

    local calc, err = calculateRuneDeposit(data and data.runes, data and data.coupon)
    if not calc then return respond(src, token, false, err or "Quantidade invalida.") end

    local passport = Utils.getPassport(src)
    local metadata = json.encode({
        runes = calc.runes,
        original = calc.original,
        final = calc.final,
        discount = calc.discount,
        coupon = calc.coupon
    })

    if calc.final <= 0 then
        local couponPassport, creationError = beginOrderCreation(src)
        if not couponPassport then return respond(src, token, false, creationError) end
        passport = couponPassport
        local orderId = insert([[
            INSERT INTO magic_pause_vip_orders(passport, player_name, product_id, product_title, payment_method, status, amount, currency, metadata, delivered, created_at, paid_at)
            VALUES(?, ?, 'rune_deposit', ?, 'coupon', 'paid', 0, 'BRL', ?, 0, ?, ?)
        ]], { passport, Utils.getName(src), ("Depósito de %s Runas"):format(calc.runes), metadata, now(), now() })

        local product = productFromOrder({ product_id = "rune_deposit", metadata = metadata })
        local delivered = markDelivered(src, orderId, product)
        if not delivered then
            return respond(src, token, false, "Cupom aplicado, mas a entrega falhou. Chame a equipe.", { balance = Utils.getRunes(src) })
        end

        return respond(src, token, true, "Cupom aplicado. Runas entregues com sucesso.", {
            balance = Utils.getRunes(src),
            status = "paid",
            history = historyPayload(src),
            quote = calc
        })
    end

    if pix.enabled ~= true or tostring(pix.apiUrl or "") == "" then
        return respond(src, token, false, "Pix ainda não está configurado nesta loja.")
    end
    if not pixApiTokenConfigured() then
        return respond(src, token, false, "A autenticação do Pix ainda não foi configurada pela equipe.")
    end

    local creationPassport, creationError = beginPixCreation(src)
    if not creationPassport then return respond(src, token, false, creationError) end
    passport = creationPassport

    local orderId = insert([[
        INSERT INTO magic_pause_vip_orders(passport, player_name, product_id, product_title, payment_method, status, amount, currency, metadata, delivered, created_at)
        VALUES(?, ?, 'rune_deposit', ?, 'pix', 'pending', ?, 'BRL', ?, 0, ?)
    ]], { passport, Utils.getName(src), ("Depósito de %s Runas"):format(calc.runes), calc.final, metadata, now() })

    local body = json.encode({
        order_id = tostring(orderId),
        resource = GetCurrentResourceName(),
        player = {
            source = src,
            passport = passport,
            name = Utils.getName(src)
        },
        product = {
            id = "rune_deposit",
            title = ("Depósito de %s Runas"):format(calc.runes),
            subtitle = "Runas para usar na Loja VIP"
        },
        amount = calc.final,
        currency = "BRL"
    })

    local createUrl = pixUrl(pix.createPath or "/orders")
    PerformHttpRequest(createUrl, function(statusCode, responseText)
        statusCode = tonumber(statusCode) or 0
        local decoded = {}
        if responseText and responseText ~= "" then
            local ok, result = pcall(json.decode, responseText)
            if ok and type(result) == "table" then decoded = result end
        end

        if statusCode < 200 or statusCode >= 300 or decoded.ok ~= true then
            logPixFailure("depósito de Runas", statusCode, orderId, decoded)
            update("UPDATE magic_pause_vip_orders SET status = 'failed' WHERE id = ?", { orderId })
            return respond(src, token, false, "Não foi possível gerar o Pix agora: " .. apiErrorMessage(statusCode))
        end

        if not validatePixResponse(decoded, orderId, calc.final) then
            logPixFailure("validação do depósito", statusCode, orderId, { code = "response_mismatch" })
            update("UPDATE magic_pause_vip_orders SET status = 'failed' WHERE id = ?", { orderId })
            return respond(src, token, false, "O serviço retornou dados divergentes. Nenhuma Runa será entregue; a equipe foi avisada.")
        end

        local externalId = tostring(decoded.external_id or decoded.externalId or "")
        if externalId == "" then
            update("UPDATE magic_pause_vip_orders SET status = 'failed' WHERE id = ?", { orderId })
            return respond(src, token, false, "O serviço de pagamento não retornou um identificador válido.")
        end
        update("UPDATE magic_pause_vip_orders SET external_id = ? WHERE id = ?", { externalId, orderId })
        respond(src, token, true, "Pix gerado. Aguardando pagamento.", {
            balance = Utils.getRunes(src),
            order = {
                id = orderId,
                externalId = externalId,
                status = normalizeStatus(decoded.status),
                qrCode = decoded.qr_code or decoded.qrCode or decoded.pix_qr_code or decoded.pixQrCode or "",
                copyPaste = decoded.copy_paste or decoded.copyPaste or decoded.pix_copy_paste or decoded.pixCopyPaste or "",
                expiresAt = decoded.expires_at or decoded.expiresAt
            },
            quote = calc
        })
    end, "POST", body, pixHeaders())
end)

RegisterNetEvent("MagicPause:server:checkVipPixOrder", function(token, data)
    local src = source
    ensureVipStore()
    local cfg = Config.VipStore or {}
    local pix = cfg.pix or {}
    local orderId = tonumber(data and data.orderId)
    if not orderId then return respond(src, token, false, "Pedido inválido.") end

    local passport = Utils.getPassport(src)
    local order = single("SELECT * FROM magic_pause_vip_orders WHERE id = ? AND passport = ? LIMIT 1", { orderId, passport })
    if not order then return respond(src, token, false, "Pedido não encontrado.") end

    local product = productFromOrder(order)
    if not product then return respond(src, token, false, "Produto do pedido não existe mais.") end
    if tostring(order.status) == "paid" then
        return respondPaidDelivery(src, token, orderId, product, "Pagamento aprovado e produto entregue.")
    end
    if pix.enabled ~= true or tostring(pix.apiUrl or "") == "" then
        return respond(src, token, false, "Pix ainda não está configurado nesta loja.", { status = order.status })
    end
    if not pixApiTokenConfigured() then
        return respond(src, token, false, "A autenticação do Pix ainda não foi configurada pela equipe.", { status = order.status })
    end
    if not canCheckPixStatus(passport) then
        return respond(src, token, true, "A consulta anterior ainda está em andamento.", { status = order.status })
    end

    local externalId = tostring(order.external_id or order.id)
    local statusPath = tostring(pix.statusPath or "/orders/%s")
    if statusPath:find("%%s") then
        statusPath = statusPath:format(externalId)
    else
        statusPath = statusPath:gsub("/+$", "") .. "/" .. externalId
    end

    local checkUrl = pixUrl(statusPath)
    PerformHttpRequest(checkUrl, function(statusCode, responseText)
        statusCode = tonumber(statusCode) or 0
        local decoded = {}
        if responseText and responseText ~= "" then
            local ok, result = pcall(json.decode, responseText)
            if ok and type(result) == "table" then decoded = result end
        end

        if statusCode < 200 or statusCode >= 300 or decoded.ok ~= true then
            logPixFailure("consulta de Pix", statusCode, orderId, decoded)
            return respond(src, token, false, "Não foi possível verificar o pagamento agora: " .. apiErrorMessage(statusCode), { status = order.status })
        end

        if not validatePixResponse(decoded, orderId, order.amount) then
            logPixFailure("validação da consulta", statusCode, orderId, { code = "response_mismatch" })
            return respond(src, token, false, "A confirmação retornou dados diferentes do pedido. Nenhum produto será entregue.", {
                status = order.status
            })
        end

        local status = normalizeStatus(decoded.status or decoded.payment_status or decoded.paymentStatus)
        update("UPDATE magic_pause_vip_orders SET status = ? WHERE id = ?", { status, orderId })

        if status == "paid" then
            return respondPaidDelivery(src, token, orderId, product, "Pagamento aprovado e produto entregue.")
        end

        respond(src, token, true, status == "cancelled" and "Pagamento cancelado ou expirado." or "Pagamento ainda pendente.", { status = status })
    end, "GET", "", pixHeaders())
end)
