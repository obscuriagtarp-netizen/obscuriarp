if Config.Garage ~= 'qs-advancedgarages' then
    return
end

RegisterNetEvent('phone:setVehicleToOutSide', function(plate)
    local str = [[
        UPDATE owned_vehicles
        SET garage = 'OUT', stored = 0
        WHERE plate = ?
    ]]
    if Config.Framework == 'qb' then
        str = [[
            UPDATE player_vehicles
            SET garage = 'OUT', state = 0
            WHERE plate = ?
        ]]
    end

    MySQL.Sync.execute(str, { plate })
end)

function getGarageData(identifier, plate)
    local str = [[
            SELECT * FROM owned_vehicles WHERE owner = ? AND (type = 'vehicle' OR type = 'car')
        ]]
    if Config.Framework == 'qb' then
        str = [[
            SELECT * FROM player_vehicles WHERE citizenid = ?
        ]]
    end
    if plate then
        str = str .. ([[
            AND plate = "%s"
        ]]):format(plate)
    end
    local result = MySQL.Sync.fetchAll(str, { identifier })
    if not result[1] then return false end
    local data = {}
    if Config.Framework == 'qb' then
        local impoundGarages = exports['qs-advancedgarages']:getImpoundGarages()
        for k, v in pairs(result) do
            local inImpound = false
            if impoundGarages and impoundGarages[v.garage] then
                inImpound = true
            end

            local garageId = v.garage or v.parking
            local inGarage = (v.state == 1 or v.state == 2) and not inImpound

            if v.state == 0 then
                garageId = 'OUT'
            end

            table.insert(data, {
                name = v.vehicle,
                plate = v.plate,
                inGarage = inGarage,
                fuel = v.fuel or 1000,
                engine = v.engine or 1000,
                body = v.body or 1000,
                vehicle = json.decode(v.mods),
                garage = garageId,
            })
        end
    else
        local impoundGarages = exports['qs-advancedgarages']:getImpoundGarages()
        for k, v in pairs(result) do
            local vehicle = json.decode(v.vehicle)
            if not vehicle then return end

            local inImpound = false
            if impoundGarages and impoundGarages[v.garage] then
                inImpound = true
            end

            local inGarage = true
            local garageId = v.garage

            if v.garage == 'OUT' or inImpound then
                inGarage = false
            end

            table.insert(data, {
                name = vehicle.model,
                plate = v.plate,
                inGarage = inGarage,
                fuel = vehicle.fuel or 1000,
                engine = vehicle.engine or 1000,
                body = vehicle.body or 1000,
                vehicle = json.decode(v.vehicle),
                garage = garageId,
            })
        end
    end
    return data
end

RegisterNetEvent('phone:addVehicleToPersistent', function(plate, netId)
    local src = source
    local identifier = sfr:getIdentifier(src)
    if type(identifier) ~= 'string' or identifier == '' then
        return
    end
    local str = ([[
        SELECT 1 FROM %s WHERE plate = ? AND %s = ? AND jobVehicle = ? LIMIT 1
    ]]):format(sfr.garageTable, sfr.garageIdentifierColumn)
    local result = MySQL.Sync.fetchAll(str,
        { plate, identifier, '' })
    if not result[1] then
        return Error(src, 'Tried to exploit phone:addVehicleToPersistent')
    end
    local response = exports['qs-advancedgarages']:setVehicleToPersistent(netId)
    if not response then
        Error(plate, 'Failed to add vehicle to persistent')
        return
    end
    Debug(plate, 'Added vehicle to persistent')
end)
