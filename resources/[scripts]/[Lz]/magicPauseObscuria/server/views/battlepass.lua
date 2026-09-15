local oxmysql = exports.oxmysql
local battlePassReady = false
local directJobXpAt = {}
local jobPaymentFallbackAt = {}

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

    query([[
        CREATE TABLE IF NOT EXISTS `magic_pause_battlepass_daily` (
            `id` BIGINT NOT NULL AUTO_INCREMENT,
            `passport` VARCHAR(80) NOT NULL,
            `season_id` INT NOT NULL,
            `day_key` CHAR(10) NOT NULL,
            `login_claimed` TINYINT(1) NOT NULL DEFAULT 0,
            `login_streak` INT NOT NULL DEFAULT 0,
            `jobs_xp` INT NOT NULL DEFAULT 0,
            `money_spent` INT NOT NULL DEFAULT 0,
            `money_claimed` TINYINT(1) NOT NULL DEFAULT 0,
            `runes_spent` INT NOT NULL DEFAULT 0,
            `runes_claimed` TINYINT(1) NOT NULL DEFAULT 0,
            `updated_at` BIGINT NOT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `passport_season_day` (`passport`, `season_id`, `day_key`),
            KEY `season_day` (`season_id`, `day_key`)
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

local function isEnabled(value)
    return value == true or value == 1 or value == "1"
end

local function dayKey(timestamp)
    return os.date("%Y-%m-%d", timestamp or now())
end

local function nextDayTimestamp()
    local date = os.date("*t", now())
    date.hour, date.min, date.sec = 0, 0, 0
    return os.time(date) + 86400
end

local function missionSettings()
    local cfg = Config.BattlePass or {}
    return cfg.missions or {}
end

local function ensureDailyProgress(src, seasonId)
    local passport = Utils.getPassport(src)
    local today = dayKey()
    insert([[
        INSERT IGNORE INTO magic_pause_battlepass_daily(
            passport, season_id, day_key, login_claimed, login_streak, jobs_xp,
            money_spent, money_claimed, runes_spent, runes_claimed, updated_at
        ) VALUES(?, ?, ?, 0, 0, 0, 0, 0, 0, 0, ?)
    ]], { passport, seasonId, today, now() })

    return single([[
        SELECT * FROM magic_pause_battlepass_daily
        WHERE passport = ? AND season_id = ? AND day_key = ? LIMIT 1
    ]], { passport, seasonId, today })
end

local function seasonMaxXp(seasonId)
    local row = single([[
        SELECT MAX(xp_required) AS max_xp
        FROM magic_pause_battlepass_slots
        WHERE season_id = ? AND enabled = 1
    ]], { seasonId }) or {}
    return math.max(0, math.floor(tonumber(row.max_xp) or 0))
end

local function isPassComplete(progress, seasonId)
    local maxXp = seasonMaxXp(seasonId)
    return maxXp <= 0 or (tonumber(progress and progress.xp) or 0) >= maxXp, maxXp
end

local function grantXp(src, season, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 or not season then return 0 end

    local progress = ensureProgress(src, season.id)
    local completed, maxXp = isPassComplete(progress, season.id)
    if completed then return 0 end

    local currentXp = math.max(0, math.floor(tonumber(progress.xp) or 0))
    local granted = math.min(amount, math.max(0, maxXp - currentXp))
    if granted <= 0 then return 0 end

    update([[
        UPDATE magic_pause_battlepass_progress
        SET xp = LEAST(?, xp + ?), updated_at = ?
        WHERE passport = ? AND season_id = ?
    ]], { maxXp, granted, now(), Utils.getPassport(src), season.id })
    return granted
end

local function previousLoginStreak(src, seasonId)
    local previous = single([[
        SELECT login_streak
        FROM magic_pause_battlepass_daily
        WHERE passport = ? AND season_id = ? AND day_key = ? AND login_claimed = 1
        LIMIT 1
    ]], { Utils.getPassport(src), seasonId, dayKey(now() - 86400) })
    return math.max(0, math.floor(tonumber(previous and previous.login_streak) or 0))
end

local function missionPayload(src, season, progress)
    local settings = missionSettings()
    local daily = ensureDailyProgress(src, season.id) or {}
    local completed, maxXp = isPassComplete(progress, season.id)
    local login = settings.login or {}
    local jobs = settings.jobs or {}
    local money = settings.money or {}
    local runes = settings.runes or {}

    local loginClaimed = isEnabled(daily.login_claimed)
    local streak = loginClaimed and (tonumber(daily.login_streak) or 0) or previousLoginStreak(src, season.id)
    local streakDays = math.max(1, math.floor(tonumber(login.streakDays) or 30))
    local nextStreak = loginClaimed and streak or ((streak % streakDays) + 1)
    local moneyTarget = math.max(1, math.floor(tonumber(money.target) or 20000))
    local runesTarget = math.max(1, math.floor(tonumber(runes.target) or 200))

    return {
        locked = completed,
        maxXp = maxXp,
        day = daily.day_key or dayKey(),
        resetsAt = nextDayTimestamp(),
        login = {
            enabled = login.enabled ~= false,
            claimed = loginClaimed,
            canClaim = not completed and login.enabled ~= false and not loginClaimed,
            streak = math.max(0, math.floor(streak)),
            nextStreak = math.max(1, math.floor(nextStreak)),
            streakDays = streakDays,
            dailyXp = math.max(0, math.floor(tonumber(login.dailyXp) or 1000)),
            streakBonusXp = math.max(0, math.floor(tonumber(login.streakBonusXp) or 5000))
        },
        jobs = {
            enabled = jobs.enabled ~= false,
            progress = math.max(0, math.floor(tonumber(daily.jobs_xp) or 0)),
            cap = math.max(1, math.floor(tonumber(jobs.dailyXpCap) or 5000))
        },
        money = {
            enabled = money.enabled ~= false,
            progress = math.min(moneyTarget, math.max(0, math.floor(tonumber(daily.money_spent) or 0))),
            target = moneyTarget,
            rewardXp = math.max(0, math.floor(tonumber(money.rewardXp) or 3500)),
            claimed = isEnabled(daily.money_claimed),
            canClaim = not completed and money.enabled ~= false and not isEnabled(daily.money_claimed)
                and (tonumber(daily.money_spent) or 0) >= moneyTarget
        },
        runes = {
            enabled = runes.enabled ~= false,
            progress = math.min(runesTarget, math.max(0, math.floor(tonumber(daily.runes_spent) or 0))),
            target = runesTarget,
            rewardXp = math.max(0, math.floor(tonumber(runes.rewardXp) or 5000)),
            claimed = isEnabled(daily.runes_claimed),
            canClaim = not completed and runes.enabled ~= false and not isEnabled(daily.runes_claimed)
                and (tonumber(daily.runes_spent) or 0) >= runesTarget
        }
    }
end

local function accountAllowed(accounts, account)
    if type(accounts) ~= "table" then return account == "cash" or account == "bank" end
    if accounts[account] == true then return true end
    for _, value in ipairs(accounts) do
        if tostring(value) == account then return true end
    end
    return false
end

local function trackDailySpend(src, kind, amount)
    src = tonumber(src)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if not src or amount <= 0 then return false end

    local season = activeSeason()
    if not season then return false end
    local progress = ensureProgress(src, season.id)
    if isPassComplete(progress, season.id) then return false end

    local settings = missionSettings()[kind] or {}
    if settings.enabled == false then return false end
    local daily = ensureDailyProgress(src, season.id)
    if not daily then return false end

    local column = kind == "runes" and "runes_spent" or "money_spent"
    local target = math.max(1, math.floor(tonumber(settings.target) or (kind == "runes" and 200 or 20000)))
    update(([[
        UPDATE magic_pause_battlepass_daily
        SET %s = LEAST(?, %s + ?), updated_at = ?
        WHERE id = ?
    ]]):format(column, column), { target, amount, now(), daily.id })
    return true
end

local function addJobMissionXp(src, amount)
    src = tonumber(src)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if not src or amount <= 0 then return 0 end

    local settings = missionSettings().jobs or {}
    if settings.enabled == false then return 0 end
    local season = activeSeason()
    if not season then return 0 end
    local progress = ensureProgress(src, season.id)
    if isPassComplete(progress, season.id) then return 0 end

    local daily = ensureDailyProgress(src, season.id)
    if not daily then return 0 end
    local cap = math.max(1, math.floor(tonumber(settings.dailyXpCap) or 5000))
    local available = math.max(0, cap - math.max(0, math.floor(tonumber(daily.jobs_xp) or 0)))
    local granted = grantXp(src, season, math.min(amount, available))
    if granted <= 0 then return 0 end

    update([[
        UPDATE magic_pause_battlepass_daily
        SET jobs_xp = LEAST(?, jobs_xp + ?), updated_at = ?
        WHERE id = ?
    ]], { cap, granted, now(), daily.id })
    return granted
end

local function rewardPayload(value)
    local reward = decodeJson(value, nil)
    if type(reward) ~= "table" then return nil end
    reward.type = tostring(reward.type or "item")
    reward.amount = math.max(1, math.floor(tonumber(reward.amount) or 1))
    reward.label = tostring(reward.label or reward.item or reward.command or "Reward")
    reward.image = tostring(reward.image or "")
    reward.description = tostring(reward.description or "")
    if reward.type == "vehicle" then
        reward.model = tostring(reward.model or ""):lower()
        reward.durationDays = math.max(1, math.min(3650, math.floor(tonumber(reward.durationDays) or 30)))
        reward.renewalRunes = math.max(0, math.floor(tonumber(reward.renewalRunes) or 150))
        reward.garage = tostring(reward.garage or "")
    end
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
    local progressData = progressPayload(progress, season)
    local missions = missionPayload(src, season, progress)
    progressData.completed = missions.locked
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
        progress = progressData,
        missions = missions
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
    local allowed = { item = true, coins = true, money = true, command = true, vehicle = true, none = true }
    if not allowed[rewardType] then rewardType = "item" end
    local item = tostring(data.item or ""):sub(1, 120)
    local command = tostring(data.command or ""):sub(1, 240)
    local model = tostring(data.model or ""):lower():gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 80)
    local label = tostring(data.label or item or command or model or "Reward"):sub(1, 120)
    if rewardType == "none" then item, command = "", "" end
    if rewardType == "item" and item == "" then return nil end
    if rewardType == "command" and command == "" then return nil end
    if rewardType == "vehicle" and model == "" then return nil end
    local durationDays = math.max(1, math.min(3650, math.floor(tonumber(data.durationDays) or 30)))
    local description = tostring(data.description or ""):sub(1, 220)
    if rewardType == "vehicle" and description == "" then
        description = ("Veiculo temporario por %d dias."):format(durationDays)
    end
    return {
        type = rewardType,
        label = label,
        item = item,
        command = command,
        model = model,
        amount = math.max(1, math.floor(tonumber(data.amount) or 1)),
        image = tostring(data.image or ""):sub(1, 255),
        description = description,
        durationDays = durationDays,
        renewalRunes = math.max(0, math.floor(tonumber(data.renewalRunes) or 150)),
        garage = tostring(data.garage or ""):gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 80)
    }
end

local function deliverReward(src, reward, context)
    if type(reward) ~= "table" then return false end
    local rewardType = tostring(reward.type or "item")
    local amount = math.max(1, math.floor(tonumber(reward.amount) or 1))

    if rewardType == "none" then return true end
    if rewardType == "coins" then return Utils.addCoins(src, amount, "battlepass_reward") end
    if rewardType == "money" then return Utils.addMoney(src, "bank", amount, "battlepass_reward") end
    if rewardType == "item" then return Utils.giveItem(src, reward.item, amount, reward.metadata) end
    if rewardType == "vehicle" then
        if GetResourceState("ob_vip") ~= "started" then return false end
        context = type(context) == "table" and context or {}
        local sourceId = ("season:%s:slot:%s:%s"):format(
            tostring(context.seasonId or "unknown"),
            tostring(context.slotIndex or "unknown"),
            tostring(context.track or "free")
        )
        local called, granted, result = pcall(function()
            return exports.ob_vip:GrantRentalVehicle(src, {
                model = reward.model,
                durationDays = reward.durationDays,
                renewalRunes = reward.renewalRunes,
                garage = reward.garage,
                sourceKind = "battlepass",
                sourceId = sourceId,
            })
        end)
        if not called or granted ~= true then
            print(("^1[magicPauseObscuria] Falha ao entregar veiculo do passe: %s^7"):format(
                tostring(called and result and result.error or result or granted)
            ))
            return false
        end
        return true
    end
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
    if price > 0 then trackDailySpend(src, "runes", price) end
    respond(src, token, true, Utils.t("battlepass.premiumBought"))
end)

RegisterNetEvent("MagicPause:server:buyBattlePassLevels", function(token, data)
    local src = source
    local season = activeSeason()
    if not season then return respond(src, token, false, Utils.t("battlepass.noSeason")) end

    local cfg = Config.BattlePass or {}
    local purchase = cfg.levelPurchase or {}
    if purchase.enabled == false then
        return respond(src, token, false, "A compra de níveis está desativada.")
    end

    local progress = ensureProgress(src, season.id)
    if not isEnabled(progress.premium) then
        return respond(src, token, false, "Compre o Passe Premium antes de comprar níveis.")
    end

    local completed, maxXp = isPassComplete(progress, season.id)
    if completed then
        return respond(src, token, false, "O Passe de Batalha já foi concluído.")
    end

    local maxPerPurchase = math.max(1, math.floor(tonumber(purchase.maxPerPurchase) or 25))
    local requested = math.max(1, math.min(maxPerPurchase, math.floor(tonumber(data and data.amount) or 1)))
    local xpPerLevel = math.max(1, math.floor(tonumber(season.xp_per_level) or tonumber(cfg.defaultXpPerLevel) or 1000))
    local remainingXp = math.max(0, maxXp - math.max(0, math.floor(tonumber(progress.xp) or 0)))
    local availableLevels = math.max(1, math.ceil(remainingXp / xpPerLevel))
    local levels = math.min(requested, availableLevels)
    local pricePerLevel = math.max(0, math.floor(tonumber(purchase.pricePerLevel) or 100))
    local price = pricePerLevel * levels

    if price > 0 and not Utils.removeCoins(src, price, "battlepass_levels") then
        return respond(src, token, false, Utils.t("battlepass.notEnoughCoins"))
    end

    local granted = grantXp(src, season, levels * xpPerLevel)
    if granted <= 0 then
        if price > 0 then Utils.addCoins(src, price, "battlepass_levels_refund") end
        return respond(src, token, false, "Não foi possível aplicar os níveis agora.")
    end

    if price > 0 then trackDailySpend(src, "runes", price) end
    local levelsGranted = math.max(1, math.ceil(granted / xpPerLevel))
    respond(src, token, true, ("%s nível(is) comprado(s) por %s Runas."):format(levelsGranted, price))
end)

RegisterNetEvent("MagicPause:server:claimBattlePassMission", function(token, data)
    local src = source
    local season = activeSeason()
    if not season then return respond(src, token, false, Utils.t("battlepass.noSeason")) end

    local progress = ensureProgress(src, season.id)
    if isPassComplete(progress, season.id) then
        return respond(src, token, false, "Missões bloqueadas: o passe já foi concluído.")
    end

    local mission = tostring(data and data.mission or "")
    local settings = missionSettings()
    local daily = ensureDailyProgress(src, season.id)
    if not daily then return respond(src, token, false, "Não foi possível carregar as missões de hoje.") end

    if mission == "login" then
        local cfg = settings.login or {}
        if cfg.enabled == false then return respond(src, token, false, "Esta missão está desativada.") end
        if isEnabled(daily.login_claimed) then
            return respond(src, token, true, "A recompensa de entrada já foi resgatada hoje.")
        end

        local streakDays = math.max(1, math.floor(tonumber(cfg.streakDays) or 30))
        local previous = previousLoginStreak(src, season.id)
        local streak = previous > 0 and ((previous % streakDays) + 1) or 1
        local changed = update([[
            UPDATE magic_pause_battlepass_daily
            SET login_claimed = 1, login_streak = ?, updated_at = ?
            WHERE id = ? AND login_claimed = 0
        ]], { streak, now(), daily.id })
        if changed <= 0 then return respond(src, token, true, "A recompensa de entrada já foi resgatada hoje.") end

        local reward = math.max(0, math.floor(tonumber(cfg.dailyXp) or 1000))
        local bonus = streak == streakDays and math.max(0, math.floor(tonumber(cfg.streakBonusXp) or 5000)) or 0
        local granted = grantXp(src, season, reward + bonus)
        local message = bonus > 0
            and ("Entrada resgatada: %s XP, incluindo o bônus de %s dias."):format(granted, streakDays)
            or ("Entrada resgatada: %s XP."):format(granted)
        return respond(src, token, true, message)
    end

    local definitions = {
        money = { progress = "money_spent", claimed = "money_claimed", defaultTarget = 20000, defaultReward = 3500 },
        runes = { progress = "runes_spent", claimed = "runes_claimed", defaultTarget = 200, defaultReward = 5000 }
    }
    local definition = definitions[mission]
    if not definition then return respond(src, token, false, "Missão inválida.") end

    local cfg = settings[mission] or {}
    if cfg.enabled == false then return respond(src, token, false, "Esta missão está desativada.") end
    local target = math.max(1, math.floor(tonumber(cfg.target) or definition.defaultTarget))
    if (tonumber(daily[definition.progress]) or 0) < target then
        return respond(src, token, false, "Complete a missão antes de resgatar o XP.")
    end
    if isEnabled(daily[definition.claimed]) then
        return respond(src, token, true, "Esta missão já foi resgatada hoje.")
    end

    local changed = update(([[
        UPDATE magic_pause_battlepass_daily
        SET %s = 1, updated_at = ?
        WHERE id = ? AND %s = 0 AND %s >= ?
    ]]):format(definition.claimed, definition.claimed, definition.progress), { now(), daily.id, target })
    if changed <= 0 then return respond(src, token, true, "Esta missão já foi resgatada hoje.") end

    local reward = math.max(0, math.floor(tonumber(cfg.rewardXp) or definition.defaultReward))
    local granted = grantXp(src, season, reward)
    respond(src, token, true, ("Missão concluída: %s XP recebidos."):format(granted))
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
    if not deliverReward(src, reward, {
        seasonId = season.id,
        slotIndex = slot.slot_index,
        track = track,
    }) then return respond(src, token, false, Utils.t("common.error")) end

    list[#list + 1] = tonumber(slot.slot_index)
    update(("UPDATE magic_pause_battlepass_progress SET %s = ?, updated_at = ? WHERE passport = ? AND season_id = ?"):format(column), {
        encodeJson(list),
        now(),
        Utils.getPassport(src),
        season.id
    })

    respond(src, token, true, Utils.t("battlepass.rewardClaimed"))
end)

AddEventHandler("QBCore:Server:OnMoneyChange", function(playerSource, moneyType, amount, actionType, reason)
    playerSource = tonumber(playerSource)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if not playerSource or amount <= 0 then return end

    reason = tostring(reason or "")

    if actionType == "add" then
        if reason:find("^tw%-litejobpack") then
            local queuedAt = now()
            SetTimeout(750, function()
                if GetPlayerPing(playerSource) <= 0 then return end
                local directAt = directJobXpAt[playerSource] or 0
                if directAt > 0 and queuedAt - directAt <= 15 then return end
                if now() - (jobPaymentFallbackAt[playerSource] or 0) < 15 then return end

                local granted = addJobMissionXp(playerSource, 15)
                if granted > 0 then
                    jobPaymentFallbackAt[playerSource] = now()
                    print(("[magicPauseObscuria] Battle Pass fallback: +%s XP por pagamento do tw-litejobpack (source=%s).")
                        :format(granted, playerSource))
                end
            end)
        end

        return
    end

    if actionType ~= "remove" then return end
    if reason == "battlepass_premium" or reason == "battlepass_levels" then return end

    local settings = missionSettings()
    local runes = settings.runes or {}
    local runeAccount = tostring(runes.account or (Config.Runes or {}).account or "crypto")
    if tostring(moneyType) == runeAccount then
        trackDailySpend(playerSource, "runes", amount)
        return
    end

    local money = settings.money or {}
    if accountAllowed(money.accounts, tostring(moneyType)) then
        trackDailySpend(playerSource, "money", amount)
    end
end)

exports("AddBattlePassXp", function(src, amount)
    src = tonumber(src)
    amount = math.floor(math.abs(tonumber(amount) or 0))
    if not src or amount <= 0 then return false end
    local season = activeSeason()
    if not season then return false end
    return grantXp(src, season, amount) > 0
end)

exports("AddBattlePassJobXp", function(src, amount)
    src = tonumber(src)
    local granted = addJobMissionXp(src, amount)
    if src and granted > 0 then directJobXpAt[src] = now() end
    return granted
end)

exports("TrackBattlePassMoneySpent", function(src, amount)
    return trackDailySpend(src, "money", amount)
end)

exports("TrackBattlePassRunesSpent", function(src, amount)
    return trackDailySpend(src, "runes", amount)
end)

AddEventHandler("playerDropped", function()
    directJobXpAt[source] = nil
    jobPaymentFallbackAt[source] = nil
end)
