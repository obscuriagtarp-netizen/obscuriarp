local cashDrops = {}
local cashModel = 'prop_cash_pile_01'
local nextPickupSound = 0
local streamDrop

local function deleteDropObject(drop)
    if drop and drop.object and DoesEntityExist(drop.object) then DeleteEntity(drop.object) end
    if drop then
        drop.object = nil
        drop.spawning = false
    end
end

local function removeDrop(id)
    local drop = cashDrops[id]
    if not drop then return end
    cashDrops[id] = nil
    deleteDropObject(drop)
end

local function registerDrop(data)
    if type(data) ~= 'table' or type(data.id) ~= 'string' or cashDrops[data.id] then return end
    local coords = ObIlegalShared.NormalizeCoords(data.coords)
    if not coords then return end
    local origin = ObIlegalShared.NormalizeCoords(data.origin) or coords

    local delay = math.max(0, math.floor(tonumber(data.delay) or 0))
    local settled = data.settled == true
    local drop = {
        id = data.id,
        coords = coords,
        origin = origin,
        heading = tonumber(data.heading) or 0.0,
        spawnAt = GetGameTimer() + delay,
        readyAt = settled and GetGameTimer() or (GetGameTimer() + delay + 1100),
        picking = false,
        spawning = false,
        ready = settled,
        settled = settled,
    }
    cashDrops[data.id] = drop

    local ped = PlayerPedId()
    if streamDrop and ped ~= 0 then
        local playerCoords = GetEntityCoords(ped)
        if #(playerCoords - vector3(coords.x, coords.y, coords.z)) < 72.0 then
            streamDrop(drop)
        end
    end
end

streamDrop = function(drop)
    if drop.object or drop.spawning then return end
    drop.spawning = true

    CreateThread(function()
        local waitTime = math.max(0, drop.spawnAt - GetGameTimer())
        if waitTime > 0 then Wait(waitTime) end
        if cashDrops[drop.id] ~= drop then return end

        local model = ObIlegalClient.EnsureModel(cashModel)
        if not model then
            drop.spawning = false
            drop.ready = GetGameTimer() >= drop.readyAt
            return
        end

        local isSettled = drop.settled or GetGameTimer() >= drop.readyAt
        local coords = drop.coords
        local spawn = isSettled and coords or drop.origin
        local object = CreateObjectNoOffset(
            model,
            spawn.x, spawn.y, spawn.z + (isSettled and 0.15 or 0.0),
            false, false, false
        )
        SetModelAsNoLongerNeeded(model)
        if not object or object == 0 or not DoesEntityExist(object) then
            drop.spawning = false
            drop.ready = isSettled
            return
        end

        drop.object = object
        SetEntityAsMissionEntity(object, true, true)
        SetEntityHeading(object, drop.heading)
        SetEntityCollision(object, true, true)

        if not isSettled then
            SetEntityDynamic(object, true)
            ActivatePhysics(object)
            local x, y = coords.x - spawn.x, coords.y - spawn.y
            local length = math.max(0.01, math.sqrt((x * x) + (y * y)))
            SetEntityVelocity(object, (x / length) * 2.75, (y / length) * 2.75, 2.05)
            Wait(math.max(0, drop.readyAt - GetGameTimer()))
        end

        if cashDrops[drop.id] == drop and DoesEntityExist(object) then
            SetEntityCoordsNoOffset(object, coords.x, coords.y, coords.z + 0.15, false, false, false)
            PlaceObjectOnGroundProperly(object)
            FreezeEntityPosition(object, true)
            local settled = GetEntityCoords(object)
            drop.coords = { x = settled.x, y = settled.y, z = settled.z }
            drop.ready = true
            drop.settled = true
            drop.spawning = false
        end
    end)
end

RegisterNetEvent('ob_ilegal:client:addCashDrops', function(entries)
    if type(entries) ~= 'table' then return end
    for index = 1, #entries do registerDrop(entries[index]) end
end)

RegisterNetEvent('ob_ilegal:client:removeCashDrop', function(id)
    removeDrop(id)
end)

CreateThread(function()
    Wait(1200)
    local ok, entries = pcall(function()
        return lib.callback.await('ob_ilegal:server:getCashDrops', false)
    end)
    if ok and type(entries) == 'table' then
        for index = 1, #entries do registerDrop(entries[index]) end
    end
end)

CreateThread(function()
    while true do
        local waitTime = 1000
        local ped = PlayerPedId()
        local playerCoords = ped ~= 0 and GetEntityCoords(ped) or nil
        local canPickup = playerCoords
            and not IsPedDeadOrDying(ped, true)
            and not IsPedInAnyVehicle(ped, false)
        local pickupDistance = math.max(0.75, tonumber(Config.Reward.pickupDistance) or 1.35)
        local lightCoords
        local lightDistance = math.huge

        for id, drop in pairs(cashDrops) do
            local dropId = id
            local coords = drop.coords
            if coords and playerCoords then
                local distance = #(playerCoords - vector3(coords.x, coords.y, coords.z))
                if distance < 72.0 and not drop.object and not drop.spawning then streamDrop(drop) end
                if distance > 96.0 and drop.object then deleteDropObject(drop) end
                if not drop.ready and GetGameTimer() >= drop.readyAt then drop.ready = true end

                if distance < 16.0 then
                    waitTime = 0
                    if drop.object and distance < lightDistance then
                        lightCoords = coords
                        lightDistance = distance
                    end
                elseif distance < 72.0 then
                    waitTime = math.min(waitTime, 200)
                end

                if canPickup and distance <= pickupDistance and drop.ready and not drop.picking then
                    drop.picking = true
                    CreateThread(function()
                        local ok, result = pcall(function()
                            return lib.callback.await('ob_ilegal:server:pickupCashDrop', false, dropId)
                        end)
                        if ok and type(result) == 'table' and result.success then
                            removeDrop(dropId)
                            if GetGameTimer() >= nextPickupSound then
                                nextPickupSound = GetGameTimer() + 180
                                PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                            end
                        elseif type(result) == 'table' and result.reason == 'missing' then
                            removeDrop(dropId)
                        elseif cashDrops[dropId] then
                            cashDrops[dropId].picking = false
                            if type(result) == 'table' and result.reason == 'inventory' then
                                ObIlegalClient.NotifyReason('inventory')
                            end
                        end
                    end)
                end
            end
        end

        if lightCoords then
            DrawLightWithRange(lightCoords.x, lightCoords.y, lightCoords.z + 0.12, 217, 183, 92, 0.75, 0.45)
        end
        Wait(waitTime)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for id in pairs(cashDrops) do removeDrop(id) end
end)
