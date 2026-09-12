MagicServer = MagicServer or {}

local DatabaseConfig = Config.Database or {}
local QboxConfig = Config.Qbox or {}
local SpellsTable = DatabaseConfig.SpellsTable or "magic_spells"
local PortusTable = DatabaseConfig.PortusTable or "magic_portus_locations"

local PlayerSpells = {}
local ItemToSpell = {}
local Wands = {}
local PendingCasts = {}
local SpellCooldowns = {}

local function IsValidTableName(name)
    return type(name) == "string" and name:match("^[%w_]+$") ~= nil
end

if not IsValidTableName(SpellsTable) then
    error(("[magicSpells] Nome de tabela invalido: %s"):format(tostring(SpellsTable)))
end

if not IsValidTableName(PortusTable) then
    error(("[magicSpells] Nome de tabela invalido: %s"):format(tostring(PortusTable)))
end

local function Debug(message, ...)
    if Config.Debug then
        print(("[magicSpells] " .. message):format(...))
    end
end

function MagicServer.Notify(source, title, message, notifyType, duration)
    TriggerClientEvent("magic:client:notify", source, title or "Magia", message or "", notifyType or "inform", duration or 5000)
end

function MagicServer.IsValidPlayer(source)
    return source and GetPlayerPing(source) ~= nil
end

function MagicServer.GetPlayerSourceFromPed(entity)
    entity = tonumber(entity) or 0
    if entity <= 0 then return nil end

    for _, playerId in ipairs(GetPlayers()) do
        local playerSource = tonumber(playerId)
        if playerSource and GetPlayerPed(playerSource) == entity then
            return playerSource
        end
    end
    return nil
end

function MagicServer.GetPlayerSourceFromNetId(netId)
    netId = math.floor(tonumber(netId) or 0)
    if netId <= 0 then return nil, 0 end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity <= 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 1 then
        return nil, 0
    end
    return MagicServer.GetPlayerSourceFromPed(entity), entity, netId
end

function MagicServer.GetPlayerPedNetId(playerSource)
    playerSource = tonumber(playerSource)
    if not MagicServer.IsValidPlayer(playerSource) then return nil, 0, 0 end

    local ped = GetPlayerPed(playerSource)
    if ped <= 0 or not DoesEntityExist(ped) then return nil, 0, 0 end
    return playerSource, ped, NetworkGetNetworkIdFromEntity(ped)
end

function MagicServer.HasPendingCast(source, spellName)
    local pending = PendingCasts[source] and PendingCasts[source][spellName]
    return pending ~= nil
        and pending.spell == spellName
        and pending.expiresAt >= GetGameTimer()
end

function MagicServer.GetPlayer(source)
    if GetResourceState("qbx_core") ~= "started" then
        print("[magicSpells] qbx_core nao esta iniciado.")
        return nil
    end

    return exports.qbx_core:GetPlayer(source)
end

function MagicServer.HasGrimoireAccess(source)
    local player = MagicServer.GetPlayer(source)
    local access = Config.GrimoireAccess or {}
    local metadata = player and player.PlayerData and player.PlayerData.metadata or {}
    local classId = tostring(metadata[access.metadataKey or 'classe'] or ''):lower()
    local allowedClasses = access.allowedClasses or { bruxa = true }
    return allowedClasses[classId] == true
end

function MagicServer.GetCitizenId(source)
    local player = MagicServer.GetPlayer(source)
    if not player or not player.PlayerData then
        return nil
    end

    return player.PlayerData.citizenid
end

function MagicServer.GetSpellsTable()
    return SpellsTable
end

function MagicServer.GetPortusTable()
    return PortusTable
end

function MagicServer.HasItem(source, itemName)
    if not itemName or itemName == "" then
        return true
    end

    if GetResourceState("ox_inventory") == "started" then
        local ok, count = pcall(function()
            return exports.ox_inventory:Search(source, "count", itemName)
        end)

        return ok and tonumber(count or 0) > 0
    end

    return true
end

function MagicServer.RemoveItem(source, itemName, count)
    if GetResourceState("ox_inventory") ~= "started" or not itemName or itemName == "" then
        return false
    end

    local ok, removed = pcall(function()
        return exports.ox_inventory:RemoveItem(source, itemName, tonumber(count) or 1)
    end)

    return ok and removed == true
end

local function GetSpellEssenceCost(spellData)
    return math.max(0, math.floor(tonumber(spellData and spellData.essenceCost) or 0))
end

