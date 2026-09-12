local activeCrafts = {}

math.randomseed(os.time())

local function debugPrint(...)
    if Config.Debug then print('[ob_crafting]', ...) end
end

local function callExport(resource, exportName, ...)
    if not resource or resource == '' or GetResourceState(resource) ~= 'started' then return nil, false end
    local args = { ... }
    local ok, result = pcall(function()
        local provider = exports[resource]
        return provider[exportName](provider, table.unpack(args))
    end)
    if not ok then debugPrint(('export %s:%s falhou: %s'):format(resource, exportName, result)) end
    return result, ok
end

local function getPlayer(src)
    local result, ok = callExport('qbx_core', 'GetPlayer', src)
    return ok and result or nil
end

local function getIdentity(src)
    local player = getPlayer(src)
    local data = player and player.PlayerData or {}
    local job = type(data.job) == 'table' and data.job or {}
    local grade = type(job.grade) == 'table' and job.grade or {}
    local metadata = type(data.metadata) == 'table' and data.metadata or {}
    return {
        citizenid = tostring(data.citizenid or src),
        job = tostring(job.name or 'unemployed'),
        grade = tonumber(grade.level) or tonumber(grade.grade) or tonumber(job.grade) or 0,
        class = tostring(metadata[Config.ClassMetadataKey or 'classe'] or ''):lower()
    }
end

local function isAdmin(src)
    if src == 0 then return true end
    if Config.AdminAce and IsPlayerAceAllowed(src, Config.AdminAce) then return true end
    for _, permission in ipairs(Config.AdminPermissions or {}) do
        local result, ok = callExport('qbx_core', 'HasPermission', src, permission)
        if ok and result == true then return true end
        if IsPlayerAceAllowed(src, permission) then return true end
    end
    return false
end

local function tableHasAccess(rule, value, grade)
    if type(rule) ~= 'table' or next(rule) == nil then return true end
    local direct = rule[value]
    if direct ~= nil then return direct == true or grade >= (tonumber(direct) or 0) end
    for _, entry in ipairs(rule) do if tostring(entry) == value then return true end end
    return false
end

local function canAccess(src, station)
    local access = type(station.access) == 'table' and station.access or {}
    local identity = getIdentity(src)
    if not tableHasAccess(access.jobs, identity.job, identity.grade) then return false end
    if not tableHasAccess(access.classes, identity.class, 0) then return false end
    if access.ace and not IsPlayerAceAllowed(src, tostring(access.ace)) then return false end
    return true
end

local function inventoryCount(src, item)
    local ok, count = pcall(function() return exports.ox_inventory:Search(src, 'count', item) end)
    return ok and math.floor(tonumber(count) or 0) or 0
end

local function canCarry(src, item, amount, metadata)
    local ok, result = pcall(function() return exports.ox_inventory:CanCarryItem(src, item, amount, metadata) end)
    return ok and result == true
end

local function addItem(src, item, amount, metadata)
    local ok, result = pcall(function() return exports.ox_inventory:AddItem(src, item, amount, metadata) end)
    return ok and result ~= false
end

local function removeItem(src, item, amount)
    local ok, result = pcall(function() return exports.ox_inventory:RemoveItem(src, item, amount) end)
    return ok and result ~= false
end

local function nearCoords(src, coords)
    if not coords then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 then return false end
    local playerCoords = GetEntityCoords(ped)
    local target = vector3((coords.x or coords[1]) + 0.0, (coords.y or coords[2]) + 0.0, (coords.z or coords[3]) + 0.0)
    return #(playerCoords - target) <= (Config.ServerDistance or 4.5)
end

local function publicCoords(coords)
    if not coords then return nil end
    return {
        x = tonumber(coords.x or coords[1]) or 0.0,
        y = tonumber(coords.y or coords[2]) or 0.0,
        z = tonumber(coords.z or coords[3]) or 0.0,
        w = tonumber(coords.w or coords[4]) or 0.0
    }
end

local function publicStages(stages)
    if type(stages) ~= 'table' or stages.enabled == false then return nil end
    local result = {}
    for key, coords in pairs(stages) do
        if key ~= 'enabled' and coords and (coords.x ~= nil or coords[1] ~= nil) then
            result[tostring(key)] = publicCoords(coords)
        end
    end
    return next(result) and result or nil
end

local function genericStation(stationId)
    local station = Config.Stations and Config.Stations[tostring(stationId)]
    if not station or station.enabled ~= true then return nil end
    station.id = tostring(stationId)
    return station
end

local function quantitySettings()
    return {
        max = math.max(1, math.floor(tonumber(Config.MaxCraftQuantity) or 20)),
        timeIncreasePercent = math.max(0, tonumber(Config.QuantityTimeIncreasePercent) or 0.12),
        maxDuration = math.max(1, math.floor(tonumber(Config.MaximumDuration) or 120))
    }
