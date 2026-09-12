if Config.Vehiclekeys ~= 'mk_vehiclekeys' then
    return
end

function AddVehiclekeys(vehicle)
    exports['mk_vehiclekeys']:AddKey(vehicle)
end
