-- qs-housing: never index `t[k]` on an empty proxy — that re-invokes __index forever (C stack overflow).
-- Memoize export results and use a PENDING sentinel so re-entrant getHouseData -> localHouses[key] returns nil instead of recursing.
local QS_HOUSE_PENDING = {}
local qsHouseClientCache = {}

local function getQsHouseData(houseKey)
    if type(houseKey) ~= 'string' or houseKey == '' then
        return nil
    end
    local cached = qsHouseClientCache[houseKey]
    if cached == QS_HOUSE_PENDING then
        return nil
    end
    if cached ~= nil then
        return cached
    end
    qsHouseClientCache[houseKey] = QS_HOUSE_PENDING
    local ok, res = pcall(function()
        return exports['qs-housing']:getHouseData(houseKey)
    end)
    if not ok then
        qsHouseClientCache[houseKey] = nil
        return nil
    end
    qsHouseClientCache[houseKey] = res
    return res
end

local localHouses = setmetatable({}, {
    __index = function(t, k)
        if Config.Houses.provider == 'qs-housing' then
            return getQsHouseData(k)
        end
        return rawget(t, k)
    end,
})

PhoneProfiler.thread('houses.initialSyncKickoff', function()
    if Config.Houses.provider == 'qb-houses' then
        TriggerServerEvent('qb-houses:server:setHouses')
    end
end, { label = '@qs-smartphone/client/apps/houses.lua:38', module = 'houses', feature = 'initial_sync' })

do
    if Config.Houses.provider == 'qb-houses' then
        RegisterNetEvent('qb-houses:client:setHouseConfig', function(houseConfig)
            localHouses = houseConfig
        end)
    end
end

RegisterNetEvent('qb-houses:client:lockHouse', function(bool, house)
    if not localHouses[house] then
        return
    end

    localHouses[house].locked = bool
end)

---@param list table?
---@return table?
local function enrichBootstrap(list)
    if type(list) ~= 'table' then
        return list
    end
    for i = 1, #list do
        local entry = list[i]
        local key = entry and entry.houseKey
        if type(key) == 'string' and key ~= '' then
            local hd = localHouses[key]
            if hd then
                if hd.mlo then
                    entry.locked = hd.mlo[1].locked
                else
                    entry.locked = hd.locked or false
                end
                entry.isMlo = type(hd.mlo) == 'table'
                if type(hd.address) == 'string' and hd.address ~= '' then
                    entry.addressLabel = hd.address
                end
            end
        end
    end
    return list
end

RegisterNUICallback('houses:bootstrap', function(_, cb)
    local result = lib.callback.await('phone:houses:bootstrap', false, {})
    if type(result) == 'table' and result.success and type(result.data) == 'table' then
        local d = result.data
        if type(d.houses) == 'table' then
            d.houses = enrichBootstrap(d.houses)
            cb({ success = true, data = d })
        elseif d[1] ~= nil then
            cb({
                success = true,
                data = {
                    houses = enrichBootstrap(d),
                    provider = Config.Houses and Config.Houses.provider or 'none',
                    qsHousing = nil,
                },
            })
        else
            cb(result)
        end
        return
    end
    cb(result)
end)

api.registerNuiCallback('houses:keyholders:resolve', 'phone:houses:keyholders:resolve')
api.registerNuiCallback('houses:nearby:players', 'phone:houses:nearbyPlayers')

RegisterNUICallback('houses:key:give', function(data, cb)
    local houseKey = data and data.houseKey
    local targetServerId = tonumber(data and data.targetServerId)
    if type(houseKey) ~= 'string' or houseKey == '' or not targetServerId then
        cb({ success = false, message = 'Invalid payload' })
        return
    end
    if Config.Houses.provider == 'qs-housing' then
        local success = lib.callback.await('housing:giveKey', false, targetServerId, houseKey)
        Debug('houses:key:give', 'success', success)
    else
        TriggerServerEvent('qb-houses:server:giveHouseKey', targetServerId, houseKey)
        Wait(250)
    end
    local refreshed = lib.callback.await('phone:houses:getKeyholders', false, { houseKey = houseKey })
    cb(refreshed)
end)

RegisterNUICallback('houses:key:remove', function(data, cb)
    local houseKey = data and data.houseKey
    local identifier = data and data.identifier
    if type(houseKey) ~= 'string' or houseKey == '' or type(identifier) ~= 'string' or identifier == '' then
        cb({ success = false, message = 'Invalid payload' })
        return
    end
    local payload = {
        citizenid = identifier,
        firstname = '',
        lastname = '',
    }
    if Config.Houses.provider == 'qs-housing' then
        local success = lib.callback.await('housing:takeKey', false, houseKey, payload)
        Debug('houses:key:remove', 'success', success)
    else
        TriggerServerEvent('qb-houses:server:removeHouseKey', houseKey, payload)
        Wait(250)
    end
    local refreshed = lib.callback.await('phone:houses:getKeyholders', false, { houseKey = houseKey })
    cb(refreshed)
end)

