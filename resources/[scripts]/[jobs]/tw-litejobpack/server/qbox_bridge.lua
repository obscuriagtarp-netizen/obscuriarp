local activeKeyRequests = {}

local function clearKeyRequest(playerSource, requestKey)
    local requests = activeKeyRequests[playerSource]
    if not requests then return end

    requests[requestKey] = nil
    if not next(requests) then
        activeKeyRequests[playerSource] = nil
    end
end

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

local function hasVehicleKeys(playerSource, vehicle)
    local ok, hasKeys = pcall(function()
        return exports.qbx_vehiclekeys:HasKeys(playerSource, vehicle)
    end)

    return ok and hasKeys == true
end

local function giveVehicleKeys(playerSource, vehicle)
    if hasVehicleKeys(playerSource, vehicle) then return true end

    for _ = 1, 4 do
        local ok = pcall(function()
            exports.qbx_vehiclekeys:GiveKeys(playerSource, vehicle, true)
        end)

        if ok and hasVehicleKeys(playerSource, vehicle) then
            return true
        end

        Wait(200)
    end

    return false
end

RegisterNetEvent('tw-litejobpack:server:obscuriaQbxVehicleKey', function(netId, shouldGive)
    local playerSource = source

    if GetResourceState('qbx_vehiclekeys') ~= 'started' then return end

    netId = tonumber(netId)
    if not netId or netId <= 0 then return end

    local requestKey = ('%s:%s'):format(netId, shouldGive == true and 'give' or 'remove')
    activeKeyRequests[playerSource] = activeKeyRequests[playerSource] or {}
    if activeKeyRequests[playerSource][requestKey] then return end
    activeKeyRequests[playerSource][requestKey] = true

    CreateThread(function()
        -- Client-created job vehicles can take a moment to enter the server's
        -- network scope. Retry before giving up on the key request.
        local vehicle = resolveNetworkVehicle(netId, 60, 250)
        if vehicle == 0 then
            print(('[tw-litejobpack] qbx_vehiclekeys: vehicle netId %s was not available for player %s'):format(netId, playerSource))
            clearKeyRequest(playerSource, requestKey)
            return
        end

        if shouldGive == true then
            local isNear = false
            for _ = 1, 20 do
                if isPlayerNearVehicle(playerSource, vehicle) then
                    isNear = true
                    break
                end
                Wait(250)
            end

            if not isNear then
                print(('[tw-litejobpack] qbx_vehiclekeys: player %s is too far from vehicle netId %s'):format(playerSource, netId))
                clearKeyRequest(playerSource, requestKey)
                return
            end

            if not giveVehicleKeys(playerSource, vehicle) then
                print(('[tw-litejobpack] qbx_vehiclekeys: key verification failed for player %s, netId %s'):format(playerSource, netId))
            end
        else
            pcall(function()
                exports.qbx_vehiclekeys:RemoveKeys(playerSource, vehicle, true)
            end)
        end

        clearKeyRequest(playerSource, requestKey)
    end)
end)

AddEventHandler('playerDropped', function()
    activeKeyRequests[source] = nil
end)
