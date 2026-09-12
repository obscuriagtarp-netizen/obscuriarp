ObIlegalShared = ObIlegalShared or {}

local function finiteNumber(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return nil
    end
    return value
end

function ObIlegalShared.NormalizeCoords(coords)
    local coordsType = type(coords)
    if coordsType ~= 'table' and coordsType ~= 'vector3' and coordsType ~= 'vector4' then return nil end

    local x = finiteNumber(coords.x or coords[1])
    local y = finiteNumber(coords.y or coords[2])
    local z = finiteNumber(coords.z or coords[3])
    if not x or not y or not z then return nil end

    return { x = x, y = y, z = z }
end

function ObIlegalShared.ModelKey(model)
    model = finiteNumber(model)
    if not model then return nil end
    model = math.floor(model)
    if model < 0 then model = model + 4294967296 end
    return tostring(model)
end

function ObIlegalShared.AtmKey(model, coords)
    coords = ObIlegalShared.NormalizeCoords(coords)
    model = ObIlegalShared.ModelKey(model)
    if not coords or not model then return nil end

    return ('%s:%d:%d:%d'):format(
        model,
        math.floor((coords.x * 10.0) + 0.5),
        math.floor((coords.y * 10.0) + 0.5),
        math.floor((coords.z * 10.0) + 0.5)
    )
end

function ObIlegalShared.Distance(first, second)
    local a = ObIlegalShared.NormalizeCoords(first)
    local b = ObIlegalShared.NormalizeCoords(second)
    if not a or not b then return math.huge end

    local x = a.x - b.x
    local y = a.y - b.y
    local z = a.z - b.z
    return math.sqrt((x * x) + (y * y) + (z * z))
end
