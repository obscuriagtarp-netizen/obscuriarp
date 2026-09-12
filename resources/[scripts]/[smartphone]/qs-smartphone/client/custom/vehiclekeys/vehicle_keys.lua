if Config.Vehiclekeys ~= 'vehicles_keys' then
    return
end

function AddVehiclekeys(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    TriggerServerEvent('vehicles_keys:selfGiveVehicleKeys', plate)
end
