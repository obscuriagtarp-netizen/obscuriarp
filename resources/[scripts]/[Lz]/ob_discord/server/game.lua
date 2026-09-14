local sessions = {}
local sequence = 0
local frozen = {}
local cooldowns = {}

local function result(callback, data)
    callback(json.encode(data))
end

local function snapshot(id)
    id = tonumber(id)
    local player = id and exports.qbx_core:GetPlayer(id)
    if not player or not GetPlayerName(id) then return { error = 'offline' } end
    local ped = GetPlayerPed(id)
    if ped == 0 or not DoesEntityExist(ped) then return { error = 'not_ready' } end
    local citizen = player.PlayerData.citizenid
    if not citizen then return { error = 'not_ready' } end
    if cooldowns[citizen] == nil then cooldowns[citizen] = GetResourceKvpInt('rescue:' .. citizen) end
    if not sessions[id] or sessions[id].citizen ~= citizen or sessions[id].ped ~= ped then
        sequence = sequence + 1
        sessions[id] = { citizen = citizen, ped = ped, token = ('%s:%s:%s'):format(os.time(), id, sequence) }
    end
    local coords = GetEntityCoords(ped)
    local metadata = player.PlayerData.metadata or {}
    local state = Player(id).state
    local blocked
    if GetPlayerRoutingBucket(id) ~= 0 then blocked = 'instance'
    elseif GetVehiclePedIsIn(ped, false) ~= 0 then blocked = 'vehicle'
    elseif metadata.ishandcuffed then blocked = 'restrained'
    elseif (tonumber(metadata.injail) or 0) > 0 then blocked = 'jailed'
    end
    for _, key in ipairs(Config.BlockedStates) do
        if state[key] then blocked = 'special_state' break end
    end
    local excluded = false
    for _, zone in ipairs(Config.Automatic.ExcludedZones) do
        if #(coords - zone.coords) <= zone.radius then excluded = true break end
    end
    local discord = GetPlayerIdentifierByType(id, 'discord') or ''
    return {
        source = id,
        discordId = discord:gsub('^discord:', ''),
        session = sessions[id].token,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        dead = metadata.isdead == true,
        down = metadata.inlaststand == true,
        health = GetEntityHealth(ped),
        blocked = blocked,
        limbo = not excluded and coords.z < Config.Automatic.BelowWorldZ,
        autoEnabled = Config.Automatic.Enabled,
        staffEnabled = Config.Staff.Enabled,
        customDestination = Config.Staff.CustomDestination,
        cooldown = math.max(0, (cooldowns[citizen] or 0) - os.time()),
    }
end

function GetObDiscordAdminSession(id)
    local current = snapshot(id)
    return not current.error and current.session or nil
end

local function movePlayer(before, destination, automatic, request)
    local id = before.source
    local ped = GetPlayerPed(id)
    local character = sessions[id].citizen
    local target = { x = destination.x, y = destination.y, z = destination.z, w = destination.w }
    if automatic then
        cooldowns[character] = os.time() + Config.Automatic.CooldownSeconds
        SetResourceKvpInt('rescue:' .. character, cooldowns[character])
    end
    frozen[ped] = true
    FreezeEntityPosition(ped, true)
    local ok, err = pcall(function()
        TriggerClientEvent('ob_discord:prepare', id, target)
        Wait(600)
        local current = snapshot(id)
        if current.error or current.session ~= before.session or current.blocked then error('session_changed') end
        if automatic and (not current.autoEnabled or current.discordId ~= request.ownerId) then error('manual_review') end
        SetEntityCoords(ped, target.x, target.y, target.z, false, false, false, false)
        SetEntityVelocity(ped, 0.0, 0.0, 0.0)
        SetEntityHeading(ped, target.w)
        local arrived = false
        for _ = 1, 15 do
            Wait(200)
            current = snapshot(id)
            if current.error or current.session ~= before.session or current.blocked then error('session_changed') end
            local position = vec3(current.coords.x, current.coords.y, current.coords.z)
            if #(position - vec3(target.x, target.y, target.z)) <= 3.0 then arrived = true break end
        end
        if not arrived then error('teleport_unconfirmed') end
        Wait(500)
    end)
    if DoesEntityExist(ped) then FreezeEntityPosition(ped, false) end
    frozen[ped] = nil
    if not ok then
        print('[ob_discord] Acao interrompida: ' .. tostring(err))
        return { error = 'uncertain' }
    end
    local after = snapshot(id)
    if after.error or after.session ~= before.session then return { error = 'uncertain' } end
    local final = vec3(after.coords.x, after.coords.y, after.coords.z)
    if #(final - vec3(target.x, target.y, target.z)) > 5.0 then return { error = 'uncertain' } end
    return { ok = true, source = id, coords = after.coords, revived = false }
