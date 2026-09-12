local ox = exports.oxmysql
local jobsTableReady = false
local rewardsTableReady = false
local clientAwardCooldown = {}

local function clampInt(value)
  value = tonumber(value) or 0
  return math.max(0, math.floor(value))
end

local function getPassport(src)
  return Utils.getPassport(src)
end

local function getJobConfig(jobId)
  return Config and Config.Jobs and Config.Jobs[tostring(jobId)] or nil
end

local function progressionConfig()
  return Config.JobProgression or {}
end

local function playerName(passport)
  local src = Utils.getSourceByIdentifier(passport)
  return src and Utils.getName(src) or ""
end

local function notify(src, title, message, color)
  if not src or src <= 0 then
    print(('[magicPause:empregos] %s: %s'):format(title, message))
    return
  end
  TriggerClientEvent('Notify', src, title, message, color or 'amarelo', 5000)
end

local function levelProgress(jobConfig, xp)
  local maxLevel = tonumber(Config.MaxLevel) or 10
  local levels = jobConfig.levels or {}
  local masteryStep = math.max(1, clampInt(progressionConfig().masteryStep or 1000))
  xp = clampInt(xp)

  local level = 1
  for index = 1, maxLevel do
    if xp >= (tonumber(levels[index]) or 0) then
      level = index
    else
      break
    end
  end

  local currentRequirement = tonumber(levels[level]) or 0
  if level >= maxLevel then
    local masteryScore = math.max(0, xp - currentRequirement)
    local masteryProgress = masteryScore % masteryStep
    return {
      level = maxLevel,
      maxLevel = maxLevel,
      xpInLevel = masteryProgress,
      xpToNext = masteryStep - masteryProgress,
      nextLevelXP = xp + (masteryStep - masteryProgress),
      percent = math.floor((masteryProgress / masteryStep) * 100),
      masteryTier = math.floor(masteryScore / masteryStep) + 1,
      masteryScore = masteryScore,
      isMaster = true
    }
  end

  local nextRequirement = tonumber(levels[level + 1]) or currentRequirement
  local inLevel = math.max(0, xp - currentRequirement)
  local span = math.max(1, nextRequirement - currentRequirement)
  return {
    level = level,
    maxLevel = maxLevel,
    xpInLevel = inLevel,
    xpToNext = math.max(0, nextRequirement - xp),
    nextLevelXP = nextRequirement,
    percent = math.max(0, math.min(100, math.floor((inLevel / span) * 100))),
    masteryTier = 0,
    masteryScore = 0,
    isMaster = false
  }
end

local function benefitsFor(jobConfig, xp)
  local progress = levelProgress(jobConfig, xp)
  local cfg = progressionConfig()
  local income = math.max(0, (progress.level - 1) * (tonumber(cfg.incomeBonusPerLevel) or 2.0))
  local execution = math.max(0, (progress.level - 1) * (tonumber(cfg.executionBonusPerLevel) or 1.25))
  return {
    level = progress.level,
    incomePercent = income,
    executionPercent = execution,
    incomeMultiplier = 1.0 + (income / 100.0),
    executionMultiplier = math.max(0.25, 1.0 - (execution / 100.0))
  }
end

