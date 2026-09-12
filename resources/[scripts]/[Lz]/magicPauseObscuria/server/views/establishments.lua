local function respond(src, token, payload)
    TriggerClientEvent('MagicPause:client:serverResponse', src, token, payload or {})
end

local requestWindows = {}

local function isRateLimited(src, action, delay)
    local now = GetGameTimer()
    local key = ('%s:%s'):format(src, action)
    if requestWindows[key] and now - requestWindows[key] < delay then return true end
    requestWindows[key] = now
    return false
end

local function restaurantExport(name, ...)
    if GetResourceState('ob_restaurantes') ~= 'started' then return nil, false end
    local args = { ... }
    local ok, result = pcall(function()
        local provider = exports.ob_restaurantes
        return provider[name](provider, table.unpack(args))
    end)
    return result, ok
end

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

RegisterNetEvent('MagicPause:server:getEstablishments', function(token)
    local src = source
    if isRateLimited(src, 'directory', 500) then
        respond(src, token, { ok = false, error = 'rate_limited' })
        return
    end
    local directory, listOk = restaurantExport('GetEstablishmentDirectory', src)
    if not listOk or type(directory) ~= 'table' then
        respond(src, token, { ok = true, available = false, restaurants = {} })
        return
    end

    local entries = {}
    for _, restaurant in ipairs(directory.restaurants or {}) do
        local details = nil
        if restaurant.canManage == true then
            details = restaurantExport('GetRestaurantAdminPayload', src, restaurant.id)
        end
        entries[#entries + 1] = {
            id = restaurant.id,
            label = restaurant.label,
            job = restaurant.job,
            theme = restaurant.theme,
            isOpen = restaurant.isOpen == true,
            canWork = restaurant.canWork == true,
            canManage = restaurant.canManage == true,
            isBoss = restaurant.isBoss == true,
            isMember = restaurant.isMember == true,
            description = restaurant.description,
            coverUrl = restaurant.coverUrl,
            menuImageUrl = restaurant.menuImageUrl,
            notes = restaurant.notes,
            features = restaurant.features,
            locationLabel = restaurant.locationLabel,
            callText = restaurant.callText,
            location = restaurant.location,
            menu = restaurant.menu,
            dashboard = details and details.dashboard or nil,
            management = details
        }
    end

    respond(src, token, {
        ok = true,
        available = true,
        isStaff = directory.isAdmin == true,
        profile = directory.profile,
        restaurants = entries
    })
end)

RegisterNetEvent('MagicPause:server:callEstablishment', function(token, data)
    local src = source
    if isRateLimited(src, 'serviceCall', 1000) then
        respond(src, token, { ok = false, error = 'rate_limited' })
        return
    end
    local restaurantId = type(data) == 'table' and tostring(data.restaurantId or '') or ''
    local result, ok = restaurantExport('CallEstablishment', src, restaurantId)
    if not ok or type(result) ~= 'table' then
        respond(src, token, { ok = false, error = 'restaurant_unavailable' })
        return
    end
    respond(src, token, result)
end)

RegisterNetEvent('MagicPause:server:setRestaurantAvailability', function(token, data)
    local src = source
    if isRateLimited(src, 'availability', 1000) then
        respond(src, token, { ok = false, error = 'rate_limited' })
        return
    end
    local restaurantId = type(data) == 'table' and tostring(data.restaurantId or '') or ''
    local isOpen = type(data) == 'table' and data.open == true
    local result, ok = restaurantExport('SetEstablishmentAvailability', src, restaurantId, isOpen)

    if not ok or type(result) ~= 'table' then
        respond(src, token, { ok = false, error = 'restaurant_unavailable' })
        return
    end

    respond(src, token, result)
end)

RegisterNetEvent('MagicPause:server:getRestaurantManagement', function(token, data)
    local src = source
    if isRateLimited(src, 'management', 500) then
        respond(src, token, { ok = false, error = 'rate_limited' })
        return
    end
    local restaurantId = type(data) == 'table' and tostring(data.restaurantId or '') or ''
    local result, ok = restaurantExport('GetRestaurantAdminPayload', src, restaurantId)

    if not ok or type(result) ~= 'table' then
        respond(src, token, { ok = false, error = 'restaurant_unavailable' })
        return
    end

    respond(src, token, result)
end)

RegisterNetEvent('MagicPause:server:restaurantManagementAction', function(token, data)
    local src = source
    local action = type(data) == 'table' and tostring(data.action or '') or ''
    local payload = type(data) == 'table' and type(data.data) == 'table' and data.data or {}
    if not managementActions[action] then
        respond(src, token, { ok = false, error = 'unknown_action' })
        return
    end
    if isRateLimited(src, 'action:' .. action, 750) then
        respond(src, token, { ok = false, error = 'rate_limited' })
        return
    end
    local result, ok = restaurantExport('RunRestaurantManagementAction', src, action, payload)

    if not ok or type(result) ~= 'table' then
        respond(src, token, { ok = false, error = 'restaurant_unavailable' })
        return
    end

    respond(src, token, result)
end)

AddEventHandler('playerDropped', function()
    local prefix = ('%s:'):format(source)
    for key in pairs(requestWindows) do
        if key:sub(1, #prefix) == prefix then requestWindows[key] = nil end
    end
end)
