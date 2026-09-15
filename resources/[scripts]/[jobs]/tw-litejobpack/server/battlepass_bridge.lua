local function parameterIndexes(fn)
    local sourceIndex
    local xpIndex
    local infoOk, info = pcall(debug.getinfo, fn, 'u')
    info = infoOk and info or {}

    for index = 1, tonumber(info.nparams) or 0 do
        local nameOk, name = pcall(debug.getlocal, fn, index)
        name = nameOk and name or nil
        name = tostring(name or ''):lower()

        if not sourceIndex and (name == 'source' or name == 'src' or name == 'playerid' or name == 'serverid') then
            sourceIndex = index
        elseif not xpIndex and (name == 'xp' or name == 'experience' or name == 'amount') then
            xpIndex = index
        end
    end

    return sourceIndex, xpIndex
end

local function onlineSource(value)
    local candidate = tonumber(value)
    if candidate and candidate > 0 and GetPlayerName(candidate) then
        return candidate
    end
end

local function sourceFromIdentifier(identifier)
    if type(identifier) ~= 'string' or identifier == '' then return end

    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src and tostring(GetIdentifier(src) or '') == identifier then
            return src
        end
    end
end

local function resolveRewardArguments(args, sourceIndex, xpIndex)
    local src
    local srcArgumentIndex
    local xp

    if sourceIndex then
        src = onlineSource(args[sourceIndex]) or sourceFromIdentifier(args[sourceIndex])
        if src then srcArgumentIndex = sourceIndex end
    end

    if xpIndex then
        xp = tonumber(args[xpIndex])
    end

    for index = 1, args.n do
        local value = args[index]

        if type(value) == 'table' then
            if not src then
                src = onlineSource(value.source or value.src or value.playerId or value.serverId)
            end
            if not xp then
                xp = tonumber(value.xp or value.experience or value.amount)
            end
        elseif not src then
            src = onlineSource(value) or sourceFromIdentifier(value)
            if src then srcArgumentIndex = index end
        end
    end

    if not xp then
        for index = args.n, 1, -1 do
            if index ~= srcArgumentIndex then
                local value = tonumber(args[index])
                if value and value > 0 then
                    xp = value
                    break
                end
            end
        end
    end

    return src, xp
end

local function wrapXpFunction(name, original)
    if type(original) ~= 'function' then
        print(('^3[tw-litejobpack] %s was not available for the Battle Pass bridge.^7'):format(name))
        return nil
    end

    local sourceIndex, xpIndex = parameterIndexes(original)

    return function(...)
        local args = table.pack(...)
        local results = table.pack(original(table.unpack(args, 1, args.n)))

        if results.n == 0 or results[1] ~= false then
            local src, jobXp = resolveRewardArguments(args, sourceIndex, xpIndex)
            if src and jobXp and type(TW_AddBattlePassJobXPFromReward) == 'function' then
                TW_AddBattlePassJobXPFromReward(src, jobXp)
            elseif Config.Debug then
                print(('[tw-litejobpack] Could not resolve %s arguments (source=%s, xp=%s).')
                    :format(name, tostring(src), tostring(jobXp)))
            end
        end

        return table.unpack(results, 1, results.n)
    end
end

local wrappedAddXP = wrapXpFunction('AddXP', AddXP)
if wrappedAddXP then AddXP = wrappedAddXP end

local wrappedRewardJobXP = wrapXpFunction('RewardJobXP', RewardJobXP)
if wrappedRewardJobXP then RewardJobXP = wrappedRewardJobXP end

if wrappedAddXP or wrappedRewardJobXP then
    print('^2[tw-litejobpack] Battle Pass action XP bridge enabled (15%).^7')
end
