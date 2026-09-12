local keyRequestCooldown = {}

local function resolveNetworkVehicle(netId, attempts, waitMs)
    for _ = 1, attempts do
        local vehicle = NetworkGetEntityFromNetworkId(netId)
        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            return vehicle
        end

        Wait(waitMs)
    end

    return 0
end

local function isPlayerNearVehicle(source, vehicle)
    local ped = GetPlayerPed(source)
    if ped == 0 or not DoesEntityExist(ped) or not DoesEntityExist(vehicle) then
        return false
    end

    return #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) <= 8.0
end

RegisterNetEvent('tw-litejobpack:server:obscuriaQbxVehicleKey', function(netId, shouldGive)
    local playerSource = source
    local now = GetGameTimer()

    if keyRequestCooldown[playerSource] and now - keyRequestCooldown[playerSource] < 500 then
        return
    end
    keyRequestCooldown[playerSource] = now

    if GetResourceState('qbx_vehiclekeys') ~= 'started' then return end

    netId = tonumber(netId)
    if not netId then return end

    CreateThread(function()
        -- Client-created job vehicles can take a moment to enter the server's
        -- network scope. Retry before giving up on the key request.
        local vehicle = resolveNetworkVehicle(netId, 12, 150)
        if vehicle == 0 then
            print(('[tw-litejobpack] qbx_vehiclekeys: vehicle netId %s was not available for player %s'):format(netId, playerSource))
            return
        end

        if shouldGive == true then
            if not isPlayerNearVehicle(playerSource, vehicle) then
                print(('[tw-litejobpack] qbx_vehiclekeys: player %s is too far from vehicle netId %s'):format(playerSource, netId))
                return
            end

            local ok, result = pcall(function()
                return exports.qbx_vehiclekeys:GiveKeys(playerSource, vehicle, true)
            end)
            if not ok or result ~= true then
                print(('[tw-litejobpack] qbx_vehiclekeys:GiveKeys failed for player %s, netId %s: %s'):format(playerSource, netId, tostring(result)))
            end
        else
            pcall(function()
                exports.qbx_vehiclekeys:RemoveKeys(playerSource, vehicle, true)
            end)
        end
    end)
end)

AddEventHandler('playerDropped', function()
    keyRequestCooldown[source] = nil
end)
