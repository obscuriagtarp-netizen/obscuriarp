if Config.Garage ~= 'RxGarages' then
    return
end

local function getTableName()
    return Config.Framework == 'qb' and 'player_vehicles' or 'owned_vehicles'
end

local function getOwnerField()
    return Config.Framework == 'qb' and 'citizenid' or 'owner'
end

local function determineGarageName(vehicleData)
    local garageName = vehicleData.location or vehicleData.in_shared
    if not garageName then
        if vehicleData.parked_at == 'garage' then
            garageName = 'Garage'
        elseif vehicleData.parked_at == 'outside' then
            garageName = 'Outside'
        elseif vehicleData.parked_at == 'impound' then
            garageName = 'Impound'
        elseif vehicleData.parked_at == 'shared' then
            garageName = 'Shared Garage'
        else
            garageName = vehicleData.parked_at
        end
    end
    return garageName
end

RegisterNetEvent('phone:setVehicleToOutSide', function(plate)
    local str = ([[
        UPDATE %s
        SET parked_at = 'outside'
        WHERE plate = ?
    ]]):format(getTableName())

    MySQL.Sync.execute(str, { plate })
end)

function getGarageData(identifier, plate)
    local tableName = getTableName()
    local ownerField = getOwnerField()

    local str = ([[
        SELECT * FROM %s WHERE %s = ? AND (type = 'vehicle' OR type = 'car')
    ]]):format(tableName, ownerField)

    if plate then
        str = str .. ([[
            AND plate = "%s"
        ]]):format(plate)
    end

    local result = MySQL.Sync.fetchAll(str, { identifier })
    if not result[1] then return false end
    local data = {}

    for k, v in pairs(result) do
        if Config.Framework ~= 'qb' then
            local vehicle = json.decode(v.vehicle)
            if not vehicle then return end

            table.insert(data, {
                name = vehicle.model,
                plate = v.plate,
                inGarage = v.parked_at == 'garage' or v.parked_at == 'shared',
                fuel = vehicle.fuel or 1000,
                engine = vehicle.engine or 1000,
                body = vehicle.body or 1000,
                vehicle = vehicle,
                garage = determineGarageName(v),
            })
        else
            table.insert(data, {
                name = v.vehicle,
                plate = v.plate,
                inGarage = v.parked_at == 'garage' or v.parked_at == 'shared',
                fuel = v.fuel or 1000,
                engine = v.engine or 1000,
                body = v.body or 1000,
                vehicle = json.decode(v.mods),
                garage = determineGarageName(v),
            })
        end
    end

    return data
end