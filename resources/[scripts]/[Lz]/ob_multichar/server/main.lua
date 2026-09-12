local function readClass(citizenId)
    if GetResourceState('classeSelector') ~= 'started' then return nil end

    local ok, classId = pcall(function()
        return exports['classeSelector']:GetPlayerClass(citizenId)
    end)

    return ok and classId or nil
end

lib.callback.register('ob_multichar:server:getClassMap', function(_, citizenIds)
    if type(citizenIds) ~= 'table' then return {} end

    if GetResourceState('classeSelector') == 'started' then
        local ok, classes = pcall(function()
            return exports['classeSelector']:GetPlayerClasses(citizenIds)
        end)

        if ok and type(classes) == 'table' then return classes end
    end

    local result = {}
    for i = 1, math.min(#citizenIds, 12) do
        local citizenId = citizenIds[i]
        if type(citizenId) == 'string' and #citizenId <= 64 then
            result[citizenId] = readClass(citizenId)
        end
    end

    return result
end)