end

local function craftDuration(baseDuration, quantity)
    local settings = quantitySettings()
    local multiplier = 1 + math.max(0, quantity - 1) * settings.timeIncreasePercent
    return math.min(settings.maxDuration, math.ceil(baseDuration * multiplier))
end

local function normalizeRecipe(recipe)
    local ingredients = {}
    for _, ingredient in ipairs(type(recipe.ingredients) == 'table' and recipe.ingredients or {}) do
        ingredients[#ingredients + 1] = {
            item = tostring(ingredient.item or ''),
            label = tostring(ingredient.label or ingredient.item or 'Ingrediente'),
            amount = math.max(1, math.floor(tonumber(ingredient.amount) or 1)),
            count = tonumber(ingredient.count)
        }
    end
    local output = type(recipe.output) == 'table' and recipe.output or {
        item = recipe.output_item,
        label = recipe.name,
        amount = recipe.output_amount
    }
    local rawSteps = recipe.craftSteps or recipe.craft_steps or recipe.steps
    local stepKeys = {}
    for _, entry in ipairs(type(rawSteps) == 'table' and rawSteps or {}) do
        local key = tostring(type(entry) == 'table' and (entry.type or entry.key) or entry)
        if Config.Operations and Config.Operations[key] then
            stepKeys[#stepKeys + 1] = key
            if #stepKeys >= 8 then break end
        end
    end
    if #stepKeys == 0 then
        local category = string.lower(tostring(recipe.category or recipe.category_key or ''))
        local requestedProfile = string.lower(tostring(recipe.craftProfile or recipe.craft_profile or ''))
        local profileKey = requestedProfile ~= '' and requestedProfile
            or (Config.KitchenCategoryProfiles and Config.KitchenCategoryProfiles[category])
            or 'default'
        local profile = Config.KitchenProfiles and (Config.KitchenProfiles[profileKey] or Config.KitchenProfiles.default)
        for _, key in ipairs(type(profile) == 'table' and profile or { 'prep', 'chop', 'grill', 'assemble' }) do
            if Config.Operations and Config.Operations[key] then
                stepKeys[#stepKeys + 1] = key
                if #stepKeys >= 8 then break end
            end
        end
    end
    local steps = {}
    for _, key in ipairs(stepKeys) do
        local operation = Config.Operations[key]
        steps[#steps + 1] = {
            key = key,
            label = operation.label,
            description = operation.description,
            animation = operation.animation,
            stage = operation.stage
        }
    end
    local requestedDuration = math.floor(tonumber(recipe.duration or recipe.prep_time) or 5)
    local minimumStepDuration = math.max(0, tonumber(Config.MinimumStepDuration) or 0)
    local durationBySteps = math.ceil(#steps * minimumStepDuration)
    local duration = math.max(Config.MinimumDuration or 3, requestedDuration, durationBySteps)
    duration = math.min(Config.MaximumDuration or 120, duration)
    return {
        id = tostring(recipe.id or recipe.recipe_key or ''),
        key = tostring(recipe.key or recipe.recipe_key or recipe.id or ''),
        category = tostring(recipe.category or recipe.category_key or ''),
        name = tostring(recipe.name or 'Receita'),
        description = tostring(recipe.description or ''),
        image = tostring(recipe.image or ''),
        duration = duration,
        difficulty = math.max(0.2, math.min(0.75, tonumber(recipe.difficulty) or 0.52)),
        output = {
            item = tostring(output.item or ''),
            label = tostring(output.label or recipe.name or output.item or 'Resultado'),
            amount = math.max(1, math.floor(tonumber(output.amount) or 1))
        },
        visual = type(recipe.visual) == 'table' and recipe.visual or nil,
        ingredients = ingredients,
        steps = steps
    }
end

local function restaurantRecipeMatches(recipe, stationType)
    local restaurant = Config.Restaurant or {}
    local expected = restaurant.recipeStations and restaurant.recipeStations[tostring(recipe.key or '')]
    if not expected then expected = restaurant.categoryDefaults and restaurant.categoryDefaults[tostring(recipe.category or '')] end
    return expected == stationType
end

local function hydrateRecipes(src, recipes)
    local hydrated = {}
    for _, raw in ipairs(recipes or {}) do
        local recipe = normalizeRecipe(raw)
        local available = recipe.output.item ~= ''
        local maxQuantity = quantitySettings().max
        for _, ingredient in ipairs(recipe.ingredients) do
            ingredient.count = inventoryCount(src, ingredient.item)
            if ingredient.count < ingredient.amount then available = false end
            maxQuantity = math.min(maxQuantity, math.floor(ingredient.count / ingredient.amount))
        end
        recipe.maxQuantity = math.max(0, maxQuantity)
        recipe.available = available and canCarry(src, recipe.output.item, recipe.output.amount, nil)
        hydrated[#hydrated + 1] = recipe
    end
    return hydrated
end

local function buildGenericPayload(src, stationId)
    local station = genericStation(stationId)
    if not station then return { ok = false, error = 'station_not_found' } end
    if not canAccess(src, station) then return { ok = false, error = 'access_denied' } end
    if not nearCoords(src, station.coords) then return { ok = false, error = 'too_far' } end
    local kind = Config.Kinds[station.kind] or Config.Kinds.utility
    return {
        ok = true,
        station = {
            id = station.id,
            label = station.label,
            kind = station.kind or 'utility',
            animation = station.animation or station.kind or 'utility',
            heading = station.coords and (station.coords.w or station.coords[4]),
            coords = publicCoords(station.coords),
            stages = publicStages(station.stages)
        },
        kind = kind,
        quantity = quantitySettings(),
        recipes = hydrateRecipes(src, station.recipes)
    }
end

local function buildRestaurantPayload(src, context)
    local setup = Config.Restaurant or {}
    local pointType = setup.pointTypes and setup.pointTypes[tostring(context.stationType or '')]
    if not pointType then return { ok = false, error = 'station_not_found' } end
    local valid, validOk = callExport(setup.resource, 'ValidateCraftPoint', src, context.restaurantId, context.pointId, context.stationType)
    if not validOk or valid ~= true then return { ok = false, error = 'too_far' } end
    local catalog, catalogOk = callExport(setup.resource, 'GetCraftCatalog', src, context.restaurantId)
    if not catalogOk or type(catalog) ~= 'table' or catalog.ok ~= true then return catalog or { ok = false, error = 'provider_unavailable' } end
    local recipes = {}
    for _, recipe in ipairs(catalog.recipes or {}) do
        local normalized = normalizeRecipe(recipe)
        if restaurantRecipeMatches(normalized, context.stationType) then recipes[#recipes + 1] = normalized end
    end
    return {
        ok = true,
        station = {
            id = ('restaurant:%s:%s'):format(context.restaurantId, context.stationType),
            label = pointType.label,
            kind = pointType.kind,
            animation = pointType.animation,
            stages = publicStages(Config.RestaurantStages and Config.RestaurantStages[tostring(context.restaurantId)])
        },
        kind = Config.Kinds[pointType.kind] or Config.Kinds.kitchen,
        quantity = quantitySettings(),
        restaurant = { id = catalog.restaurant.id, label = catalog.restaurant.label },
        recipes = hydrateRecipes(src, recipes)
    }
end

local function buildPayload(src, context)
    if context.provider == 'restaurant' then return buildRestaurantPayload(src, context) end
    return buildGenericPayload(src, context.stationId)
end

local function findRecipe(payload, recipeId)
    for _, recipe in ipairs(payload.recipes or {}) do if tostring(recipe.id) == tostring(recipeId) then return recipe end end
end

local function completeGeneric(src, recipe, quantity)
    quantity = math.max(1, math.min(quantitySettings().max, math.floor(tonumber(quantity) or 1)))
    local outputAmount = recipe.output.amount * quantity
    if not canCarry(src, recipe.output.item, outputAmount, nil) then return { ok = false, error = 'inventory_full' } end
    for _, ingredient in ipairs(recipe.ingredients) do
        if inventoryCount(src, ingredient.item) < ingredient.amount * quantity then return { ok = false, error = 'missing_ingredient', item = ingredient.item } end
    end
    local removed = {}
    for _, ingredient in ipairs(recipe.ingredients) do
        local amount = ingredient.amount * quantity
        if not removeItem(src, ingredient.item, amount) then
            for _, rollback in ipairs(removed) do addItem(src, rollback.item, rollback.amount) end
            return { ok = false, error = 'inventory_changed', item = ingredient.item }
        end
        removed[#removed + 1] = { item = ingredient.item, amount = amount }
    end
    if not addItem(src, recipe.output.item, outputAmount, { craftedBy = getIdentity(src).citizenid, craftedAt = os.time() }) then
        for _, rollback in ipairs(removed) do addItem(src, rollback.item, rollback.amount) end
        return { ok = false, error = 'inventory_full' }
    end
    return { ok = true, item = recipe.output.item, amount = outputAmount, label = recipe.output.label }
end

local function hasConfiguredCraftPoint(station)
    return station and (station.coords or (type(station.stages) == 'table' and next(station.stages) ~= nil))
end

local function nearConfiguredCraftPoint(src, station)
    if station and station.coords and nearCoords(src, station.coords) then return true end
    for _, coords in pairs(station and station.stages or {}) do
        if nearCoords(src, coords) then return true end
    end
    return false
end

local handlers = {}

handlers.bootstrap = function(src, data)
    return buildPayload(src, type(data.context) == 'table' and data.context or {})
end

handlers.preview = function(src, data)
    if not isAdmin(src) then return { ok = false, error = 'access_denied' } end
    local key = tostring(data.kind or 'kitchen')
    local preview = Config.Preview[key] or Config.Preview.kitchen
    local recipes = {}
    for _, raw in ipairs(preview.recipes or {}) do
        local recipe = normalizeRecipe(raw)
        recipe.available = true
        recipes[#recipes + 1] = recipe
    end
    return { ok = true, preview = true, station = preview.station, kind = Config.Kinds[preview.station.kind] or Config.Kinds.kitchen, quantity = quantitySettings(), recipes = recipes }
end

handlers.begin = function(src, data)
    if activeCrafts[src] then return { ok = false, error = 'already_crafting' } end
    local context = type(data.context) == 'table' and data.context or {}
    local payload = buildPayload(src, context)
    if not payload.ok then return payload end
    local recipe = findRecipe(payload, data.recipeId)
    if not recipe then return { ok = false, error = 'recipe_not_found' } end
    if not recipe.available then return { ok = false, error = 'missing_ingredient' } end
    local quantity = math.max(1, math.min(quantitySettings().max, math.floor(tonumber(data.quantity) or 1)))
    if recipe.maxQuantity and quantity > recipe.maxQuantity then return { ok = false, error = 'missing_ingredient' } end
    for _, ingredient in ipairs(recipe.ingredients) do
        if inventoryCount(src, ingredient.item) < ingredient.amount * quantity then return { ok = false, error = 'missing_ingredient', item = ingredient.item } end
    end
    local outputAmount = recipe.output.amount * quantity
    if not canCarry(src, recipe.output.item, outputAmount, nil) then return { ok = false, error = 'inventory_full' } end
    local duration = craftDuration(recipe.duration, quantity)
    local token = ('%s:%s:%s'):format(src, GetGameTimer(), math.random(100000, 999999))
    activeCrafts[src] = { token = token, startedAt = GetGameTimer(), duration = duration * 1000, context = context, recipe = recipe, station = payload.station, quantity = quantity }
    local firstStep = recipe.steps and recipe.steps[1]
    local animationKey = firstStep and firstStep.animation or payload.station.animation
    return {
        ok = true,
        token = token,
        duration = duration,
        quantity = quantity,
        recipe = recipe,
        station = payload.station,
        animation = Config.Animations[animationKey] or Config.Animations.utility,
        heading = payload.station.heading
    }
end

handlers.complete = function(src, data)
    local craft = activeCrafts[src]
    if not craft or craft.token ~= data.token then return { ok = false, error = 'craft_not_found' } end
    if GetGameTimer() - craft.startedAt < craft.duration - 250 then return { ok = false, error = 'not_ready' } end
    local currentRecipe = craft.recipe
    if hasConfiguredCraftPoint(craft.station) then
        if not nearConfiguredCraftPoint(src, craft.station) then
            activeCrafts[src] = nil
            return { ok = false, error = 'too_far' }
        end
    else
        local payload = buildPayload(src, craft.context)
        currentRecipe = payload.ok and findRecipe(payload, craft.recipe.id) or nil
        if not payload.ok or not currentRecipe then
            activeCrafts[src] = nil
            return payload.ok and { ok = false, error = 'recipe_not_found' } or payload
        end
    end
    activeCrafts[src] = nil
    if craft.context.provider == 'restaurant' then
        local result, ok = callExport(Config.Restaurant.resource, 'CompleteCraftRecipe', src, craft.context.restaurantId, craft.recipe.id, craft.quantity)
        return ok and result or { ok = false, error = 'provider_unavailable' }
    end
    return completeGeneric(src, currentRecipe, craft.quantity)
end

handlers.cancel = function(src, data)
    local craft = activeCrafts[src]
    if craft and (not data.token or data.token == craft.token) then activeCrafts[src] = nil end
    return { ok = true }
end

RegisterNetEvent('ob_crafting:server:request', function(requestId, action, data)
    local src = source
    local handler = handlers[tostring(action or '')]
    if not handler then TriggerClientEvent('ob_crafting:client:response', src, requestId, { ok = false, error = 'unknown_action' }) return end
    local ok, result = pcall(handler, src, type(data) == 'table' and data or {})
    if not ok then
        print(('[ob_crafting] Erro em %s: %s'):format(tostring(action), result))
        result = { ok = false, error = 'server_error' }
    end
    TriggerClientEvent('ob_crafting:client:response', src, requestId, result or { ok = true })
end)

AddEventHandler('playerDropped', function() activeCrafts[source] = nil end)

exports('OpenStationForPlayer', function(src, stationId)
    TriggerClientEvent('ob_crafting:client:open', tonumber(src), tostring(stationId))
end)
