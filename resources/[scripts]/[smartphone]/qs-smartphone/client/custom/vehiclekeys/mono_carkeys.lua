if Config.Vehiclekeys ~= 'mono_carkeys' then
    return
end

function AddVehiclekeys(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    TriggerServerEvent('mono_carkeys:CreateKey', plate)
end