---@param houseKey string
---@param state boolean
local function qsToggleDoor(houseKey, state)
    local house = localHouses[houseKey]
    if house.mlo then
        TriggerServerEvent('qb-houses:mloToggleAllDoors', houseKey, state)
    end

    if house.locked then
        TriggerServerEvent('qb-houses:server:lockHouse', state, houseKey)
    else
        TriggerServerEvent('qb-houses:server:lockHouse', state, houseKey)
    end
end

RegisterNUICallback('houses:door:toggle', function(data, cb)
    local houseKey = data and data.houseKey
    if type(houseKey) ~= 'string' or houseKey == '' then
        cb({ success = false, message = 'Invalid house' })
        return
    end
    local houseData = localHouses[houseKey]
    if not houseData then
        cb({ success = false, message = 'House not loaded. Wait for housing sync or re-open the phone.' })
        return
    end
    local locked = houseData.mlo and houseData.mlo[1].locked or houseData.locked or false
    local newLocked = not locked
    if Config.Houses.provider == 'qs-housing' then
        qsToggleDoor(houseKey, newLocked)
    else
        TriggerServerEvent('qb-houses:server:lockHouse', newLocked, houseKey)
    end
    cb({ success = true, data = { locked = newLocked } })
end)

RegisterNUICallback('houses:waypoint:set', function(data, cb)
    local houseKey = data and data.houseKey
    if type(houseKey) ~= 'string' or houseKey == '' then
        cb({ success = false, message = 'Invalid house' })
        return
    end
    local houseData = localHouses[houseKey]
    Debug('houses:waypoint:set', 'houseData', localHouses)
    if not houseData or type(houseData.coords) ~= 'table' or type(houseData.coords.enter) ~= 'table' then
        cb({ success = false, message = 'No map position for this house yet.' })
        return
    end
    local enter = houseData.coords.enter
    local x = enter.x or enter[1]
    local y = enter.y or enter[2]
    if type(x) ~= 'number' or type(y) ~= 'number' then
        cb({ success = false, message = 'Invalid entrance coordinates.' })
        return
    end
    SetNewWaypoint(x + 0.0, y + 0.0)
    cb({ success = true, data = { ok = true } })
end)

local function qsHousingOk()
    return Config.Houses and Config.Houses.provider == 'qs-housing' and GetResourceState('qs-housing') == 'started'
end

local function qsAwait(name, ...)
    if not qsHousingOk() then
        return nil
    end
    return lib.callback.await(name, false, ...)
end

RegisterNUICallback('houses:qs:snapshot', function(data, cb)
    local house = data and data.houseKey
    if type(house) ~= 'string' or house == '' then
        return cb({ success = false, message = 'Invalid house' })
    end
    local res = qsAwait('housing:phoneHouseSnapshot', house)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:listings', function(data, cb)
    local res = qsAwait('housing:phoneListings', data or {})
    cb({ success = true, data = res })
end)

RegisterNUICallback('houses:qs:mapProperties', function(_, cb)
    if not qsHousingOk() then
        return cb({ success = false, message = 'qs-housing not available' })
    end
    local res = qsAwait('housing:phoneMapProperties')
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local playerCoords = { x = pos.x + 0.0, y = pos.y + 0.0, z = pos.z + 0.0 }
    if type(res) ~= 'table' or res.ok ~= true then
        return cb({
            success = false,
            message = 'map_properties_failed',
            data = { properties = {}, playerCoords = playerCoords },
        })
    end
    cb({
        success = true,
        data = {
            properties = res.properties or {},
            playerCoords = playerCoords,
        },
    })
end)

