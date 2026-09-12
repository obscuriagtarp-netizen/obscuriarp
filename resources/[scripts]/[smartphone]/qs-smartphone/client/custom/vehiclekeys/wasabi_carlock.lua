if Config.Vehiclekeys ~= 'wasabi_carlock' then
    return
end

function AddVehiclekeys(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    exports.wasabi_carlock:GiveKey(plate)
end
