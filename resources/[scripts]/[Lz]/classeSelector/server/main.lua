local SelectorConfig = Config.ClassSelector or {}
local DatabaseConfig = Config.Database or {}
local QboxConfig = Config.Qbox or {}
local CommandConfig = Config.Commands or {}

local TableName = DatabaseConfig.TableName or "classe_selector"
local ClassMap = {}
local PlayerClassCache = {}
local RaceVoucherCooldown = {}

local function IsValidTableName(name)
    return type(name) == "string" and name:match("^[%w_]+$") ~= nil
end

if not IsValidTableName(TableName) then
    error(("[classeSelector] Nome de tabela invalido: %s"):format(tostring(TableName)))
end

local function Notify(source, title, message, notifyType, duration)
    TriggerClientEvent("classeSelector:notify", source, title, message, notifyType or "inform", duration or 5000)
end

local function BuildClassMap()
    local map = {}

    for _, class in ipairs(Config.Classes or {}) do
        if class.id then
            map[class.id] = {
                id = class.id,
                label = class.label or class.id,
                description = class.description,
                image = class.image,
                logo = class.logo,
                card = class.card,
                affinity = class.affinity or "Indefinido",
                weakness = class.weakness or "Indefinido"
            }
        end
    end

    return map
end

local function GetQboxPlayer(source)
    if GetResourceState("qbx_core") ~= "started" then
        print("[classeSelector] qbx_core nao esta iniciado.")
        return nil
    end

    return exports.qbx_core:GetPlayer(source)
end

local function GetCitizenId(source)
    local player = GetQboxPlayer(source)
    if not player or not player.PlayerData then
        return nil, player
    end

    return player.PlayerData.citizenid, player
end

local function GetPlayerClass(citizenid)
    if not citizenid then
        return nil
    end

    local cached = PlayerClassCache[citizenid]
    if cached ~= nil then
        return cached or nil
    end

    local query = ("SELECT `class` FROM `%s` WHERE `citizenid` = ? LIMIT 1"):format(TableName)
    local classId = MySQL.scalar.await(query, { citizenid })
    PlayerClassCache[citizenid] = classId or false

    return classId
end

