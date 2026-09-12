local RESOURCE = GetCurrentResourceName()
local purchaseLocks = {}
local testDrivePlayers = {}
local databaseReady = false

math.randomseed(os.time())

local function debugLog(message)
    if Config.Debug then print(('^5[%s]^7 %s'):format(RESOURCE, tostring(message))) end
end

local function notify(source, message, notifyType)
    if source and GetResourceState('qbx_core') == 'started' then
        exports.qbx_core:Notify(source, tostring(message), notifyType or 'inform', 5000)
    end
end

local function qboxPlayer(source)
    if GetResourceState('qbx_core') ~= 'started' then return nil end
    return exports.qbx_core:GetPlayer(source)
end

local function playerData(source)
    local player = qboxPlayer(source)
    return player and player.PlayerData or nil
end

local function citizenId(source)
    local data = playerData(source)
    return data and tostring(data.citizenid or '') or nil
end

local function playerLicense(source)
    local data = playerData(source)
    if data and data.license then return tostring(data.license) end
    return GetPlayerIdentifierByType(source, 'license') or GetPlayerIdentifier(source, 0)
end

local function hasStaffAccess(source)
    local permissions = Config.StaffPermissions or { 'admin', 'god' }
    if type(permissions) == 'string' then permissions = { permissions } end

    local ok, allowed = pcall(function()
        return exports.qbx_core:HasPermission(source, permissions)
    end)
    if ok and allowed then return true end

    return Config.StaffAce and IsPlayerAceAllowed(source, Config.StaffAce) or false
end

local function query(queryText, params)
    return MySQL.query.await(queryText, params or {}) or {}
end

local function scalar(queryText, params)
    return MySQL.scalar.await(queryText, params or {})
end

local function update(queryText, params)
    return MySQL.update.await(queryText, params or {}) or 0
end

local function insert(queryText, params)
    return MySQL.insert.await(queryText, params or {})
end

local function encode(value)
    local ok, result = pcall(json.encode, value or {})
    return ok and result or '{}'
end

local function normalize(value)
    return tostring(value or ''):lower():gsub('%s+', '')
end

local function normalizeId(value)
    return tostring(value or ''):lower():gsub('[^%w_%-]', '')
end

local function currencyFor(shop)
    return tostring(shop.currency or 'money'):lower() == 'crypto' and 'crypto' or 'money'
end

local function accountBalance(source, account)
    local player = qboxPlayer(source)
    if not player then return 0 end
    if player.Functions and player.Functions.GetMoney then
        local ok, value = pcall(player.Functions.GetMoney, account)
        if ok then return tonumber(value) or 0 end
    end
    return tonumber(player.PlayerData.money and player.PlayerData.money[account]) or 0
end

local function changeBalance(source, account, amount, method)
    local player = qboxPlayer(source)
    if not player or amount <= 0 or not player.Functions or not player.Functions[method] then return amount <= 0 end
    local ok, result = pcall(player.Functions[method], account, amount, 'ob_concessionaria')
    return ok and result ~= false
end

local function takePayment(source, amount, currency)
    if amount <= 0 then return true end
    if accountBalance(source, currency) < amount then return false end
    return changeBalance(source, currency, amount, 'RemoveMoney')
end

local function refundPayment(source, amount, currency)
    if amount > 0 then changeBalance(source, currency, amount, 'AddMoney') end
end

local function paymentError(currency)
    return currency == 'crypto' and 'Cripto insuficiente.' or 'Dinheiro insuficiente.'
end

local function dealership(id)
    return Config.Dealerships and Config.Dealerships[id]
end

local function nearDealership(source, id)
    local shop = dealership(id)
    local ped = GetPlayerPed(source)
    if not shop or not shop.coords or ped <= 0 then return false end
    return #(GetEntityCoords(ped) - shop.coords) <= ((tonumber(Config.OpenDistance) or 2.0) + 2.0)
end

local function periodId(value)
    local id = normalizeId(value or Config.DefaultVehiclePeriod or 'permanent')
    return Config.VehiclePeriods and Config.VehiclePeriods[id] and id or 'permanent'
end

local function periodDays(value)
    local cfg = (Config.VehiclePeriods or {})[periodId(value)] or {}
    local days = tonumber(cfg.days) or 0
    return days > 0 and math.floor(days) or nil
