local RESOURCE = GetCurrentResourceName()
local pendingCheckouts = {}
local itemUses = {}
local checkoutTimes = {}
local shopSessions = {}
local databaseReady = false

local function debugPrint(...)
    if MechanicConfig.Debug then
        print(('^5[%s]^7'):format(RESOURCE), ...)
    end
end

local function notify(source, notifyType, message, duration)
    exports.qbx_core:Notify(source, tostring(message or ''), notifyType or 'inform', duration or 5000)
end

local function getPlayer(source)
    source = tonumber(source)
    return source and exports.qbx_core:GetPlayer(source) or nil
end

local function getCitizenId(player)
    local data = player and player.PlayerData or {}
    local citizenid = tostring(data.citizenid or '')
    return citizenid ~= '' and citizenid or nil
end

local function locationPoint(location, rawPoint, pointIndex)
    local point = type(rawPoint) == 'table' and rawPoint or nil
    if point and point.enabled == false then return nil end

    local coords = point and (point.coords or (point.x and point)) or rawPoint
    if not coords or tonumber(coords.x) == nil or tonumber(coords.y) == nil or tonumber(coords.z) == nil then
        return nil
    end

    local id = tostring(location.id or '')
    if id == '' then return nil end
    if pointIndex > 1 then id = ('%s:%s'):format(id, pointIndex) end

    local blip
    if point and point.blip ~= nil then
        blip = point.blip
    elseif pointIndex == 1 or location.blip and location.blip.eachPoint == true then
        blip = location.blip
    end

    local marker = location.marker
    if point and point.marker ~= nil then marker = point.marker end

    return {
        id = id,
        locationId = tostring(location.id),
        label = point and point.label or location.label,
        coords = coords,
        radius = tonumber(point and point.radius) or tonumber(location.radius) or 3.0,
        jobs = location.jobs,
        marker = marker,
        blip = blip,
    }
end

