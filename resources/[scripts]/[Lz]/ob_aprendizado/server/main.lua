local SpellById = {}
local SpellByItem = {}
local SpellByIndex = {}
local Sessions = {}
local KnownSpellCache = {}
local CitizenBySource = {}
local TableName = Config.TableName or 'magic_spells'

local function debugLog(message, ...)
    if Config.Debug then print(('[ob_aprendizado] ' .. message):format(...)) end
end

local function isValidTableName(name)
    return type(name) == 'string' and name:match('^[%w_]+$') ~= nil
end

if not isValidTableName(TableName) then
    error(('[ob_aprendizado] Nome de tabela invalido: %s'):format(tostring(TableName)))
end

for index, spell in ipairs(Config.Spells or {}) do
    SpellById[spell.id] = spell
    SpellByIndex[index] = spell
    if spell.item and spell.item ~= '' then SpellByItem[spell.item] = spell end
end

local function getPlayer(source)
    if GetResourceState('qbx_core') ~= 'started' then return nil end
    return exports.qbx_core:GetPlayer(source)
end

local function getCitizenId(source)
    local player = getPlayer(source)
    local citizenid = player and player.PlayerData and player.PlayerData.citizenid or nil
    if citizenid then CitizenBySource[source] = citizenid end
    return citizenid, player
end

local function hasClassAccess(player)
    local access = Config.ClassAccess or {}
    if access.enabled == false then return true end

    local metadata = player and player.PlayerData and player.PlayerData.metadata or {}
    local classId = tostring(metadata[access.metadataKey or 'classe'] or ''):lower()
    return access.allowed and access.allowed[classId] == true
end

local function resolveSpell(value)
    if type(value) == 'number' then return SpellByIndex[value] end

    local asNumber = tonumber(value)
    if asNumber and SpellByIndex[asNumber] then return SpellByIndex[asNumber] end
    return SpellById[value] or SpellByItem[value]
end

local function hasItem(source, itemName)
    if not itemName or itemName == '' then return true end

    local ok, count = pcall(function()
        return exports.ox_inventory:Search(source, 'count', itemName)
    end)
    return ok and (tonumber(count) or 0) > 0
end

local function loadKnownSpellMap(citizenid)
    if not citizenid then return {} end
    if KnownSpellCache[citizenid] then return KnownSpellCache[citizenid] end

    local rows = MySQL.query.await(
        ('SELECT `spell` FROM `%s` WHERE `citizenid` = ?'):format(TableName),
        { citizenid }
    ) or {}
    local known = {}

    for _, row in ipairs(rows) do
        if SpellById[row.spell] then known[row.spell] = true end
    end

    KnownSpellCache[citizenid] = known
    return known
end

local function hasSpell(citizenid, spellId)
    if not citizenid or not SpellById[spellId] then return false end
    return loadKnownSpellMap(citizenid)[spellId] == true
end

