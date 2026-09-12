local oxmysql = exports.oxmysql

local tableName = Config.RaspadinhaTable or "magic_raspadinhas"
local rewardsPool = Config.RaspadinhasRewards or {}
local scratchTableReady = false

local function ensureScratchTable()
    if scratchTableReady then return end
    oxmysql:executeSync(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `passport` VARCHAR(80) NOT NULL,
            `last_play` DATE NOT NULL,
            `chosen_card` INT NOT NULL DEFAULT 1,
            `reward_id` VARCHAR(80) DEFAULT NULL,
            `reward_amount` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`passport`, `last_play`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]):format(tableName))
    pcall(function()
        oxmysql:executeSync(("ALTER TABLE `%s` MODIFY COLUMN `passport` VARCHAR(80) NOT NULL"):format(tableName))
    end)
    scratchTableReady = true
end

local function findRewardById(id)
    for _, reward in ipairs(rewardsPool) do
        if reward.id == id then return reward end
    end
    return nil
end

local function copyReward(reward)
    local result = {}
    for key, value in pairs(reward or {}) do result[key] = value end
    if type(result.amount) == "table" then
        local min = tonumber(result.amount[1]) or 0
        local max = tonumber(result.amount[2]) or min
        result.amount = math.random(min, max)
    else
        result.amount = tonumber(result.amount) or 0
    end
    return result
end

local function pickReward()
    local totalChance = 0
    for _, reward in ipairs(rewardsPool) do
        totalChance = totalChance + (tonumber(reward.chance) or 0)
    end

    if totalChance <= 0 then
        return { id = "none", type = "none", amount = 0, label = "Nenhuma recompensa configurada." }
    end

    local roll = math.random() * totalChance
    local current = 0
    for _, reward in ipairs(rewardsPool) do
        current = current + (tonumber(reward.chance) or 0)
        if roll <= current then return copyReward(reward) end
    end

    return copyReward(rewardsPool[#rewardsPool])
end

local function rewardPayload(reward)
    if not reward then return nil end
    return {
        id = reward.id,
        type = reward.type,
        amount = reward.amount,
        item = reward.item,
        label = reward.label,
        image = reward.image,
        permission = reward.permission,
        duration = reward.duration,
        vehicle = reward.vehicle,
        days = reward.days,
        block = reward.block
    }
end

local function applyReward(src, reward)
    if not reward then return false end
    local amount = tonumber(reward.amount) or 0

    if reward.type == "money" and amount > 0 then
        return Utils.addMoney(src, "cash", amount, "scratchcard")
    end

    if reward.type == "bank" and amount > 0 then
        return Utils.addMoney(src, "bank", amount, "scratchcard")
    end

    if reward.type == "item" and amount > 0 and reward.item then
        return Utils.giveItem(src, reward.item, amount)
    end

    if reward.type == "premium" then
        local passport = Utils.getPassport(src)
        if Config.OnScratchPremium then
            return Config.OnScratchPremium(src, passport, reward) ~= false
        end

        if GetResourceState("ob_vip") ~= "started" then return false end
        local days = math.max(1, math.floor((tonumber(reward.duration) or 86400) / 86400))
        local ok, granted = pcall(function()
            return exports.ob_vip:AddVip(passport, reward.permission, days, {
                grantedBy = "magicPauseObscuria",
                reason = "premio da raspadinha",
                metadata = { rewardId = reward.id }
            })
        end)
        return ok and granted == true
    end

    if reward.type == "vehicle" and Config.OnScratchVehicle then
        return Config.OnScratchVehicle(src, Utils.getPassport(src), reward) ~= false
    end

    return true
end

RegisterNetEvent("magicPause:raspadinha:play", function(token, cardIndex)
    local src = source
    ensureScratchTable()
    local passport = Utils.getPassport(src)
    if not passport then
        TriggerClientEvent("magicPause:raspadinha:playResult", src, token, {
            ok = false,
            message = "Não foi possível localizar seu passaporte."
        })
        return
    end

    cardIndex = tonumber(cardIndex) or 1
    local today = os.date("%Y-%m-%d")

    oxmysql:single(("SELECT chosen_card, reward_id, reward_amount FROM %s WHERE passport = ? AND last_play = ?"):format(tableName), {
        passport,
        today
    }, function(row)
        if row then
            local reward = copyReward(findRewardById(row.reward_id) or { id = "none", type = "none", label = "Resultado de hoje" })
            reward.amount = tonumber(row.reward_amount) or reward.amount or 0
            TriggerClientEvent("magicPause:raspadinha:playResult", src, token, {
                ok = false,
                alreadyPlayed = true,
                message = "Você já usou a raspadinha hoje. Volte amanhã!",
                reward = rewardPayload(reward),
                rewardLabel = reward.label,
                chosenCard = row.chosen_card
            })
            return
        end

        local reward = pickReward()
        applyReward(src, reward)

        oxmysql:execute(("INSERT INTO %s (passport, last_play, chosen_card, reward_id, reward_amount) VALUES (?, ?, ?, ?, ?)"):format(tableName), {
            passport,
            today,
            cardIndex,
            reward.id,
            tonumber(reward.amount) or 0
        })

        TriggerClientEvent("magicPause:raspadinha:playResult", src, token, {
            ok = true,
            message = reward.label or "Resultado da raspadinha.",
            reward = rewardPayload(reward),
            chosenCard = cardIndex
        })
    end)
end)

RegisterNetEvent("magicPause:raspadinha:getStatus", function(token)
    local src = source
    ensureScratchTable()
    local passport = Utils.getPassport(src)
    if not passport then
        TriggerClientEvent("magicPause:raspadinha:statusResult", src, token, { playedToday = false })
        return
    end

    local today = os.date("%Y-%m-%d")
    oxmysql:single(("SELECT chosen_card, reward_id, reward_amount FROM %s WHERE passport = ? AND last_play = ?"):format(tableName), {
        passport,
        today
    }, function(row)
        if not row then
            TriggerClientEvent("magicPause:raspadinha:statusResult", src, token, { playedToday = false })
            return
        end

        local reward = copyReward(findRewardById(row.reward_id) or { id = "none", type = "none", label = "Resultado de hoje" })
        reward.amount = tonumber(row.reward_amount) or reward.amount or 0
        TriggerClientEvent("magicPause:raspadinha:statusResult", src, token, {
            playedToday = true,
            chosenCard = row.chosen_card,
            rewardLabel = reward.label,
            reward = rewardPayload(reward),
            message = "Você já usou a raspadinha hoje. Volte amanhã!"
        })
    end)
end)