local function GetPlayerClasses(citizenids)
    if type(citizenids) ~= "table" then return {} end

    local result = {}
    local pending = {}
    local seen = {}

    for i = 1, math.min(#citizenids, 12) do
        local citizenid = citizenids[i]
        if type(citizenid) == "string" and #citizenid <= 64 and not seen[citizenid] then
            seen[citizenid] = true
            local cached = PlayerClassCache[citizenid]
            if cached ~= nil then
                if cached then result[citizenid] = cached end
            else
                pending[#pending + 1] = citizenid
            end
        end
    end

    if #pending == 0 then return result end

    local placeholders = {}
    for i = 1, #pending do placeholders[i] = "?" end

    local query = ("SELECT `citizenid`, `class` FROM `%s` WHERE `citizenid` IN (%s)"):format(
        TableName,
        table.concat(placeholders, ",")
    )
    local rows = MySQL.query.await(query, pending) or {}

    for i = 1, #rows do
        local row = rows[i]
        if row.citizenid and row.class then
            PlayerClassCache[row.citizenid] = row.class
            result[row.citizenid] = row.class
        end
    end

    for i = 1, #pending do
        local citizenid = pending[i]
        if PlayerClassCache[citizenid] == nil then PlayerClassCache[citizenid] = false end
    end

    return result
end

local function SetPlayerClass(citizenid, classId)
    local query = ([[
        INSERT INTO `%s` (`citizenid`, `class`)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE
            `class` = VALUES(`class`),
            `updated_at` = CURRENT_TIMESTAMP
    ]]):format(TableName)

    MySQL.query.await(query, { citizenid, classId })
    PlayerClassCache[citizenid] = classId
end

local function SetQboxMetadata(player, classId)
    if not player or not QboxConfig.SaveMetadata then
        return
    end

    local metadataKey = QboxConfig.MetadataKey or "classe"
    local funcs = player.Functions or player.functions

    if funcs and funcs.SetMetaData then
        pcall(function()
            funcs.SetMetaData(metadataKey, classId)
        end)
        return
    end

    if funcs and funcs.SetMetadata then
        pcall(function()
            funcs.SetMetadata(metadataKey, classId)
        end)
    end
end

local function InitializeEssence(source)
    if GetResourceState("ob_essencias") ~= "started" then
        return
    end

    pcall(function()
        exports.ob_essencias:SetEssencia(source, 100)
    end)
end

local function NotifyCommand(source, title, message, notifyType, duration)
    if source == 0 then
        print(("[%s] %s"):format(title or "classeSelector", message or ""))
        return
    end

    Notify(source, title, message, notifyType, duration)
end

local function ChangePlayerClass(targetSource, classId, changedBy)
    targetSource = tonumber(targetSource)
    classId = tostring(classId or ""):lower()

    if not targetSource or not ClassMap[classId] then
        return false, "Jogador ou classe invalida."
    end

    local citizenid, player = GetCitizenId(targetSource)
    if not citizenid or not player then
        return false, "Jogador nao encontrado ou personagem indisponivel."
    end

    SetPlayerClass(citizenid, classId)
    SetQboxMetadata(player, classId)
    TriggerClientEvent("classeSelector:classChanged", targetSource, classId)
    TriggerEvent("classeSelector:server:classChanged", targetSource, citizenid, classId)

    print((
        "[classeSelector] Classe alterada por comando. admin=%s target=%s citizenid=%s class=%s"
    ):format(tostring(changedBy), tostring(targetSource), citizenid, classId))

    return true, ClassMap[classId]
end

local function EnsureDatabase()
    if DatabaseConfig.AutoCreate == false then
        return
    end

    local query = ([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `citizenid` VARCHAR(64) NOT NULL,
            `class` VARCHAR(32) NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]):format(TableName)

    MySQL.query.await(query)
end

local function LoadPlayerClassCache()
    local query = ("SELECT `citizenid`, `class` FROM `%s`"):format(TableName)
    local rows = MySQL.query.await(query) or {}
    PlayerClassCache = {}

    for i = 1, #rows do
        PlayerClassCache[rows[i].citizenid] = rows[i].class
    end
end

RegisterNetEvent("classeSelector:enterFlow", function()
    local source = source
    local citizenid = GetCitizenId(source)

    if not citizenid then
        print(("[classeSelector] enterFlow: citizenid nil para source %s"):format(source))
        Notify(source, "Classe", "Nao foi possivel identificar seu personagem.", "error", 5000)
        return
    end

    local classId = GetPlayerClass(citizenid)
    if classId then
        TriggerClientEvent("classeSelector:alreadyHasClass", source, classId)
        return
    end

    TriggerClientEvent("classeSelector:startSelector", source, false)
end)

RegisterNetEvent("classeSelector:enterCreationFlow", function()
    local source = source

    CreateThread(function()
        local citizenid

        for _ = 1, 50 do
            citizenid = GetCitizenId(source)
            if citizenid then break end
            Wait(100)
        end

        if not citizenid then
            print(("[classeSelector] enterCreationFlow: citizenid nil para source %s"):format(source))
            Notify(source, "Classe", "Não foi possível iniciar a seleção de classe.", "error", 5000)
            TriggerClientEvent("classeSelector:creationFlowFailed", source)
            return
        end

        local classId = GetPlayerClass(citizenid)
        if classId then
            TriggerClientEvent("classeSelector:alreadyHasClass", source, classId)
            return
        end

        TriggerClientEvent("classeSelector:startSelector", source, true)
    end)
end)

RegisterNetEvent("classeSelector:useRaceChangeVoucher", function()
    local source = source
    local current = os.time()
    if current - (RaceVoucherCooldown[source] or 0) < 5 then return end
    RaceVoucherCooldown[source] = current

    local citizenid, player = GetCitizenId(source)
    if not citizenid or not player then
        Notify(source, "Troca de raca", "Nao foi possivel identificar seu personagem.", "error", 5000)
        return
    end
    if GetResourceState("ox_inventory") ~= "started" then
        Notify(source, "Troca de raca", "O inventario nao esta disponivel agora.", "error", 5000)
        return
    end
    if exports.ox_inventory:GetItemCount(source, "troca_raca") < 1 then
        Notify(source, "Troca de raca", "Voce nao possui este selo.", "error", 5000)
        return
    end
    if exports.ox_inventory:RemoveItem(source, "troca_raca", 1) ~= true then
        Notify(source, "Troca de raca", "Nao foi possivel consumir o selo.", "error", 5000)
        return
    end

    local cleared, clearError = pcall(function()
        MySQL.update.await(("DELETE FROM `%s` WHERE `citizenid` = ?"):format(TableName), { citizenid })
        PlayerClassCache[citizenid] = false
        SetQboxMetadata(player, nil)
    end)
    if not cleared then
        exports.ox_inventory:AddItem(source, "troca_raca", 1)
        print(("[classeSelector] Falha ao preparar troca de raca para %s: %s"):format(citizenid, tostring(clearError)))
        Notify(source, "Troca de raca", "A troca nao pode ser iniciada; o selo foi devolvido.", "error", 6000)
        return
    end

    TriggerEvent("classeSelector:server:classChanged", source, citizenid, nil)
    TriggerClientEvent("classeSelector:startSelector", source, false)
end)

AddEventHandler("playerDropped", function()
    RaceVoucherCooldown[source] = nil
end)

RegisterNetEvent("classeSelector:chooseClass", function(classId, creation)
    local source = source
    local citizenid, player = GetCitizenId(source)

    if not citizenid then
        print(("[classeSelector] chooseClass: citizenid nil para source %s"):format(source))
        Notify(source, "Classe", "Nao foi possivel identificar seu personagem.", "error", 5000)
        return
    end

    if not classId or classId == "" or not ClassMap[classId] then
        print(("[classeSelector] Classe invalida: %s"):format(tostring(classId)))
        Notify(source, "Classe", "Classe invalida ao tentar vincular.", "error", 5000)
        return
    end

    if QboxConfig.PreventChangingClass ~= false then
        local currentClass = GetPlayerClass(citizenid)
        if currentClass then
            TriggerClientEvent("classeSelector:alreadyHasClass", source, currentClass)
            return
        end
    end

    SetPlayerClass(citizenid, classId)
    SetQboxMetadata(player, classId)
    InitializeEssence(source)

    print(("[classeSelector] Classe gravada. citizenid=%s class=%s creation=%s"):format(citizenid, classId, tostring(creation)))

    TriggerClientEvent("classeSelector:classChosenSuccess", source, classId)
    TriggerEvent("classeSelector:server:classChanged", source, citizenid, classId)
end)

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    ClassMap = BuildClassMap()
    EnsureDatabase()
    LoadPlayerClassCache()
end)

ClassMap = BuildClassMap()

if CommandConfig.ChangeClass and CommandConfig.ChangeClass ~= "" then
    lib.addCommand(CommandConfig.ChangeClass, {
        help = "Altera a classe de um jogador",
        params = {
            { name = "target", type = "playerId", help = "ID do jogador" },
            { name = "class", type = "string", help = "bruxa, vampiro, curandeira ou humano" }
        },
        restricted = CommandConfig.AdminPermission or "group.admin"
    }, function(source, args)
        local success, result = ChangePlayerClass(args.target, args.class, source)
        if not success then
            NotifyCommand(source, "Classe", result, "error", 5000)
            return
        end

        local targetName = GetPlayerName(args.target) or ("ID %s"):format(args.target)
        NotifyCommand(
            source,
            "Classe alterada",
            ("%s agora pertence a classe %s."):format(targetName, result.label),
            "success",
            5000
        )
        Notify(
            args.target,
            "Classe alterada",
            ("Sua classe agora e %s."):format(result.label),
            "success",
            6000
        )
    end)
end

if CommandConfig.CurrentClass and CommandConfig.CurrentClass ~= "" then
    lib.addCommand(CommandConfig.CurrentClass, {
        help = "Mostra sua classe atual"
    }, function(source)
        if source == 0 then
            print("[classeSelector] O comando minhaclasse deve ser usado por um jogador.")
            return
        end

        local citizenid, player = GetCitizenId(source)
        local metadata = player and player.PlayerData and player.PlayerData.metadata or {}
        local classId = citizenid and GetPlayerClass(citizenid)
            or metadata[QboxConfig.MetadataKey or "classe"]

        if not classId then
            Notify(source, "Classe", "Voce ainda nao possui uma classe.", "error", 5000)
            return
        end

        local class = ClassMap[classId]
        Notify(
            source,
            "Classe atual",
            class and class.label or tostring(classId),
            "inform",
            5000
        )
    end)
end

exports("GetPlayerClass", function(sourceOrCitizenId)
    local citizenid = sourceOrCitizenId

    if type(sourceOrCitizenId) == "number" then
        citizenid = GetCitizenId(sourceOrCitizenId) or tostring(sourceOrCitizenId)
    end

    return GetPlayerClass(citizenid)
end)

exports("GetPlayerClasses", function(citizenids)
    return GetPlayerClasses(citizenids)
end)

exports("GetPlayerClassInfo", function(sourceOrCitizenId)
    local citizenid = sourceOrCitizenId

    if type(sourceOrCitizenId) == "number" then
        citizenid = GetCitizenId(sourceOrCitizenId) or tostring(sourceOrCitizenId)
    end

    local classId = GetPlayerClass(citizenid)
    if not classId then
        return nil
    end

    return ClassMap[classId] or {
        id = classId,
        label = classId,
        affinity = "Indefinido",
        weakness = "Indefinido"
    }
end)
