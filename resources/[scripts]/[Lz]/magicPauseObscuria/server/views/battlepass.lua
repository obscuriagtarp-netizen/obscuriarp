local oxmysql = exports.oxmysql
local battlePassReady = false

local function now()
    return os.time()
end

local function query(sql, params)
    return oxmysql:executeSync(sql, params or {}) or {}
end

local function single(sql, params)
    return oxmysql:singleSync(sql, params or {})
end

local function insert(sql, params)
    return oxmysql:insertSync(sql, params or {}) or 0
end

local function update(sql, params)
    local ok, result = pcall(function()
        return oxmysql:updateSync(sql, params or {})
    end)
    if ok and result ~= nil then return tonumber(result) or 0 end
    result = oxmysql:executeSync(sql, params or {}) or 0
    if type(result) == "number" then return result end
    if type(result) == "table" then return tonumber(result.affectedRows or result.affected_rows) or 0 end
    return 0
end

local function decodeJson(value, fallback)
    if not value or value == "" then return fallback end
    local ok, decoded = pcall(json.decode, value)
    return ok and decoded or fallback
end

local function encodeJson(value)
    if value == nil then return nil end
    return json.encode(value or {})
end

local function ensureBattlePass()
    if battlePassReady then return end
    query([[
        CREATE TABLE IF NOT EXISTS `magic_pause_battlepass_seasons` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `title` VARCHAR(120) NOT NULL DEFAULT 'Battle Pass',
            `subtitle` VARCHAR(220) NOT NULL DEFAULT '',
            `starts_at` BIGINT NOT NULL DEFAULT 0,
            `ends_at` BIGINT NOT NULL DEFAULT 0,
            `premium_price` INT NOT NULL DEFAULT 1000,
            `xp_per_level` INT NOT NULL DEFAULT 1000,
            `active` TINYINT(1) NOT NULL DEFAULT 1,
            `created_at` BIGINT NOT NULL,
            `updated_at` BIGINT NOT NULL,
            PRIMARY KEY (`id`),
            KEY `active_updated` (`active`, `updated_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    query([[
        CREATE TABLE IF NOT EXISTS `magic_pause_battlepass_slots` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `season_id` INT NOT NULL,
            `slot_index` INT NOT NULL,
            `title` VARCHAR(120) NOT NULL DEFAULT '',
            `subtitle` VARCHAR(180) NOT NULL DEFAULT '',
            `image` VARCHAR(255) NOT NULL DEFAULT '',
            `xp_required` INT NOT NULL DEFAULT 0,
            `free_reward` LONGTEXT DEFAULT NULL,
            `premium_reward` LONGTEXT DEFAULT NULL,
            `enabled` TINYINT(1) NOT NULL DEFAULT 1,
            `created_at` BIGINT NOT NULL,
            `updated_at` BIGINT NOT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `season_slot` (`season_id`, `slot_index`),
            KEY `season_order` (`season_id`, `slot_index`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    query([[
        CREATE TABLE IF NOT EXISTS `magic_pause_battlepass_progress` (
            `id` BIGINT NOT NULL AUTO_INCREMENT,
            `passport` VARCHAR(80) NOT NULL,
            `season_id` INT NOT NULL,
            `xp` INT NOT NULL DEFAULT 0,
            `premium` TINYINT(1) NOT NULL DEFAULT 0,
            `claimed_free` LONGTEXT DEFAULT NULL,
            `claimed_premium` LONGTEXT DEFAULT NULL,
            `updated_at` BIGINT NOT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `passport_season` (`passport`, `season_id`),
            KEY `season_xp` (`season_id`, `xp`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    battlePassReady = true
end

local function seedSeasonSlots(season)
    if not season then return end
    local total = single("SELECT COUNT(*) AS count FROM magic_pause_battlepass_slots WHERE season_id = ?", { season.id }) or {}
    if (tonumber(total.count) or 0) > 0 then return end

    local cfg = Config.BattlePass or {}
    local xpPerLevel = math.max(1, tonumber(season.xp_per_level) or tonumber(cfg.defaultXpPerLevel) or 1000)
    local ts = now()

    for index, slot in ipairs(cfg.initialSlots or {}) do
        insert([[
            INSERT INTO magic_pause_battlepass_slots(season_id, slot_index, title, subtitle, image, xp_required, free_reward, premium_reward, enabled, created_at, updated_at)
            VALUES(?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
        ]], {
            season.id,
            index,
            tostring(slot.title or ("Etapa " .. index)):sub(1, 120),
            tostring(slot.subtitle or ""):sub(1, 180),
            tostring(slot.image or ""):sub(1, 255),
            math.max(0, math.floor(tonumber(slot.xpRequired) or ((index - 1) * xpPerLevel))),
            slot.freeReward and json.encode(slot.freeReward) or nil,
            slot.premiumReward and json.encode(slot.premiumReward) or nil,
            ts,
            ts
        })
    end
end

local function activeSeason()
    ensureBattlePass()
    local row = single("SELECT * FROM magic_pause_battlepass_seasons WHERE active = 1 ORDER BY updated_at DESC, id DESC LIMIT 1")
    if row then
        seedSeasonSlots(row)
        return row
    end

    local cfg = Config.BattlePass or {}
    local ts = now()
    local id = insert([[
        INSERT INTO magic_pause_battlepass_seasons(title, subtitle, starts_at, ends_at, premium_price, xp_per_level, active, created_at, updated_at)
        VALUES(?, ?, ?, ?, ?, ?, 1, ?, ?)
    ]], {
        cfg.defaultTitle or "Battle Pass",
        cfg.defaultSubtitle or "Initial season",
        ts,
        ts + ((tonumber(cfg.defaultDurationDays) or 30) * 86400),
        tonumber(cfg.defaultPremiumPrice) or 1000,
        tonumber(cfg.defaultXpPerLevel) or 1000,
        ts,
        ts
    })

    row = single("SELECT * FROM magic_pause_battlepass_seasons WHERE id = ? LIMIT 1", { id })
    seedSeasonSlots(row)
    return row
end

local function ensureProgress(src, seasonId)
    local passport = Utils.getPassport(src)
    local row = single("SELECT * FROM magic_pause_battlepass_progress WHERE passport = ? AND season_id = ? LIMIT 1", { passport, seasonId })
    if row then return row end

    insert([[
        INSERT INTO magic_pause_battlepass_progress(passport, season_id, xp, premium, claimed_free, claimed_premium, updated_at)
        VALUES(?, ?, 0, 0, '[]', '[]', ?)
    ]], { passport, seasonId, now() })

    return single("SELECT * FROM magic_pause_battlepass_progress WHERE passport = ? AND season_id = ? LIMIT 1", { passport, seasonId })
end

local function rewardPayload(value)
    local reward = decodeJson(value, nil)
    if type(reward) ~= "table" then return nil end
    reward.type = tostring(reward.type or "item")
    reward.amount = math.max(1, math.floor(tonumber(reward.amount) or 1))
    reward.label = tostring(reward.label or reward.item or reward.command or "Reward")
    reward.image = tostring(reward.image or "")
    reward.description = tostring(reward.description or "")
    return reward
end

local function slotPayload(row)
    return {
        id = tonumber(row.id),
        seasonId = tonumber(row.season_id),
        index = tonumber(row.slot_index) or 1,
        title = row.title or "",
        subtitle = row.subtitle or "",
        image = row.image or "",
        xpRequired = tonumber(row.xp_required) or 0,
        enabled = row.enabled == true or row.enabled == 1 or row.enabled == "1",
        freeReward = rewardPayload(row.free_reward),
        premiumReward = rewardPayload(row.premium_reward)
    }
end

local function slotRows(seasonId)
    local cfg = Config.BattlePass or {}
    local limit = math.max(1, math.min(tonumber(cfg.maxSlotsLoaded) or 250, 500))
    local rows = {}
    for _, row in ipairs(query("SELECT * FROM magic_pause_battlepass_slots WHERE season_id = ? ORDER BY slot_index ASC LIMIT " .. limit, { seasonId })) do
        rows[#rows + 1] = slotPayload(row)
    end
    return rows
end

local function claimedMap(value)
    local list = decodeJson(value, {}) or {}
    local map = {}
    for _, id in ipairs(list) do map[tostring(id)] = true end
    return map, list
end

local function progressPayload(row, season)
    local xp = tonumber(row.xp) or 0
    local xpPerLevel = math.max(1, tonumber(season.xp_per_level) or 1000)
    return {
        xp = xp,
        level = math.floor(xp / xpPerLevel) + 1,
        premium = row.premium == true or row.premium == 1 or row.premium == "1",
        claimedFree = decodeJson(row.claimed_free, {}) or {},
        claimedPremium = decodeJson(row.claimed_premium, {}) or {}
    }
end

local function buildPayload(src)
    local season = activeSeason()
    if not season then
        return {
            isAdmin = Utils.isStaff(src),
            season = nil,
            slots = {},
            progress = {},
            locale = Utils.localePayload(),
            theme = Config.Theme or {}
        }
    end

    local progress = ensureProgress(src, season.id)
    return {
        isAdmin = Utils.isStaff(src),
        balance = Utils.getCoins(src),
        locale = Utils.localePayload(),
        theme = Config.Theme or {},
        config = Config.BattlePass or {},
        season = {
            id = tonumber(season.id),
            title = season.title,
            subtitle = season.subtitle,
            startsAt = tonumber(season.starts_at) or 0,
            endsAt = tonumber(season.ends_at) or 0,
            premiumPrice = tonumber(season.premium_price) or 0,
            xpPerLevel = tonumber(season.xp_per_level) or 1000,
            active = season.active == true or season.active == 1 or season.active == "1"
        },
        slots = slotRows(season.id),
        progress = progressPayload(progress, season)
    }
end

local function respond(src, token, ok, message, extra)
    local payload = extra or {}
    payload.ok = ok == true
    payload.message = message or Utils.t(payload.ok and "common.success" or "common.error")
    payload.payload = buildPayload(src)
    TriggerClientEvent("MagicPause:client:serverResponse", src, token, payload)
end

local function sanitizeReward(data)
    if type(data) ~= "table" then return nil end
    local rewardType = tostring(data.type or "item"):lower()
    local allowed = { item = true, coins = true, money = true, command = true, none = true }
    if not allowed[rewardType] then rewardType = "item" end
    local item = tostring(data.item or ""):sub(1, 120)
    local command = tostring(data.command or ""):sub(1, 240)
    local label = tostring(data.label or item or command or "Reward"):sub(1, 120)
    if rewardType == "none" then item, command = "", "" end
    if rewardType == "item" and item == "" then return nil end
    if rewardType == "command" and command == "" then return nil end
    return {
        type = rewardType,
        label = label,
        item = item,
        command = command,
        amount = math.max(1, math.floor(tonumber(data.amount) or 1)),
        image = tostring(data.image or ""):sub(1, 255),
        description = tostring(data.description or ""):sub(1, 220)
    }
end

local function deliverReward(src, reward)
    if type(reward) ~= "table" then return false end
    local rewardType = tostring(reward.type or "item")
    local amount = math.max(1, math.floor(tonumber(reward.amount) or 1))

    if rewardType == "none" then return true end
    if rewardType == "coins" then return Utils.addCoins(src, amount, "battlepass_reward") end
    if rewardType == "money" then return Utils.addMoney(src, "bank", amount, "battlepass_reward") end
    if rewardType == "item" then return Utils.giveItem(src, reward.item, amount, reward.metadata) end
    if rewardType == "command" then
        local command = tostring(reward.command or "")
        command = command:gsub("{source}", tostring(src)):gsub("{passport}", tostring(Utils.getPassport(src))):gsub("{amount}", tostring(amount))
        ExecuteCommand(command)
        return true
    end

    return false
end

RegisterNetEvent("MagicPause:server:getBattlePass", function(token)
    local src = source
    TriggerClientEvent("MagicPause:client:serverResponse", src, token, buildPayload(src))
end)

RegisterNetEvent("MagicPause:server:saveBattlePassSeason", function(token, data)
    local src = source
    if not Utils.isStaff(src) then return respond(src, token, false, "No permission.") end
    local season = activeSeason()
    if not season then return respond(src, token, false, Utils.t("battlepass.noSeason")) end
    data = data or {}
    update([[
        UPDATE magic_pause_battlepass_seasons
        SET title = ?, subtitle = ?, starts_at = ?, ends_at = ?, premium_price = ?, xp_per_level = ?, active = ?, updated_at = ?
        WHERE id = ?
    ]], {
        tostring(data.title or season.title or "Battle Pass"):sub(1, 120),
        tostring(data.subtitle or season.subtitle or ""):sub(1, 220),
        math.max(0, math.floor(tonumber(data.startsAt) or tonumber(season.starts_at) or 0)),
        math.max(0, math.floor(tonumber(data.endsAt) or tonumber(season.ends_at) or 0)),
        math.max(0, math.floor(tonumber(data.premiumPrice) or tonumber(season.premium_price) or 0)),
        math.max(1, math.floor(tonumber(data.xpPerLevel) or tonumber(season.xp_per_level) or 1000)),
        data.active == false and 0 or 1,
        now(),
        season.id
    })
    respond(src, token, true, Utils.t("battlepass.seasonSaved"))
end)

RegisterNetEvent("MagicPause:server:setBattlePassSlotCount", function(token, data)
    local src = source
    if not Utils.isStaff(src) then return respond(src, token, false, "No permission.") end
    local season = activeSeason()
    if not season then return respond(src, token, false, Utils.t("battlepass.noSeason")) end

    local cfg = Config.BattlePass or {}
    local count = math.max(1, math.min(math.floor(tonumber(data and data.count) or 1), tonumber(cfg.maxSlots) or 200))
    local xpPerLevel = math.max(1, tonumber(season.xp_per_level) or tonumber(cfg.defaultXpPerLevel) or 1000)
    local ts = now()

    for index = 1, count do
        insert([[
            INSERT INTO magic_pause_battlepass_slots(season_id, slot_index, title, subtitle, xp_required, free_reward, premium_reward, enabled, created_at, updated_at)
            VALUES(?, ?, ?, '', ?, NULL, NULL, 1, ?, ?)
            ON DUPLICATE KEY UPDATE enabled = VALUES(enabled), updated_at = VALUES(updated_at)
        ]], { season.id, index, ("Slot %s"):format(index), (index - 1) * xpPerLevel, ts, ts })
    end

    update("DELETE FROM magic_pause_battlepass_slots WHERE season_id = ? AND slot_index > ?", { season.id, count })
    respond(src, token, true, Utils.t("battlepass.slotsUpdated"))
end)

RegisterNetEvent("MagicPause:server:saveBattlePassSlot", function(token, data)
    local src = source
    if not Utils.isStaff(src) then return respond(src, token, false, "No permission.") end
    local season = activeSeason()
    if not season then return respond(src, token, false, Utils.t("battlepass.noSeason")) end
    data = data or {}

    local index = math.max(1, math.floor(tonumber(data.index) or 1))
    local cfg = Config.BattlePass or {}
    if index > (tonumber(cfg.maxSlots) or 200) then return respond(src, token, false, "Invalid slot.") end

    insert([[
        INSERT INTO magic_pause_battlepass_slots(season_id, slot_index, title, subtitle, image, xp_required, free_reward, premium_reward, enabled, created_at, updated_at)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            title = VALUES(title),
            subtitle = VALUES(subtitle),
            image = VALUES(image),
            xp_required = VALUES(xp_required),
            free_reward = VALUES(free_reward),
            premium_reward = VALUES(premium_reward),
            enabled = VALUES(enabled),
            updated_at = VALUES(updated_at)
    ]], {
        season.id,
        index,
        tostring(data.title or ("Slot " .. index)):sub(1, 120),
        tostring(data.subtitle or ""):sub(1, 180),
        tostring(data.image or ""):sub(1, 255),
        math.max(0, math.floor(tonumber(data.xpRequired) or 0)),
        encodeJson(sanitizeReward(data.freeReward)),
        encodeJson(sanitizeReward(data.premiumReward)),
        data.enabled == false and 0 or 1,
        now(),
        now()
    })

    respond(src, token, true, Utils.t("battlepass.slotSaved"))
end)

RegisterNetEvent("MagicPause:server:buyBattlePassPremium", function(token)
    local src = source
    local season = activeSeason()
    if not season then return respond(src, token, false, Utils.t("battlepass.noSeason")) end
    local progress = ensureProgress(src, season.id)
    if progress.premium == true or progress.premium == 1 or progress.premium == "1" then
        return respond(src, token, true, Utils.t("battlepass.premiumOwned"))
    end

    local price = math.max(0, math.floor(tonumber(season.premium_price) or 0))
    if price > 0 and not Utils.removeCoins(src, price, "battlepass_premium") then
        return respond(src, token, false, Utils.t("battlepass.notEnoughCoins"))
    end

    update("UPDATE magic_pause_battlepass_progress SET premium = 1, updated_at = ? WHERE passport = ? AND season_id = ?", {
        now(),
        Utils.getPassport(src),
        season.id
    })
    respond(src, token, true, Utils.t("battlepass.premiumBought"))
end)

RegisterNetEvent("MagicPause:server:claimBattlePassReward", function(token, data)
    local src = source
    local season = activeSeason()
    if not season then return respond(src, token, false, Utils.t("battlepass.noSeason")) end
    data = data or {}
    local track = tostring(data.track or "free")
    if track ~= "free" and track ~= "premium" then track = "free" end

    local slot = single("SELECT * FROM magic_pause_battlepass_slots WHERE season_id = ? AND slot_index = ? AND enabled = 1 LIMIT 1", {
        season.id,
        math.floor(tonumber(data.index) or 0)
    })
    if not slot then return respond(src, token, false, "Invalid slot.") end

    local progress = ensureProgress(src, season.id)
    if (tonumber(progress.xp) or 0) < (tonumber(slot.xp_required) or 0) then
        return respond(src, token, false, Utils.t("battlepass.lockedReward"))
    end
    if track == "premium" and not (progress.premium == true or progress.premium == 1 or progress.premium == "1") then
        return respond(src, token, false, Utils.t("battlepass.premiumRequired"))
    end

    local column = track == "premium" and "claimed_premium" or "claimed_free"
    local map, list = claimedMap(progress[column])
    local slotKey = tostring(slot.slot_index)
    if map[slotKey] then return respond(src, token, true, Utils.t("battlepass.rewardClaimed")) end

    local reward = rewardPayload(track == "premium" and slot.premium_reward or slot.free_reward)
    if not reward then return respond(src, token, false, Utils.t("battlepass.emptyReward")) end
    if not deliverReward(src, reward) then return respond(src, token, false, Utils.t("common.error")) end

    list[#list + 1] = tonumber(slot.slot_index)
    update(("UPDATE magic_pause_battlepass_progress SET %s = ?, updated_at = ? WHERE passport = ? AND season_id = ?"):format(column), {
        encodeJson(list),
        now(),
        Utils.getPassport(src),
        season.id
    })

    respond(src, token, true, Utils.t("battlepass.rewardClaimed"))
end)

exports("AddBattlePassXp", function(src, amount)
    src = tonumber(src)
    amount = math.floor(math.abs(tonumber(amount) or 0))
    if not src or amount <= 0 then return false end
    local season = activeSeason()
    if not season then return false end
    ensureProgress(src, season.id)
    update("UPDATE magic_pause_battlepass_progress SET xp = xp + ?, updated_at = ? WHERE passport = ? AND season_id = ?", {
        amount,
        now(),
        Utils.getPassport(src),
        season.id
    })
    return true
end)
