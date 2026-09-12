ObIlegalServer = ObIlegalServer or {}
ObIlegalServer.ActiveSessions = ObIlegalServer.ActiveSessions or {}

function ObIlegalServer.ClaimSession(source, owner, token)
    if ObIlegalServer.ActiveSessions[source] then return false end
    ObIlegalServer.ActiveSessions[source] = { owner = owner, token = token }
    return true
end

function ObIlegalServer.ReleaseSession(source, token)
    local session = ObIlegalServer.ActiveSessions[source]
    if not session or (token and session.token ~= token) then return false end
    ObIlegalServer.ActiveSessions[source] = nil
    return true
end

function ObIlegalServer.HasActiveSession(source)
    return ObIlegalServer.ActiveSessions[source] ~= nil
end

function ObIlegalServer.GetPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

function ObIlegalServer.GetClass(source)
    local player = ObIlegalServer.GetPlayer(source)
    local metadata = player and player.PlayerData and player.PlayerData.metadata or {}
    local classId = tostring(metadata[Config.ClassMetadataKey] or ''):lower()
    return classId, Config.Classes[classId], player
end

function ObIlegalServer.PlayerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then return nil end
    local coords = GetEntityCoords(ped)
    return { x = coords.x, y = coords.y, z = coords.z }, ped
end

function ObIlegalServer.IsPlayerAvailable(source)
    local coords, ped = ObIlegalServer.PlayerCoords(source)
    if not coords or GetEntityHealth(ped) <= 0 then return false, 'dead' end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'vehicle' end
    return true, nil, coords
end

function ObIlegalServer.CountPolice()
    local count = 0
    for _, playerId in ipairs(GetPlayers()) do
        local player = ObIlegalServer.GetPlayer(tonumber(playerId))
        local job = player and player.PlayerData and player.PlayerData.job or {}
        if Config.Police.jobs[tostring(job.name or '')] and job.onduty ~= false then
            count = count + 1
        end
    end
    return count
end

function ObIlegalServer.HasItem(source, item)
    if not item then return true end
    local count = exports.ox_inventory:Search(source, 'count', item.name)
    return (tonumber(count) or 0) >= (tonumber(item.count) or 1)
end

function ObIlegalServer.TakeRequiredItem(source, item)
    if not item or item.consume ~= true then return true end
    local success = exports.ox_inventory:RemoveItem(source, item.name, tonumber(item.count) or 1)
    return success == true
end

function ObIlegalServer.ConsumeEssence(source, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount == 0 then return true end
    local result = exports.ob_essencias:ConsumeEssencia(source, amount)
    return type(result) == 'table' and result.success == true
end

function ObIlegalServer.CalculateReward(multiplier, rewardConfig)
    rewardConfig = rewardConfig or Config.Reward
    local minimum = math.floor(tonumber(rewardConfig.minimum) or 0)
    local maximum = math.floor(tonumber(rewardConfig.maximum) or minimum)
    if maximum < minimum then minimum, maximum = maximum, minimum end

    return math.max(1, math.floor(math.random(minimum, maximum) * (tonumber(multiplier) or 1.0)))
end

function ObIlegalServer.GiveRewardItem(source, amount, itemName)
    amount = math.max(1, math.floor(tonumber(amount) or 0))
    itemName = tostring(itemName or Config.Reward.item)
    if not exports.ox_inventory:CanCarryItem(source, itemName, amount) then
        return false, 'inventory'
    end

    local success = exports.ox_inventory:AddItem(source, itemName, amount)
    if success ~= true then return false, 'inventory' end
    return true, nil
end

function ObIlegalServer.SendPoliceAlert(coords)
    local payload = {
        coords = coords,
        radius = Config.Police.alertRadius,
        duration = math.floor((tonumber(Config.Police.alertDuration) or 60) * 1000),
    }

    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        local player = target and ObIlegalServer.GetPlayer(target)
        local job = player and player.PlayerData and player.PlayerData.job or {}
        if target and Config.Police.jobs[tostring(job.name or '')] and job.onduty ~= false then
            TriggerClientEvent('ob_ilegal:client:policeAlert', target, payload)
        end
    end
end