end

local function apply(request)
    if request.revive or request.action == 'revive' then return { error = 'revive_disabled' } end
    local before = snapshot(request.targetId)
    if before.error then return before end
    if before.session ~= request.session then return { error = 'session_changed' } end
    if before.blocked then return { error = before.blocked } end
    local automatic = request.mode == 'self'
    if automatic and (not before.autoEnabled or before.cooldown > 0
        or before.discordId ~= request.ownerId or request.actorId ~= request.ownerId) then
        return { error = 'manual_review' }
    end
    if not automatic and not Config.Staff.Enabled then return { error = 'disabled' } end

    local destination = Config.Destination
    if request.destination then
        if automatic or not Config.Staff.CustomDestination then return { error = 'forbidden_destination' } end
        local d = request.destination
        if type(d.x) ~= 'number' or type(d.y) ~= 'number' or type(d.z) ~= 'number' or type(d.w) ~= 'number'
            or math.abs(d.x) > 12000 or math.abs(d.y) > 12000 or d.z < -200 or d.z > 2000
            or d.w < 0 or d.w > 360 then return { error = 'invalid_destination' } end
        destination = vec4(d.x, d.y, d.z, d.w)
    end
    return movePlayer(before, destination, automatic, request)
end

local function adminAction(request)
    local cfg = Config.Admin or {}
    if cfg.Enabled ~= true or request.mode ~= 'staff' then return { error = 'disabled' } end
    local before = snapshot(request.targetId)
    if before.error then return before end
    if before.session ~= request.adminSession then return { error = 'session_changed' } end
    if before.blocked then return { error = before.blocked } end

    if request.action == 'teleport' then
        local destination = (cfg.Destinations or {})[request.destinationKey]
        if not destination or not destination.coords then return { error = 'invalid_destination' } end
        return movePlayer(before, destination.coords, false, request)
    end

    if request.action == 'revive' then
        if cfg.AllowRevive ~= true then return { error = 'disabled' } end
        if not before.dead and not before.down then return { error = 'not_dead' } end
        local medical = cfg.MedicalResource or 'qbx_medical'
        if GetResourceState(medical) ~= 'started' then return { error = 'medical_offline' } end
        local ok = pcall(function() exports[medical]:Revive(before.source) end)
        if not ok then return { error = 'internal' } end
        Wait(700)
        local after = snapshot(before.source)
        if after.error or after.session ~= before.session then return { error = 'session_changed' } end
        return { ok = true, source = before.source, action = request.action, revived = true }
    end

    if request.action == 'character_selection' then
        local multichar = cfg.MulticharResource or 'ob_multichar'
        if GetResourceState(multichar) ~= 'started' then return { error = 'multichar_offline' } end
        TriggerClientEvent('ob_multichar:client:prepareAdminFlow', before.source, 'selection')
        Wait(150)
        local current = snapshot(before.source)
        if current.error or current.session ~= before.session or current.blocked then return { error = 'session_changed' } end
        local ok = pcall(function() exports.qbx_core:Logout(before.source) end)
        if not ok then return { error = 'internal' } end
        return { ok = true, source = before.source, action = request.action }
    end

    if request.action == 'clothing_menu' then
        local appearance = cfg.AppearanceResource or 'illenium-appearance'
        if GetResourceState(appearance) ~= 'started' then return { error = 'appearance_offline' } end
        TriggerClientEvent('illenium-appearance:client:openClothingShopMenu', before.source, true)
        return { ok = true, source = before.source, action = request.action }
    end

    return { error = 'invalid_action' }
end

-- Apenas export server-side. Nenhum RegisterNetEvent concede acoes aos clientes.
exports('TicketBridge', function(operation, encoded, callback)
    CreateThread(function()
        local ok, data = pcall(function()
            local request = json.decode(encoded)
            if operation == 'snapshot' then return snapshot(request.targetId) end
            if operation == 'apply' then return apply(request) end
            if operation == 'profile' then return ReadDiscordPlayerProfile(request) end
            if operation == 'admin' then return adminAction(request) end
            return { error = 'invalid_action' }
        end)
        result(callback, ok and data or { error = 'internal' })
    end)
end)

AddEventHandler('playerDropped', function() sessions[source] = nil end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for ped in pairs(frozen) do
        if DoesEntityExist(ped) then FreezeEntityPosition(ped, false) end
    end
end)
