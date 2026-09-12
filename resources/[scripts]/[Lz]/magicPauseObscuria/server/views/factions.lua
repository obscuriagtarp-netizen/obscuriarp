local oxmysql = exports.oxmysql
local factionTablesReady = false
local testNonStaffView = {}

local function now()
    return os.time()
end

local function query(sql, params)
    return oxmysql:executeSync(sql, params or {}) or {}
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

local function ensureFactionTables()
    if factionTablesReady then return end
    query([[
        CREATE TABLE IF NOT EXISTS `magic_pause_factions` (
            `faction_key` VARCHAR(80) NOT NULL,
            `owner_identifier` VARCHAR(80) DEFAULT NULL,
            `owner_name` VARCHAR(120) DEFAULT NULL,
            `group_name` VARCHAR(80) NOT NULL,
            `monthly_price` INT NOT NULL DEFAULT 0,
            `member_limit` INT NOT NULL DEFAULT 20,
            `status` VARCHAR(20) NOT NULL DEFAULT 'active',
            `paid_until` BIGINT DEFAULT NULL,
            `created_at` BIGINT NOT NULL,
            `updated_at` BIGINT NOT NULL,
            PRIMARY KEY (`faction_key`),
            KEY `owner_identifier` (`owner_identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    query([[
        CREATE TABLE IF NOT EXISTS `magic_pause_faction_features` (
            `id` BIGINT NOT NULL AUTO_INCREMENT,
            `faction_key` VARCHAR(80) NOT NULL,
            `feature_id` VARCHAR(80) NOT NULL,
            `feature_type` VARCHAR(40) NOT NULL,
            `model_id` VARCHAR(80) DEFAULT NULL,
            `label` VARCHAR(100) NOT NULL,
            `source_kind` VARCHAR(20) NOT NULL DEFAULT 'included',
            `price` INT NOT NULL DEFAULT 0,
            `quantity` INT NOT NULL DEFAULT 0,
            `weight` INT NOT NULL DEFAULT 0,
            `coords` LONGTEXT DEFAULT NULL,
            `metadata` LONGTEXT DEFAULT NULL,
            `status` VARCHAR(20) NOT NULL DEFAULT 'active',
            `recurring` TINYINT(1) NOT NULL DEFAULT 0,
            `paid_until` BIGINT DEFAULT NULL,
            `created_by` VARCHAR(80) NOT NULL,
            `created_at` BIGINT NOT NULL,
            PRIMARY KEY (`id`),
            KEY `faction_key` (`faction_key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    query([[
        CREATE TABLE IF NOT EXISTS `magic_pause_faction_members` (
            `faction_key` VARCHAR(80) NOT NULL,
            `user_id` VARCHAR(80) NOT NULL,
            `display_name` VARCHAR(120) NOT NULL,
            `grade` INT NOT NULL DEFAULT 0,
            `joined_at` BIGINT NOT NULL,
            PRIMARY KEY (`faction_key`, `user_id`),
            KEY `user_id` (`user_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    query([[
        CREATE TABLE IF NOT EXISTS `magic_pause_faction_transactions` (
            `id` BIGINT NOT NULL AUTO_INCREMENT,
            `faction_key` VARCHAR(80) NOT NULL,
            `user_id` VARCHAR(80) NOT NULL,
            `transaction_type` VARCHAR(40) NOT NULL,
            `reference_id` VARCHAR(80) DEFAULT NULL,
            `amount` INT NOT NULL DEFAULT 0,
            `currency` VARCHAR(16) NOT NULL DEFAULT 'runes',
            `created_at` BIGINT NOT NULL,
            PRIMARY KEY (`id`),
            KEY `faction_created` (`faction_key`, `created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    update("UPDATE magic_pause_factions SET monthly_price = 0, status = 'active', paid_until = NULL WHERE owner_identifier IS NOT NULL")
    factionTablesReady = true
end

local function findFaction(key)
    return (Config.Factions or {})[tostring(key or "")]
end

local function findIncluded(id)
    for _, feature in ipairs(Config.IncludedFeatures or {}) do
        if tostring(feature.id) == tostring(id or "") then return feature end
    end
    return nil
end

local function findUpgrade(id)
    for _, upgrade in ipairs(Config.Upgrades or {}) do
        if tostring(upgrade.id) == tostring(id or "") then return upgrade end
    end
    return nil
end

local function getModuleModel(featureType, modelId)
    return (((Config.ModuleModels or {})[tostring(featureType or "")]) or {})[tostring(modelId or "")]
end

local function configuredModelId(factionKey, definition)
    if type(definition) ~= "table" then return nil end
    if definition.model and definition.model ~= "" then return tostring(definition.model) end
    if definition.modelFromFaction == true then
        local faction = findFaction(factionKey) or {}
        local moduleId = (faction.modules or {})[tostring(definition.type or "")]
        if moduleId and moduleId ~= "" then return tostring(moduleId) end
    end
    return nil
end

local function resolveFeatureModel(factionKey, feature)
    if type(feature) ~= "table" then return nil, nil end
    local featureType = tostring(feature.type or feature.feature_type or "")
    local modelId = feature.modelId or feature.model_id
    if not modelId or modelId == "" then
        local definition
        if tostring(feature.source_kind or feature.sourceKind or "") == "upgrade" then
            definition = findUpgrade(feature.feature_id or feature.featureId)
        else
            definition = findIncluded(feature.feature_id or feature.featureId)
        end
        modelId = configuredModelId(factionKey, definition)
    end
    if not modelId or modelId == "" then return nil, nil end
    return tostring(modelId), getModuleModel(featureType, modelId)
end

local function ownershipRows()
    ensureFactionTables()
    local rows = query("SELECT * FROM magic_pause_factions")
    local map = {}
    for _, row in ipairs(rows) do
        map[tostring(row.faction_key)] = row
    end
    return map
end

local function decodeMaybe(value)
    if type(value) == "table" then return value end
    if type(value) ~= "string" or value == "" then return nil end
    local ok, decoded = pcall(json.decode, value)
    return ok and decoded or nil
end

local function featureRows(key)
    local features = query("SELECT * FROM magic_pause_faction_features WHERE faction_key = ? ORDER BY created_at DESC, id DESC", { key })
    for _, feature in ipairs(features) do
        feature.coords = decodeMaybe(feature.coords)
        feature.metadata = decodeMaybe(feature.metadata) or {}
        feature.recurring = tonumber(feature.recurring) == 1
        local modelId, model = resolveFeatureModel(key, feature)
        feature.modelId = modelId
        feature.modelLabel = model and model.label or nil
    end
    return features
end

local function memberRows(key)
    return query("SELECT * FROM magic_pause_faction_members WHERE faction_key = ? ORDER BY grade DESC, joined_at ASC", { key })
end

local function recordTransaction(key, userId, txType, reference, amount)
    insert([[
        INSERT INTO magic_pause_faction_transactions(faction_key, user_id, transaction_type, reference_id, amount, created_at)
        VALUES(?, ?, ?, ?, ?, ?)
    ]], { key, tostring(userId), tostring(txType), tostring(reference or ""), math.floor(tonumber(amount) or 0), now() })
end

local function placedCoords(feature)
    local coords = feature and feature.coords
    if type(coords) ~= "table" then return nil end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return nil end
    return { x = x, y = y, z = z, h = tonumber(coords.h or coords.w) or 0.0 }
end

local function integrationId(key, feature)
    return ("magicpause:%s:%s"):format(tostring(key), tostring(feature.id or feature.feature_id or feature.featureId or "point"))
end

local function resourceExport(resource, exportName, ...)
    if GetResourceState(resource) ~= "started" then return false end
    local args = { ... }
    local ok, result = pcall(function()
        local provider = exports[resource]
        return provider[exportName](provider, table.unpack(args))
    end)
    return ok and result ~= false
end

local function garageSpawnSettings(model)
    local cfg = Config.GarageSpawn or {}
    return {
        maxPoints = math.max(1, math.min(2, tonumber(model and model.maxSpawnPoints) or tonumber(cfg.maxPoints) or 2)),
        maxDistance = tonumber(model and model.maxSpawnDistance) or tonumber(cfg.maxDistance) or 20.0
    }
end

local function validGarageSpawn(anchor, point, maxDistance)
    if not anchor or type(point) ~= "table" then return false end
    local x, y, z = tonumber(point.x), tonumber(point.y), tonumber(point.z)
    if not x or not y or not z then return false end
    local distance = #(vector3(x, y, z) - vector3(anchor.x, anchor.y, anchor.z))
    return distance <= (tonumber(maxDistance) or 20.0), distance
end

local function configuredGarageSpawns(feature, anchor, model)
    local settings = garageSpawnSettings(model)
    local metadata = type(feature.metadata) == "table" and feature.metadata or {}
    local points = type(metadata.spawnPoints) == "table" and metadata.spawnPoints or {}
    local spawn = {}
    for slot = 1, settings.maxPoints do
        local point = points[slot] or points[tostring(slot)]
        if validGarageSpawn(anchor, point, settings.maxDistance) then
            spawn[#spawn + 1] = vector4(
                tonumber(point.x) or anchor.x,
                tonumber(point.y) or anchor.y,
                tonumber(point.z) or anchor.z,
                tonumber(point.h or point.w) or anchor.h or 0.0
            )
        end
    end
    return spawn, settings
end

local function supportsPosition(featureType)
    featureType = tostring(featureType or "")
    return featureType ~= "" and featureType ~= "panel" and featureType ~= "member_capacity"
end

local function materializeFeature(key, feature, group)
    local coords = placedCoords(feature)
    local featureType = tostring(feature.type or feature.feature_type or "")
    if not coords or feature.status == "blocked" then return false end
    local modelId, model = resolveFeatureModel(key, feature)
    model = model or {}

    if featureType == "storage" then
        return resourceExport("VanguardInventory", "RegisterStash", integrationId(key, feature), {
            label = feature.label or model.label or "Baú do clã",
            coords = vector3(coords.x, coords.y, coords.z),
            maxSlots = tonumber(model.maxSlots) or (math.max(tonumber(model.maxWeight) or 0, tonumber(feature.weight) or 0, 200) >= 1000 and 120 or 50),
            maxWeight = math.max(tonumber(model.maxWeight) or 0, tonumber(feature.weight) or 0, 200),
            group = group,
            perm = group
        })
    end

    if featureType == "garage" then
        local spawn = configuredGarageSpawns(feature, coords, model)
        if #spawn == 0 then
            local radians = math.rad(coords.h)
            local forwardX, forwardY = -math.sin(radians), math.cos(radians)
            local rightX, rightY = math.cos(radians), math.sin(radians)
            for _, offset in ipairs(model.spawnOffsets or { { forward = 4.0, right = 0.0 }, { forward = 4.0, right = 3.0 } }) do
                if #spawn >= (garageSpawnSettings(model)).maxPoints then break end
                spawn[#spawn + 1] = vector4(
                    coords.x + (forwardX * (tonumber(offset.forward) or 4.0)) + (rightX * (tonumber(offset.right) or 0.0)),
                    coords.y + (forwardY * (tonumber(offset.forward) or 4.0)) + (rightY * (tonumber(offset.right) or 0.0)),
                    coords.z + (tonumber(offset.z) or 0.0),
                    coords.h + (tonumber(offset.heading) or 0.0)
                )
            end
        end
        return resourceExport("VanguardGarage", "RegisterHouseGarage", integrationId(key, feature), {
            label = model.label or ("Garagem - " .. tostring(key)),
            kind = model.kind or "job",
            public = false,
            group = group,
            permission = group,
            typeFilter = model.typeFilter,
            teleportIntoVehicle = model.teleportIntoVehicle == true,
            access = vector3(coords.x, coords.y, coords.z),
            store = vector3(coords.x, coords.y, coords.z),
            spawn = spawn
        })
    end

    if featureType == "craft" then
        return resourceExport("VanguardCraft", "RegisterBench", integrationId(key, feature), {
            label = model.label or ("Mesa - " .. tostring(key)),
            subtitle = model.subtitle or "Produção do clã",
            kind = model.kind or "drugs",
            icon = model.icon or "fa-flask",
            recipes = model.recipes or {},
            public = false,
            group = group,
            permission = group,
            coords = vector3(coords.x, coords.y, coords.z),
            heading = coords.h,
            prop = model.prop
        })
    end

    if featureType == "farm" then
        return resourceExport("VanguardFarm", "RegisterStartPoint", integrationId(key, feature), {
            label = model.label or "Iniciar rota",
            route = model.route,
            group = group,
            permission = group,
            coords = vector3(coords.x, coords.y, coords.z)
        })
    end

    return true
end

local function removeFeatureIntegration(key, feature, clearContents)
    local featureType = tostring(feature.type or feature.feature_type or "")
    if featureType == "storage" then
        resourceExport("VanguardInventory", "UnregisterStash", integrationId(key, feature), clearContents == true)
    elseif featureType == "garage" then
        resourceExport("VanguardGarage", "UnregisterHouseGarage", integrationId(key, feature))
    elseif featureType == "craft" then
        resourceExport("VanguardCraft", "UnregisterBench", integrationId(key, feature))
    elseif featureType == "farm" then
        resourceExport("VanguardFarm", "UnregisterStartPoint", integrationId(key, feature))
    end
end

local function restoreIntegrations()
    for _, row in ipairs(query("SELECT * FROM magic_pause_factions WHERE owner_identifier IS NOT NULL")) do
        for _, feature in ipairs(featureRows(row.faction_key)) do
            materializeFeature(row.faction_key, feature, row.group_name)
        end
    end
end

local function deliverAutomaticFeatures(factionKey, userId)
    for _, feature in ipairs(Config.IncludedFeatures or {}) do
        if feature.automatic == true then
            local modelId = configuredModelId(factionKey, feature)
            insert([[
                INSERT INTO magic_pause_faction_features(faction_key, feature_id, feature_type, model_id, label, source_kind, price, quantity, weight, created_by, created_at)
                SELECT ?, ?, ?, ?, ?, 'included', 0, 1, ?, ?, ?
                WHERE NOT EXISTS (
                    SELECT 1 FROM magic_pause_faction_features WHERE faction_key = ? AND feature_id = ? AND source_kind = 'included'
                )
            ]], {
                factionKey, feature.id, feature.type, modelId, feature.label, tonumber(feature.weight) or 0, tostring(userId), now(),
                factionKey, feature.id
            })
        end
    end
end

local function userFaction(src)
    local identifier = Utils.getPassport(src)
    local groups = Utils.getGroups(src)
    local rows = ownershipRows()

    for key, faction in pairs(Config.Factions or {}) do
        local row = rows[key]
        if row and row.owner_identifier == identifier then return key, row, faction end
        local member = query("SELECT faction_key FROM magic_pause_faction_members WHERE user_id = ? AND faction_key = ? LIMIT 1", { identifier, key })[1]
        if member then return key, row, faction end
        if faction.group and Utils.hasFaction(src, faction.group) then return key, row, faction end
        if groups.gang and groups.gang.name == faction.group then return key, row, faction end
        if groups.job and groups.job.name == faction.group then return key, row, faction end
    end

    return nil, nil, nil
end

local function ownerFactionBySource(src)
    local identifier = Utils.getPassport(src)
    return query("SELECT * FROM magic_pause_factions WHERE owner_identifier = ? LIMIT 1", { identifier })[1]
end

local function factionList()
    local rows = ownershipRows()
    local list = {}
    for key, faction in pairs(Config.Factions or {}) do
        local row = rows[key]
        list[#list + 1] = {
            key = key,
            label = faction.label or key,
            group = faction.group or key,
            image = faction.image or "",
            product = faction.product or "",
            description = faction.description or "",
            accent = faction.accent or "#a855f7",
            memberLimit = tonumber(faction.memberLimit) or tonumber(Config.FactionDefaults.memberLimit) or 20,
            available = row == nil or row.owner_identifier == nil,
            ownerName = row and row.owner_name or nil,
            status = row and row.status or "available"
        }
    end
    table.sort(list, function(a, b) return tostring(a.label) < tostring(b.label) end)
    return list
end

local function includedFeaturesPayload(factionKey)
    local rows = {}
    for _, feature in ipairs(Config.IncludedFeatures or {}) do
        local row = {}
        for key, value in pairs(feature) do row[key] = value end
        local modelId = configuredModelId(factionKey, feature)
        local model = getModuleModel(feature.type, modelId)
        row.modelId = modelId
        row.modelLabel = model and model.label or nil
        rows[#rows + 1] = row
    end
    return rows
end

local function buildMyFaction(src)
    local key, row, faction = userFaction(src)
    if not key or not faction then return nil end
    local identifier = Utils.getPassport(src)
    local ownerName = row and row.owner_name or Utils.getName(src)

    return {
        key = key,
        faction_key = key,
        label = faction.label or key,
        owner_name = ownerName,
        group_name = faction.group or key,
        member_limit = tonumber(row and row.member_limit) or tonumber(faction.memberLimit) or tonumber(Config.FactionDefaults.memberLimit) or 20,
        status = "active",
        permanent = true,
        features = featureRows(key),
        members = memberRows(key),
        isOwner = row and row.owner_identifier == identifier or false
    }
end

local function visibleMenuOptions()
    local options = {}

    for _, option in ipairs(Config.MenuOptions or {}) do
        if option.disabled ~= true then
            options[#options + 1] = option
        end
    end

    return options
end

local function buildPayload(src)
    local isStaff = Utils.isStaff(src)
    if testNonStaffView[src] then isStaff = false end
    local myFaction = buildMyFaction(src)
    local profile = {
        id = Utils.getPassport(src),
        name = Utils.getName(src),
        avatar = Utils.getIdentity(src).avatar or ""
    }

    return {
        profile = profile,
        runes = Utils.getRunes(src),
        options = visibleMenuOptions(),
        factions = factionList(),
        myFaction = myFaction,
        isStaff = isStaff,
        testNonStaff = testNonStaffView[src] == true,
        texts = Config.FactionTexts or {},
        includedFeatures = includedFeaturesPayload(myFaction and myFaction.faction_key),
        upgrades = Config.Upgrades or {},
        autonomy = (Config.FactionDefaults or {}).autonomy or {
            "Liderança definida exclusivamente pela staff.",
            "Posse permanente, sem mensalidade ou expiração.",
            "Líder pode administrar os recursos do clã."
        },
        benefits = (Config.FactionDefaults or {}).benefits or {
            "Garagem, baú e sistemas configuráveis conforme a cidade.",
            "Limite inicial de membros por clã.",
            "Base pronta para upgrades e módulos autônomos."
        },
        positionReset = Config.PositionReset or { singlePrice = 30, allPrice = 100 }
    }
end

local function respond(src, token, ok, message, kind)
    TriggerClientEvent("MagicPause:client:serverResponse", src, token, {
        ok = ok == true,
        message = message,
        kind = kind or (ok and "success" or "error"),
        payload = buildPayload(src)
    })
end

local function setLeader(src, target, key)
    local faction = findFaction(key)
    if not faction then return false, "Clã inválido." end
    local targetSrc = tonumber(target)
    if not targetSrc or targetSrc <= 0 or GetPlayerPing(targetSrc) <= 0 then
        return false, "O jogador precisa estar online para receber a liderança."
    end

    local ownerIdentifier = Utils.getPassport(targetSrc)
    local ownerName = Utils.getName(targetSrc)
    local limit = tonumber(faction.memberLimit) or tonumber(Config.FactionDefaults.memberLimit) or 20
    local grade = tonumber(faction.leaderGrade) or tonumber(Config.FactionDefaults.leaderGrade) or 3
    Utils.setFaction(targetSrc, faction.group or key, grade)

    insert([[
        INSERT INTO magic_pause_factions(faction_key, owner_identifier, owner_name, group_name, monthly_price, member_limit, status, paid_until, created_at, updated_at)
        VALUES(?, ?, ?, ?, ?, ?, 'active', NULL, ?, ?)
        ON DUPLICATE KEY UPDATE
            owner_identifier = VALUES(owner_identifier),
            owner_name = VALUES(owner_name),
            group_name = VALUES(group_name),
            monthly_price = VALUES(monthly_price),
            member_limit = VALUES(member_limit),
            status = 'active',
            paid_until = NULL,
            updated_at = VALUES(updated_at)
    ]], { key, ownerIdentifier, ownerName, faction.group or key, 0, limit, now(), now() })

    insert([[
        INSERT INTO magic_pause_faction_members(faction_key, user_id, display_name, grade, joined_at)
        VALUES(?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE display_name = VALUES(display_name), grade = VALUES(grade)
    ]], { key, ownerIdentifier, ownerName, grade, now() })
    deliverAutomaticFeatures(key, ownerIdentifier)

    return true, ownerName .. " agora é líder do clã " .. (faction.label or key) .. "."
end

local function activeOwner(src)
    local row = ownerFactionBySource(src)
    if not row then return nil, nil, "Somente o líder do clã pode realizar esta ação." end
    return Utils.getPassport(src), row
end

local function serializeCoords(src, coords)
    if type(coords) ~= "table" then return nil end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return nil end
    local ped = GetPlayerPed(src)
    if ped and ped > 0 then
        local real = GetEntityCoords(ped)
        if #(real - vector3(x, y, z)) > 5.0 then return nil end
        x, y, z = real.x, real.y, real.z
    end
    return json.encode({ x = x, y = y, z = z, h = tonumber(coords.h) or 0.0 })
end

local function coordsTableFromClient(src, coords)
    local encoded = serializeCoords(src, coords)
    if not encoded then return nil end
    local ok, decoded = pcall(json.decode, encoded)
    return ok and decoded or nil
end

RegisterNetEvent("MagicPause:server:getFactions", function(token)
    local src = source
    TriggerClientEvent("MagicPause:client:serverResponse", src, token, buildPayload(src))
end)

RegisterNetEvent("MagicPause:server:setFactionLeader", function(token, data)
    local src = source
    if not Utils.isStaff(src) then return respond(src, token, false, "Você não possui permissão.") end
    local ok, message = setLeader(src, data and data.target, data and data.key)
    respond(src, token, ok, message)
end)

RegisterNetEvent("MagicPause:server:addFactionMember", function(token, data)
    local src = source
    local userId, owner, err = activeOwner(src)
    if not userId then return respond(src, token, false, err) end
    local targetSrc = tonumber(data and data.userId)
    if not targetSrc or targetSrc <= 0 or GetPlayerPing(targetSrc) <= 0 then return respond(src, token, false, "O jogador precisa estar online.") end
    local memberTotal = query("SELECT COUNT(*) AS total FROM magic_pause_faction_members WHERE faction_key = ?", { owner.faction_key })[1]
    if tonumber(memberTotal and memberTotal.total) >= tonumber(owner.member_limit or 20) then return respond(src, token, false, "Limite de membros atingido.") end
    local faction = findFaction(owner.faction_key)
    local targetId = Utils.getPassport(targetSrc)
    Utils.setFaction(targetSrc, faction.group or owner.group_name, tonumber(faction.memberGrade) or tonumber(Config.FactionDefaults.memberGrade) or 0)
    insert([[
        INSERT INTO magic_pause_faction_members(faction_key, user_id, display_name, grade, joined_at)
        VALUES(?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE display_name = VALUES(display_name), grade = VALUES(grade)
    ]], { owner.faction_key, targetId, Utils.getName(targetSrc), tonumber(faction.memberGrade) or 0, now() })
    respond(src, token, true, "Membro adicionado ao clã.")
end)

RegisterNetEvent("MagicPause:server:removeFactionMember", function(token, data)
    local src = source
    local userId, owner, err = activeOwner(src)
    if not userId then return respond(src, token, false, err) end
    local targetId = tostring(data and data.userId or "")
    if targetId == "" or targetId == tostring(owner.owner_identifier) then return respond(src, token, false, "O líder não pode ser removido.") end
    local removed = update("DELETE FROM magic_pause_faction_members WHERE faction_key = ? AND user_id = ?", { owner.faction_key, targetId })
    respond(src, token, removed > 0, removed > 0 and "Membro removido do clã." or "Membro não encontrado.")
end)

RegisterNetEvent("MagicPause:server:placeIncludedFeature", function(token, data)
    local src = source
    local userId, owner, err = activeOwner(src)
    local feature = findIncluded(data and data.id)
    if not userId then return respond(src, token, false, err) end
    if not feature then return respond(src, token, false, "Módulo inválido.") end
    if feature.automatic == true then return respond(src, token, false, "Este recurso já é liberado automaticamente.", "info") end
    local modelId = configuredModelId(owner.faction_key, feature)
    if (feature.type == "storage" or feature.type == "garage" or feature.type == "craft" or feature.type == "farm") and not getModuleModel(feature.type, modelId) then
        return respond(src, token, false, "Modelo não configurado.")
    end
    local encoded = serializeCoords(src, data and data.coords)
    if not encoded then return respond(src, token, false, "Local inválido para instalar o módulo.") end
    local current = query("SELECT * FROM magic_pause_faction_features WHERE faction_key = ? AND feature_id = ? AND source_kind = 'included' LIMIT 1", { owner.faction_key, feature.id })[1]
    if current and current.coords and current.coords ~= "" then return respond(src, token, false, "Este módulo incluso já foi instalado.") end
    local id = current and tonumber(current.id) or insert([[
        INSERT INTO magic_pause_faction_features(faction_key, feature_id, feature_type, model_id, label, source_kind, price, quantity, weight, coords, created_by, created_at)
        VALUES(?, ?, ?, ?, ?, 'included', 0, 1, ?, ?, ?, ?)
    ]], { owner.faction_key, feature.id, feature.type, modelId, feature.label, tonumber(feature.weight) or 0, encoded, userId, now() })
    if current then update("UPDATE magic_pause_faction_features SET model_id = ?, coords = ?, status = 'active' WHERE id = ?", { modelId, encoded, id }) end
    for _, row in ipairs(featureRows(owner.faction_key)) do if tonumber(row.id) == tonumber(id) then materializeFeature(owner.faction_key, row, owner.group_name) end end
    recordTransaction(owner.faction_key, userId, "placement", feature.id, 0)
    respond(src, token, true, feature.label .. " instalado no local atual.")
end)

RegisterNetEvent("MagicPause:server:buyFactionUpgrade", function(token, data)
    local src = source
    local userId, owner, err = activeOwner(src)
    local upgrade = findUpgrade(data and data.id)
    if not userId then return respond(src, token, false, err) end
    if not upgrade then return respond(src, token, false, "Upgrade inválido.") end
    data = type(data) == "table" and data or {}
    local price = math.floor(tonumber(upgrade.price) or 0)
    if upgrade.type == "storage" and tostring(data.mode or "") == "expand" then
        local targetId = tonumber(data.targetFeatureId)
        local target = targetId and query("SELECT * FROM magic_pause_faction_features WHERE id = ? AND faction_key = ? AND feature_type = 'storage' LIMIT 1", { targetId, owner.faction_key })[1]
        if not target then return respond(src, token, false, "Selecione qual baú receberá o aumento de peso.") end
        if not Utils.removeRunes(src, price, "faction_upgrade_expand_storage:" .. tostring(target.id)) then return respond(src, token, false, ("Você precisa de %s Runas."):format(price)) end
        removeFeatureIntegration(owner.faction_key, target, false)
        update("UPDATE magic_pause_faction_features SET weight = COALESCE(weight, 0) + ? WHERE id = ?", { tonumber(upgrade.weight) or 200, target.id })
        for _, row in ipairs(featureRows(owner.faction_key)) do if tonumber(row.id) == tonumber(target.id) then materializeFeature(owner.faction_key, row, owner.group_name) end end
        recordTransaction(owner.faction_key, userId, "upgrade_storage_weight", tostring(target.id), price)
        return respond(src, token, true, ("Peso do baú aumentado em %sKg."):format(tonumber(upgrade.weight) or 200))
    end

    local modelId = configuredModelId(owner.faction_key, upgrade)
    if (upgrade.type == "storage" or upgrade.type == "garage" or upgrade.type == "craft" or upgrade.type == "farm") and not getModuleModel(upgrade.type, modelId) then
        return respond(src, token, false, "Este upgrade ainda não possui um modelo instalável.")
    end
    local encoded
    if upgrade.requiresLocation then
        encoded = serializeCoords(src, data.coords)
        if not encoded then return respond(src, token, false, "Fique no local desejado para comprar este upgrade.") end
    end
    if not Utils.removeRunes(src, price, "faction_upgrade:" .. upgrade.id) then return respond(src, token, false, ("Você precisa de %s Runas."):format(price)) end
    local paidUntil = upgrade.recurring and (now() + ((Config.Subscription.periodDays or 30) * 86400)) or nil
    local id = insert([[
        INSERT INTO magic_pause_faction_features(faction_key, feature_id, feature_type, model_id, label, source_kind, price, quantity, weight, coords, recurring, paid_until, created_by, created_at)
        VALUES(?, ?, ?, ?, ?, 'upgrade', ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { owner.faction_key, upgrade.id, upgrade.type, modelId, upgrade.label, price, tonumber(upgrade.amount) or 1, tonumber(upgrade.weight) or 0, encoded, upgrade.recurring and 1 or 0, paidUntil, userId, now() })
    if upgrade.type == "member_capacity" then update("UPDATE magic_pause_factions SET member_limit = member_limit + ? WHERE faction_key = ?", { tonumber(upgrade.amount) or 10, owner.faction_key }) end
    for _, row in ipairs(featureRows(owner.faction_key)) do if tonumber(row.id) == tonumber(id) then materializeFeature(owner.faction_key, row, owner.group_name) end end
    recordTransaction(owner.faction_key, userId, "upgrade", upgrade.id, price)
    respond(src, token, true, upgrade.label .. " adquirido com sucesso.")
end)

RegisterNetEvent("MagicPause:server:renewFactionUpgrade", function(token, data)
    local src = source
    local userId, owner, err = activeOwner(src)
    if not userId then return respond(src, token, false, err) end
    local feature = query("SELECT * FROM magic_pause_faction_features WHERE id = ? AND faction_key = ? AND recurring = 1 LIMIT 1", { tonumber(data and data.id), owner.faction_key })[1]
    if not feature then return respond(src, token, false, "Serviço mensal não encontrado.") end
    local price = tonumber(feature.price) or 0
    if not Utils.removeRunes(src, price, "faction_upgrade_renew:" .. feature.feature_id) then return respond(src, token, false, ("Você precisa de %s Runas."):format(price)) end
    update("UPDATE magic_pause_faction_features SET paid_until = ?, status = 'active' WHERE id = ?", { now() + ((Config.Subscription.periodDays or 30) * 86400), feature.id })
    recordTransaction(owner.faction_key, userId, "upgrade_renewal", feature.feature_id, price)
    respond(src, token, true, "Upgrade mensal renovado.")
end)

RegisterNetEvent("MagicPause:server:setFeatureLocation", function(token, data)
    local src = source
    local userId, owner, err = activeOwner(src)
    if not userId then return respond(src, token, false, err) end
    local feature = query("SELECT * FROM magic_pause_faction_features WHERE id = ? AND faction_key = ? LIMIT 1", { tonumber(data and data.id), owner.faction_key })[1]
    if not feature or not supportsPosition(feature.feature_type) then return respond(src, token, false, "Módulo inválido.") end
    if feature.coords and feature.coords ~= "" then return respond(src, token, false, "Use mover para trocar um local instalado.") end
    local encoded = serializeCoords(src, data and data.coords)
    if not encoded then return respond(src, token, false, "Fique no ponto desejado antes de confirmar.") end
    update("UPDATE magic_pause_faction_features SET coords = ?, metadata = NULL WHERE id = ?", { encoded, feature.id })
    for _, row in ipairs(featureRows(owner.faction_key)) do if tonumber(row.id) == tonumber(feature.id) then materializeFeature(owner.faction_key, row, owner.group_name) end end
    recordTransaction(owner.faction_key, userId, "placement", feature.feature_id, 0)
    respond(src, token, true, feature.label .. " instalado no local atual.")
end)

RegisterNetEvent("MagicPause:server:renameFactionFeature", function(token, data)
    local src = source
    local userId, owner, err = activeOwner(src)
    if not userId then return respond(src, token, false, err) end
    local label = tostring(data and data.label or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #label < 2 or #label > 32 then return respond(src, token, false, "Use um nome entre 2 e 32 caracteres.") end
    local feature = query("SELECT * FROM magic_pause_faction_features WHERE id = ? AND faction_key = ? AND feature_type = 'storage' LIMIT 1", { tonumber(data and data.id), owner.faction_key })[1]
    if not feature then return respond(src, token, false, "Baú não encontrado.") end
    removeFeatureIntegration(owner.faction_key, feature, false)
    update("UPDATE magic_pause_faction_features SET label = ? WHERE id = ?", { label, feature.id })
    for _, row in ipairs(featureRows(owner.faction_key)) do if tonumber(row.id) == tonumber(feature.id) then materializeFeature(owner.faction_key, row, owner.group_name) end end
    respond(src, token, true, "Baú renomeado com sucesso.")
end)

RegisterNetEvent("MagicPause:server:repositionFactionFeature", function(token, data)
    local src = source
    local userId, owner, err = activeOwner(src)
    if not userId then return respond(src, token, false, err) end
    local feature = query("SELECT * FROM magic_pause_faction_features WHERE id = ? AND faction_key = ? LIMIT 1", { tonumber(data and data.id), owner.faction_key })[1]
    if not feature or not supportsPosition(feature.feature_type) or not feature.coords or feature.coords == "" then return respond(src, token, false, "Ponto inválido para mover.") end
    local encoded = serializeCoords(src, data and data.coords)
    if not encoded then return respond(src, token, false, "Fique no novo local antes de confirmar.") end
    local price = math.max(0, math.floor(tonumber((Config.PositionReset or {}).singlePrice) or 30))
    if not Utils.removeRunes(src, price, "faction_position_reset:" .. tostring(feature.id)) then return respond(src, token, false, ("Você precisa de %s Runas."):format(price)) end
    removeFeatureIntegration(owner.faction_key, feature, false)
    update("UPDATE magic_pause_faction_features SET coords = ?, metadata = NULL WHERE id = ?", { encoded, feature.id })
    for _, row in ipairs(featureRows(owner.faction_key)) do if tonumber(row.id) == tonumber(feature.id) then materializeFeature(owner.faction_key, row, owner.group_name) end end
    recordTransaction(owner.faction_key, userId, "position_reset", tostring(feature.id), price)
    respond(src, token, true, "Ponto reposicionado.")
end)

RegisterNetEvent("MagicPause:server:setGarageSpawn", function(token, data)
    local src = source
    local userId, owner, err = activeOwner(src)
    if not userId then return respond(src, token, false, err) end
    local feature = query("SELECT * FROM magic_pause_faction_features WHERE id = ? AND faction_key = ? AND feature_type = 'garage' LIMIT 1", { tonumber(data and data.id), owner.faction_key })[1]
    if not feature then return respond(src, token, false, "Garagem inválida.") end
    feature.coords = decodeMaybe(feature.coords)
    feature.metadata = decodeMaybe(feature.metadata) or {}
    local anchor = placedCoords(feature)
    if not anchor then return respond(src, token, false, "Instale primeiro o local principal da garagem.") end
    local modelId, model = resolveFeatureModel(owner.faction_key, feature)
    local settings = garageSpawnSettings(model)
    local slot = math.floor(tonumber(data and data.slot) or 1)
    if slot < 1 or slot > settings.maxPoints then return respond(src, token, false, "Slot inválido.") end
    local point = coordsTableFromClient(src, data and data.coords)
    local allowed, distance = validGarageSpawn(anchor, point, settings.maxDistance)
    if not allowed then return respond(src, token, false, ("O spawn precisa ficar em até %sm da garagem. Distância atual: %.1fm."):format(math.floor(settings.maxDistance + 0.5), distance or 0.0)) end
    removeFeatureIntegration(owner.faction_key, feature, false)
    feature.metadata.spawnPoints = type(feature.metadata.spawnPoints) == "table" and feature.metadata.spawnPoints or {}
    feature.metadata.spawnPoints[slot] = { x = point.x, y = point.y, z = point.z, h = point.h or 0.0 }
    update("UPDATE magic_pause_faction_features SET metadata = ? WHERE id = ?", { json.encode(feature.metadata), feature.id })
    for _, row in ipairs(featureRows(owner.faction_key)) do if tonumber(row.id) == tonumber(feature.id) then materializeFeature(owner.faction_key, row, owner.group_name) end end
    recordTransaction(owner.faction_key, userId, "garage_spawn", tostring(feature.id) .. ":" .. tostring(slot), 0)
    respond(src, token, true, ("Spawn %s da garagem atualizado."):format(slot))
end)

RegisterNetEvent("MagicPause:server:resetAllFactionPositions", function(token)
    local src = source
    local userId, owner, err = activeOwner(src)
    if not userId then return respond(src, token, false, err) end
    local positioned = {}
    for _, feature in ipairs(featureRows(owner.faction_key)) do
        if supportsPosition(feature.feature_type) and placedCoords(feature) then positioned[#positioned + 1] = feature end
    end
    if #positioned == 0 then return respond(src, token, false, "Não existem pontos ativos para resetar.", "info") end
    local price = math.max(0, math.floor(tonumber((Config.PositionReset or {}).allPrice) or 100))
    if not Utils.removeRunes(src, price, "faction_positions_reset_all:" .. owner.faction_key) then return respond(src, token, false, ("Você precisa de %s Runas."):format(price)) end
    for _, feature in ipairs(positioned) do removeFeatureIntegration(owner.faction_key, feature, false) end
    update("UPDATE magic_pause_faction_features SET coords = NULL, metadata = NULL WHERE faction_key = ? AND coords IS NOT NULL AND source_kind <> 'fixed'", { owner.faction_key })
    recordTransaction(owner.faction_key, userId, "positions_reset_all", owner.faction_key, price)
    respond(src, token, true, "Posições resetadas. Instale cada ponto novamente.")
end)

RegisterCommand("testclanuser", function(src)
    if src <= 0 then return end
    if not Utils.isStaff(src) then
        TriggerClientEvent("chat:addMessage", src, { args = { "MagicPause", "Você não possui permissão." } })
        return
    end
    testNonStaffView[src] = not testNonStaffView[src]
    local mode = testNonStaffView[src] and "jogador comum" or "staff"
    TriggerClientEvent("chat:addMessage", src, { args = { "MagicPause", "Modo teste de clã: " .. mode .. "." } })
    TriggerClientEvent("MagicPause:client:refreshFactions", src)
end, false)

AddEventHandler("playerDropped", function()
    testNonStaffView[source] = nil
end)

CreateThread(function()
    Wait(500)
    ensureFactionTables()
    restoreIntegrations()
end)

AddEventHandler("onResourceStart", function(resource)
    if resource ~= "VanguardInventory" and resource ~= "VanguardGarage" and resource ~= "VanguardCraft" and resource ~= "VanguardFarm" then return end
    CreateThread(function()
        Wait(1000)
        restoreIntegrations()
    end)
end)
