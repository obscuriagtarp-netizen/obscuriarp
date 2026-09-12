local logger = require '@qbx_core.modules.logger'

assert(lib.checkDependency('qbx_core', '1.19.0', true))
assert(lib.checkDependency('qbx_vehicles', '1.3.1', true))
lib.versionCheck('Qbox-project/qbx_garages')

---@class ErrorResult
---@field code string
---@field message string

---@class PlayerVehicle
---@field id number
---@field citizenid? string
---@field modelName string
---@field garage string
---@field state VehicleState
---@field depotPrice integer
---@field props table ox_lib properties table

Config = require 'config.server'
VEHICLES = exports.qbx_core:GetVehiclesByName()
Storage = require 'server.storage'
---@type table<string, GarageConfig>
Garages = Config.garages
local previewPlayers = {}

lib.callback.register('qbx_garages:server:getGarages', function()
    return Garages
end)

---Returns garages for use server side.
local function getGarages()
    return Garages
end
exports('GetGarages', getGarages)

---@param name string
---@param config GarageConfig
local function registerGarage(name, config)
    Garages[name] = config
    TriggerClientEvent('qbx_garages:client:garageRegistered', -1, name, config)
    TriggerEvent('qbx_garages:server:garageRegistered', name, config)
end

exports('RegisterGarage', registerGarage)

---Sets the vehicle's garage. It is the caller's responsibility to make sure the vehicle is not currently spawned in the world, or else this may have no effect.
---@param vehicleId integer
---@param garageName string
---@return boolean success, ErrorResult?
local function setVehicleGarage(vehicleId, garageName)
    local garage = Garages[garageName]
    if not garage then
        return false, {
            code = 'not_found',
            message = string.format('garage name %s not found. Did you forget to register it?', garageName)
        }
    end

    local state = garage.type == GarageType.DEPOT and VehicleState.IMPOUNDED or VehicleState.GARAGED
    local numRowsAffected = Storage.setVehicleGarage(vehicleId, garageName, state)
    if numRowsAffected == 0 then
        return false, {
            code = 'no_rows_changed',
            message = string.format('no rows were changed for vehicleId=%s', vehicleId)
        }
    end
    return true
end

exports('SetVehicleGarage', setVehicleGarage)

---Sets the vehicle's price for retrieval at a depot. Only affects vehicles that are OUT or IMPOUNDED.
---@param vehicleId integer
---@param depotPrice integer
---@return boolean success, ErrorResult?
local function setVehicleDepotPrice(vehicleId, depotPrice)
    local numRowsAffected = Storage.setVehicleDepotPrice(vehicleId, depotPrice)
    if numRowsAffected == 0 then
        return false, {
            code = 'no_rows_changed',
            message = string.format('no rows were changed for vehicleId=%s', vehicleId)
        }
    end
    return true
end

exports('SetVehicleDepotPrice', setVehicleDepotPrice)

function FindPlateOnServer(plate)
    local vehicles = GetAllVehicles()
    for i = 1, #vehicles do
        if plate == GetVehicleNumberPlateText(vehicles[i]) then
            return true
        end
    end
end

---@param garage string
---@return GarageType?
function GetGarageType(garage)
    return Garages[garage]?.type
end

---@class PlayerVehiclesFilters
---@field citizenid? string
---@field states? VehicleState|VehicleState[]
---@field garage? string

---@param source number
---@param garageName string
---@return PlayerVehiclesFilters
function GetPlayerVehicleFilter(source, garageName)
    local player = exports.qbx_core:GetPlayer(source)
    local garage = Garages[garageName]
    local filter = {}
    local retrieveFromSameType = Config.retrieveFromAnyGarageOfSameType == true
        and garage.type ~= GarageType.DEPOT
        and not garage.shared

    filter.citizenid = not garage.shared and player.PlayerData.citizenid or nil
    filter.states = garage.states or VehicleState.GARAGED
    filter.garage = not garage.skipGarageCheck and not retrieveFromSameType and garageName or nil
    return filter
