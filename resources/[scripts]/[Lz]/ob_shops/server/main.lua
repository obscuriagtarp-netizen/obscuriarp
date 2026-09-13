local shopsByType = {}
local registered = false
local hooksRegistered = false
local requestCooldown = {}

local function debugPrint(message)
    if Config.Debug then print(('[ob_shops] %s'):format(message)) end
end

local function lower(value)
    return tostring(value or ''):lower()
end

local function getGrade(group)
    local grade = type(group) == 'table' and group.grade or nil
    if type(grade) == 'table' then return tonumber(grade.level) or tonumber(grade.grade) or 0 end
    return tonumber(grade) or 0
end

local function hasRules(rules)
    return type(rules) == 'table' and next(rules) ~= nil
end

local function ruleAllows(rules, name, grade)
    if not hasRules(rules) then return nil end
    name = lower(name)
    for key, requirement in pairs(rules) do
        if type(key) == 'string' and lower(key) == name then
            if requirement == true then return true end
            return type(requirement) == 'number' and grade >= requirement
        end
        if type(key) == 'number' and lower(requirement) == name then return true end
    end
    return false
end

local function getIdentity(source)
    if GetResourceState('qbx_core') ~= 'started' then return nil end
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(source) end)
    local data = ok and player and player.PlayerData
    if not data then return nil end
    local metadata = type(data.metadata) == 'table' and data.metadata or {}
    return {
        job = type(data.job) == 'table' and data.job or {},
        gang = type(data.gang) == 'table' and data.gang or {},
        class = lower(metadata[Config.ClassMetadataKey or 'classe']),
    }
end

