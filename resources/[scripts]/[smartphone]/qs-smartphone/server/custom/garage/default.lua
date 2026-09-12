if Config.Garage ~= 'default' then
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
            SET state = 0
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
        for k, v in pairs(result) do
            local garageId = v.garage or v.parking
            local inGarage = v.state == 1 or v.state == 2

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
        for k, v in pairs(result) do
            local vehicle = json.decode(v.vehicle)
            if not vehicle then return end
            local inGarage = v.stored == 1
            local garageId = v.garage or v.parking

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