end

---@param source number
---@param garageName string
---@return GarageConfig?
function TryGetGarage(source, garageName)
    local garage = Garages[garageName]
    if garage then return garage end

    logger.log({
        source = source,
        event = 'error',
        message = string.format(
            'Attempted to spawn a vehicle from a non-existent garage: %s',
            garageName
        ),
        webhook = Config.logging.webhook.error,
        color = 'red'
    })
end

function getCanAccessGarage(player, garage)
    if not player or not garage then return false end
    if garage.groups and not exports.qbx_core:HasPrimaryGroup(player.PlayerData.source, garage.groups) then
        return false
    end
    if garage.classes then
        local metadata = player.PlayerData.metadata or {}
        local classId = tostring(metadata.classe or metadata.class or ''):lower()
        local allowed = garage.classes
        if type(allowed) == 'string' then
            allowed = { [allowed:lower()] = true }
        elseif type(allowed) == 'table' and #allowed > 0 then
            local normalized = {}
            for i = 1, #allowed do normalized[tostring(allowed[i]):lower()] = true end
            allowed = normalized
        end
        if not allowed[classId] then return false end
    end
    if garage.canAccess ~= nil and not garage.canAccess(player.PlayerData.source) then
        return false
    end
    return true
end

lib.callback.register('qbx_garages:server:enterPreview', function(source, garageName)
    local player = exports.qbx_core:GetPlayer(source)
    local garage = Garages[garageName]
    if not getCanAccessGarage(player, garage) then return false end

    if previewPlayers[source] == nil then
        previewPlayers[source] = GetPlayerRoutingBucket(source)
    end

    local bucket = (tonumber(Config.previewBucketBase) or 42000) + source
    SetRoutingBucketPopulationEnabled(bucket, false)
    SetPlayerRoutingBucket(source, bucket)
    return true
end)

lib.callback.register('qbx_garages:server:exitPreview', function(source)
    local previousBucket = previewPlayers[source]
    if previousBucket == nil then return true end

    SetPlayerRoutingBucket(source, previousBucket)
    previewPlayers[source] = nil
    return true
end)

function MatchesGarageVehicle(vehicle, garage)
    if garage.allowedModels then
        local allowed = {}
        for i = 1, #garage.allowedModels do allowed[tostring(garage.allowedModels[i]):lower()] = true end
        if not allowed[tostring(vehicle.modelName):lower()] then return false end
    end
    if garage.allowedVehicleClasses then
        local definition = VEHICLES[vehicle.modelName] or {}
        local classId = definition.class or definition.vehicleClass
        local allowed = garage.allowedVehicleClasses
        if type(allowed) == 'table' and #allowed > 0 then
            local normalized = {}
            for i = 1, #allowed do normalized[tostring(allowed[i])] = true end
            allowed = normalized
        end
        if not allowed[tostring(classId)] then return false end
    end
    return true
end

---@param playerVehicle PlayerVehicle
---@return VehicleType
function GetPlayerVehicleType(playerVehicle)
    local definition = VEHICLES[playerVehicle.modelName] or {}
    if definition.category == 'helicopters' or definition.category == 'planes' then
        return VehicleType.AIR
    elseif definition.category == 'boats' then
        return VehicleType.SEA
    else
        return VehicleType.CAR
    end
end

function IsGarageVehicleTypeAllowed(garage, vehicleType)
    if garage.vehicleType == VehicleType.ALL then return true end
    if Config.universalGarages and garage.vehicleType == VehicleType.CAR then return true end
    return garage.vehicleType == vehicleType
end

function IsPlayerVehicleAllowedInGarage(playerVehicle, garage)
    return IsGarageVehicleTypeAllowed(garage, GetPlayerVehicleType(playerVehicle))
        and MatchesGarageVehicle(playerVehicle, garage)
end

