local starterVehicleLocks = {}
local tutorialProgressReady = false

math.randomseed(os.time())

local function ensureTutorialProgressTable()
    if tutorialProgressReady then return true end

    local ok, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS ob_initial_tutorial_progress (
                identifier VARCHAR(96) NOT NULL,
                completed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (identifier)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]])
    end)

    if not ok then
        print(('[ob_initial] Falha ao preparar o progresso do tutorial: %s'):format(tostring(err)))
        return false
    end

    tutorialProgressReady = true
    return true
end

local function tutorialIdentifier(source)
    return GetPlayerIdentifierByType(source, 'license') or GetPlayerIdentifier(source, 0)
end

local function usesLicenseProgress()
    return ((Config.Tutorial or {}).progressScope or 'license') ~= 'character'
end

local function setLicenseTutorialCompleted(source, completed)
    local identifier = tutorialIdentifier(source)
    if not identifier or not ensureTutorialProgressTable() then return false end

    if completed then
        MySQL.query.await([[
            INSERT INTO ob_initial_tutorial_progress (identifier)
            VALUES (?)
            ON DUPLICATE KEY UPDATE completed_at = CURRENT_TIMESTAMP
        ]], { identifier })
    else
        MySQL.query.await('DELETE FROM ob_initial_tutorial_progress WHERE identifier = ?', { identifier })
    end

    return true
end

local function hasCompletedTutorial(source)
    local tutorial = Config.Tutorial or {}
    local metadataKey = tutorial.metadataKey or 'ob_initial_completed'
    local player = exports.qbx_core:GetPlayer(source)

    if not usesLicenseProgress() then
        return player ~= nil and exports.qbx_core:GetMetadata(source, metadataKey) == true
    end

    local identifier = tutorialIdentifier(source)
    if not identifier or not ensureTutorialProgressTable() then return false end

    local completed = MySQL.scalar.await(
        'SELECT 1 FROM ob_initial_tutorial_progress WHERE identifier = ? LIMIT 1',
        { identifier }
    ) ~= nil

    if not completed and player and exports.qbx_core:GetMetadata(source, metadataKey) == true then
        completed = setLicenseTutorialCompleted(source, true)
    end

    return completed
end

local function starterVehicleConfig()
    return Config.Guide and Config.Guide.starterVehicle or {}
end

local function normalizeVehicleModel(value)
    return tostring(value or ''):lower():gsub('%s+', '')
end

local function findCatalogVehicle(vehicles, configuredModel)
    local normalizedModel = normalizeVehicleModel(configuredModel)
    local vehicle = vehicles[configuredModel] or vehicles[normalizedModel]
    if vehicle then
        return vehicles[configuredModel] and configuredModel or normalizedModel, vehicle
    end

    for key, definition in pairs(vehicles) do
        if normalizeVehicleModel(key) == normalizedModel
            or normalizeVehicleModel(definition.model) == normalizedModel then
            return key, definition
        end
    end
end

local function generateStarterPlate(prefix)
    prefix = tostring(prefix or 'OB'):upper():gsub('[^A-Z0-9]', ''):sub(1, 2)
    if prefix == '' then prefix = 'OB' end

    for _ = 1, 40 do
        local plate = ('%s%06d'):format(prefix, math.random(0, 999999)):sub(1, 8)
        if not MySQL.scalar.await('SELECT id FROM player_vehicles WHERE plate = ? LIMIT 1', { plate }) then
            return plate
        end
    end

    return ('%s%06d'):format(prefix, os.time() % 1000000):sub(1, 8)
end

local function validateStarterGarage(garageName)
    if GetResourceState('qbx_garages') ~= 'started' then
        return false, 'A garagem ainda não está disponível.'
    end

    local ok, garages = pcall(function()
        return exports.qbx_garages:GetGarages()
    end)

    if not ok or type(garages) ~= 'table' or not garages[garageName] then
        return false, ('A garagem "%s" não foi encontrada.'):format(garageName)
    end

    return true
end

