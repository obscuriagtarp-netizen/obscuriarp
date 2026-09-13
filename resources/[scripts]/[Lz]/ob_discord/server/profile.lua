local function discordId(id)
    return (GetPlayerIdentifierByType(id, 'discord') or ''):gsub('^discord:', '')
end

local function amount(value)
    local number = tonumber(value)
    if not number or number ~= number or math.abs(number) == math.huge then return nil end
    return number
end

local function adminDestinations()
    local admin = Config.Admin or {}
    if admin.Enabled ~= true then return {} end
    local result = {}
    for key, destination in pairs(admin.Destinations or {}) do
        if type(key) == 'string' and type(destination) == 'table' and type(destination.label) == 'string'
            and destination.coords then
            result[#result + 1] = { key = key, label = destination.label }
        end
    end
    table.sort(result, function(a, b) return a.label < b.label end)
    return result
end

function ReadDiscordPlayerProfile(request)
    local cfg = Config.Profile or {}
    if cfg.Enabled ~= true then return { error = 'disabled' } end
    if request.mode ~= 'self' and request.mode ~= 'staff' then return { error = 'forbidden' } end
    if request.mode == 'staff' and not Config.Staff.Enabled then return { error = 'disabled' } end
    if request.mode == 'self' and request.actorId ~= request.ownerId then return { error = 'identity_mismatch' } end
    local id = tonumber(request.targetId)
    if request.mode == 'self' and id == 0 then
        for _, source in ipairs(GetPlayers()) do
            if discordId(tonumber(source)) == request.actorId then
                if id ~= 0 then return { error = 'ambiguous_player' } end
                id = tonumber(source)
            end
        end
    end
    local player = id and id > 0 and exports.qbx_core:GetPlayer(id)
    if not player or not GetPlayerName(id) then return { error = 'offline' } end
    if request.mode == 'self' and discordId(id) ~= request.actorId then return { error = 'identity_mismatch' } end
    local data = player.PlayerData
    if not data or not data.citizenid then return { error = 'not_ready' } end
    local citizen = data.citizenid
    local money, metadata, charinfo = data.money or {}, data.metadata or {}, data.charinfo or {}
    local job, gang = data.job or {}, data.gang or {}
    local jobGrade = type(job.grade) == 'table' and (job.grade.name or job.grade.level) or job.grade
    local gangGrade = type(gang.grade) == 'table' and (gang.grade.name or gang.grade.level) or gang.grade
    local runes
    if GetResourceState(cfg.RunesResource) == 'started' then
        local ok, value = pcall(function() return exports[cfg.RunesResource][cfg.RunesExport](nil, id) end)
        if ok then runes = amount(value) end
    end
    local vehicles, vehicleCount = {}, nil
    if GetResourceState('oxmysql') == 'started' then
        local ok, rows = pcall(function()
            return exports.oxmysql:query_async('SELECT vehicle, plate FROM player_vehicles WHERE citizenid = ? ORDER BY id LIMIT 501', { citizen })
        end)
        if ok and type(rows) == 'table' then
            vehicleCount = #rows
            for index, row in ipairs(rows) do
                if index > 500 then break end
                vehicles[#vehicles + 1] = { model = tostring(row.vehicle or 'Desconhecido'), plate = tostring(row.plate or '') }
            end
        end
    end

    local current = exports.qbx_core:GetPlayer(id)
    if not current or current.PlayerData.citizenid ~= citizen or not GetPlayerName(id)
        or (request.mode == 'self' and discordId(id) ~= request.actorId) then return { error = 'session_changed' } end
    local ped = type(GetPlayerPed) == 'function' and GetPlayerPed(id) or 0
    local health = type(GetEntityHealth) == 'function' and amount(GetEntityHealth(ped)) or nil
    local armor = type(GetPedArmour) == 'function' and amount(GetPedArmour(ped)) or nil
    local adminSession
    if request.mode == 'staff' and type(GetObDiscordAdminSession) == 'function' then
        adminSession = GetObDiscordAdminSession(id)
        if not adminSession then return { error = 'session_changed' } end
    end
    return {
        ok = true,
        player = {
            source = id,
            citizenId = request.mode == 'staff' and tostring(citizen) or nil,
            name = tostring(charinfo.firstname or '') .. ' ' .. tostring(charinfo.lastname or ''),
            phone = request.mode == 'staff' and tostring(charinfo.phone or '') or nil,
            cash = amount(money.cash), bank = amount(money.bank), runes = runes,
            class = tostring(metadata[cfg.ClassMetadataKey] or 'Sem classe'),
            job = tostring(job.label or job.name or 'Sem emprego'),
            jobGrade = tostring(jobGrade or ''),
            gang = tostring(gang.label or gang.name or 'Sem grupo'),
            gangGrade = tostring(gangGrade or ''),
            health = health,
            armor = armor,
            dead = metadata.isdead == true,
            down = metadata.inlaststand == true,
            adminSession = adminSession,
            adminDestinations = request.mode == 'staff' and adminDestinations() or nil,
            vehicles = vehicles, vehicleCount = vehicleCount,
            vehiclesTruncated = vehicleCount ~= nil and vehicleCount > 500,
        },
    }
end