---@param source number
---@param garageName string
---@return PlayerVehicle[]?
lib.callback.register('qbx_garages:server:getGarageVehicles', function(source, garageName)
    local player = exports.qbx_core:GetPlayer(source)
    local garage = TryGetGarage(source, garageName)
    if not garage then return end
    if not getCanAccessGarage(player, garage) then return end
    local filter = GetPlayerVehicleFilter(source, garageName)
    local playerVehicles = exports.qbx_vehicles:GetPlayerVehicles(filter) or {}
    local toSend = {}
    if not playerVehicles[1] and not garage.fixedVehicles then return end

    for _, vehicle in pairs(playerVehicles) do
        if not FindPlateOnServer(vehicle.props.plate) then
            if IsPlayerVehicleAllowedInGarage(vehicle, garage) then
                OverrideFreeDepotPriceForOutVehicle(vehicle)
                toSend[#toSend + 1] = vehicle
            end
        end
    end
    if garage.fixedVehicles then
        for index, fixedVehicle in ipairs(garage.fixedVehicles) do
            local modelName = tostring(fixedVehicle.model or ''):lower()
            if modelName ~= '' and VEHICLES[modelName] then
                toSend[#toSend + 1] = {
                    id = ('fixed:%s:%s'):format(garageName, index),
                    modelName = modelName,
                    garage = garageName,
                    state = VehicleState.GARAGED,
                    fixed = true,
                    fixedIndex = index,
                    props = fixedVehicle.props or { model = joaat(modelName), plate = fixedVehicle.plate or 'SERVICO' },
                    label = fixedVehicle.label,
                }
            end
        end
    end
    return toSend
end)

---@param source number
---@param vehicleId string
---@param garageName string
---@return boolean
local function isParkable(source, vehicleId, garageName)
    local garageType = GetGarageType(garageName)
    --- DEPOTS are only for retrieving, not storing
    if garageType == GarageType.DEPOT then return false end
    if not vehicleId then return false end
    local player = exports.qbx_core:GetPlayer(source)
    local garage = Garages[garageName]
    if not getCanAccessGarage(player, garage) then
        return false
    end
    ---@type PlayerVehicle
    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)
    if not IsGarageVehicleTypeAllowed(garage, GetPlayerVehicleType(playerVehicle)) then
        return false
    end
    if not garage.shared then
        if playerVehicle.citizenid ~= player.PlayerData.citizenid then
            return false
        end
    end
    return true
end

lib.callback.register('qbx_garages:server:isParkable', function(source, garage, netId)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local vehicleId = Entity(vehicle).state.vehicleid or exports.qbx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(vehicle))
    return isParkable(source, vehicleId, garage)
end)

---@param source number
---@param netId number
---@param props table ox_lib vehicle props https://github.com/communityox/ox_lib/blob/master/resource/vehicleProperties/client.lua#L3
---@param garage string
lib.callback.register('qbx_garages:server:parkVehicle', function(source, netId, props, garage)
    assert(Garages[garage] ~= nil, string.format('Garage %s not found. Did you register this garage?', garage))
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local vehicleId = Entity(vehicle).state.vehicleid or exports.qbx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(vehicle))
    local owned = isParkable(source, vehicleId, garage) --Check ownership
    if not owned then
        exports.qbx_core:Notify(source, locale('error.not_owned'), 'error')
        return
    end

    exports.qbx_vehicles:SaveVehicle(vehicle, {
        garage = garage,
        state = VehicleState.GARAGED,
        props = props
    })

    exports.qbx_core:DeleteVehicle(vehicle)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    Wait(100)
    if Config.autoRespawn then
        Storage.moveOutVehiclesIntoGarages()
    end
end)

AddEventHandler('playerDropped', function()
    previewPlayers[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    for playerSource, previousBucket in pairs(previewPlayers) do
        if GetPlayerPing(playerSource) > 0 then
            SetPlayerRoutingBucket(playerSource, previousBucket)
        end
    end
end)
