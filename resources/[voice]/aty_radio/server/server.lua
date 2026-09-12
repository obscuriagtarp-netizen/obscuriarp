Channels = {}
Requests = {}
Accepted = {}

RegisterCallback("radio:joinChannel", function(src, dat)
    local data = tonumber(dat.channel)
    local forced = dat.forced or false

    local player = GetPlayer(src)
    local job = GetPlayerJob(player)?.name

    if not data then
        return {status = "error", message = "No channel provided"}
    end

    if not forced then
        if IsChannelLocked(data, job) and not (Accepted[data] and Accepted[data][src]) then
            if Config.EnableRequesting then
                SendRequest(src, data)
                return {status = "error", message = "You are not allowed to join this channel, request sent to the channel owner"}
            else
                return {status = "error", message = "You are not allowed to join this channel"}
            end
        end
    end

    local lastId = 1

    for k, v in pairs(Channels) do
        lastId = tonumber(k)
    end

    local frequency = tostring(data)

    if not Channels[lastId] then
        Channels[lastId] = {
            id = lastId,
            players = {},
            frequency = frequency
        }
    end

    Channels[lastId].players[tostring(src)] = {
        name = GetPlayerNameBySource(src),
        networkId = NetworkGetNetworkIdFromEntity(GetPlayerPed(src)),
        src = src
    }

    if Config.EnableShowUsers then
        for src, player in pairs(Channels[lastId].players) do
            local src = player.src
            TriggerClientEvent("radio:refreshMembers", src, Channels[lastId].players)
        end
    end

    return {status = "success", message = "You have joined the channel"}
end)

RegisterCallback("radio:leaveChannel", function(src, channel)
    local channel = FindPlayerRadio(src)

    if not Channels[channel] then
        return {status = "error", message = "You are not in a channel"}
    end

    Channels[channel][src] = nil

    return {status = "success", message = "You have left the channel"}
end)

function FindPlayerRadio(src)
    for k, v in pairs(Channels) do
        if v.players[tostring(src)] then
            return k
        end
    end
    return nil
end

RegisterCallback("radio:getRequests", function(src, channel)
    local player = GetPlayer(src)
    local job = GetPlayerJob(player)
    local grade = 0

    if Utils.Framework == "qb-core" then
        grade = player.PlayerData.job?.grade?.level or player.PlayerData.job?.grade_level or 0
    elseif Utils.Framework == "es_extended" then
        grade = job.grade
    end

    local requests = {}
    local id = nil

    for k, v in pairs(Requests) do
        for _, c in ipairs(Config.LockedChannels) do
            if c.frequency == tonumber(k) and c.job == job.name and grade >= c.accepterGrade then
                requests[k] = v
                id = k

                if not Accepted[k] then
                    Accepted[k] = {}
                end

                Accepted[k][src] = true
            end
        end
    end 

    return requests[id]
end)

RegisterCallback("radio:getRandomChannels", function(src)
    local channels = {}

    for i = 1, 10 do
        local size = table.size(Channels)

        if size == 0 then
            break
        end

        local random = math.random(1, size)
        local channel = Channels[random]

        local chance = math.random(1, 100)

        if channel and not channels[channel.frequency] and chance <= 20 then
            channels[channel.frequency] = channel
        end
    end

    return channels
end)

RegisterCallback("hasItem", function(src, item)
    return HasItem(src, item, 1)
end)

RegisterCallback("hasMoney", function(src, money)
    if HasMoney(src, money) then
        RemoveMoney(src, money)
        return true
    else
        return false
    end
end)

RegisterCallback("radio:acceptRequest", function(src, data)
    local player = GetPlayer(src)
    local job = GetPlayerJob(player)
    local grade = 0

    if Utils.Framework == "qb-core" then
        grade = player.PlayerData.job?.grade?.level or player.PlayerData.job?.grade_level or 0
    elseif Utils.Framework == "es_extended" then
        grade = job.grade
    end

    local channel = tonumber(data.channel)
    local identifier = data.identifier

    if not channel then
        return {status = "error", message = "No channel provided"}
    end

    if not identifier then
        return {status = "error", message = "No identifier provided"}
    end

    if not Requests[channel] then
        return {status = "error", message = "No requests found for this channel"}
    end

    local exists = false
    local name = nil

    for k, v in ipairs(Requests[channel]) do
        if v.identifier == identifier then
            exists = true
            name = v.name
            table.remove(Requests[channel], k)
            break
        end
    end

    if not exists then
        return {status = "error", message = "Request not found"}
    end

    if not Channels[channel] then
        return {status = "error", message = "Channel not found"}
    end

    if not Accepted[channel] then
        Accepted[channel] = {}
    end

    Accepted[channel][src] = true

    return {status = "success", message = "You have accepted the request from "..name}
end)

RegisterCallback("radio:declineRequest", function(src, data)
    local channel = tonumber(data.channel)
    local identifier = data.identifier

    if not channel then
        return {status = "error", message = "No channel provided"}
    end

    if not identifier then
        return {status = "error", message = "No identifier provided"}
    end

    if not Requests[channel] then
        return {status = "error", message = "No requests found for this channel"}
    end

    local exists = false
    local name = nil

    for k, v in ipairs(Requests[channel]) do
        if v.identifier == identifier then
            exists = true
            name = v.name
            table.remove(Requests[channel], k)
            break
        end
    end

    if not exists then
        return {status = "error", message = "Request not found"}
    end

    return {status = "success", message = "You have declined the request from "..name}
end)

AddEventHandler("playerDropped", function()
    local src = source
    local channel = FindPlayerRadio(src)

    if not Channels[channel] then
        return
    end

    Channels[channel].players[tostring(src)] = nil

    if Config.EnableShowUsers then
        for src, player in pairs(Channels[channel].players) do
            local src = player.src
            TriggerClientEvent("radio:refreshMembers", src, Channels[channel].players)
        end
    end
end)

function IsChannelLocked(channel, job)
    local dataFound = false
    local jobFound = false

    for _, v in ipairs(Config.LockedChannels) do
        if v.frequency == tonumber(channel) then
            dataFound = true
            for _, j in ipairs(v.jobs) do
                if j == job then
                    jobFound = true
                    break
                end
            end
        end
    end

    if dataFound and not jobFound then
        return true
    else
        return false
    end
end

function GetPlayerJob(player)
    if Utils.Framework == "qb-core" then
        return player.PlayerData.job
    elseif Utils.Framework == "es_extended" then
        return player.getJob()
    end
end

function SendRequest(src, channel)
    local name = GetPlayerNameBySource(src)
    local identifier = GetPlayerIdentifier(src)

    for _, v in ipairs(Config.LockedChannels) do
        if v.frequency == tonumber(channel) then
            if Requests[channel] then
                local exists = false
                for _, request in ipairs(Requests[channel]) do
                    if request.identifier == identifier then
                        exists = true
                        break
                    end
                end

                if not exists then
                    table.insert(Requests[channel], {name = name, identifier = identifier})
                end
            else
                Requests[channel] = {{name = name, identifier = identifier}}
            end
        end
    end
end

function table.size(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end