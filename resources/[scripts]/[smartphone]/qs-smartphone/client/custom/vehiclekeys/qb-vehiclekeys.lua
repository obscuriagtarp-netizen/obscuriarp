if Config.Vehiclekeys ~= 'qb-vehiclekeys' then
    return
end

function AddVehiclekeys(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
end
