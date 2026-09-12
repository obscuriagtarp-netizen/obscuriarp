if Config.Garage ~= 'okokGarage' then
    return
end

RegisterNetEvent('phone:setVehicleToOutSide', function(plate)
    local str = [[
        UPDATE owned_vehicles
        SET parking = '', stored = 0
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
        SELECT *, cast(`stored` as signed) as `stored` FROM owned_vehicles WHERE owner = ? AND (type = 'vehicle' OR type = 'car')
    ]]
    if Config.Framework == 'qb' then
        str = [[
            SELECT *, cast(`state` as signed) as `state` FROM player_vehicles WHERE citizenid = ?
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
            if type(v.state) ~= 'number' then
                v.state = tonumber(v.state)
            end
            local garageId = v.garage or v.parking
            local inGarage = v.state == 1

            if v.state == 0 then
                garageId = 'OUT'
                if tonumber(v.state) == 2 then
                    garageId = 'IMPOUNDED'
                end
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
            if type(v.stored) ~= 'number' then
                v.stored = tonumber(v.stored)
            end
            local inGarage = v.stored == 1
            local garageId = v.garage or v.parking
            if not inGarage then
                garageId = 'OUT'
                if tonumber(v.stored) == 2 then
                    garageId = 'IMPOUNDED'
                end
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
