local isOpen = false
local currentContext = nil
local requestId = 0
local requests = {}
local targetZones = {}
local publicPoints = {}
local activeDisplayId = nil
local nextDisplayRefresh = 0
local craftingPointTypes = {
    cutting = true,
    stove = true,
    drinks = true,
    assembly = true
}

local restaurantProductAnimations = {
    food = {
        anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger' },
        prop = { model = `prop_cs_burger_01`, pos = vec3(0.02, 0.01, -0.02), rot = vec3(-70.0, 0.0, 0.0) }
    },
    drink = {
        anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
        prop = { model = `prop_ld_can_01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) }
    }
}

exports('useRestaurantProduct', function(data, slot)
    local metadata = type(slot) == 'table' and slot.metadata or nil
    if type(metadata) ~= 'table' or metadata.restaurantProduct ~= true then return end

    local productType = metadata.restaurantProductType == 'drink' and 'drink' or 'food'
    local presentation = restaurantProductAnimations[productType]
    local completed = exports.ox_lib:progressBar({
        duration = math.max(750, math.floor(tonumber((Config.RestaurantProduct or {}).useTime) or 2500)),
        label = ('%s %s'):format(productType == 'drink' and 'Bebendo' or 'Comendo', metadata.label or 'produto'),
        canCancel = true,
        disable = { car = true, combat = true },
        anim = presentation.anim,
        prop = presentation.prop
    })

    if completed then
        exports.ox_inventory:useItem(data, nil, true)
    end
end)

local function requestServer(action, payload, callback)
    requestId = requestId + 1
    requests[requestId] = callback
    TriggerServerEvent('ob_restaurantes:server:request', requestId, action, payload or {})
end

RegisterNetEvent('ob_restaurantes:client:response', function(token, payload)
    local callback = requests[tonumber(token)]
    if not callback then return end
    requests[tonumber(token)] = nil
    callback(payload or {})
end)

local function currentCoords()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    return { x = coords.x, y = coords.y, z = coords.z, h = GetEntityHeading(ped) }
end

local function closeInterface()
    if not isOpen then return end
    isOpen = false
    currentContext = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openInterface(mode, restaurantId, pointId)
    if isOpen then closeInterface() end
    requestServer('bootstrap', { mode = mode, restaurantId = restaurantId }, function(payload)
        if not payload.ok then
            SendNUIMessage({ action = 'feedback', type = 'error', code = payload.error })
            return
        end

        currentContext = { mode = mode, restaurantId = restaurantId, pointId = pointId }
        isOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open', payload = payload, context = currentContext })
    end)
end

exports('OpenRestaurant', openInterface)

RegisterNetEvent('ob_restaurantes:client:open', function(mode, restaurantId, pointId)
    openInterface(mode or 'pos', restaurantId, pointId)
end)

RegisterNetEvent('ob_restaurantes:client:openFromMagicPause', function(restaurantId)
    openInterface('admin', restaurantId, nil)
end)

RegisterNUICallback('close', function(_, cb)
    closeInterface()
    cb({ ok = true })
end)

RegisterNUICallback('request', function(body, cb)
    body = type(body) == 'table' and body or {}
    local action = tostring(body.action or '')
    local data = type(body.data) == 'table' and body.data or {}
    if action == '' then cb({ ok = false, error = 'unknown_action' }) return end

    if currentContext then
        data.restaurantId = data.restaurantId or currentContext.restaurantId
        if action == 'pay' then data.pointId = data.pointId or currentContext.pointId end
    end
    if action == 'savePoint' and type(data.point) == 'table' and data.point.useCurrent then
        data.point.coords = currentCoords()
        data.point.useCurrent = nil
    end

    requestServer(action, data, cb)
end)

local function removeTargets()
    for _, zoneId in ipairs(targetZones) do
        pcall(function() exports.ox_target:removeZone(zoneId) end)
    end
    targetZones = {}
end

local function registerTargets(payload)
    removeTargets()
    publicPoints = payload.points or {}
    local types = payload.types or {}
    for _, point in ipairs(publicPoints) do
        local pointType = types[point.type] or {}
        local coords = point.coords or {}
        if point.type ~= 'display' and coords.x and coords.y and coords.z then
            local captured = point
            local zoneId = exports.ox_target:addSphereZone({
                coords = vec3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0),
                radius = Config.InteractionDistance,
                debug = Config.Debug,
                options = {
                    {
                        name = ('ob_restaurant_%s_%s'):format(point.type, point.id),
                        label = point.label or pointType.label or 'Interagir',
                        icon = pointType.icon or 'fa-solid fa-utensils',
                        distance = Config.InteractionDistance + 0.5,
                        onSelect = function()
                            if craftingPointTypes[captured.type] and GetResourceState('ob_crafting') == 'started' then
                                local ok = pcall(function()
                                    exports.ob_crafting:OpenRestaurantStation(captured.type, captured.restaurant_id, captured.id)
                                end)
                                if ok then return end
                            end
                            openInterface(captured.type, captured.restaurant_id, captured.id)
                        end
                    }
                }
            })
            targetZones[#targetZones + 1] = zoneId
        end
    end
end

local function reloadPoints()
    requestServer('publicPoints', {}, function(payload)
        if payload.ok then registerTargets(payload) end
    end)
end

RegisterNetEvent('ob_restaurantes:client:reloadPoints', reloadPoints)

RegisterNetEvent('ob_restaurantes:client:update', function(restaurantId, action, payload)
    if currentContext and currentContext.restaurantId == restaurantId then
        SendNUIMessage({ action = 'serverUpdate', update = action, payload = payload or {} })
    end
    if activeDisplayId then nextDisplayRefresh = 0 end
end)

RegisterNetEvent('ob_restaurantes:client:serviceCall', function(payload)
    local coords = payload and payload.coords or {}
    if not coords.x or not coords.y or not coords.z then return end

    local message = ('%s (ID %s) solicitou atendimento.'):format(
        tostring(payload.callerName or 'Um cidadão'),
        tostring(payload.callerSource or '?')
    )
    pcall(function() exports.qbx_core:Notify(message, 'inform', 9000, tostring(payload.restaurantLabel or 'Estabelecimento')) end)

    local blip = AddBlipForCoord(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 27)
    SetBlipScale(blip, 0.9)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(('Chamado: %s'):format(tostring(payload.restaurantLabel or 'Estabelecimento')))
    EndTextCommandSetBlipName(blip)

    CreateThread(function()
        Wait(math.max(30, tonumber(payload.expiresIn) or 90) * 1000)
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)

RegisterNetEvent('ob_restaurantes:client:announcement', function(payload)
    if not Config.TTS.enabled then return end
    local points = payload and payload.points or {}
    if #points == 0 and not (payload and payload.coords and payload.coords.x) then return end
    if #points > 0 then
        local playerCoords = GetEntityCoords(PlayerPedId())
        local closeEnough = false
        for _, coords in ipairs(points) do
            local sourceCoords = vec3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
            if #(playerCoords - sourceCoords) <= (Config.TTS.maxDistance or 32.0) then
                closeEnough = true
                break
            end
        end
        if not closeEnough then return end
    elseif payload and payload.coords and payload.coords.x then
        local playerCoords = GetEntityCoords(PlayerPedId())
        local coords = payload.coords
        if #(playerCoords - vec3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)) > (Config.TTS.maxDistance or 32.0) then return end
    end
    if payload and payload.restaurantId then
        requestServer('display', { restaurantId = payload.restaurantId }, function(display)
            if display.ok then
                SendNUIMessage({ action = 'display', visible = display.visible == true, payload = display })
            end
        end)
    end
    SendNUIMessage({ action = 'announcement', payload = payload })
end)

RegisterCommand(Config.AdminCommand, function(_, args)
    openInterface('admin', args[1], nil)
end, false)

CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(500) end
    Wait(500)
    reloadPoints()
end)

CreateThread(function()
    while true do
        local wait = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local closest, closestDistance

        for _, point in ipairs(publicPoints) do
            if point.type == 'display' and point.coords and point.coords.x then
                local pointCoords = vec3(point.coords.x + 0.0, point.coords.y + 0.0, point.coords.z + 0.0)
                local distance = #(coords - pointCoords)
                if distance <= Config.DisplayRenderDistance and (not closestDistance or distance < closestDistance) then
                    closest, closestDistance = point, distance
                end
            end
        end

        if closest and not IsPauseMenuActive() and not IsEntityDead(ped) then
            wait = 250
            if activeDisplayId ~= closest.id then
                activeDisplayId = closest.id
                nextDisplayRefresh = 0
            end
            if GetGameTimer() >= nextDisplayRefresh then
                nextDisplayRefresh = GetGameTimer() + Config.DisplayRefreshMs
                requestServer('display', { restaurantId = closest.restaurant_id }, function(payload)
                    if activeDisplayId == closest.id and payload.ok then
                        SendNUIMessage({ action = 'display', visible = payload.visible == true, payload = payload })
                    end
                end)
            end
        elseif activeDisplayId then
            activeDisplayId = nil
            SendNUIMessage({ action = 'display', visible = false })
        end
        Wait(wait)
    end
end)

CreateThread(function()
    while true do
        if isOpen then
            local ped = PlayerPedId()
            if IsEntityDead(ped) or IsPauseMenuActive() then closeInterface() end
            Wait(250)
        else
            Wait(1000)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    removeTargets()
    SetNuiFocus(false, false)
end)
