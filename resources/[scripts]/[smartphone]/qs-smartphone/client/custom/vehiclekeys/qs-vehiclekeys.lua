if Config.Vehiclekeys ~= 'qs-vehiclekeys' then
    return
end

function AddVehiclekeys(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    exports['qs-vehiclekeys']:GiveKeys(plate, model)
end