end

local function expiryFor(value)
    local days = periodDays(value)
    return days and os.date('%Y-%m-%d %H:%M:%S', os.time() + days * 86400) or nil
end

local function periodLabel(value)
    local id = periodId(value)
    local cfg = (Config.VehiclePeriods or {})[id] or {}
    return cfg.label or id
end

local function periodShort(value)
    local id = periodId(value)
    local cfg = (Config.VehiclePeriods or {})[id] or {}
    return cfg.short or cfg.label or id
end

local function taxFor(shopId, price)
    local cfg = (Config.Taxes or {})[shopId] or {}
    return math.floor((tonumber(price) or 0) * (tonumber(cfg.percent) or 0) + 0.5), cfg.label or 'Taxa'
end

local function vipPrice(source, price)
    local cfg = Config.VipDiscount or {}
    local resource = tostring(cfg.resource or 'ob_vip')
    if cfg.enabled == false or not source or GetResourceState(resource) ~= 'started' then
        return price, 0, 0
    end

    local ok, finalPrice, discount, percent = pcall(function()
        return exports[resource]:CalculateVehicleDiscount(source, price)
    end)
    if not ok then
        debugLog(('Falha ao consultar desconto VIP: %s'):format(finalPrice))
        return price, 0, 0
    end

    return math.max(0, tonumber(finalPrice) or price), math.max(0, tonumber(discount) or 0), math.max(0, tonumber(percent) or 0)
end

local function vehicleDefinition(model)
    local ok, vehicles = pcall(function() return exports.qbx_core:GetVehiclesByName() end)
    if not ok or type(vehicles) ~= 'table' then return nil end
    return vehicles[normalize(model)]
end

local function vehicleIsRegistered(model)
    if Config.RequireGarageVehicle == false then return true end
    if not vehicleDefinition(model) then return false, 'Este modelo não está registrado no catálogo do Qbox.' end
    return true
end

local function generatePlate()
    for _ = 1, 30 do
        local plate = ('OB%06d'):format(math.random(0, 999999))
        if not scalar('SELECT id FROM player_vehicles WHERE plate = ? LIMIT 1', { plate }) then return plate end
    end
    return ('OB%06d'):format(os.time() % 1000000)
end

local function configuredGarage()
    local garageName = tostring(Config.VehicleGarage or '')
    if garageName == '' then return nil, 'Configure Config.VehicleGarage antes de vender veículos.' end
    if GetResourceState('qbx_garages') ~= 'started' then return nil, 'qbx_garages precisa estar iniciado.' end

    local ok, garages = pcall(function() return exports.qbx_garages:GetGarages() end)
    if not ok or type(garages) ~= 'table' or not garages[garageName] then
        return nil, ('A garagem Qbox "%s" não foi encontrada.'):format(garageName)
    end
    return garageName
end

