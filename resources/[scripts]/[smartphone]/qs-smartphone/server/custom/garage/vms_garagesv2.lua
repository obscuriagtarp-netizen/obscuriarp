if Config.Garage ~= 'vms_garagesv2' then
    return
end

RegisterNetEvent('phone:setVehicleToOutSide', function(plate)
    local plate = plate

    local queryVehicleData = 'SELECT garage, garageSpotID FROM owned_vehicles WHERE plate = ? AND impound_data IS NULL AND impound_date IS NULL'
    if Config.Framework == 'qb' then
        queryVehicleData = 'SELECT garage, garageSpotID FROM player_vehicles WHERE plate = ? AND impound_data IS NULL AND impound_date IS NULL'
    end
    local vehicleData = MySQL.query.await(queryVehicleData, { plate })

    if vehicleData and vehicleData[1] then
        TriggerEvent('vms_garagesv2:vehicleTakenByPhone', vehicleData[1].garage, vehicleData[1].garageSpotID)
    end

    Citizen.CreateThread(function()
        Citizen.Wait(3000)
        local foundNetId = nil

        local allVehicles = GetAllVehicles()
        for i = 1, #allVehicles do
            if DoesEntityExist(allVehicles[i]) then
                local vehPlate = GetVehicleNumberPlateText(allVehicles[i])
                local cleanedPlate = vehPlate:match('^%s*(.-)%s*$')
                if cleanedPlate == plate then
                    foundNetId = NetworkGetNetworkIdFromEntity(allVehicles[i])
                    break
                end
            end
        end

        local str = [[
            UPDATE owned_vehicles
            SET garage = NULL, garageSpotID = NULL
        ]]
        if Config.Framework == 'qb' then
            str = [[
                UPDATE player_vehicles
                SET garage = NULL, garageSpotID = NULL
            ]]
        end

        if foundNetId then
            str = str .. ', netid = ? WHERE plate = ?'
            MySQL.Sync.execute(str, { foundNetId, plate })
        else
            str = str .. ' WHERE plate = ?'
            MySQL.Sync.execute(str, { plate })
        end
    end)
end)

function getGarageData(identifier, plate)
    local str = [[
        SELECT * FROM owned_vehicles WHERE owner = ? AND (type = 'vehicle' OR type = 'car') AND impound_data IS NULL AND impound_date IS NULL
    ]]
    if Config.Framework == 'qb' then
        str = [[
            SELECT * FROM player_vehicles WHERE citizenid = ? AND (type = 'vehicle' OR type = 'car' OR type = 'automobile') AND impound_data IS NULL AND impound_date IS NULL
        ]]
    end
    if plate then
        str = str .. ([[
            AND plate = "%s"
        ]]):format(plate)
    end
    print(str)
    local result = MySQL.Sync.fetchAll(str, { identifier })
    if not result[1] then
        return false
    end

    local data = {}
    if Config.Framework == 'qb' then
        for k, v in pairs(result) do
            local mods = json.decode(v.mods)
            if not mods then
                return
            end

            local inGarage = false
            local garageId = 'OUT'
            if v.garage then
                local label, coords = exports['vms_garagesv2']:getGarageInfo(v.garage)
                inGarage = true
                garageId = label
            elseif v.impound then
                garageId = 'IMPOUND'
            end

            table.insert(data, {
                name = mods.model,
                plate = v.plate,
                inGarage = inGarage,
                fuel = mods.fuel or 1000,
                engine = mods.engine or 1000,
                body = mods.body or 1000,
                vehicle = mods,
                garage = garageId,
            })
        end
    else
        for k, v in pairs(result) do
            local vehicle = json.decode(v.vehicle)
            if not vehicle then
                return
            end

            local inGarage = false
            local garageId = 'OUT'
            print(v.garage)
            if v.garage then
                local label, coords = exports['vms_garagesv2']:getGarageInfo(v.garage)
                inGarage = true
                garageId = label
            elseif v.impound then
                garageId = 'IMPOUND'
            end

            table.insert(data, {
                name = vehicle.model,
                plate = v.plate,
                inGarage = inGarage,
                fuel = vehicle.fuel or 1000,
                engine = vehicle.engine or 1000,
                body = vehicle.body or 1000,
                vehicle = vehicle,
                garage = garageId,
            })
        end
    end
    return data
end
