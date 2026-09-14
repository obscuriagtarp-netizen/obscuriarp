local RESOURCE = GetCurrentResourceName()
local RoleSync = Config.RoleSync or {}
local LINK_FILE = 'data/discord-links.json'
local DiscordLinks = {}
local databaseWarningAt = 0

do
    local raw = LoadResourceFile(RESOURCE, LINK_FILE)
    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then DiscordLinks = decoded end
    end
end

local function normalize(value)
    return tostring(value or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
end

local function cleanNamePart(value)
    return tostring(value or '')
        :gsub('[%c]', '')
        :gsub('%s+', ' ')
        :gsub('^%s+', '')
        :gsub('%s+$', '')
end

local function characterName(charinfo)
    if type(charinfo) == 'string' then
        local ok, decoded = pcall(json.decode, charinfo)
        charinfo = ok and decoded or nil
    end
    if type(charinfo) ~= 'table' then return '' end
    local firstname = cleanNamePart(charinfo.firstname)
    local lastname = cleanNamePart(charinfo.lastname)
    return cleanNamePart(('%s %s'):format(firstname, lastname))
end

local function firstCharacterName(source, citizenid, player)
    if GetResourceState('oxmysql') == 'started' then
        local license = source and GetPlayerIdentifierByType(tostring(source), 'license') or ''
        local license2 = source and GetPlayerIdentifierByType(tostring(source), 'license2') or ''
        local playerLicense = player and player.PlayerData and player.PlayerData.license or ''
        local ok, rows = pcall(function()
            return exports.oxmysql:query_async([[
                SELECT candidate.charinfo
                FROM players AS candidate
                INNER JOIN players AS selected ON selected.citizenid = ?
                WHERE candidate.license = selected.license
                    OR (selected.userId IS NOT NULL AND candidate.userId = selected.userId)
                    OR candidate.license = ?
                    OR candidate.license = ?
                    OR candidate.license = ?
                ORDER BY COALESCE(candidate.cid, 2147483647), candidate.id
                LIMIT 1
            ]], { tostring(citizenid), license, license2, playerLicense })
        end)
        if ok and type(rows) == 'table' and rows[1] then
            local name = characterName(rows[1].charinfo)
            if name ~= '' then return name end
        elseif not ok and GetGameTimer() - databaseWarningAt > 60000 then
            databaseWarningAt = GetGameTimer()
            print(('[%s] Nome do primeiro personagem nao consultado no banco: %s'):format(RESOURCE, tostring(rows)))
        end
    end

    -- Mantem a sincronizacao disponivel durante uma indisponibilidade temporaria do banco.
    return characterName(player and player.PlayerData and player.PlayerData.charinfo)
end

local function discordId(source)
    return (GetPlayerIdentifierByType(tostring(source), 'discord') or ''):gsub('^discord:', '')
end

local function playerByCitizenId(citizenid)
    if GetResourceState('qbx_core') ~= 'started' then return nil end
    for _, player in pairs(exports.qbx_core:GetQBPlayers()) do
        if player.PlayerData and tostring(player.PlayerData.citizenid) == tostring(citizenid) then
            return player
        end
    end
    return nil
end

local function getClass(source, citizenid, player)
    local resource = RoleSync.ClassResource or 'classeSelector'
    if GetResourceState(resource) == 'started' then
        local ok, value = pcall(function()
            return exports[resource]:GetPlayerClass(citizenid)
        end)
        if ok and value then return normalize(value) end
    end
    local metadata = player and player.PlayerData and player.PlayerData.metadata or {}
    local value = metadata[RoleSync.ClassMetadataKey or 'classe']
    return value and normalize(value) or ''
end

local function getVips(citizenid, payload)
    local memberships = payload and payload.memberships
    local resource = RoleSync.VipResource or 'ob_vip'
    if type(memberships) ~= 'table' then
        if GetResourceState(resource) ~= 'started' then return {} end
        local ok, value = pcall(function()
            return exports[resource]:GetVips(citizenid)
        end)
        if not ok or type(value) ~= 'table' then return {} end
        memberships = value
    end

    local result, seen = {}, {}
    for _, membership in ipairs(memberships) do
        local vip = normalize(type(membership) == 'table' and membership.vip or membership)
        if vip ~= '' and not seen[vip] then
            seen[vip] = true
            result[#result + 1] = vip
        end
    end
    return result
end

local function emitSync(discord, citizenid, class, vips, displayName)
    discord = tostring(discord or '')
    if #discord < 17 or #discord > 20 or not discord:match('^%d+$') then return false end
    TriggerEvent('ob_discord:internal:syncRoles', json.encode({
        discordId = discord,
        citizenid = tostring(citizenid),
        class = class or '',
        vips = vips or {},
        displayName = displayName or '',
    }))
    return true
end

local function saveDiscordLink(citizenid, discord)
    local previous = DiscordLinks[citizenid]
    if previous == discord then return end
    if previous then emitSync(previous, citizenid, '', {}, '') end
    DiscordLinks[citizenid] = discord
    SaveResourceFile(RESOURCE, LINK_FILE, json.encode(DiscordLinks), -1)
end

local function syncPlayer(source)
    if RoleSync.Enabled == false or GetConvar('ob_discord_role_sync_enabled', 'true') ~= 'true' then return false end
    source = tonumber(source)
    if not source or GetPlayerPing(source) <= 0 then return false end

    local player = exports.qbx_core:GetPlayer(source)
    if not player or not player.PlayerData or not player.PlayerData.citizenid then return false end
    local discord = discordId(source)
    if discord == '' then
        print(('[%s] Cargos nao sincronizados: Discord ausente no jogador %s.'):format(RESOURCE, source))
        return false
    end
    local citizenid = tostring(player.PlayerData.citizenid)
    saveDiscordLink(citizenid, discord)
    return emitSync(
        discord,
        citizenid,
        getClass(source, citizenid, player),
        getVips(citizenid),
        firstCharacterName(source, citizenid, player)
    )
end

local function syncAll()
    if GetResourceState('qbx_core') ~= 'started' then return end
    for source in pairs(exports.qbx_core:GetQBPlayers()) do
        syncPlayer(tonumber(source))
    end
end

CreateThread(function()
    local seconds = math.max(60, math.floor(tonumber(RoleSync.ReconcileSeconds) or 300))
    while true do
        Wait(seconds * 1000)
        syncAll()
    end
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if not player or not player.PlayerData then return end
    local source = tonumber(player.PlayerData.source)
    SetTimeout(1500, function()
        if source and GetPlayerPing(source) > 0 then syncPlayer(source) end
    end)
end)

AddEventHandler('ob_vip:server:membershipChanged', function(citizenid, payload)
    local player = playerByCitizenId(citizenid)
    if player and player.PlayerData then
        syncPlayer(player.PlayerData.source)
        return
    end
    citizenid = tostring(citizenid or '')
    local discord = DiscordLinks[citizenid]
    if discord then
        emitSync(
            discord,
            citizenid,
            getClass(nil, citizenid, nil),
            getVips(citizenid, payload),
            firstCharacterName(nil, citizenid, nil)
        )
    end
end)

AddEventHandler('classeSelector:server:classChanged', function(source)
    SetTimeout(250, function()
        if GetPlayerPing(tonumber(source)) > 0 then syncPlayer(source) end
    end)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE and resourceName ~= (RoleSync.VipResource or 'ob_vip')
        and resourceName ~= (RoleSync.ClassResource or 'classeSelector') then return end
    SetTimeout(2500, syncAll)
end)

exports('SyncDiscordRoles', syncPlayer)