local function canAccess(source, shop)
    local access = type(shop.access) == 'table' and shop.access or nil
    local configured = access and (hasRules(access.jobs) or hasRules(access.gangs) or hasRules(access.classes))
    if not configured then return true end

    local identity = getIdentity(source)
    if not identity then return false end

    local checks = {}
    if hasRules(access.jobs) then
        local allowed = ruleAllows(access.jobs, identity.job.name, getGrade(identity.job)) == true
        if access.requireDuty == true then allowed = allowed and identity.job.onduty == true end
        checks[#checks + 1] = allowed
    end
    if hasRules(access.gangs) then
        checks[#checks + 1] = ruleAllows(access.gangs, identity.gang.name, getGrade(identity.gang)) == true
    end
    if hasRules(access.classes) then
        checks[#checks + 1] = ruleAllows(access.classes, identity.class, 0) == true
    end

    if access.mode == 'all' then
        for index = 1, #checks do if not checks[index] then return false end end
        return #checks > 0
    end
    for index = 1, #checks do if checks[index] then return true end end
    return false
end

local function normalizeLocations(shop)
    local locations = {}
    for _, coords in ipairs(type(shop.locations) == 'table' and shop.locations or {}) do
        local x, y, z = tonumber(coords.x or coords[1]), tonumber(coords.y or coords[2]), tonumber(coords.z or coords[3])
        if x and y and z then locations[#locations + 1] = vec3(x, y, z) end
    end
    return locations
end

local function itemExists(name)
    local ok, item = pcall(function() return exports.ox_inventory:Items(name) end)
    return ok and item ~= nil
end

local function normalizeInventory(shopId, shop)
    local inventory = {}
    for index, entry in ipairs(type(shop.inventory) == 'table' and shop.inventory or {}) do
        local name = type(entry) == 'table' and tostring(entry.name or '') or ''
        local currency = type(entry) == 'table' and tostring(entry.currency or '') or ''
        if name ~= '' and itemExists(name) and (currency == '' or itemExists(currency)) then
            local item = {
                name = name,
                price = math.max(0, math.floor(tonumber(entry.price) or 0)),
            }
            if tonumber(entry.count) and tonumber(entry.count) > 0 then item.count = math.floor(tonumber(entry.count)) end
            if currency ~= '' then item.currency = currency end
            if type(entry.metadata) == 'table' or type(entry.metadata) == 'string' then item.metadata = entry.metadata end
            if type(entry.license) == 'string' and entry.license ~= '' then item.license = entry.license end
            inventory[#inventory + 1] = item
        else
            print(('[ob_shops] Item invalido ignorado em %s, posicao %s: %s'):format(shopId, index, name))
        end
    end
    return inventory
end

local function nearLocation(source, shop, shopIndex)
    local coords = shop.locations[tonumber(shopIndex) or 0]
    local ped = GetPlayerPed(source)
    if not coords or not ped or ped <= 0 or not DoesEntityExist(ped) then return false end
    return #(GetEntityCoords(ped) - coords) <= math.max(1.0, tonumber(Config.ServerDistance) or 6.0)
end

local function authorizeShop(payload)
    local shop = shopsByType[tostring(payload.shopType or '')]
    if not shop then return true end
    local source = tonumber(payload.source)
    if not source or source <= 0 then return false end
    return nearLocation(source, shop, payload.shopId) and canAccess(source, shop.config)
end

local function registerHooks()
    if hooksRegistered then return true end
    local ok, openHook = pcall(function()
        return exports.ox_inventory:registerHook('openShop', function(payload)
            return authorizeShop(payload)
        end)
    end)
    if not ok then
        print(('[ob_shops] Nao foi possivel proteger a abertura das lojas: %s'):format(openHook))
        return false
    end
    local buyOk, buyHook = pcall(function()
        return exports.ox_inventory:registerHook('buyItem', function(payload)
            return authorizeShop(payload)
        end)
    end)
    if not buyOk then
        pcall(function() exports.ox_inventory:removeHooks(openHook) end)
        print(('[ob_shops] Nao foi possivel proteger as compras: %s'):format(buyHook))
        return false
    end
    hooksRegistered = true
    return true
end

local function registerShops()
    if registered or GetResourceState('ox_inventory') ~= 'started' then return false end
    shopsByType = {}
    if not registerHooks() then return false end

    local count = 0
    for shopId, config in pairs(Config.Shops or {}) do
        shopId = lower(shopId)
        if config.enabled == true and shopId:match('^[%w_-]+$') then
            local locations = normalizeLocations(config)
            local inventory = normalizeInventory(shopId, config)
            if #locations > 0 and #inventory > 0 then
                local shopType = 'ob_shops_' .. shopId
                local ok, err = pcall(function()
                    exports.ox_inventory:RegisterShop(shopType, {
                        name = tostring(config.label or shopId),
                        inventory = inventory,
                        locations = locations,
                    })
                end)
                if ok then
                    shopsByType[shopType] = {
                        id = shopId,
                        type = shopType,
                        locations = locations,
                        config = config,
                    }
                    count = count + 1
                else
                    print(('[ob_shops] Falha ao registrar %s: %s'):format(shopId, err))
                end
            else
                print(('[ob_shops] Loja %s ignorada: configure ao menos um local e um item valido.'):format(shopId))
            end
        elseif config.enabled == true then
            print(('[ob_shops] Identificador de loja invalido: %s'):format(shopId))
        end
    end
    registered = true
    print(('[ob_shops] %s loja(s) registrada(s) no ox_inventory.'):format(count))
    return true
end

local function syncAccess(source)
    source = tonumber(source)
    if not source or source <= 0 then return end
    local grants = {}
    if registered then
        for _, shop in pairs(shopsByType) do
            if canAccess(source, shop.config) then
                grants[shop.id] = { shopType = shop.type }
            end
        end
    end
    TriggerClientEvent('ob_shops:client:setAccess', source, grants)
end

local function syncAllPlayers()
    for _, source in ipairs(GetPlayers()) do syncAccess(tonumber(source)) end
end

RegisterNetEvent('ob_shops:server:requestAccess', function()
    local source = source
    local now = GetGameTimer()
    if now < (requestCooldown[source] or 0) then return end
    requestCooldown[source] = now + 1000
    syncAccess(source)
end)

AddEventHandler('QBCore:Server:OnPlayerLoaded', function() syncAccess(source) end)
AddEventHandler('QBCore:Server:OnJobUpdate', function(source) syncAccess(source) end)
AddEventHandler('QBCore:Server:OnGangUpdate', function(source) syncAccess(source) end)
AddEventHandler('classeSelector:server:classChanged', function(source) syncAccess(source) end)
AddEventHandler('qbx_core:server:onSetMetaData', function(key, _, _, source)
    if key == (Config.ClassMetadataKey or 'classe') then syncAccess(source) end
end)

AddEventHandler('playerDropped', function() requestCooldown[source] = nil end)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() or resource == 'ox_inventory' then
        if resource == 'ox_inventory' then registered, hooksRegistered = false, false end
        CreateThread(function()
            Wait(500)
            if registerShops() then syncAllPlayers() end
        end)
    elseif resource == 'qbx_core' then
        CreateThread(function() Wait(500); syncAllPlayers() end)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == 'ox_inventory' then
        registered, hooksRegistered = false, false
        shopsByType = {}
        return
    end
    if resource ~= GetCurrentResourceName() or GetResourceState('ox_inventory') ~= 'started' then return end

    for shopType in pairs(shopsByType) do
        pcall(function()
            exports.ox_inventory:RegisterShop(shopType, { name = 'Loja indisponivel', inventory = {} })
        end)
    end
end)

CreateThread(function()
    while not registered do
        registerShops()
        if not registered then Wait(5000) end
    end
    syncAllPlayers()
end)

exports('CanAccess', function(source, shopId)
    local shop = shopsByType['ob_shops_' .. lower(shopId)]
    return shop ~= nil and canAccess(tonumber(source), shop.config)
end)

exports('RefreshPlayer', function(source)
    syncAccess(tonumber(source))
end)
