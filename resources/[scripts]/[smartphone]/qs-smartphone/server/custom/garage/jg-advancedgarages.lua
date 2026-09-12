if Config.Garage ~= 'jg-advancedgarages' then
    return
end

RegisterNetEvent('phone:setVehicleToOutSide', function(plate)
    local str = [[
        UPDATE owned_vehicles
        SET in_garage = 0
        WHERE plate = ?
    ]]
    if Core.isQbFramework() then
        str = [[
            UPDATE player_vehicles
            SET in_garage = 0
            WHERE plate = ?
        ]]
    end

    MySQL.Sync.execute(str, { plate })
end)

---@param mods unknown
---@param spawnCode unknown
---@param plate string
---@return table|nil
local function resolveVehicleProps(mods, spawnCode, plate)
    local vehicle = Core.decodeVehicleProps(mods)
    if vehicle then
        return vehicle
    end

    if type(spawnCode) == 'string' and spawnCode ~= '' then
        return { model = spawnCode, plate = plate }
    end

    return nil
end

function getGarageData(identifier, plate)
    local str = [[
        SELECT * FROM owned_vehicles WHERE owner = ? AND (type = 'vehicle' OR type = 'car')
    ]]
    if Core.isQbFramework() then
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
    if Core.isQbFramework() then
        for k, v in pairs(result) do
            local inGarage = v.in_garage
            local garageId = v.garage_id
            local impound = v.impound

            if not inGarage then
                garageId = v.impound == 1 and 'IMPOUND' or 'OUT'
            end

            if impound == 1 then
                garageId = v.garage_id
                inGarage = false
            end

            local vehicleProps = resolveVehicleProps(v.mods, v.vehicle, v.plate)
            local fuel = math.floor((tonumber(v.fuel) or 100) * 10)

            table.insert(data, {
                name = v.vehicle,
                plate = v.plate,
                inGarage = inGarage,
                fuel = fuel > 0 and fuel or 1000,
                engine = tonumber(v.engine) or 1000,
                body = tonumber(v.body) or 1000,
                vehicle = vehicleProps,
                garage = garageId,
            })
        end
    else
        for k, v in pairs(result) do
            local vehicle = Core.decodeVehicleProps(v.vehicle)
            if not vehicle then
                goto continue
            end

            local inGarage = v.in_garage
            local garageId = v.garage_id
            local impound = v.impound

            if not inGarage then
                garageId = 'OUT'
            end

            if impound == 1 then
                garageId = v.impound == 1 and 'IMPOUND' or 'OUT'
                inGarage = false
            end

            local fuel = math.floor(tonumber(vehicle.fuel or v.fuel) or 1000)

            table.insert(data, {
                name = vehicle.model,
                plate = v.plate,
                inGarage = inGarage,
                fuel = fuel > 0 and fuel or 1000,
                engine = tonumber(vehicle.engine) or 1000,
                body = tonumber(vehicle.body) or 1000,
                vehicle = vehicle,
                garage = garageId,
            })

            ::continue::
        end
    end
    return data
end
