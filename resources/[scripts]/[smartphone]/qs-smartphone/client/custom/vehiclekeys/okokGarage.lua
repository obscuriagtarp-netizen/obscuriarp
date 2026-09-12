if Config.Vehiclekeys ~= 'okokGarage' then
    return
end

function AddVehiclekeys(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    TriggerServerEvent('okokGarage:GiveKeys', plate)
end