local function HasSpellEssence(source, spellData)
    local cost = GetSpellEssenceCost(spellData)
    if cost <= 0 then
        return true, cost
    end

    if GetResourceState("ob_essencias") ~= "started" then
        print("[magicSpells] ob_essencias nao esta iniciado; conjuracao bloqueada.")
        return false, cost
    end

    local ok, result = pcall(function()
        return exports.ob_essencias:GetEssenciaSnapshot(source)
    end)

    return ok
        and type(result) == "table"
        and result.success == true
        and (tonumber(result.value) or 0) >= cost,
        cost
end

local function ConsumeSpellEssence(source, spellName, spellData)
    local cost = GetSpellEssenceCost(spellData)
    if cost <= 0 then
        return true, cost
    end

    if GetResourceState("ob_essencias") ~= "started" then
        print("[magicSpells] ob_essencias nao esta iniciado; conjuracao bloqueada.")
        return false, cost
    end

    local ok, result = pcall(function()
        return exports.ob_essencias:ConsumeEssencia(source, cost, {
            origin = 'magicSpells',
            ability = spellName,
            skipEvaluation = true,
        })
    end)

    return ok and type(result) == "table" and result.success == true, cost
end


local function PreflightSpellEssence(source, spellName, spellData)
    local cost = GetSpellEssenceCost(spellData)
    if cost <= 0 then return true, cost, nil end
    if GetResourceState('ob_essencias') ~= 'started' then return false, cost, 'resource' end

    local ok, result = pcall(function()
        return exports.ob_essencias:PreflightEssencia(source, cost, {
            origin = 'magicSpells',
            ability = spellName,
        })
    end)
    if not ok or type(result) ~= 'table' then return false, cost, 'resource' end
    return result.success == true, cost, result.reason
end

local function EnsureDatabase()
    if DatabaseConfig.AutoCreate == false then
        return
    end

    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `citizenid` VARCHAR(64) NOT NULL,
            `spell` VARCHAR(64) NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`, `spell`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]):format(SpellsTable))

    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(64) NOT NULL,
            `slot` TINYINT UNSIGNED NULL,
            `name` VARCHAR(60) NOT NULL,
            `x` DOUBLE NOT NULL,
            `y` DOUBLE NOT NULL,
            `z` DOUBLE NOT NULL,
            `heading` DOUBLE NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            INDEX `idx_magic_portus_citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]):format(PortusTable))

    local slotColumn = MySQL.query.await(("SHOW COLUMNS FROM `%s` LIKE 'slot'"):format(PortusTable)) or {}
    if #slotColumn == 0 then
        MySQL.query.await(("ALTER TABLE `%s` ADD COLUMN `slot` TINYINT UNSIGNED NULL AFTER `citizenid`"):format(PortusTable))
    end
end

local function BuildItemMap()
    ItemToSpell = {}

    for spellName, data in pairs(Config.Spells or {}) do
        if data.item and data.item ~= "" then
            ItemToSpell[data.item] = spellName
            Debug("item '%s' -> spell '%s'", data.item, spellName)
        end
    end
end

local function BuildAllSpellsList()
    local list = {}

    for spellName in pairs(Config.Spells or {}) do
        list[spellName] = true
    end

    return list
end

local function LoadPlayerSpells(citizenid)
    if not citizenid then
        return {}
    end

    if PlayerSpells[citizenid] then
        return PlayerSpells[citizenid]
    end

    local list = {}

    if QboxConfig.LearnAllSpellsByDefault == true then
        list = BuildAllSpellsList()
    else
        local rows = MySQL.query.await(("SELECT `spell` FROM `%s` WHERE `citizenid` = ?"):format(SpellsTable), { citizenid }) or {}
        for _, row in ipairs(rows) do
            if row.spell then
                list[row.spell] = true
            end
        end
    end

    PlayerSpells[citizenid] = list
    return list
end

