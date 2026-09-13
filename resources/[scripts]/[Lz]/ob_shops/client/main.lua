local access = {}
local points = {}
local opening = false
local refreshQueued = false
local textUiOpen = false
local textUiPoint

local function notify(message)
    lib.notify({
        title = 'Loja',
        description = message,
        type = 'error',
    })
end

local function requestAccess(delay)
    if refreshQueued then return end
    refreshQueued = true
    CreateThread(function()
        Wait(delay or 0)
        refreshQueued = false
        TriggerServerEvent('ob_shops:server:requestAccess')
    end)
end

local function rebuildPoints()
    points = {}
    for shopId, grant in pairs(access) do
        local shop = Config.Shops and Config.Shops[shopId]
        if type(grant) == 'table' and type(grant.shopType) == 'string'
            and shop and shop.enabled == true then
            for index, coords in ipairs(shop.locations or {}) do
                if coords and coords.x and coords.y and coords.z then
                    points[#points + 1] = {
                        shopId = shopId,
                        shopType = grant.shopType,
                        shopIndex = index,
                        label = tostring(shop.label or 'Loja'),
                        coords = vec3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0),
                        drawDistance = math.max(1.0, tonumber(shop.drawDistance)
                            or tonumber(Config.Marker.drawDistance) or 10.0),
                        openDistance = math.max(0.5, tonumber(shop.openDistance)
                            or tonumber(Config.Marker.openDistance) or 1.8),
                    }
                end
            end
        end
    end
end

RegisterNetEvent('ob_shops:client:setAccess', function(grants)
    access = type(grants) == 'table' and grants or {}
    rebuildPoints()
end)

local function fallbackMarker(point)
    local marker = Config.Marker.fallback or {}
    local scale = marker.scale or vec3(0.28, 0.28, 0.28)
    local color = marker.color or {}
    DrawMarker(
        math.floor(tonumber(marker.type) or 2),
        point.coords.x, point.coords.y, point.coords.z + (tonumber(marker.zOffset) or 0.2),
        0.0, 0.0, 0.0,
        0.0, 0.0, marker.rotate == false and 0.0 or ((GetGameTimer() % 3600) / 10.0),
        scale.x, scale.y, scale.z,
        color.r or 164, color.g or 100, color.b or 205, color.a or 175,
        marker.bob ~= false, true, 2, marker.rotate ~= false, nil, nil, false
    )
end

local function drawShopMarker(point, distance)
    local markerResource = tostring(Config.Marker.resource or 'ob_markers')
    if GetResourceState(markerResource) == 'started' then
        local ok, drawn = pcall(function()
            return exports[markerResource]:Draw(Config.Marker.image or 'loja', point.coords, {
                distance = distance,
                drawDistance = math.min(point.drawDistance, 10.0),
                height = tonumber(Config.Marker.height) or 1.0,
                size = tonumber(Config.Marker.size) or 0.92,
            })
        end)
        if ok and drawn then return end
    end
    fallbackMarker(point)
end

local function hideShopTextUi()
    if not textUiOpen then return end

    lib.hideTextUI()
    textUiOpen = false
    textUiPoint = nil
end

local function showShopTextUi(point)
    local pointId = ('%s:%s'):format(point.shopId, point.shopIndex)
    if textUiOpen and textUiPoint == pointId then return end

    lib.showTextUI(('[E] Abrir %s'):format(point.label), {
        position = 'left-center',
        icon = 'store',
        iconColor = '#b47ad6',
    })

    textUiOpen = true
    textUiPoint = pointId
end

local function openShop(point)
    if opening then return end
    if GetResourceState('ox_inventory') ~= 'started' then
        notify('O sistema de inventario esta indisponivel no momento.')
        return
    end

    hideShopTextUi()
    opening = true
    local ok, result = pcall(function()
        return exports.ox_inventory:openInventory('shop', {
            type = point.shopType,
            id = point.shopIndex,
        })
    end)
    if not ok then
        notify('Nao foi possivel abrir esta loja agora.')
        if Config.Debug then print(('[ob_shops] Falha ao abrir %s: %s'):format(point.shopId, result)) end
    end
    SetTimeout(600, function() opening = false end)
end

CreateThread(function()
    requestAccess(500)
    while true do
        Wait(math.max(5000, math.floor(tonumber(Config.AccessRefreshMs) or 15000)))
        requestAccess()
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)
        local closest, closestDistance

        for index = 1, #points do
            local point = points[index]
            local distance = #(playerCoords - point.coords)
            if distance <= point.drawDistance then
                sleep = 0
                drawShopMarker(point, distance)
                if distance <= point.openDistance and (not closestDistance or distance < closestDistance) then
                    closest, closestDistance = point, distance
                end
            elseif distance <= point.drawDistance + 25.0 then
                sleep = math.min(sleep, 200)
            end
        end

        local inventoryOpen = LocalPlayer and LocalPlayer.state and LocalPlayer.state.invOpen

        if closest and not opening and not inventoryOpen and not IsPedDeadOrDying(ped, true) then
            showShopTextUi(closest)
            if IsControlJustReleased(0, Config.OpenControl or 38) then openShop(closest) end
        else
            hideShopTextUi()
        end

        Wait(sleep)
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() requestAccess(500) end)
RegisterNetEvent('QBCore:Player:SetPlayerData', function() requestAccess(150) end)
RegisterNetEvent('classeSelector:classChanged', function() requestAccess(150) end)
RegisterNetEvent('classeSelector:classChosenSuccess', function() requestAccess(150) end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'ox_inventory' or resource == 'qbx_core' then requestAccess(750) end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then hideShopTextUi() end
end)

exports('OpenShop', function(shopId, locationIndex)
    shopId = tostring(shopId or '')
    locationIndex = math.floor(tonumber(locationIndex) or 1)
    for index = 1, #points do
        local point = points[index]
        if point.shopId == shopId and point.shopIndex == locationIndex then
            openShop(point)
            return true
        end
    end
    return false
end)