local function createStarterVehicle(source)
    local cfg = starterVehicleConfig()
    if cfg.enabled == false then return false, 'O veículo inicial está desativado.' end

    local player = exports.qbx_core:GetPlayer(source)
    local data = player and player.PlayerData
    if not data then return false, 'Seu personagem Qbox não foi encontrado.' end

    local metadataKey = cfg.metadataKey or 'ob_initial_starter_vehicle'
    if cfg.once ~= false and exports.qbx_core:GetMetadata(source, metadataKey) == true then
        return true, 'Seu veículo inicial já está registrado na garagem.', true
    end

    local garageName = tostring(cfg.garage or 'motelgarage')
    local garageOk, garageError = validateStarterGarage(garageName)
    if not garageOk then return false, garageError end

    local configuredModel = tostring(cfg.model or 'blista')
    local ok, vehicles = pcall(function()
        return exports.qbx_core:GetVehiclesByName()
    end)
    if not ok or type(vehicles) ~= 'table' then
        return false, 'O catálogo de veículos do Qbox não está disponível.'
    end

    local model, vehicleDefinition = findCatalogVehicle(vehicles, configuredModel)
    if not model or not vehicleDefinition then
        return false, ('O veículo "%s" não está no catálogo do Qbox.'):format(configuredModel)
    end

    local citizenId = tostring(data.citizenid or '')
    local license = data.license or GetPlayerIdentifierByType(source, 'license') or GetPlayerIdentifier(source, 0)
    if citizenId == '' or not license then return false, 'Não foi possível identificar seu personagem.' end

    local plate = generateStarterPlate(cfg.platePrefix)
    local hash = vehicleDefinition.hash or joaat(vehicleDefinition.model or configuredModel)
    local properties = {
        model = hash,
        plate = plate,
        fuelLevel = 100.0,
        engineHealth = 1000.0,
        bodyHealth = 1000.0,
        dirtLevel = 0.0,
    }

    local vehicleId = MySQL.insert.await([[INSERT INTO player_vehicles
        (license, citizenid, vehicle, hash, mods, plate, garage, fuel, engine, body, state)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        tostring(license), citizenId, model, hash, json.encode(properties), plate,
        garageName, 100, 1000, 1000, 1,
    })

    if not vehicleId then return false, 'Não foi possível registrar o veículo na garagem.' end

    exports.qbx_core:SetMetadata(source, metadataKey, true)
    exports.qbx_core:Save(source)
    return true, ('Seu %s foi enviado para a garagem.'):format(vehicleDefinition.name or model), false
end

lib.callback.register('ob_initial:server:shouldOpen', function(source)
    local tutorial = Config.Tutorial or {}
    if tutorial.enabled == false then return false end
    if tutorial.openOnce == false then return true end
    return not hasCompletedTutorial(source)
end)

lib.callback.register('ob_initial:server:claimStarterVehicle', function(source)
    local guide = Config.Guide or {}
    local ped = GetPlayerPed(source)
    if ped <= 0 or not guide.coords then
        return { ok = false, message = 'Não foi possível localizar Edward.' }
    end

    local playerCoords = GetEntityCoords(ped)
    local guideCoords = vec3(guide.coords.x, guide.coords.y, guide.coords.z)
    local claimDistance = (tonumber(guide.interactionDistance) or 2.2) + 3.0
    if #(playerCoords - guideCoords) > claimDistance then
        return { ok = false, message = 'Aproxime-se de Edward para receber o veículo.' }
    end

    if starterVehicleLocks[source] then
        return { ok = false, message = 'O registro do veículo já está em andamento.' }
    end

    starterVehicleLocks[source] = true
    local callOk, success, message, alreadyClaimed = pcall(createStarterVehicle, source)
    starterVehicleLocks[source] = nil

    if not callOk then
        print(('[ob_initial] Falha ao registrar veículo inicial para %s: %s'):format(source, tostring(success)))
        return { ok = false, message = 'Não foi possível concluir o registro agora.' }
    end

    return {
        ok = success == true,
        message = tostring(message or ''),
        alreadyClaimed = alreadyClaimed == true,
    }
end)

AddEventHandler('playerDropped', function()
    starterVehicleLocks[source] = nil
end)

local function completeTutorial(source)
    local player = exports.qbx_core:GetPlayer(source)
    local metadataKey = (Config.Tutorial and Config.Tutorial.metadataKey) or 'ob_initial_completed'
    local completed = true

    if usesLicenseProgress() then
        completed = setLicenseTutorialCompleted(source, true)
    elseif not player then
        completed = false
    end

    if player then
        exports.qbx_core:SetMetadata(source, metadataKey, true)
        exports.qbx_core:Save(source)
    end

    return completed
end

RegisterNetEvent('ob_initial:server:completeTutorial', function()
    completeTutorial(source)
end)

lib.callback.register('ob_initial:server:completeTutorial', function(source)
    return completeTutorial(source)
end)

exports('HasCompletedTutorial', function(source)
    return hasCompletedTutorial(source)
end)

exports('ResetTutorial', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    local metadataKey = (Config.Tutorial and Config.Tutorial.metadataKey) or 'ob_initial_completed'
    local reset = true

    if usesLicenseProgress() then
        reset = setLicenseTutorialCompleted(source, false)
    end

    if player then
        exports.qbx_core:SetMetadata(source, metadataKey, false)
        exports.qbx_core:Save(source)
    end

    return reset
end)

MySQL.ready(ensureTutorialProgressTable)