local function getKnownSpells(citizenid)
    local knownMap = loadKnownSpellMap(citizenid)
    local known = {}

    for index = 1, #SpellByIndex do
        local spell = SpellByIndex[index]
        if knownMap[spell.id] then known[#known + 1] = spell.id end
    end

    return known
end

local function refreshMagicSpells(source)
    TriggerEvent('magic:server:refreshKnownSpells', source)
end

local function insertUnlock(source, spell)
    local citizenid = getCitizenId(source)
    if not citizenid then return false, 'player' end
    local known = loadKnownSpellMap(citizenid)

    MySQL.query.await(
        ('INSERT IGNORE INTO `%s` (`citizenid`, `spell`) VALUES (?, ?)'):format(TableName),
        { citizenid, spell.id }
    )
    known[spell.id] = true
    refreshMagicSpells(source)
    return true
end

local function createToken(source, spellId)
    return ('%s:%s:%s:%s'):format(source, spellId, GetGameTimer(), math.random(100000, 999999))
end

local function startLearning(source, spellValue, options)
    options = type(options) == 'table' and options or {
        bypassItem = options == true,
    }

    local spell = resolveSpell(spellValue)
    local citizenid, player = getCitizenId(source)
    if not spell then return false, 'spell' end
    if not citizenid then return false, 'player' end

    local activeSession = Sessions[source]
    if activeSession and activeSession.expiresAt > GetGameTimer() then
        return false, 'busy'
    end
    Sessions[source] = nil

    if options.bypassClass ~= true and not hasClassAccess(player) then return false, 'class' end

    if options.allowKnown ~= true and hasSpell(citizenid, spell.id) then
        refreshMagicSpells(source)
        return false, 'known'
    end

    local learning = Config.Learning or {}
    local needsItem = learning.requireItem ~= false and options.bypassItem ~= true
    if needsItem and not hasItem(source, spell.item) then return false, 'item' end

    local token = createToken(source, spell.id)
    Sessions[source] = {
        token = token,
        spell = spell.id,
        item = needsItem and spell.item or nil,
        bypassClass = options.bypassClass == true,
        startedAt = GetGameTimer(),
        expiresAt = GetGameTimer() + (tonumber(learning.sessionTimeout) or 120000),
    }

    TriggerClientEvent('ob_aprendizado:client:startLesson', source, {
        token = token,
        spell = spell.id,
        label = spell.label,
        letter = spell.letter,
        rune = spell.rune,
        image = spell.image,
        icon = spell.icon,
        accent = spell.accent,
        position = spell.position,
        total = #SpellByIndex,
        inputTimeout = tonumber(learning.inputTimeout) or 2000,
    })
    return true
end

local function ensureDatabase()
    if Config.AutoCreateTable == false then return end

    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `citizenid` VARCHAR(64) NOT NULL,
            `spell` VARCHAR(64) NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`, `spell`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]):format(TableName))
end

RegisterNetEvent('ob_aprendizado:server:completeLesson', function(token, spellId, clientElapsed)
    local source = source
    local session = Sessions[source]
    local learning = Config.Learning or {}
    local elapsed = session and (GetGameTimer() - session.startedAt) or 0

    if not session or session.token ~= token or session.spell ~= spellId then
        TriggerClientEvent('ob_aprendizado:client:lessonResult', source, { success = false, reason = 'session' })
        return
    end

    if session.expiresAt < GetGameTimer() then
        Sessions[source] = nil
        TriggerClientEvent('ob_aprendizado:client:lessonResult', source, { success = false, reason = 'expired' })
        return
    end

    if elapsed < (tonumber(learning.minimumTraceTime) or 1800)
        or (tonumber(clientElapsed) or 0) < (tonumber(learning.minimumTraceTime) or 1800) then
        TriggerClientEvent('ob_aprendizado:client:lessonResult', source, { success = false, reason = 'trace' })
        return
    end

    local spell = SpellById[spellId]
    local _, player = getCitizenId(source)
    if not spell or (session.bypassClass ~= true and not hasClassAccess(player)) then
        TriggerClientEvent('ob_aprendizado:client:lessonResult', source, { success = false, reason = 'access' })
        return
    end

    if session.item and not hasItem(source, session.item) then
        TriggerClientEvent('ob_aprendizado:client:lessonResult', source, { success = false, reason = 'item' })
        return
    end

    Sessions[source] = nil
    local success, reason = insertUnlock(source, spell)
    if success and session.item and learning.consumeItemOnSuccess ~= false then
        exports.ox_inventory:RemoveItem(source, session.item, 1)
    end

    TriggerClientEvent('ob_aprendizado:client:lessonResult', source, {
        success = success,
        reason = reason,
        spell = spell.id,
    })
end)

RegisterNetEvent('ob_aprendizado:server:cancelLesson', function(token)
    local source = source
    if Sessions[source] and Sessions[source].token == token then Sessions[source] = nil end
end)

RegisterNetEvent('ob_aprendizado:server:useLearningItem', function(itemName)
    local playerSource = source
    local success, reason = startLearning(playerSource, itemName, { bypassItem = false })
    if not success then
        TriggerClientEvent('ob_aprendizado:client:learningError', playerSource, reason)
    end
end)

local learningCommand = Config.LearningCommand or {}
if learningCommand.enabled ~= false then
    RegisterCommand(learningCommand.name or 'aprenderruna', function(source, args)
        if source <= 0 then
            print(('[ob_aprendizado] Uso: /%s <1-8|id_do_feitico>'):format(learningCommand.name or 'aprenderruna'))
            return
        end

        local success, reason = startLearning(source, args[1], {
            bypassItem = true,
            bypassClass = true,
            allowKnown = true,
        })

        if not success then
            TriggerClientEvent('ob_aprendizado:client:learningError', source, reason)
        end
    end, learningCommand.restricted == true)
end

AddEventHandler('playerDropped', function()
    Sessions[source] = nil
    local citizenid = CitizenBySource[source]
    if citizenid then KnownSpellCache[citizenid] = nil end
    CitizenBySource[source] = nil
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    math.randomseed(os.time())
    ensureDatabase()
    debugLog('%s runas registradas.', #SpellByIndex)
end)

exports('StartLearning', function(source, spellValue)
    return startLearning(source, spellValue, { bypassItem = true })
end)

exports('StartLearningWithItem', function(source, spellValue)
    return startLearning(source, spellValue, { bypassItem = false })
end)

exports('UnlockSpell', function(source, spellValue)
    local spell = resolveSpell(spellValue)
    if not spell then return false end
    return insertUnlock(source, spell)
end)

exports('HasSpell', function(sourceOrCitizenId, spellId)
    local citizenid = sourceOrCitizenId
    if type(sourceOrCitizenId) == 'number' then citizenid = getCitizenId(sourceOrCitizenId) end
    return hasSpell(citizenid, spellId)
end)

exports('GetKnownSpells', function(sourceOrCitizenId)
    local citizenid = sourceOrCitizenId
    if type(sourceOrCitizenId) == 'number' then citizenid = getCitizenId(sourceOrCitizenId) end
    return getKnownSpells(citizenid)
end)
