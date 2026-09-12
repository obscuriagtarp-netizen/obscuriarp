ObIlegalDrops = ObIlegalDrops or {}

local drops = {}
local dropSequence = 0

local function now()
    return os.time()
end

local function publicDrop(drop)
    return {
        id = drop.id,
        coords = drop.coords,
        origin = drop.origin,
        heading = drop.heading,
        delay = GetGameTimer() >= drop.collectAt and 0 or drop.delay,
        settled = GetGameTimer() >= drop.collectAt,
        remaining = math.max(1, drop.expiresAt - now()),
    }
end

local function removeDrop(id)
    if not drops[id] then return end
    drops[id] = nil
    TriggerClientEvent('ob_ilegal:client:removeCashDrop', -1, id)
end

local function splitReward(total, count)
    local values = {}
    local remaining = total
    for index = 1, count do
        local slotsLeft = count - index + 1
        local amount = index == count and remaining or math.max(1, math.floor(remaining / slotsLeft))
        values[index] = amount
        remaining = remaining - amount
    end
    return values
end

function ObIlegalDrops.Create(source, atmCoords, playerCoords, multiplier, rewardOverride)
    atmCoords = ObIlegalShared.NormalizeCoords(atmCoords)
    playerCoords = ObIlegalShared.NormalizeCoords(playerCoords)
    if not atmCoords or not playerCoords then return false, 0, 0 end

    local rewardConfig = rewardOverride or Config.Reward
    local total = ObIlegalServer.CalculateReward(multiplier, rewardConfig)
    local countConfig = rewardConfig.dropCount or {}
    local minimum = math.max(1, math.floor(tonumber(countConfig.minimum) or 7))
    local maximum = math.max(minimum, math.floor(tonumber(countConfig.maximum) or minimum))
    local count = math.min(total, math.random(minimum, maximum))
    local amounts = splitReward(total, count)

    local directionX = playerCoords.x - atmCoords.x
    local directionY = playerCoords.y - atmCoords.y
    local length = math.sqrt((directionX * directionX) + (directionY * directionY))
    if length < 0.05 then
        directionX, directionY, length = 0.0, -1.0, 1.0
    end
    directionX, directionY = directionX / length, directionY / length

    local lifetime = math.max(20, math.floor(tonumber(rewardConfig.dropLifetime) or 90))
    local expiresAt = now() + lifetime
    local payload = {}

    for index = 1, count do
        dropSequence = dropSequence + 1
        local spread = count == 1 and 0.0 or (-0.82 + (((index - 1) / (count - 1)) * 1.64))
        local radial = 1.15 + (((index - 1) % 3) * 0.48) + (math.random() * 0.18)
        local cosAngle, sinAngle = math.cos(spread), math.sin(spread)
        local offsetX = ((directionX * cosAngle) - (directionY * sinAngle)) * radial
        local offsetY = ((directionX * sinAngle) + (directionY * cosAngle)) * radial
        local id = ('cash:%d:%d:%d'):format(now(), source, dropSequence)
        local drop = {
            id = id,
            amount = amounts[index],
            item = tostring(rewardConfig.item or Config.Reward.item),
            pickupDistance = tonumber(rewardConfig.pickupDistance) or Config.Reward.pickupDistance,
            coords = {
                x = atmCoords.x + offsetX,
                y = atmCoords.y + offsetY,
                z = atmCoords.z + 0.10,
            },
            origin = {
                x = atmCoords.x + (directionX * 0.38),
                y = atmCoords.y + (directionY * 0.38),
                z = atmCoords.z + 0.78,
            },
            heading = math.random(0, 359) + 0.0,
            delay = (index - 1) * 65,
            collectAt = GetGameTimer() + 1050 + ((index - 1) * 65),
            expiresAt = expiresAt,
            claimed = false,
        }
        drops[id] = drop
        payload[#payload + 1] = publicDrop(drop)
    end

    TriggerClientEvent('ob_ilegal:client:addCashDrops', -1, payload)
    return true, total, count
end

lib.callback.register('ob_ilegal:server:getCashDrops', function()
    local result = {}
    for _, drop in pairs(drops) do
        if drop.expiresAt > now() then result[#result + 1] = publicDrop(drop) end
    end
    return result
end)

lib.callback.register('ob_ilegal:server:pickupCashDrop', function(source, id)
    local drop = type(id) == 'string' and drops[id] or nil
    if not drop or drop.expiresAt <= now() or drop.claimed then
        return { success = false, reason = 'missing' }
    end
    if GetGameTimer() < drop.collectAt then
        return { success = false, reason = 'settling' }
    end

    local available, reason, playerCoords = ObIlegalServer.IsPlayerAvailable(source)
    local maximumDistance = math.max(0.75, tonumber(drop.pickupDistance) or 1.35) + 0.8
    if not available or ObIlegalShared.Distance(playerCoords, drop.coords) > maximumDistance then
        return { success = false, reason = reason or 'distance' }
    end

    drop.claimed = true
    local added, addReason = ObIlegalServer.GiveRewardItem(source, drop.amount, drop.item)
    if not added then
        drop.claimed = false
        return { success = false, reason = addReason }
    end

    local amount = drop.amount
    removeDrop(id)
    return { success = true, amount = amount }
end)

CreateThread(function()
    while true do
        Wait(5000)
        local expired = {}
        local timestamp = now()
        for id, drop in pairs(drops) do
            if drop.expiresAt <= timestamp then expired[#expired + 1] = id end
        end
        for index = 1, #expired do removeDrop(expired[index]) end
    end
end)