local function SendKnownSpellsToClient(source, citizenid)
    local list = LoadPlayerSpells(citizenid)
    local spellNames = {}

    for spellName, has in pairs(list) do
        if has and Config.Spells[spellName] then
            spellNames[#spellNames + 1] = spellName
        end
    end

    table.sort(spellNames)
    TriggerClientEvent("magic:client:setKnownSpells", source, spellNames)
end

local function LearnSpell(source, spellOrItem)
    if GetResourceState('ob_aprendizado') ~= 'started' then
        MagicServer.Notify(source, 'Grimorio', 'O aprendizado runico esta indisponivel.', 'error')
        return false
    end

    local ok, started = pcall(function()
        return exports.ob_aprendizado:StartLearning(source, spellOrItem)
    end)
    return ok and started == true
end

local function RegisterUsableItem(itemName, handler)
    if not itemName or itemName == "" then
        return
    end

    if GetResourceState("ox_inventory") == "started" then
        local ok = pcall(function()
            exports.ox_inventory:RegisterUsableItem(itemName, function(source, item, data)
                handler(source, item, data)
            end)
        end)

        if ok then
            Debug("Item usavel registrado via ox_inventory: %s", itemName)
            return
        end
    end

    pcall(function()
        exports.qbx_core:CreateUseableItem(itemName, function(source, item)
            handler(source, item)
        end)
    end)
end

local function RegisterItems()
    RegisterUsableItem(Config.MagicWandItem, function(source)
        TriggerClientEvent("magic:client:useWand", source)
    end)
end

AddEventHandler('magic:server:refreshKnownSpells', function(targetSource)
    targetSource = tonumber(targetSource)
    if not targetSource then return end

    local citizenid = MagicServer.GetCitizenId(targetSource)
    if not citizenid then return end

    PlayerSpells[citizenid] = nil
    SendKnownSpellsToClient(targetSource, citizenid)
end)

RegisterNetEvent("magic:server:syncSpells", function()
    local source = source
    if not MagicServer.HasGrimoireAccess(source) then
        TriggerClientEvent("magic:client:setKnownSpells", source, {})
        return
    end

    local citizenid = MagicServer.GetCitizenId(source)
    if not citizenid then
        return
    end

    SendKnownSpellsToClient(source, citizenid)
end)

RegisterNetEvent("magic:server:learnSpellItem", function(spellOrItem)
    local source = source
    if GetResourceState('ob_aprendizado') ~= 'started' then return end

    pcall(function()
        exports.ob_aprendizado:StartLearningWithItem(source, spellOrItem)
    end)
end)

RegisterNetEvent("magic:server:useWandItem", function()
    local source = source

    local player = Player(source)
    if player and player.state and (
        player.state.magicFauna
        or player.state.obscuriaPowerBlocked
        or player.state.obHypnotized
        or player.state.obInVehicleAttachment
        or player.state.magicGlaciesFrozen
    ) then
        local hypnotized = player.state.obHypnotized == true
        local inVehicleAttachment = player.state.obInVehicleAttachment == true
        local frozen = player.state.magicGlaciesFrozen == true
        MagicServer.Notify(
            source,
            inVehicleAttachment and "Porta-malas" or (hypnotized and "Hipnose" or (frozen and "Glacies" or "Forma animal")),
            hypnotized and "Voce nao consegue usar a varinha enquanto esta hipnotizado."
                or (inVehicleAttachment and "Voce nao consegue usar a varinha dentro do porta-malas."
                    or (frozen and "Voce nao consegue usar a varinha enquanto esta congelado."
                        or "Voce nao consegue usar a varinha nessa forma.")),
            "error"
        )
        return
    end

    if not MagicServer.HasItem(source, Config.MagicWandItem) then
        MagicServer.Notify(source, "Grimorio", "Voce precisa da varinha para canalizar magia.", "error")
        return
    end

    TriggerClientEvent("magic:client:useWand", source)
end)

RegisterNetEvent("magic:server:requestCast", function(spellName, castMode)
    local source = source
    if not MagicServer.HasGrimoireAccess(source) then
        return
    end

    local citizenid = MagicServer.GetCitizenId(source)
    if not citizenid then
        MagicServer.Notify(source, "Magia", "Nao foi possivel identificar seu personagem.", "error")
        return
    end

    local player = Player(source)
    if player and player.state and (
        player.state.magicFauna
        or player.state.obscuriaPowerBlocked
        or player.state.obHypnotized
        or player.state.obInVehicleAttachment
        or player.state.magicGlaciesFrozen
    ) then
        local hypnotized = player.state.obHypnotized == true
        local inVehicleAttachment = player.state.obInVehicleAttachment == true
        local frozen = player.state.magicGlaciesFrozen == true
        MagicServer.Notify(
            source,
            inVehicleAttachment and "Porta-malas" or (hypnotized and "Hipnose" or (frozen and "Glacies" or "Forma animal")),
            hypnotized and "Voce nao consegue conjurar enquanto esta hipnotizado."
                or (inVehicleAttachment and "Voce nao consegue usar skills dentro do porta-malas."
                    or (frozen and "Voce nao consegue conjurar enquanto esta congelado."
                        or "Voce nao consegue conjurar nessa forma.")),
            "error"
        )
        return
    end

    if not spellName or not Config.Spells[spellName] then
        MagicServer.Notify(source, "Magia", "Feitico invalido.", "error")
        return
    end

    if not MagicServer.HasItem(source, Config.MagicWandItem) then
        MagicServer.Notify(source, "Grimorio", "Voce precisa estar com a varinha.", "error")
        return
    end

    local list = LoadPlayerSpells(citizenid)
    if not list[spellName] then
        MagicServer.Notify(source, "Grimorio", "Voce ainda nao aprendeu essa magia.", "error")
        return
    end

    local spellData = Config.Spells[spellName]
    local now = GetGameTimer()

    if spellName == "blink" then
        local pending = PendingCasts[source] and PendingCasts[source][spellName]
        if pending and pending.expiresAt > now then
            TriggerClientEvent("magic:client:castDenied", source, spellName, "busy")
            return
        end

        local cooldownEnd = SpellCooldowns[source]
            and SpellCooldowns[source][spellName]
            or 0
        if cooldownEnd > now then
            TriggerClientEvent("magic:client:castDenied", source, spellName, "cooldown", cooldownEnd - now)
            return
        end
    end

    local hasEssence, essenceCost = HasSpellEssence(source, spellData)
    if not hasEssence then
        TriggerClientEvent("magic:client:castDenied", source, spellName, "essence", essenceCost)
        return
    end


    local preflightOk, _, preflightReason = PreflightSpellEssence(source, spellName, spellData)
    if not preflightOk then
        TriggerClientEvent(
            "magic:client:castDenied",
            source,
            spellName,
            preflightReason == 'overload' and 'overload' or 'essence',
            essenceCost
        )
        return
    end

    PendingCasts[source] = PendingCasts[source] or {}
    PendingCasts[source][spellName] = {
        spell = spellName,
        expiresAt = GetGameTimer() + (spellName == "blink" and 20000 or 300000),
    }

    TriggerClientEvent("magic:client:castSpell", source, spellName, castMode)
end)

RegisterNetEvent("magic:server:commitCast", function(spellName)
    local source = source
    local sourcePending = PendingCasts[source]
    local pending = sourcePending and sourcePending[spellName]
    if not pending then
        return
    end

    sourcePending[spellName] = nil
    if not next(sourcePending) then
        PendingCasts[source] = nil
    end

    if pending.spell ~= spellName or pending.expiresAt < GetGameTimer() then
        return
    end

    local spellData = Config.Spells[spellName]
    local consumed, essenceCost = ConsumeSpellEssence(source, spellName, spellData)
    if not consumed then
        TriggerClientEvent("magic:client:castDenied", source, spellName, "essence", essenceCost)
    elseif spellName == "blink" then
        SpellCooldowns[source] = SpellCooldowns[source] or {}
        SpellCooldowns[source][spellName] = GetGameTimer() + math.max(0, tonumber(spellData.cooldown) or 0)
    end
end)

RegisterNetEvent("magic:server:cancelCast", function(spellName)
    local source = source
    local sourcePending = PendingCasts[source]
    if not sourcePending or not sourcePending[spellName] then
        return
    end

    sourcePending[spellName] = nil
    if not next(sourcePending) then
        PendingCasts[source] = nil
    end
end)

RegisterNetEvent("magic:server:setWandState", function(state, modelName)
    local source = source
    local citizenid = MagicServer.GetCitizenId(source)
    if not citizenid then
        return
    end

    state = state and true or false

    if state then
        if not MagicServer.HasItem(source, Config.MagicWandItem) then
            MagicServer.Notify(source, "Grimorio", "Voce precisa da varinha para canalizar magia.", "error")
            return
        end

        local model = modelName or Config.WandProp or "victoriawand"
        Wands[source] = { model = model }
        TriggerClientEvent("magic:client:updateWandState", -1, source, true, model)
    else
        Wands[source] = nil
        TriggerClientEvent("magic:client:updateWandState", -1, source, false, "")
    end
end)

AddEventHandler("playerDropped", function()
    local source = source
    Wands[source] = nil
    PendingCasts[source] = nil
    SpellCooldowns[source] = nil
    TriggerClientEvent("magic:client:updateWandState", -1, source, false, "")
end)

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    EnsureDatabase()
    BuildItemMap()
    RegisterItems()
end)

BuildItemMap()

exports("HasSpell", function(sourceOrCitizenId, spellName)
    local citizenid = sourceOrCitizenId
    if type(sourceOrCitizenId) == "number" then
        citizenid = MagicServer.GetCitizenId(sourceOrCitizenId)
    end

    local list = LoadPlayerSpells(citizenid)
    return list and list[spellName] == true
end)

exports("LearnSpell", function(source, spellOrItem)
    LearnSpell(source, spellOrItem)
end)