local function getLocationPoints(location)
    local result = {}
    local configured = type(location.points) == 'table' and location.points or nil

    if configured and #configured > 0 then
        for index, point in ipairs(configured) do
            local entry = locationPoint(location, point, index)
            if entry then result[#result + 1] = entry end
        end
    elseif location.coords then
        local entry = locationPoint(location, location.coords, 1)
        if entry then result[1] = entry end
    end

    return result
end

local function getLocation(locationId)
    for _, location in ipairs(MechanicConfig.Locations or {}) do
        for _, point in ipairs(getLocationPoints(location)) do
            if point.id == locationId then return point end
        end
    end
end

local function jobMatches(player, jobs, ignoreDuty)
    if type(jobs) ~= 'table' or #jobs == 0 then return true end
    local job = player and player.PlayerData and player.PlayerData.job or {}

    for _, name in ipairs(jobs) do
        if job.name == name then
            return ignoreDuty == true or MechanicConfig.RequireDuty ~= true or job.onduty ~= false
        end
    end

    return false
end

local function isMechanic(source, ignoreDuty)
    local jobs = MechanicConfig.Jobs and MechanicConfig.Jobs.mechanic or {}
    return jobMatches(getPlayer(source), jobs, ignoreDuty)
end

local function isNear(source, coords, distance)
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then return false end
    return #(GetEntityCoords(ped) - coords) <= distance
end

local function canUseLocation(source, location)
    local player = getPlayer(source)
    if not player or not location or not jobMatches(player, location.jobs) then return false end
    return isNear(source, location.coords, (tonumber(location.radius) or 3.0) + 8.0)
end

local function createShopSession(source, locationId, plate, vehicleId)
    local duration = tonumber(MechanicConfig.Shop.sessionDurationMs) or 1800000
    local token = ('%s:%s:%s'):format(source, GetGameTimer(), math.random(100000, 999999))
    shopSessions[source] = {
        token = token,
        locationId = locationId,
        vehiclePlate = plate,
        vehicleId = vehicleId,
        vehicleOwned = vehicleId ~= nil,
        expiresAt = GetGameTimer() + duration
    }
    return token
end

local function validShopSession(source, token, locationId)
    local session = shopSessions[source]
    if not session or session.expiresAt < GetGameTimer() then
        shopSessions[source] = nil
        return false
    end
    local valid = session.token == tostring(token or '') and session.locationId == locationId
    if valid then
        session.expiresAt = GetGameTimer() + (tonumber(MechanicConfig.Shop.sessionDurationMs) or 1800000)
    end
    return valid
end

local function beginPaidAction(source)
    local now = GetGameTimer()
    local cooldown = tonumber(MechanicConfig.Shop.checkoutCooldownMs) or 1500
    if checkoutTimes[source] and now - checkoutTimes[source] < cooldown then return false end
    checkoutTimes[source] = now
    return true
end

local function getAllowedLocations(source)
    local player = getPlayer(source)
    if not player then return {} end

    local allowed = {}
    for _, location in ipairs(MechanicConfig.Locations or {}) do
        if jobMatches(player, location.jobs, true) then
            for _, point in ipairs(getLocationPoints(location)) do
                allowed[#allowed + 1] = point
            end
        end
    end
    return allowed
end

local function normalizePlate(plate)
    local normalized = tostring(plate or ''):upper():gsub('%s+', '')
    return normalized
end

local function paymentAccounts()
    local accounts = MechanicConfig.Shop and MechanicConfig.Shop.paymentAccounts
    return type(accounts) == 'table' and accounts or { 'cash', 'bank' }
end

local function getBillableOptions()
    local options = {}

    for categoryId, categoryOptions in pairs(MechanicConfig.Shop.billableOptions or {}) do
        for _, optionId in ipairs(categoryOptions) do
            options[tostring(optionId)] = tostring(categoryId)
        end
    end

    return options
end

local billableOptions = getBillableOptions()

local levelPropertyNames = {
    engine = 'modEngine',
    brakes = 'modBrakes',
    transmission = 'modTransmission',
    suspension = 'modSuspension',
    armor = 'modArmor'
}

local function checkoutOptionPrice(categoryId, optionId, value, properties)
    local prices = MechanicConfig.Shop.prices or {}
    local price = tonumber(prices[categoryId]) or tonumber(MechanicConfig.Shop.defaultPrice) or 0
    local levelPricing = MechanicConfig.Shop.levelPricing or {}

    if type(levelPricing.options) == 'table' and levelPricing.options[optionId] == true then
        local level = tonumber(value)
        local propertyName = levelPropertyNames[optionId]
        if not level or level ~= math.floor(level) or level < -1 or level > 20
            or not propertyName or tonumber(properties and properties[propertyName]) ~= level
        then
            return nil
        end

        if level >= 0 then
            price = price * (1.0 + level * math.max(0, tonumber(levelPricing.step) or 0.5))
        end
    end

    return math.floor(price)
end

local function calculateCheckoutTotal(changes, properties)
    if type(changes) ~= 'table' or #changes > 100 then return nil end

    local total = 0
    local seen = {}

    for _, change in ipairs(changes) do
        if type(change) ~= 'table' then return nil end

        local optionId = tostring(change.optionId or '')
        local categoryId = tostring(change.categoryId or '')
        if optionId == '' or categoryId == '' or billableOptions[optionId] ~= categoryId then return nil end

        if not seen[optionId] then
            seen[optionId] = true
            local price = checkoutOptionPrice(categoryId, optionId, change.value, properties)
            if price == nil then return nil end
            total = total + price
        end
    end

    return math.max(0, math.floor(total))
end

local function tryPayment(player, amount)
    amount = math.floor(math.abs(tonumber(amount) or 0))
    if amount < 1 then return true, nil end

    for _, account in ipairs(paymentAccounts()) do
        local balance = tonumber(player.PlayerData.money and player.PlayerData.money[account]) or 0
        if balance >= amount and player.Functions.RemoveMoney(account, amount, 'ob_mechanic_checkout') == true then
            return true, account
        end
    end

    return false
end

local function refund(player, account, amount)
    if account and amount > 0 then player.Functions.AddMoney(account, amount, 'ob_mechanic_refund') end
end

local function depositSociety(amount)
    local bank = MechanicConfig.Shop and MechanicConfig.Shop.societyBank or {}
    if bank.provider ~= 'renewed' then return true end
    local resource = tostring(bank.resource or 'Renewed-Banking')
    if GetResourceState(resource) ~= 'started' then
        debugPrint(('receita não depositada: %s não iniciado'):format(resource))
        return false
    end

    local ok, err = pcall(function()
        exports[resource]:addAccountMoney(tostring(bank.account or 'mechanic'), amount, 'serviço mecânico')
    end)
    if not ok then debugPrint('falha ao depositar receita:', err) end
    return ok
end

local function decode(value)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return nil end
    local ok, data = pcall(json.decode, value)
    return ok and type(data) == 'table' and data or nil
end

local function awaitDatabase()
    local timeout = GetGameTimer() + 10000
    while not databaseReady and GetGameTimer() < timeout do Wait(50) end
    return databaseReady
end

local function getRegisteredVehicleId(vehicle, plate)
    plate = normalizePlate(plate)
    if plate == '' or not awaitDatabase() then return nil end

    local ok, vehicleId = pcall(function()
        return MySQL.scalar.await([[SELECT id FROM player_vehicles
            WHERE REPLACE(UPPER(plate), ' ', '') = ? LIMIT 1]], { plate })
    end)

    if not ok then
        debugPrint(('falha ao validar a placa %s: %s'):format(plate, tostring(vehicleId)))
        return nil
    end

    vehicleId = tonumber(vehicleId)
    if vehicleId and vehicleId > 0 and vehicle and DoesEntityExist(vehicle) then
        Entity(vehicle).state:set('vehicleid', vehicleId, true)
    end
    return vehicleId
end

local function getPendingMods(citizenid, plate)
    if not awaitDatabase() then return nil end
    local row = MySQL.single.await([[SELECT payload FROM ob_mechanic_pending
        WHERE citizenid = ? AND plate = ? LIMIT 1]], { citizenid, normalizePlate(plate) })
    local payload = row and decode(row.payload)
    return payload and type(payload.mods) == 'table' and payload or nil
end

local function setPendingMods(citizenid, plate, payload)
    if not awaitDatabase() then return false end
    plate = normalizePlate(plate)
    if not citizenid or plate == '' then return false end
    local affected = MySQL.update.await([[INSERT INTO ob_mechanic_pending (citizenid, plate, payload)
        VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE payload = VALUES(payload), updated_at = CURRENT_TIMESTAMP]],
        { citizenid, plate, json.encode(payload or {}) })
    return tonumber(affected) ~= nil
end

local function clearPendingMods(citizenid, plate)
    if not citizenid or not awaitDatabase() then return false end
    MySQL.update.await('DELETE FROM ob_mechanic_pending WHERE citizenid = ? AND plate = ?', {
        citizenid, normalizePlate(plate)
    })
    return true
end

local function validatedVehicle(source, netId, plate)
    netId = tonumber(netId)
    if not netId then return nil end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle <= 0 or not DoesEntityExist(vehicle) then return nil end
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 or #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > 12.0 then return nil end
    if MechanicConfig.Shop.requireDriver == true and GetPedInVehicleSeat(vehicle, -1) ~= ped then return nil end
    local actualPlate = normalizePlate(GetVehicleNumberPlateText(vehicle))
    if actualPlate == '' or actualPlate ~= normalizePlate(plate) then return nil end
    return vehicle, actualPlate
end

local function validProperties(props)
    if type(props) ~= 'table' then return false end
    local ok, encoded = pcall(json.encode, props)
    return ok and #encoded <= 100000
end

local function saveVehicleProperties(vehicle, plate, props)
    if MechanicConfig.Shop.saveVehicle ~= true then return true, 'disabled' end
    if not validProperties(props) then return false, 'invalid_properties' end

    props.plate = GetVehicleNumberPlateText(vehicle)
    props.model = GetEntityModel(vehicle)

    if GetResourceState('qbx_vehicles') == 'started' then
        local ok, result, reason = pcall(function()
            local vehicleId = Entity(vehicle).state.vehicleid or exports.qbx_vehicles:GetVehicleIdByPlate(props.plate)
            if not vehicleId then return false, 'unowned' end
            local saved, saveError = exports.qbx_vehicles:SaveVehicle(vehicle, { props = props })
            if saved ~= true then return false, saveError or 'save_failed' end
            return true, 'saved'
        end)
        if ok and result == true then return true, reason end
        debugPrint('qbx_vehicles recusou a persistência:', ok and reason or result)
    end

    local ok, affected = pcall(function()
        return MySQL.update.await([[UPDATE player_vehicles SET mods = ?
            WHERE REPLACE(UPPER(plate), ' ', '') = ?]], { json.encode(props), plate })
    end)
    if ok and tonumber(affected) and affected > 0 then return true, 'database' end
    if not ok then debugPrint('fallback player_vehicles indisponível:', affected) end
    return false, 'unowned'
end

local function rejectCheckout(source, message)
    notify(source, 'error', message or MechanicConfig.Messages.invalidCheckout)
    TriggerClientEvent('VanguardMechanic:client:checkoutResult', source, false)
end

RegisterNetEvent('VanguardMechanic:server:requestLocations', function()
    TriggerClientEvent('VanguardMechanic:client:setLocations', source, getAllowedLocations(source))
end)

RegisterNetEvent('VanguardMechanic:server:requestOpen', function(request)
    local source = source
    request = type(request) == 'table' and request or { locationId = request }
    local locationId = tostring(request.locationId or '')
    local location = getLocation(tostring(locationId or ''))
    local player = getPlayer(source)

    if not location or not player or not jobMatches(player, location.jobs, true)
        or not isNear(source, location and location.coords or vec3(0.0, 0.0, 0.0), (tonumber(location and location.radius) or 3.0) + 8.0)
    then
        notify(source, 'error', MechanicConfig.Messages.noPermission)
        return
    end

    if not jobMatches(player, location.jobs) then
        notify(source, 'warning', MechanicConfig.Messages.offDuty)
        return
    end

    local vehicle, plate = validatedVehicle(source, request.vehicleNetId, request.plate)
    if not vehicle then
        notify(source, 'warning', MechanicConfig.Messages.needVehicle)
        return
    end

    local vehicleId = getRegisteredVehicleId(vehicle, plate)
    local vehicleOwned = vehicleId ~= nil
    local sessionToken = createShopSession(source, location.id, plate, vehicleId)
    TriggerClientEvent('VanguardMechanic:client:openShop', source, location.id, location.label, sessionToken, vehicleOwned)

    if not vehicleOwned then
        notify(source, 'warning', MechanicConfig.Messages.npcVehicle)
    end
end)

RegisterNetEvent('VanguardMechanic:server:closeSession', function(token)
    local source = source
    local session = shopSessions[source]
    if session and session.token == tostring(token or '') then shopSessions[source] = nil end
end)

RegisterNetEvent('VanguardMechanic:server:shopRepair', function(data)
    local source = source
    local player = getPlayer(source)
    data = type(data) == 'table' and data or {}
    local location = getLocation(tostring(data.locationId or ''))
    local vehicle = validatedVehicle(source, data.vehicleNetId, data.plate)

    if not beginPaidAction(source)
        or not player
        or not location
        or not validShopSession(source, data.sessionToken, location.id)
        or not canUseLocation(source, location)
        or not vehicle
    then
        notify(source, 'error', MechanicConfig.Messages.invalidCheckout)
        TriggerClientEvent('VanguardMechanic:client:repairResult', source, false)
        return
    end

    local price = math.max(0, math.floor(tonumber(MechanicConfig.Shop.repairPrice) or 0))
    local paid, account = true, nil
    if MechanicConfig.Shop.usePayment == true then paid, account = tryPayment(player, price) end
    if not paid then
        notify(source, 'error', MechanicConfig.Messages.notEnoughMoney)
        TriggerClientEvent('VanguardMechanic:client:repairResult', source, false)
        return
    end

    depositSociety(price)
    TriggerClientEvent('VanguardMechanic:client:repairResult', source, true)
end)

RegisterNetEvent('VanguardMechanic:server:checkout', function(data)
    local source = source
    local player = getPlayer(source)
    data = type(data) == 'table' and data or {}
    local location = getLocation(tostring(data.locationId or ''))

    if not beginPaidAction(source) then
        return rejectCheckout(source, 'Aguarde o orçamento anterior ser processado.')
    end

    if not player
        or not location
        or not validShopSession(source, data.sessionToken, location.id)
        or not canUseLocation(source, location)
    then
        return rejectCheckout(source, MechanicConfig.Messages.noPermission)
    end

    local vehicle, plate = validatedVehicle(source, data.vehicleNetId, data.plate)
    local total = calculateCheckoutTotal(data.changes, data.properties)
    local displayedTotal = math.floor(tonumber(data.total) or -1)
    local maxCheckout = tonumber(MechanicConfig.Shop.maxCheckout) or 1000000
    if not vehicle or not total or total ~= displayedTotal or total > maxCheckout
        or not validProperties(data.properties) or type(data.mods) ~= 'table'
    then
        return rejectCheckout(source)
    end

    local session = shopSessions[source]
    if not session or session.vehicleOwned ~= true or session.vehiclePlate ~= plate then
        return rejectCheckout(source, MechanicConfig.Messages.npcVehicle)
    end

    local paid, account = true, nil
    if MechanicConfig.Shop.usePayment == true then paid, account = tryPayment(player, total) end
    if not paid then
        notify(source, 'error', MechanicConfig.Messages.notEnoughMoney)
        if MechanicConfig.Shop.savePendingModifications == true then
            pendingCheckouts[source] = {
                citizenid = getCitizenId(player), total = total, plate = plate,
                vehicleName = data.vehicleName, vehicleModel = data.vehicleModel,
                mods = data.mods, createdAt = os.time()
            }
            TriggerClientEvent('VanguardMechanic:client:askSavePending', source, MechanicConfig.Messages.savePendingQuestion)
        end
        TriggerClientEvent('VanguardMechanic:client:checkoutResult', source, false)
        return
    end

    local saved, reason = saveVehicleProperties(vehicle, plate, data.properties)
    if not saved then
        refund(player, account, total)
        debugPrint(('persistência recusada para %s: %s'):format(plate, tostring(reason)))
        return rejectCheckout(source, 'O pagamento foi estornado porque não foi possível registrar o veículo.')
    end

    notify(source, 'success', MechanicConfig.Messages.checkoutDone)
    TriggerClientEvent('VanguardMechanic:client:checkoutResult', source, true)

    CreateThread(function()
        depositSociety(total)
        clearPendingMods(getCitizenId(player), plate)
    end)
end)

RegisterNetEvent('VanguardMechanic:server:savePending', function()
    local source = source
    local player = getPlayer(source)
    local data = pendingCheckouts[source]
    pendingCheckouts[source] = nil
    local citizenid = getCitizenId(player)

    if not data or not citizenid or data.citizenid ~= citizenid or type(data.mods) ~= 'table' then
        return notify(source, 'error', MechanicConfig.Messages.pendingSaveFailed)
    end

    local ok = setPendingMods(citizenid, data.plate, {
        total = data.total, vehicleName = data.vehicleName, vehicleModel = data.vehicleModel,
        plate = data.plate, mods = data.mods, createdAt = data.createdAt or os.time()
    })
    notify(source, ok and 'success' or 'error', ok and MechanicConfig.Messages.pendingSaved or MechanicConfig.Messages.pendingSaveFailed)
end)

RegisterNetEvent('VanguardMechanic:server:discardPendingCheckout', function()
    pendingCheckouts[source] = nil
end)

RegisterNetEvent('VanguardMechanic:server:requestPending', function(plate)
    local source = source
    local citizenid = getCitizenId(getPlayer(source))
    if not citizenid or MechanicConfig.Shop.savePendingModifications ~= true then return end
    local pending = getPendingMods(citizenid, plate)
    if pending then
        TriggerClientEvent('VanguardMechanic:client:askResumePending', source, {
            message = MechanicConfig.Messages.resumePendingQuestion,
            plate = pending.plate or plate,
            mods = pending.mods
        })
    end
end)

RegisterNetEvent('VanguardMechanic:server:clearPending', function(plate)
    local citizenid = getCitizenId(getPlayer(source))
    if citizenid then clearPendingMods(citizenid, plate) end
end)

local function createItemToken(source, itemName, clientEvent, freeForMechanic)
    if itemUses[source] then return end
    local count = tonumber(exports.ox_inventory:Search(source, 'count', itemName)) or 0
    if count < 1 then return end

    local consume = not (freeForMechanic and isMechanic(source, true))
    if consume and exports.ox_inventory:RemoveItem(source, itemName, 1) == false then return end

    local token = ('%s:%s:%s'):format(source, os.time(), math.random(100000, 999999))
    itemUses[source] = { token = token, item = itemName, consumed = consume }
    TriggerClientEvent(clientEvent, source, token)

    SetTimeout(30000, function()
        local pending = itemUses[source]
        if not pending or pending.token ~= token then return end
        itemUses[source] = nil
        if pending.consumed and getPlayer(source) then exports.ox_inventory:AddItem(source, pending.item, 1) end
    end)
end

RegisterNetEvent('VanguardMechanic:server:itemResult', function(token, success)
    local source = source
    local pending = itemUses[source]
    if not pending or pending.token ~= tostring(token or '') then return end
    itemUses[source] = nil
    if success ~= true and pending.consumed then exports.ox_inventory:AddItem(source, pending.item, 1) end
end)

exports.qbx_core:CreateUseableItem(MechanicConfig.Items.repairKit, function(source)
    createItemToken(source, MechanicConfig.Items.repairKit, 'VanguardMechanic:client:useRepairKit', MechanicConfig.Repair.mechanicFree)
end)

exports.qbx_core:CreateUseableItem(MechanicConfig.Items.tire, function(source)
    createItemToken(source, MechanicConfig.Items.tire, 'VanguardMechanic:client:useTire', MechanicConfig.Tire.mechanicFree)
end)

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS ob_mechanic_pending (
        citizenid varchar(64) NOT NULL,
        plate varchar(16) NOT NULL,
        payload longtext NOT NULL,
        updated_at timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
        PRIMARY KEY (citizenid, plate),
        KEY idx_ob_mechanic_pending_updated (updated_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    databaseReady = true
    debugPrint('integração Qbox pronta')
end)

AddEventHandler('playerDropped', function()
    pendingCheckouts[source] = nil
    itemUses[source] = nil
    checkoutTimes[source] = nil
    shopSessions[source] = nil
end)

exports('IsMechanic', isMechanic)
