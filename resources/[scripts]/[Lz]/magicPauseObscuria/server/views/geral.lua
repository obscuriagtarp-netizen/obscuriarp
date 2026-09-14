local oxmysql = exports.oxmysql
local SessionJoin = {}
local playtimeReady = false

local function ensurePlaytimeTable()
    if playtimeReady then return end
    oxmysql:executeSync([[
        CREATE TABLE IF NOT EXISTS `playtime` (
            `passport` VARCHAR(80) NOT NULL,
            `total_seconds` INT NOT NULL DEFAULT 0,
            `last_join_ts` BIGINT DEFAULT NULL,
            `updated_at` BIGINT NOT NULL DEFAULT 0,
            PRIMARY KEY (`passport`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    pcall(function()
        oxmysql:executeSync("ALTER TABLE `playtime` MODIFY COLUMN `passport` VARCHAR(80) NOT NULL")
    end)
    playtimeReady = true
end

local function mapGender(value)
    if value == nil then return "Indefinido" end
    if type(value) == "number" then
        return value == 0 and "Masculino" or value == 1 and "Feminino" or "Indefinido"
    end

    local text = tostring(value):lower()
    if text == "m" or text == "male" or text == "masculino" then return "Masculino" end
    if text == "f" or text == "female" or text == "feminino" then return "Feminino" end
    return tostring(value)
end

local function formatPlaytime(totalSeconds)
    totalSeconds = math.max(0, tonumber(totalSeconds) or 0)
    return ("%dh"):format(math.floor(totalSeconds / 3600))
end

local function ensurePlayRow(identifier)
    ensurePlaytimeTable()
    oxmysql:insertSync([[
        INSERT INTO playtime (passport, total_seconds, last_join_ts, updated_at)
        VALUES (?, 0, NULL, ?)
        ON DUPLICATE KEY UPDATE updated_at = VALUES(updated_at)
    ]], { identifier, os.time() })
end

local function getPlaySeconds(identifier)
    local row = oxmysql:singleSync("SELECT total_seconds, last_join_ts FROM playtime WHERE passport = ? LIMIT 1", { identifier })
    if not row then
        ensurePlayRow(identifier)
        return 0, nil
    end
    return tonumber(row.total_seconds) or 0, tonumber(row.last_join_ts)
end

local function startSession(identifier)
    if not identifier then return end
    ensurePlayRow(identifier)
    local now = os.time()
    SessionJoin[identifier] = now
    oxmysql:updateSync("UPDATE playtime SET last_join_ts = ?, updated_at = ? WHERE passport = ?", { now, now, identifier })
end

local function stopSession(identifier, keepJoin)
    if not identifier then return end
    local now = os.time()
    local join = SessionJoin[identifier]

    if not join then
        local _, dbJoin = getPlaySeconds(identifier)
        join = dbJoin
    end

    if join and join > 0 then
        local delta = math.max(0, now - join)
        if keepJoin then
            oxmysql:updateSync([[
                UPDATE playtime
                SET total_seconds = total_seconds + ?, last_join_ts = ?, updated_at = ?
                WHERE passport = ?
            ]], { delta, now, now, identifier })
            SessionJoin[identifier] = now
        else
            oxmysql:updateSync([[
                UPDATE playtime
                SET total_seconds = total_seconds + ?, last_join_ts = NULL, updated_at = ?
                WHERE passport = ?
            ]], { delta, now, identifier })
            SessionJoin[identifier] = nil
        end
    elseif not keepJoin then
        SessionJoin[identifier] = nil
    end
end

local function toKilograms(value)
    return math.floor(((tonumber(value) or 0) / 1000) * 10 + 0.5) / 10
end

local function getInventoryStats(src)
    local current, max, itemCount = 0, 0, 0
    if GetResourceState("ox_inventory") == "started" then
        local ok, inventory = pcall(function()
            return exports.ox_inventory:GetInventory(src)
        end)

        if ok and type(inventory) == "table" then
            current = tonumber(inventory.weight) or 0
            max = tonumber(inventory.maxWeight) or 0
            for _, item in pairs(inventory.items or {}) do
                itemCount = itemCount + math.max(0, math.floor(tonumber(item.count) or 0))
            end
        end
    end

    return toKilograms(current), toKilograms(max), itemCount
end

local function normalizeClassId(value)
    if type(value) == "table" then
        value = value.id or value.name or value.class
    end
    value = tostring(value or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    return value ~= "" and value or nil
end

local function getPlayerClass(src, identifier)
    local cfg = Config.PlayerClass or {}
    local player = Utils.getPlayer(src)
    local metadata = player and player.PlayerData and player.PlayerData.metadata or {}
    local classId = normalizeClassId(metadata[cfg.metadataKey or "classe"] or metadata.class)
    local classInfo

    local selectorResource = tostring(cfg.selectorResource or "classeSelector")
    if GetResourceState(selectorResource) == "started" then
        local ok, result = pcall(function()
            return exports[selectorResource]:GetPlayerClassInfo(src)
        end)
        if ok and type(result) == "table" then
            classInfo = result
            classId = normalizeClassId(result.id) or classId
        end
    end

    if not classId and identifier then
        local tableName = tostring(cfg.databaseTable or "classe_selector")
        if tableName:match("^[%w_]+$") then
            local ok, storedClass = pcall(function()
                return oxmysql:scalarSync(
                    ("SELECT `class` FROM `%s` WHERE `citizenid` = ? LIMIT 1"):format(tableName),
                    { identifier }
                )
            end)
            if ok then classId = normalizeClassId(storedClass) end
        end
    end

    local definition = classInfo or (cfg.definitions or {})[classId or ""]
    if not classId then
        return "Sem Classe", "Indefinido", "Indefinido"
    end

    return definition and definition.label or classId,
        definition and definition.affinity or "Indefinido",
        definition and definition.weakness or "Indefinido"
end

local function countVehicles(identifier)
    local tables = (Config.VehicleCountTables or {
        { table = "player_vehicles", column = "citizenid" },
        { table = "vehicles", column = "Passport" }
    })

    for _, cfg in ipairs(tables) do
        local tableName = tostring(cfg.table or "")
        local column = tostring(cfg.column or "")
        if tableName ~= "" and column ~= "" then
            local ok, row = pcall(function()
                return oxmysql:singleSync(("SELECT COUNT(*) AS amount FROM `%s` WHERE `%s` = ?"):format(tableName, column), { identifier })
            end)
            if ok and row and row.amount then return tonumber(row.amount) or 0 end
        end
    end

    return 0
end

local function getVipProfile(src)
    if GetResourceState("ob_vip") ~= "started" then return "Nenhum", nil end

    local ok, vip = pcall(function()
        return exports.ob_vip:GetHighestVip(src)
    end)
    if not ok or type(vip) ~= "table" then return "Nenhum", nil end

    return tostring(vip.label or vip.vip or "Nenhum"), tonumber(vip.expiresAt)
end

local function buildPlayerInfo(src)
    local player = Utils.getPlayer(src)
    local playerData = player and player.PlayerData
    local charinfo = playerData and playerData.charinfo
    if type(playerData) ~= "table" or type(charinfo) ~= "table" or not playerData.citizenid then
        return { ok = false, loading = true }
    end

    local identifier = Utils.getPassport(src)
    local identity = Utils.getIdentity(src)
    local job = Utils.getJob(src)
    local gang = Utils.getGang(src)
    local currentWeight, maxWeight, inventoryItems = getInventoryStats(src)
    local classLabel, classAffinity, classWeakness = getPlayerClass(src, identifier)
    local vipTier, vipExpiresAt = getVipProfile(src)
    local runes = Utils.getRunes(src)

    if identifier and not SessionJoin[identifier] then
        startSession(identifier)
    end

    local totalSeconds = 0
    if identifier then
        totalSeconds = getPlaySeconds(identifier)
        local join = SessionJoin[identifier]
        if join and join > 0 then
            totalSeconds = (tonumber(totalSeconds) or 0) + math.max(0, os.time() - join)
        end
    end

    return {
        name = Utils.getName(src),
        passport = identifier or tostring(src),
        gender = mapGender(identity.gender),
        maritalStatus = "Solteiro",
        phone = identity.phone or "N/A",

        wallet = Utils.getMoney(src, "cash"),
        bank = Utils.getMoney(src, "bank"),
        vipMoney = runes,
        runes = runes,

        job = job.label or "Desempregado",
        jobLevel = job.gradeName or job.grade,
        org = gang.name ~= "none" and gang.label or "Nenhuma",

        backpackCurrent = currentWeight,
        backpackMax = maxWeight,
        inventoryItems = inventoryItems,

        houses = 0,
        vehicles = identifier and countVehicles(identifier) or 0,

        vipTier = vipTier,
        vipExpiresAt = vipExpiresAt,
        playTime = formatPlaytime(totalSeconds),
        wantedLevel = 0,

        classLabel = classLabel,
        classAffinity = classAffinity,
        classWeakness = classWeakness,
    }
end

CreateThread(ensurePlaytimeTable)

RegisterNetEvent("MagicPause:server:getPlayerInfo", function(token)
    local src = source
    TriggerClientEvent("MagicPause:client:serverResponse", src, token, buildPlayerInfo(src))
end)

AddEventHandler("QBCore:Server:OnPlayerLoaded", function()
    local src = source
    CreateThread(function()
        Wait(250)
        local identifier = Utils.getPassport(src)
        if identifier then startSession(identifier) end
    end)
end)

AddEventHandler("playerDropped", function()
    local src = source
    local identifier = Utils.getPassport(src)
    if identifier then stopSession(identifier, false) end
end)

CreateThread(function()
    while true do
        Wait(5 * 60 * 1000)
        for identifier in pairs(SessionJoin) do
            stopSession(identifier, true)
        end
    end
end)