RegisterNUICallback('houses:qs:buy', function(data, cb)
    local house = data and data.houseKey
    local isCredit = data and data.isCredit == true
    if type(house) ~= 'string' or house == '' then
        return cb({ success = false, message = 'Invalid house' })
    end
    local res = qsAwait('housing:phoneBuyHouse', house, isCredit)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:rent', function(data, cb)
    local house = data and data.houseKey
    if type(house) ~= 'string' or house == '' then
        return cb({ success = false, message = 'Invalid house' })
    end
    local res = qsAwait('housing:phoneRentHouse', house)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:sell', function(data, cb)
    local house = data and data.houseKey
    if type(house) ~= 'string' or house == '' then
        return cb({ success = false, message = 'Invalid house' })
    end
    local res = qsAwait('housing:phoneSellHouse', house)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:lights:toggle', function(data, cb)
    local house = data and data.houseKey
    if type(house) ~= 'string' or house == '' then
        return cb({ success = false, message = 'Invalid house' })
    end
    local res = qsAwait('housing:phoneToggleLights', house)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:payRent', function(data, cb)
    local res = qsAwait('housing:phonePayRent', tonumber(data and data.rentId), data and data.houseKey)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:payBill', function(data, cb)
    local res = qsAwait('housing:phonePayBill', tonumber(data and data.billId), data and data.houseKey)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:payAllBills', function(data, cb)
    local res = qsAwait('housing:phonePayAllBills', data and data.houseKey)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:vault:get', function(data, cb)
    local res = qsAwait('housing:phoneVaultGet', data and data.houseKey)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:vault:set', function(data, cb)
    local res = qsAwait('housing:phoneVaultSet', data and data.houseKey, data and data.code, data and data.id)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:vault:remove', function(data, cb)
    local res = qsAwait('housing:phoneVaultRemove', data and data.houseKey, data and data.id)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:upgrade:buy', function(data, cb)
    local res = qsAwait('housing:phoneBuyUpgrade', data and data.houseKey, data and data.upgrade)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:deliveries', function(data, cb)
    local res = qsAwait('housing:phoneDeliveries', data and data.houseKey)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:delivery:order', function(data, cb)
    local res = qsAwait('housing:phoneOrderDelivery', data and data.houseKey, data and data.title, tonumber(data and data.price), data and data.items)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:delivery:collect', function(data, cb)
    local res = qsAwait('housing:phoneCollectDelivery', tonumber(data and data.deliveryId))
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:cameras:list', function(data, cb)
    local houseKey = data and data.houseKey
    if type(houseKey) ~= 'string' or houseKey == '' then
        return cb({ success = false, message = 'Invalid house' })
    end
    if not qsHousingOk() then
        return cb({ success = false, message = 'qs-housing not available' })
    end
    local current = exports['qs-housing']:getCurrentHouse()
    if current ~= houseKey then
        return cb({ success = true, data = { ok = true, items = {}, mustBeInside = true } })
    end
    local okList, cams = pcall(function()
        return exports['qs-housing']:GetSecurityCameras()
    end)
    if not okList or type(cams) ~= 'table' then
        return cb({ success = true, data = { ok = true, items = {} } })
    end
    cb({ success = true, data = { ok = true, items = cams } })
end)

RegisterNUICallback('houses:qs:camera:watch', function(data, cb)
    if not qsHousingOk() then
        return cb({ success = false, message = 'qs-housing not available' })
    end
    local id = tonumber(data and data.cameraId)
    if not id then
        return cb({ success = false, message = 'Invalid camera' })
    end
    local okPcall, watched = pcall(function()
        return exports['qs-housing']:WatchSecurityCamera(id) == true
    end)
    local ok = okPcall and watched == true
    cb({ success = ok, data = { ok = ok } })
end)

RegisterNUICallback('houses:qs:ikea:state', function(data, cb)
    local res = qsAwait('housing:phoneIkeaState', data and data.houseKey)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:ikea:collect', function(data, cb)
    local res = qsAwait('housing:phoneIkeaCollect', data and data.houseKey)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:ikea:order', function(data, cb)
    local res = qsAwait('housing:phoneIkeaOrder', data and data.houseKey, data and data.orderData)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:dancers', function(data, cb)
    local res = qsAwait('housing:phoneDancers', data and data.houseKey)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:dancer:order', function(data, cb)
    local res = qsAwait('housing:phoneOrderDancer', data and data.houseKey, data and data.title, tonumber(data and data.price))
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:apartment:units', function(data, cb)
    local res = qsAwait('housing:phoneApartmentUnits', data and data.baseName)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:apartment:shell', function(data, cb)
    local res = qsAwait('housing:phoneApartmentShell', data and data.apartmentName, data and data.shellData)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:apartment:ipl', function(data, cb)
    local res = qsAwait('housing:phoneApartmentIpl', data and data.apartmentName, data and data.iplData)
    cb({ success = type(res) == 'table' and res.ok == true, data = res })
end)

RegisterNUICallback('houses:qs:metakey:create', function(data, cb)
    if not qsHousingOk() then
        return cb({ success = false, message = 'housing unavailable' })
    end
    local ok = lib.callback.await('housing:createMetaKey', false, data and data.houseKey)
    cb({ success = ok == true })
end)

RegisterNUICallback('houses:qs:metakey:delete', function(data, cb)
    if not qsHousingOk() then
        return cb({ success = false, message = 'housing unavailable' })
    end
    local ok = lib.callback.await('housing:deleteMetaKey', false, data and data.houseKey, data and data.keyId)
    cb({ success = ok == true })
end)