local function insertPlayerVehicle(source, row, plate, expiry)
    local garageName, garageError = configuredGarage()
    if not garageName then return false, garageError end

    local data = playerData(source)
    local cid = data and tostring(data.citizenid or '')
    local license = playerLicense(source)
    if cid == '' or not license then return false, 'Personagem Qbox não encontrado.' end

    local model = normalize(row.model)
    local hash = joaat(model)
    local props = {
        model = hash,
        plate = plate,
        fuelLevel = 100.0,
        engineHealth = 1000.0,
        bodyHealth = 1000.0,
        dirtLevel = 0.0,
    }

    local id = insert([[INSERT INTO player_vehicles
        (license, citizenid, vehicle, hash, mods, plate, garage, fuel, engine, body, state)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        license, cid, model, hash, encode(props), plate, garageName, 100, 1000, 1000, 1,
    })

    if not id then return false, 'Não foi possível registrar o veículo na garagem Qbox.' end
    if expiry then debugLog(('Validade %s registrada para %s (%s).'):format(expiry, model, id)) end
    return true, id
end

local function tableExists(tableName)
    return (tonumber(scalar([[SELECT COUNT(*)
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?]], { tableName })) or 0) > 0
end

local function columnInfo(tableName, columnName)
    return query([[SELECT DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?
        LIMIT 1]], { tableName, columnName })[1]
end

local function createTables()
    if not tableExists('vg_dealership_vehicles') then
        update([[CREATE TABLE vg_dealership_vehicles (
        id INT NOT NULL AUTO_INCREMENT,
        dealership VARCHAR(40) NOT NULL,
        category VARCHAR(40) NOT NULL,
        model VARCHAR(80) NOT NULL,
        name VARCHAR(100) NOT NULL,
        brand VARCHAR(80) DEFAULT NULL,
        price BIGINT NOT NULL DEFAULT 0,
        stock INT NOT NULL DEFAULT 0,
        purchase_type VARCHAR(20) NOT NULL DEFAULT 'permanent',
        duration_days INT DEFAULT NULL,
        image VARCHAR(255) DEFAULT NULL,
        enabled TINYINT(1) NOT NULL DEFAULT 1,
        display_order INT NOT NULL DEFAULT 0,
        metadata LONGTEXT DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY unique_dealership_model (dealership, model),
        KEY idx_dealership_category (dealership, category)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    end

    if not tableExists('vg_dealership_sales') then
        update([[CREATE TABLE vg_dealership_sales (
        id INT NOT NULL AUTO_INCREMENT,
        user_id VARCHAR(64) NOT NULL,
        dealership VARCHAR(40) NOT NULL,
        model VARCHAR(80) NOT NULL,
        plate VARCHAR(16) NOT NULL,
        currency VARCHAR(20) NOT NULL,
        purchase_type VARCHAR(20) NOT NULL DEFAULT 'permanent',
        expires_at TIMESTAMP NULL DEFAULT NULL,
        base_price BIGINT NOT NULL DEFAULT 0,
        discount_amount BIGINT NOT NULL DEFAULT 0,
        discount_percent DECIMAL(5,2) NOT NULL DEFAULT 0,
        tax_amount BIGINT NOT NULL DEFAULT 0,
        total_price BIGINT NOT NULL DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_user (user_id),
        KEY idx_dealership (dealership)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    end

    if not columnInfo('vg_dealership_vehicles', 'purchase_type') then
        update("ALTER TABLE vg_dealership_vehicles ADD COLUMN purchase_type VARCHAR(20) NOT NULL DEFAULT 'permanent' AFTER stock")
    end
    if not columnInfo('vg_dealership_vehicles', 'duration_days') then
        update('ALTER TABLE vg_dealership_vehicles ADD COLUMN duration_days INT DEFAULT NULL AFTER purchase_type')
    end
    if not columnInfo('vg_dealership_sales', 'purchase_type') then
        update("ALTER TABLE vg_dealership_sales ADD COLUMN purchase_type VARCHAR(20) NOT NULL DEFAULT 'permanent' AFTER currency")
    end
    if not columnInfo('vg_dealership_sales', 'expires_at') then
        update('ALTER TABLE vg_dealership_sales ADD COLUMN expires_at TIMESTAMP NULL DEFAULT NULL AFTER purchase_type')
    end
    if not columnInfo('vg_dealership_sales', 'discount_amount') then
        update('ALTER TABLE vg_dealership_sales ADD COLUMN discount_amount BIGINT NOT NULL DEFAULT 0 AFTER base_price')
    end
    if not columnInfo('vg_dealership_sales', 'discount_percent') then
        update('ALTER TABLE vg_dealership_sales ADD COLUMN discount_percent DECIMAL(5,2) NOT NULL DEFAULT 0 AFTER discount_amount')
    end

    local userIdColumn = columnInfo('vg_dealership_sales', 'user_id')
    if userIdColumn and (tonumber(userIdColumn.CHARACTER_MAXIMUM_LENGTH) or 0) < 64 then
        update('ALTER TABLE vg_dealership_sales MODIFY COLUMN user_id VARCHAR(64) NOT NULL')
    end
end

local function databaseUnavailable()
    if databaseReady then return nil end
    return { ok = false, message = 'A concessionária ainda está preparando o banco de dados.', type = 'error' }
end

local function categoryPayload(shop)
    local result = {}
    for i = 1, #(shop.categories or {}) do
        local item = shop.categories[i]
        result[#result + 1] = { id = item.id, label = item.label, icon = item.icon }
    end
    return result
end

local function vehiclePayload(row, shopId, source)
    local originalPrice = tonumber(row.price) or 0
    local price, discount, discountPercent = vipPrice(source, originalPrice)
    local tax, taxLabel = taxFor(shopId, price)
    local stock = tonumber(row.stock) or 0
    local period = periodId(row.purchase_type)
    return {
        id = tonumber(row.id), dealership = row.dealership, category = row.category, model = row.model,
        name = row.name, brand = row.brand, price = price, originalPrice = originalPrice,
        vipDiscount = discount, vipDiscountPercent = discountPercent,
        tax = tax, taxLabel = taxLabel, total = price + tax,
        stock = stock, purchaseType = period, durationDays = tonumber(row.duration_days) or periodDays(period),
        durationLabel = periodLabel(period), durationShort = periodShort(period),
        available = tonumber(row.enabled) == 1 and (stock < 0 or stock > 0), enabled = tonumber(row.enabled) == 1, image = row.image,
    }
end

local function playerPayload(source, currency)
    local data = playerData(source) or {}
    local charinfo = data.charinfo or {}
    local name = (('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return {
        name = name ~= '' and name or GetPlayerName(source) or 'Jogador',
        money = accountBalance(source, 'cash'), bank = accountBalance(source, 'bank'), crypto = accountBalance(source, 'crypto'), currency = currency,
    }
end

local function storePayload(source, shopId)
    local shop = dealership(shopId)
    if not shop then return nil end
    local rows = query('SELECT * FROM vg_dealership_vehicles WHERE dealership = ? AND enabled = 1 ORDER BY display_order ASC, name ASC', { shopId })
    local vehicles = {}
    for i = 1, #rows do vehicles[#vehicles + 1] = vehiclePayload(rows[i], shopId, source) end
    local currency = currencyFor(shop)
    return {
        ok = true,
        dealership = { id = shopId, label = shop.label, subtitle = shop.subtitle, currency = currency, categories = categoryPayload(shop) },
        player = playerPayload(source, currency), vehicles = vehicles, testDrive = Config.TestDrive, fallbackImage = Config.FallbackImage,
    }
end

local function adminPayload()
    local dealerships = {}
    for id, shop in pairs(Config.Dealerships or {}) do
        dealerships[#dealerships + 1] = { id = id, label = shop.label, currency = currencyFor(shop), categories = categoryPayload(shop) }
    end
    table.sort(dealerships, function(a, b) return a.id < b.id end)
    local rows = query('SELECT * FROM vg_dealership_vehicles ORDER BY dealership ASC, display_order ASC, name ASC')
    local vehicles = {}
    for i = 1, #rows do vehicles[#vehicles + 1] = vehiclePayload(rows[i], rows[i].dealership) end
    return { ok = true, mode = 'admin', dealerships = dealerships, vehicles = vehicles, periods = Config.VehiclePeriods, fallbackImage = Config.FallbackImage }
end

local function seedVehicles()
    for _, item in ipairs(Config.SeedVehicles or {}) do
        local model = normalize(item.model)
        if model ~= '' and dealership(item.dealership) then
            update([[INSERT INTO vg_dealership_vehicles
                (dealership, category, model, name, brand, price, stock, purchase_type, duration_days, image, enabled, display_order)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE name = VALUES(name), brand = VALUES(brand), price = VALUES(price), stock = VALUES(stock),
                purchase_type = VALUES(purchase_type), duration_days = VALUES(duration_days), image = VALUES(image), enabled = VALUES(enabled), display_order = VALUES(display_order)]], {
                item.dealership, item.category or 'carro', model, item.name or model, item.brand, tonumber(item.price) or 0,
                tonumber(item.stock) or Config.SeedDefaultStock or 0, periodId(item.purchaseType or item.purchase_type), periodDays(item.purchaseType or item.purchase_type),
                item.image, item.enabled == false and 0 or 1, tonumber(item.displayOrder) or 0,
            })
        end
    end
end

local function rowById(id)
    return query('SELECT * FROM vg_dealership_vehicles WHERE id = ? LIMIT 1', { tonumber(id) or 0 })[1]
end

lib.callback.register('ob_concessionaria:openDealership', function(source, shopId)
    local unavailable = databaseUnavailable()
    if unavailable then return unavailable end
    if not citizenId(source) then return { ok = false, message = 'Personagem Qbox não encontrado.', type = 'error' } end
    if not dealership(shopId) or not nearDealership(source, shopId) then return { ok = false, message = 'Você está longe da concessionária.', type = 'error' } end
    return storePayload(source, shopId)
end)

lib.callback.register('ob_concessionaria:buyVehicle', function(source, shopId, vehicleId)
    local unavailable = databaseUnavailable()
    if unavailable then return unavailable end
    local shop = dealership(shopId)
    local cid = citizenId(source)
    if not shop or not cid or not nearDealership(source, shopId) then return { ok = false, message = 'Compra inválida.', type = 'error' } end
    if purchaseLocks[cid] then return { ok = false, message = 'Aguarde a compra anterior terminar.', type = 'error' } end

    local row = rowById(vehicleId)
    if not row or row.dealership ~= shopId or tonumber(row.enabled) ~= 1 then return { ok = false, message = 'Veículo indisponível.', type = 'error' } end
    if tonumber(row.stock) == 0 then return { ok = false, message = 'Este veículo está esgotado.', type = 'error' } end
    local registered, registerError = vehicleIsRegistered(row.model)
    if not registered then return { ok = false, message = registerError, type = 'error' } end

    purchaseLocks[cid] = true
    local currency = currencyFor(shop)
    local originalPrice = tonumber(row.price) or 0
    local price, discount, discountPercent = vipPrice(source, originalPrice)
    local tax = taxFor(shopId, price)
    local total = price + tax
    if not takePayment(source, total, currency) then
        purchaseLocks[cid] = nil
        return { ok = false, message = paymentError(currency), type = 'error' }
    end

    local plate = generatePlate()
    local expiry = expiryFor(row.purchase_type)
    local registeredVehicle, registerMessage = insertPlayerVehicle(source, row, plate, expiry)
    if not registeredVehicle then
        refundPayment(source, total, currency)
        purchaseLocks[cid] = nil
        return { ok = false, message = registerMessage or 'Não foi possível registrar o veículo.', type = 'error' }
    end

    if tonumber(row.stock) > 0 then update('UPDATE vg_dealership_vehicles SET stock = stock - 1 WHERE id = ? AND stock > 0', { row.id }) end
    insert([[INSERT INTO vg_dealership_sales
        (user_id, dealership, model, plate, currency, purchase_type, expires_at, base_price, discount_amount, discount_percent, tax_amount, total_price)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        cid, shopId, row.model, plate, currency, periodId(row.purchase_type), expiry,
        originalPrice, discount, discountPercent, tax, total,
    })
    purchaseLocks[cid] = nil
    notify(source, ('%s adquirido. Placa %s.'):format(row.name, plate), 'success')
    return { ok = true, message = ('%s foi enviado para sua garagem.'):format(row.name), payload = storePayload(source, shopId) }
end)

lib.callback.register('ob_concessionaria:startTestDrive', function(source, shopId, vehicleId)
    local unavailable = databaseUnavailable()
    if unavailable then return unavailable end
    local shop = dealership(shopId)
    if not shop or not nearDealership(source, shopId) or testDrivePlayers[source] then return { ok = false, message = 'Test drive indisponível.', type = 'error' } end
    local row = rowById(vehicleId)
    if not row or row.dealership ~= shopId or tonumber(row.enabled) ~= 1 then return { ok = false, message = 'Veículo indisponível.', type = 'error' } end
    if Config.TestDrive.enabled == false then return { ok = false, message = 'Test drive desativado.', type = 'error' } end

    local cfg = Config.TestDrive
    local price = tonumber(cfg.price) or 0
    local currency = tostring(cfg.currency or 'money'):lower() == 'crypto' and 'crypto' or 'money'
    if not takePayment(source, price, currency) then return { ok = false, message = paymentError(currency), type = 'error' } end
    testDrivePlayers[source] = true
    SetPlayerRoutingBucket(source, (tonumber(cfg.bucketBase) or 9000) + source)
    return { ok = true, model = row.model, seconds = tonumber(cfg.seconds) or 45, spawn = cfg.spawn }
end)

lib.callback.register('ob_concessionaria:finishTestDrive', function(source)
    if testDrivePlayers[source] then
        SetPlayerRoutingBucket(source, 0)
        testDrivePlayers[source] = nil
    end
    return { ok = true }
end)

lib.callback.register('ob_concessionaria:openAdmin', function(source)
    local unavailable = databaseUnavailable()
    if unavailable then return unavailable end
    if not hasStaffAccess(source) then return { ok = false, message = 'Você não tem permissão.', type = 'error' } end
    return adminPayload()
end)

lib.callback.register('ob_concessionaria:adminSaveVehicle', function(source, data)
    local unavailable = databaseUnavailable()
    if unavailable then return unavailable end
    if not hasStaffAccess(source) then return { ok = false, message = 'Você não tem permissão.', type = 'error' } end
    data = data or {}
    local shopId = tostring(data.dealership or 'normal')
    local model = normalize(data.model)
    if not dealership(shopId) or model == '' or tostring(data.name or '') == '' then return { ok = false, message = 'Preencha loja, modelo e nome.', type = 'error' } end
    local registered, registerError = vehicleIsRegistered(model)
    if not registered then return { ok = false, message = registerError, type = 'error' } end

    local values = { shopId, tostring(data.category or 'carro'), model, tostring(data.name), tostring(data.brand or ''), tonumber(data.price) or 0,
        tonumber(data.stock) or 0, periodId(data.purchaseType), periodDays(data.purchaseType), tostring(data.image or ''), data.enabled == false and 0 or 1, tonumber(data.displayOrder) or 0 }
    if tonumber(data.id) and tonumber(data.id) > 0 then
        values[#values + 1] = tonumber(data.id)
        update('UPDATE vg_dealership_vehicles SET dealership = ?, category = ?, model = ?, name = ?, brand = ?, price = ?, stock = ?, purchase_type = ?, duration_days = ?, image = ?, enabled = ?, display_order = ? WHERE id = ?', values)
    else
        insert([[INSERT INTO vg_dealership_vehicles
            (dealership, category, model, name, brand, price, stock, purchase_type, duration_days, image, enabled, display_order)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], values)
    end
    return { ok = true, message = 'Veículo salvo.', payload = adminPayload() }
end)

lib.callback.register('ob_concessionaria:adminSetVehicleEnabled', function(source, id, enabled)
    local unavailable = databaseUnavailable()
    if unavailable then return unavailable end
    if not hasStaffAccess(source) then return { ok = false, message = 'Você não tem permissão.', type = 'error' } end
    update('UPDATE vg_dealership_vehicles SET enabled = ? WHERE id = ?', { enabled and 1 or 0, tonumber(id) or 0 })
    return { ok = true, message = enabled and 'Veículo ativado.' or 'Veículo pausado.', payload = adminPayload() }
end)

lib.callback.register('ob_concessionaria:adminDeleteVehicle', function(source, id)
    local unavailable = databaseUnavailable()
    if unavailable then return unavailable end
    if not hasStaffAccess(source) then return { ok = false, message = 'Você não tem permissão.', type = 'error' } end
    update('DELETE FROM vg_dealership_vehicles WHERE id = ?', { tonumber(id) or 0 })
    return { ok = true, message = 'Veículo removido.', payload = adminPayload() }
end)

AddEventHandler('playerDropped', function()
    local playerSource = source
    if testDrivePlayers[playerSource] then
        SetPlayerRoutingBucket(playerSource, 0)
        testDrivePlayers[playerSource] = nil
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= RESOURCE then return end
    for playerSource in pairs(testDrivePlayers) do
        if GetPlayerPing(playerSource) > 0 then SetPlayerRoutingBucket(playerSource, 0) end
        testDrivePlayers[playerSource] = nil
    end
    for citizenid in pairs(purchaseLocks) do purchaseLocks[citizenid] = nil end
end)

MySQL.ready(function()
    CreateThread(function()
        Wait(750)
        local ok, err = pcall(function()
            createTables()
            seedVehicles()
        end)

        databaseReady = ok
        if not ok then
            print(('^1[%s] Falha ao preparar o banco: %s^7'):format(RESOURCE, tostring(err)))
            return
        end
        debugLog('Concessionária Qbox pronta.')
    end)
end)