local function ensureJobsTable()
  if jobsTableReady then return end
  ox:executeSync([[
    CREATE TABLE IF NOT EXISTS `magic_empregos` (
      `passport` VARCHAR(80) NOT NULL,
      `job` VARCHAR(80) NOT NULL,
      `player_name` VARCHAR(120) NOT NULL DEFAULT '',
      `xp` INT NOT NULL DEFAULT 0,
      PRIMARY KEY (`passport`, `job`),
      KEY `job_score` (`job`, `xp`),
      KEY `passport_score` (`passport`, `xp`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])
  pcall(function() ox:executeSync("ALTER TABLE `magic_empregos` ADD COLUMN `player_name` VARCHAR(120) NOT NULL DEFAULT '' AFTER `job`") end)
  pcall(function() ox:executeSync("ALTER TABLE `magic_empregos` MODIFY COLUMN `passport` VARCHAR(80) NOT NULL") end)
  pcall(function() ox:executeSync("ALTER TABLE `magic_empregos` ADD KEY `job_score` (`job`, `xp`)") end)
  pcall(function() ox:executeSync("ALTER TABLE `magic_empregos` ADD KEY `passport_score` (`passport`, `xp`)") end)
  jobsTableReady = true
end

local function ensureRewardsTable()
  if rewardsTableReady then return end
  ox:executeSync([[
    CREATE TABLE IF NOT EXISTS `magic_empregos_rewards` (
      `id` BIGINT NOT NULL AUTO_INCREMENT,
      `cycle_key` VARCHAR(40) NOT NULL,
      `ranking_type` VARCHAR(20) NOT NULL,
      `job` VARCHAR(80) NOT NULL DEFAULT '',
      `passport` VARCHAR(80) NOT NULL,
      `player_name` VARCHAR(120) NOT NULL DEFAULT '',
      `position` INT NOT NULL,
      `amount` INT NOT NULL,
      `claimed` TINYINT(1) NOT NULL DEFAULT 0,
      `created_at` BIGINT NOT NULL,
      `claimed_at` BIGINT DEFAULT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `ranking_reward` (`cycle_key`, `ranking_type`, `job`, `passport`),
      KEY `pending_reward` (`passport`, `claimed`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])
  rewardsTableReady = true
end

local function ensureRow(passport, jobId, name)
  ensureJobsTable()
  ox:executeSync(
    "INSERT INTO magic_empregos (passport, job, player_name, xp) VALUES (?, ?, ?, 0) ON DUPLICATE KEY UPDATE player_name = IF(VALUES(player_name) <> '', VALUES(player_name), player_name)",
    { tostring(passport), tostring(jobId), tostring(name or '') }
  )
end

local function getXP(passport, jobId)
  ensureJobsTable()
  local rows = ox:executeSync(
    'SELECT xp FROM magic_empregos WHERE passport = ? AND job = ? LIMIT 1',
    { tostring(passport), tostring(jobId) }
  ) or {}
  return clampInt(rows[1] and rows[1].xp)
end

local function setXP(passport, jobId, xp)
  local jobConfig = getJobConfig(jobId)
  if not jobConfig then return false end
  xp = clampInt(xp)
  local name = playerName(passport)
  ensureRow(passport, jobId, name)
  ox:executeSync(
    "UPDATE magic_empregos SET xp = ?, player_name = IF(? <> '', ?, player_name) WHERE passport = ? AND job = ?",
    { xp, name, name, tostring(passport), tostring(jobId) }
  )

  local src = Utils.getSourceByIdentifier(passport)
  if src then
    notify(src, 'Atenção', ('Sua pontuação em %s foi definida para %d.'):format(jobConfig.label or jobId, xp), 'amarelo')
  end
  return true
end

local function addXP(passport, jobId, amount)
  local jobConfig = getJobConfig(jobId)
  amount = clampInt(amount)
  if not jobConfig or amount <= 0 then return false end

  local name = playerName(passport)
  ensureRow(passport, jobId, name)
  ox:executeSync(
    "UPDATE magic_empregos SET xp = xp + ?, player_name = IF(? <> '', ?, player_name) WHERE passport = ? AND job = ?",
    { amount, name, name, tostring(passport), tostring(jobId) }
  )

  local src = Utils.getSourceByIdentifier(passport)
  if src then
    notify(src, 'Progresso', ('Você recebeu %d pontos em %s.'):format(amount, jobConfig.label or jobId), 'verde')
  end
  return true
end

local function sortRanking(entries)
  table.sort(entries, function(a, b)
    if a.score == b.score then return tostring(a.name) < tostring(b.name) end
    return a.score > b.score
  end)
end

local function collectRankings(rows)
  local overallMap, services = {}, {}
  for jobId in pairs(Config.Jobs or {}) do services[tostring(jobId)] = {} end

  for _, row in ipairs(rows or {}) do
    local passport = tostring(row.passport or '')
    local jobId = tostring(row.job or '')
    local score = clampInt(row.xp)
    if passport ~= '' and score > 0 and services[jobId] then
      local name = tostring(row.player_name or '')
      if name == '' then name = 'Cidadão' end
      services[jobId][#services[jobId] + 1] = { passport = passport, name = name, score = score }

      local overall = overallMap[passport]
      if not overall then
        overall = { passport = passport, name = name, score = 0, services = 0 }
        overallMap[passport] = overall
      end
      overall.score = overall.score + score
      overall.services = overall.services + 1
      if overall.name == 'Cidadão' and name ~= 'Cidadão' then overall.name = name end
    end
  end

  local overall = {}
  for _, entry in pairs(overallMap) do overall[#overall + 1] = entry end
  sortRanking(overall)
  for _, entries in pairs(services) do sortRanking(entries) end
  return overall, services
end

local function boardPayload(entries, passport, rewards)
  local limit = math.max(3, clampInt(progressionConfig().rankingLimit or 10))
  local top, playerPosition, playerScore = {}, nil, 0
  for position, entry in ipairs(entries or {}) do
    if entry.passport == tostring(passport) then
      playerPosition = position
      playerScore = entry.score
    end
    if position <= limit then
      top[#top + 1] = {
        position = position,
        name = entry.name,
        score = entry.score,
        services = entry.services,
        isPlayer = entry.passport == tostring(passport),
        reward = clampInt(rewards and rewards[position])
      }
    end
  end
  return {
    entries = top,
    playerPosition = playerPosition,
    playerScore = playerScore,
    rewards = rewards or {}
  }
end

local function loadRankingRows()
  ensureJobsTable()
  return ox:executeSync('SELECT passport, job, player_name, xp FROM magic_empregos WHERE xp > 0') or {}
end

local function deliverPendingRewards(src, passport)
  ensureRewardsTable()
  local pending = ox:executeSync(
    'SELECT id, amount FROM magic_empregos_rewards WHERE passport = ? AND claimed = 0 ORDER BY id ASC',
    { tostring(passport) }
  ) or {}
  local total = 0
  for _, reward in ipairs(pending) do
    local amount = clampInt(reward.amount)
    if amount > 0 and Utils.addMoney(src, progressionConfig().rewardAccount or 'bank', amount, 'job_ranking_reward') then
      ox:executeSync('UPDATE magic_empregos_rewards SET claimed = 1, claimed_at = ? WHERE id = ? AND claimed = 0', {
        os.time(), reward.id
      })
      total = total + amount
    end
  end
  if total > 0 then
    notify(src, 'Ranking profissional', ('Você recebeu $ %s em premiações de carreira.'):format(total), 'verde')
  end
end

local function buildPayload(passport, src)
  ensureJobsTable()
  local currentName = src and Utils.getName(src) or ''
  if currentName ~= '' then
    ox:executeSync('UPDATE magic_empregos SET player_name = ? WHERE passport = ?', { currentName, tostring(passport) })
  end

  local rankingRows = loadRankingRows()
  local xpByJob = {}
  for _, row in ipairs(rankingRows) do
    if tostring(row.passport) == tostring(passport) then xpByJob[tostring(row.job)] = clampInt(row.xp) end
  end

  local jobs, totalScore, totalLevels = {}, 0, 0
  local rewardConfig = progressionConfig().rewards or {}
  local overallRanking, serviceRankings = collectRankings(rankingRows)
  local serviceBoards = {}

  for jobId, jobConfig in pairs(Config.Jobs or {}) do
    local id = tostring(jobId)
    local xp = xpByJob[id] or 0
    local progress = levelProgress(jobConfig, xp)
    local benefits = benefitsFor(jobConfig, xp)
    totalScore = totalScore + xp
    totalLevels = totalLevels + progress.level

    serviceBoards[id] = boardPayload(serviceRankings[id] or {}, passport, rewardConfig.service)
    jobs[#jobs + 1] = {
      id = id,
      label = jobConfig.label or id,
      description = jobConfig.description or 'Desenvolva sua experiência para ampliar ganhos e eficiência neste serviço.',
      image = jobConfig.image or '',
      coords = jobConfig.coords,
      score = xp,
      xp = xp,
      level = progress.level,
      maxLevel = progress.maxLevel,
      xpInLevel = progress.xpInLevel,
      xpToNext = progress.xpToNext,
      nextLevelXP = progress.nextLevelXP,
      percent = progress.percent,
      masteryTier = progress.masteryTier,
      masteryScore = progress.masteryScore,
      isMaster = progress.isMaster,
      benefits = benefits,
      ranking = serviceBoards[id]
    }
  end

  table.sort(jobs, function(a, b)
    if a.score == b.score then return tostring(a.label) < tostring(b.label) end
    return a.score > b.score
  end)

  local generalBoard = boardPayload(overallRanking, passport, rewardConfig.overall)
  return {
    jobs = jobs,
    currentJobId = nil,
    summary = {
      totalJobs = #jobs,
      totalScore = totalScore,
      combinedLevels = totalLevels,
      overallPosition = generalBoard.playerPosition
    },
    rankings = {
      overall = generalBoard,
      services = serviceBoards,
      cycle = os.date('%Y-W%W'),
      rewardAccount = progressionConfig().rewardAccount or 'bank'
    }
  }
end

local function queueReward(cycleKey, rankingType, jobId, entry, position, amount)
  amount = clampInt(amount)
  if not entry or amount <= 0 then return false end
  ensureRewardsTable()
  ox:executeSync([[
    INSERT IGNORE INTO magic_empregos_rewards
      (cycle_key, ranking_type, job, passport, player_name, position, amount, claimed, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)
  ]], {
    cycleKey, rankingType, jobId or '', entry.passport, entry.name or '', position, amount, os.time()
  })
  return true
end

RegisterNetEvent('escmenu:jobs:requestProgress', function()
  local src = source
  if Config.JobsEnabled == false then
    TriggerClientEvent('escmenu:jobs:payload', src, { jobs = {}, currentJobId = nil, disabled = true })
    return
  end

  local passport = getPassport(src)
  if not passport then
    TriggerClientEvent('escmenu:jobs:payload', src, { jobs = {}, currentJobId = nil })
    return
  end
  deliverPendingRewards(src, passport)
  TriggerClientEvent('escmenu:jobs:payload', src, buildPayload(passport, src))
end)

RegisterNetEvent('VanguardJobs:AddXP', function(a, b, c)
  local src = source
  if src and src > 0 then
    local passport = getPassport(src)
    local jobId, amount = a, b
    local now = os.time()
    local key = ('%s:%s'):format(src, tostring(jobId))
    if not passport or clientAwardCooldown[key] == now then return end
    clientAwardCooldown[key] = now
    addXP(passport, tostring(jobId), math.min(clampInt(amount), 250))
    return
  end

  local passport, jobId, amount = a, b, c
  if passport and jobId and amount then addXP(passport, tostring(jobId), amount) end
end)

exports('AddXP', function(passport, jobId, amount)
  return passport and addXP(passport, tostring(jobId), amount) or false
end)

exports('SetXP', function(passport, jobId, xp)
  return passport and setXP(passport, tostring(jobId), xp) or false
end)

exports('GetXP', function(passport, jobId)
  return passport and getXP(passport, tostring(jobId)) or 0
end)

exports('GetBenefits', function(passport, jobId)
  local jobConfig = getJobConfig(jobId)
  if not passport or not jobConfig then return nil end
  return benefitsFor(jobConfig, getXP(passport, tostring(jobId)))
end)

exports('ApplyIncomeBonus', function(passport, jobId, baseAmount)
  local jobConfig = getJobConfig(jobId)
  if not passport or not jobConfig then return clampInt(baseAmount) end
  local benefits = benefitsFor(jobConfig, getXP(passport, tostring(jobId)))
  return math.floor(clampInt(baseAmount) * benefits.incomeMultiplier)
end)

exports('GetExecutionMultiplier', function(passport, jobId)
  local jobConfig = getJobConfig(jobId)
  if not passport or not jobConfig then return 1.0 end
  return benefitsFor(jobConfig, getXP(passport, tostring(jobId))).executionMultiplier
end)

RegisterCommand('addjobxp', function(source, args)
  local src = source
  if src > 0 and not Utils.isStaff(src) then return end
  local targetArg, jobId, amount = args[1], args[2], tonumber(args[3])
  if not targetArg or not jobId or not amount or amount <= 0 then
    notify(src, 'Atenção', 'Uso: /addjobxp <passport|id|me> <emprego> <quantidade>', 'amarelo')
    return
  end

  local targetPassport
  if targetArg == 'me' and src > 0 then
    targetPassport = getPassport(src)
  elseif tonumber(targetArg) and GetPlayerPing(tonumber(targetArg)) > 0 then
    targetPassport = getPassport(tonumber(targetArg))
  else
    targetPassport = targetArg
  end

  if not targetPassport or not getJobConfig(jobId) then
    notify(src, 'Erro', 'Jogador ou emprego inválido.', 'vermelho')
    return
  end
  if addXP(targetPassport, tostring(jobId), amount) then
    notify(src, 'Sucesso', ('Foram adicionados %d pontos em %s.'):format(amount, getJobConfig(jobId).label or jobId), 'verde')
  end
end)

RegisterCommand(progressionConfig().payoutCommand or 'premiarjobranking', function(source, args)
  local src = source
  if src > 0 and not Utils.isStaff(src) then return end
  local cycleKey = tostring(args[1] or os.date('%Y-W%W')):gsub('[^%w_-]', '')
  if cycleKey == '' then cycleKey = os.date('%Y-W%W') end

  local overall, services = collectRankings(loadRankingRows())
  local rewards = progressionConfig().rewards or {}
  local queued = 0
  for position, amount in ipairs(rewards.overall or {}) do
    if queueReward(cycleKey, 'overall', '', overall[position], position, amount) then queued = queued + 1 end
  end
  for jobId, entries in pairs(services) do
    for position, amount in ipairs(rewards.service or {}) do
      if queueReward(cycleKey, 'service', jobId, entries[position], position, amount) then queued = queued + 1 end
    end
  end

  for _, playerId in ipairs(GetPlayers()) do
    local onlinePassport = getPassport(playerId)
    if onlinePassport then deliverPendingRewards(tonumber(playerId), onlinePassport) end
  end
  notify(src, 'Ranking profissional', ('Ciclo %s processado com %d posições premiáveis.'):format(cycleKey, queued), 'verde')
end)
