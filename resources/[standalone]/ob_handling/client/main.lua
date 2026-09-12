local handlingClass = 'CHandlingData'
local vehicleRules = {}
local appliedVehicles = {}

local function debugPrint(message)
    if Config.Debug then
        print(('[ob_handling] %s'):format(message))
    end
end

local function buildVehicleRules()
    vehicleRules = {}

    for modelName, settings in pairs(Config.Vehicles or {}) do
        if settings.enabled ~= false then
            local modelHash = joaat(modelName)
            vehicleRules[modelHash] = {
                model = modelName,
                label = settings.label or modelName,
                multiply = settings.multiply or {},
                set = settings.set or {}
            }

            for field in pairs(settings.multiply or {}) do
                if settings.set and settings.set[field] ~= nil then
                    print(('[ob_handling] Campo duplicado em %s: %s. O valor de set tera prioridade.'):format(modelName, field))
                end
            end
        end
    end
end

local function rememberOriginal(state, vehicle, field)
    if state.original[field] == nil then
        state.original[field] = GetVehicleHandlingFloat(vehicle, handlingClass, field)
    end
end

local function restoreVehicle(vehicle)
    local state = appliedVehicles[vehicle]
    if not state then return false end

    if DoesEntityExist(vehicle) and GetEntityModel(vehicle) == state.modelHash then
        for field, value in pairs(state.original) do
            SetVehicleHandlingFloat(vehicle, handlingClass, field, value)
        end
    end

    appliedVehicles[vehicle] = nil
    debugPrint(('Handling original restaurada no veiculo %s.'):format(vehicle))
    return true
end

local function applyVehicle(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end

    local modelHash = GetEntityModel(vehicle)
    local rule = vehicleRules[modelHash]
    if not rule then return false end

    local previous = appliedVehicles[vehicle]
    if previous and previous.modelHash == modelHash then return true end
    if previous then restoreVehicle(vehicle) end

    local state = {
        modelHash = modelHash,
        original = {}
    }

    appliedVehicles[vehicle] = state

    for field, multiplier in pairs(rule.multiply) do
        if type(multiplier) == 'number' then
            rememberOriginal(state, vehicle, field)
            SetVehicleHandlingFloat(
                vehicle,
                handlingClass,
                field,
                state.original[field] * multiplier
            )
        else
            print(('[ob_handling] Multiplicador invalido em %s.%s.'):format(rule.model, field))
        end
    end

    for field, value in pairs(rule.set) do
        if type(value) == 'number' then
            rememberOriginal(state, vehicle, field)
            SetVehicleHandlingFloat(vehicle, handlingClass, field, value)
        else
            print(('[ob_handling] Valor absoluto invalido em %s.%s.'):format(rule.model, field))
        end
    end

    debugPrint(('%s aplicado ao veiculo %s.'):format(rule.label, vehicle))
    return true
end

local function refreshVehicle(vehicle)
    restoreVehicle(vehicle)
    return applyVehicle(vehicle)
end

local function cleanupDeletedVehicles()
    for vehicle, state in pairs(appliedVehicles) do
        if not DoesEntityExist(vehicle) or GetEntityModel(vehicle) ~= state.modelHash then
            appliedVehicles[vehicle] = nil
        end
    end
end

buildVehicleRules()

CreateThread(function()
    local previousVehicle = 0

    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and vehicle ~= previousVehicle then
            applyVehicle(vehicle)
        end

        previousVehicle = vehicle
        Wait(Config.CurrentVehicleInterval or 400)
    end
end)

CreateThread(function()
    while true do
        cleanupDeletedVehicles()

        for _, vehicle in ipairs(GetGamePool('CVehicle')) do
            if vehicleRules[GetEntityModel(vehicle)] then
                applyVehicle(vehicle)
            end
        end

        Wait(Config.ScanInterval or 2500)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() or not Config.RestoreOnStop then return end

    local vehicles = {}
    for vehicle in pairs(appliedVehicles) do
        vehicles[#vehicles + 1] = vehicle
    end

    for i = 1, #vehicles do
        restoreVehicle(vehicles[i])
    end
end)

exports('ApplyVehicleHandling', applyVehicle)
exports('RestoreVehicleHandling', restoreVehicle)
exports('RefreshVehicleHandling', refreshVehicle)
