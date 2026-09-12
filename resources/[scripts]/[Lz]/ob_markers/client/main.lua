local textureDictionary = 'ob_interaction_markers'
local textureFiles = {
    loja = 'web/markers/loja.png',
    concessionaria = 'web/markers/concessionaria.png',
    banco = 'web/markers/banco.png',
    bancada = 'web/markers/bancada.png',
    ammunation = 'web/markers/ammunation.png',
    bau = 'web/markers/bau.png',
    garagem = 'web/markers/garagem.png',
}

local runtimeDictionary = CreateRuntimeTxd(textureDictionary)
local textures = {}
local retryAt = {}
local mapBlips = {}
local imageMarkers = {}
local requestedDictionaries = {}

local function categoryFor(id)
    local category = Config.BlipCategories and Config.BlipCategories[id]
    if type(category) == 'string' then
        return { label = category, enabled = true, prefix = true }
    end
    return category
end

local function mapBlipLabel(entry, category)
    local name = tostring(entry.name or entry.label or 'Local')
    if not category or category.prefix == false or not category.label then return name end
    return ('%s: %s'):format(category.label, name)
end

local function requestBlipDictionary(name)
    name = type(name) == 'string' and name:gsub('%.ytd$', '') or nil
    if not name or name == '' or requestedDictionaries[name] then return end
    requestedDictionaries[name] = true
    RequestStreamedTextureDict(name, false)
end

local function removeMapBlips()
    for index = #mapBlips, 1, -1 do
        local blip = mapBlips[index]
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        mapBlips[index] = nil
    end
end

local function createMapBlip(entry)
    if type(entry) ~= 'table' or entry.enabled == false then return nil end

    local category = categoryFor(entry.category)
    if entry.category and not category then return nil end
    if category and category.enabled == false then return nil end

    local coords = entry.coords
    if not coords or not coords.x or not coords.y or not coords.z then return nil end

    requestBlipDictionary(entry.ytd or entry.textureDictionary)

    local blip = AddBlipForCoord(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    if not blip or blip == 0 then return nil end

    SetBlipSprite(blip, math.floor(tonumber(entry.sprite) or 1))
    SetBlipDisplay(blip, math.floor(tonumber(entry.display) or 4))
    SetBlipScale(blip, tonumber(entry.scale) or 0.75)
    SetBlipAsShortRange(blip, entry.shortRange ~= false)

    if entry.color ~= nil then SetBlipColour(blip, math.floor(tonumber(entry.color) or 0)) end
    if entry.alpha ~= nil then SetBlipAlpha(blip, math.max(0, math.min(255, math.floor(tonumber(entry.alpha) or 255)))) end
    if entry.priority ~= nil then SetBlipPriority(blip, math.floor(tonumber(entry.priority) or 0)) end
    if entry.rotation ~= nil then SetBlipRotation(blip, math.floor(tonumber(entry.rotation) or 0)) end
    if entry.route == true then
        SetBlipRoute(blip, true)
        if entry.routeColor ~= nil then SetBlipRouteColour(blip, math.floor(tonumber(entry.routeColor) or 0)) end
    end

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(mapBlipLabel(entry, category))
    EndTextCommandSetBlipName(blip)

    mapBlips[#mapBlips + 1] = blip
    return blip
end

local function reloadMapBlips()
    removeMapBlips()
    for _, entry in ipairs(Config.Blips or {}) do createMapBlip(entry) end
    return #mapBlips
end

local function loadTexture(name)
    if textures[name] then return true end
    if not textureFiles[name] or GetGameTimer() < (retryAt[name] or 0) then return false end

    local ok, handle = pcall(
        CreateRuntimeTextureFromImage,
        runtimeDictionary,
        name,
        textureFiles[name]
    )

    if ok and handle and handle ~= 0 then
        textures[name] = handle
        return true
    end

    retryAt[name] = GetGameTimer() + 3000
    return false
end

local function draw(name, coords, options)
    name = tostring(name or ''):lower()
    if not textureFiles[name] or not coords then return false end
    if not loadTexture(name) then return false end

    options = options or {}
    local worldCoords = vec3(coords.x, coords.y, coords.z)
    local distance = tonumber(options.distance) or #(GetEntityCoords(PlayerPedId()) - worldCoords)
    local drawDistance = math.min(tonumber(options.drawDistance) or 10.0, 10.0)
    if distance > drawDistance then return false end

    local height = tonumber(options.height) or 1.0
    local size = tonumber(options.size) or 0.92
    local markerCoords = vec3(worldCoords.x, worldCoords.y, worldCoords.z + height)
    local cameraDistance = #(GetGameplayCamCoord() - markerCoords)
    local screenWidth, screenHeight = GetActiveScreenResolution()
    local aspectRatio = screenHeight > 0 and (screenWidth / screenHeight) or 1.7778
    local width = math.min(0.13, (size * 0.52) / math.max(cameraDistance, 2.5))
    local visibility = math.max(0.0, math.min(1.0, (drawDistance - distance) / 4.0))
    local alpha = math.floor(72 + visibility * 183)

    SetDrawOrigin(markerCoords.x, markerCoords.y, markerCoords.z, 0)
    DrawSprite(textureDictionary, name, 0.0, 0.0, width, width * aspectRatio, 0.0, 255, 255, 255, alpha)
    ClearDrawOrigin()
    return true
end

local function reloadImageMarkers()
    imageMarkers = {}
    local defaults = Config.MarkerDefaults or {}

    for _, entry in ipairs(Config.Markers or {}) do
        local coords = entry.coords
        local image = tostring(entry.image or entry.type or ''):lower()
        if entry.enabled ~= false and textureFiles[image]
            and coords and coords.x and coords.y and coords.z then
            imageMarkers[#imageMarkers + 1] = {
                image = image,
                coords = vec3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0),
                drawDistance = math.min(
                    tonumber(entry.drawDistance) or tonumber(defaults.drawDistance) or 10.0,
                    10.0
                ),
                height = tonumber(entry.height) or tonumber(defaults.height) or 1.0,
                size = tonumber(entry.size) or tonumber(defaults.size) or 0.92,
            }
        end
    end

    return #imageMarkers
end

exports('Draw', draw)
exports('ReloadBlips', reloadMapBlips)
exports('ReloadMarkers', reloadImageMarkers)
exports('CreateBlip', createMapBlip)

CreateThread(function()
    reloadMapBlips()
    reloadImageMarkers()

    while true do
        local waitDuration = 1000
        if #imageMarkers > 0 then
            local playerCoords = GetEntityCoords(PlayerPedId())

            for index = 1, #imageMarkers do
                local marker = imageMarkers[index]
                local distance = #(playerCoords - marker.coords)
                if distance <= marker.drawDistance then
                    waitDuration = 0
                    draw(marker.image, marker.coords, {
                        distance = distance,
                        drawDistance = marker.drawDistance,
                        height = marker.height,
                        size = marker.size,
                    })
                elseif distance <= marker.drawDistance + 20.0 then
                    waitDuration = math.min(waitDuration, 150)
                end
            end
        end

        Wait(waitDuration)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then removeMapBlips() end
end)
