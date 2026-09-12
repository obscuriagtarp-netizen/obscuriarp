---@param message string
---@return table
local function failMessage(message)
    return { success = false, message = message }
end

---@param row table
---@return number
local function stableHouseId(row)
    local id = tonumber(row.id)
    if id and id > 0 then
        return math.floor(id)
    end
    local house = tostring(row.house or row.name or row.label or '')
    if house == '' then
        return 1
    end
    local h = 0
    for i = 1, #house do
        h = (h * 31 + string.byte(house, i)) % 2147483647
    end
    if h <= 0 then
        h = 1
    end
    return h
end

---@param keyholders unknown
---@return string[]
local function decodeKeyholdersList(keyholders)
    if type(keyholders) == 'table' then
        local out = {}
        for _, v in pairs(keyholders) do
            if type(v) == 'string' and v ~= '' then
                out[#out + 1] = v
            end
        end
        return out
    end
    if type(keyholders) == 'string' and keyholders ~= '' then
        local decoded = json.decode(keyholders)
        return decodeKeyholdersList(decoded)
    end
    return {}
end

---@param identifiers string[]
---@return table[]
local function formatKeyholders(identifiers)
    local out = {}
    for i = 1, #identifiers do
        local id = identifiers[i]
        if type(id) == 'string' and id ~= '' then
            local firstName, lastName = '', ''
            if sfr.getUserNameFromIdentifier then
                firstName, lastName = sfr:getUserNameFromIdentifier(id)
            end
            out[#out + 1] = {
                firstName = type(firstName) == 'string' and firstName or '',
                lastName = type(lastName) == 'string' and lastName or '',
                identifier = id,
            }
        end
    end
    return out
end

---@param houseKey string
---@return string[]|nil keys, string|nil err
local function loadKeyholderIdentifiers(houseKey)
    if type(houseKey) ~= 'string' or houseKey == '' then
        return nil, 'Invalid house'
    end
    local row = MySQL.single.await('SELECT keyholders FROM player_houses WHERE house = ? LIMIT 1', { houseKey })
    if not row then
        return nil, 'House not found'
    end
    return decodeKeyholdersList(row.keyholders), nil
end

---@param source number
---@param identifier string
---@param houseKey string
---@return boolean, string|nil err
local function playerCanAccessHouse(source, identifier, houseKey)
    local row = MySQL.single.await(
        'SELECT citizenid, identifier, owner, rented, keyholders FROM player_houses WHERE house = ? LIMIT 1',
        { houseKey }
    )
    if not row then
        return false, 'House not found'
    end
    local occ = tostring(row.citizenid or row.identifier or '')
    if occ == identifier then
        return true, nil
    end
    local propOwner = tostring(row.owner or '')
    if propOwner ~= '' and propOwner == identifier then
        return true, nil
    end
    if tonumber(row.rented) == 1 and occ == identifier then
        return true, nil
    end
    local keys = decodeKeyholdersList(row.keyholders)
    for i = 1, #keys do
        if keys[i] == identifier then
            return true, nil
        end
    end
    return false, 'No access'
end

---@param source number
---@param identifier string
Core.callback('houses:bootstrap', function(source, identifier)
    local rows = MySQL.query.await('SELECT * FROM player_houses', {}) or {}
    local list = {}
    local provider = 'none'
    if type(Config) == 'table' and type(Config.Houses) == 'table' and type(Config.Houses.provider) == 'string' then
        provider = Config.Houses.provider
    end
    local qsHousing = nil
    if provider == 'qs-housing' and GetResourceState('qs-housing') == 'started' then
        local okCaps, caps = pcall(function()
            return exports['qs-housing']:PhoneCapabilitiesTable()
        end)
        if okCaps and type(caps) == 'table' then
            qsHousing = caps
        end
    end

    for i = 1, #rows do
        local row = rows[i]
        local houseKey = tostring(row.house or row.name or '')
        if houseKey == '' then
            goto continue
        end
        local keyList = decodeKeyholdersList(row.keyholders)
        local hasKey = false
        for k = 1, #keyList do
            if keyList[k] == identifier then
                hasKey = true
                break
            end
        end

        local isOwner, ownerLabel
        local ownerId = row.citizenid or row.identifier or ''

        if provider == 'qs-housing' then
            local propOwner = tostring(row.owner or '')
            local occ = tostring(row.citizenid or row.identifier or '')
            local rented = tonumber(row.rented) == 1
            isOwner = propOwner ~= '' and propOwner == identifier
            local isTenant = rented and occ == identifier
            if not isOwner and not isTenant and not hasKey then
                goto continue
            end
            if isTenant and not isOwner and propOwner ~= '' and sfr.getUserNameFromIdentifier then
                local pf, pl = sfr:getUserNameFromIdentifier(propOwner)
                ownerLabel = Core.trim(tostring(pf or '') .. ' ' .. tostring(pl or ''))
                if ownerLabel == '' then
                    ownerLabel = nil
                end
            end
        else
            isOwner = ownerId == identifier
            if not isOwner and not hasKey then
                goto continue
            end
            local ownerFirst, ownerLast = '', ''
            if ownerId ~= '' and sfr.getUserNameFromIdentifier then
                ownerFirst, ownerLast = sfr:getUserNameFromIdentifier(ownerId)
            end
            if not isOwner and ownerId ~= '' then
                ownerLabel = Core.trim(tostring(ownerFirst or '') .. ' ' .. tostring(ownerLast or ''))
                if ownerLabel == '' then
                    ownerLabel = nil
                end
            end
        end

        list[#list + 1] = {
            id = stableHouseId(row),
            houseKey = houseKey,
            isOwner = isOwner,
            ownerLabel = ownerLabel,
            playerIdentifier = identifier,
            keyholders = formatKeyholders(keyList),
        }
        ::continue::
    end

    return Core.ok({
        houses = list,
        provider = provider,
        qsHousing = qsHousing,
    })
end)

---@param source number
---@param identifier string
---@param scopeId string
---@param data { houseKey: string }
Core.callback('houses:getKeyholders', function(source, identifier, scopeId, data)
    local houseKey = Core.asString(data and data.houseKey)
    local okAccess, errAccess = playerCanAccessHouse(source, identifier, houseKey)
    if not okAccess then
        return failMessage(errAccess or 'No access')
    end
    local ids, err = loadKeyholderIdentifiers(houseKey)
    if not ids then
        return failMessage(err or 'Failed to load keyholders')
    end
    return Core.ok(formatKeyholders(ids))
end)

---@param source number
---@param identifier string
---@param scopeId string
---@param data { identifiers: string[] }
Core.callback('houses:keyholders:resolve', function(source, identifier, scopeId, data)
    local raw = data and data.identifiers
    if type(raw) ~= 'table' then
        return Core.ok({})
    end
    local ids = {}
    for j = 1, #raw do
        local id = raw[j]
        if type(id) == 'string' and id ~= '' then
            ids[#ids + 1] = id
        end
    end
    return Core.ok(formatKeyholders(ids))
end)

---@param source number
---@return table[]
local function getNearbyPlayers(source)
    local srcPed = GetPlayerPed(source)
    if not srcPed or srcPed == 0 then
        return {}
    end

    local srcCoords = GetEntityCoords(srcPed)
    local radius = 12.0
    if type(Config) == 'table' and type(Config.Houses) == 'table' then
        local r = tonumber(Config.Houses.nearbyRadius)
        if r and r >= 1.0 and r <= 50.0 then
            radius = r
        end
    end

    local allPlayers = GetPlayers()
    local withDist = {}

    for idx = 1, #allPlayers do
        local target = tonumber(allPlayers[idx])
        if target and target > 0 and target ~= source then
            local tPed = GetPlayerPed(target)
            if tPed and tPed ~= 0 then
                local tCoords = GetEntityCoords(tPed)
                local dist = #(tCoords - srcCoords)
                if dist <= radius then
                    local firstName, lastName = sfr:getUserName(target)
                    withDist[#withDist + 1] = {
                        serverId = target,
                        firstName = type(firstName) == 'string' and firstName or '',
                        lastName = type(lastName) == 'string' and lastName or '',
                        _dist = dist,
                    }
                end
            end
        end
    end

    table.sort(withDist, function(a, b)
        return a._dist < b._dist
    end)

    local out = {}
    for j = 1, #withDist do
        out[j] = {
            serverId = withDist[j].serverId,
            firstName = withDist[j].firstName,
            lastName = withDist[j].lastName,
        }
    end
    return out
end

---@param source number
Core.callback('houses:nearbyPlayers', function(source)
    return Core.ok(getNearbyPlayers(source))
end)
