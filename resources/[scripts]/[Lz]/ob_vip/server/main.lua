local RESOURCE = GetCurrentResourceName()
local DAY_SECONDS = 86400
local databaseReady = false
local cache = {}
local inventoryState = {}
local refreshCooldown = {}
local nameChangeCooldown = {}
local rentalLocks = {}
local rentalCooldowns = {}
local salarySessions = {}
local salaryCitizenBySource = {}
local syncCitizen

local function debugLog(message)
    if Config.Debug then
        print(('^5[%s]^7 %s'):format(RESOURCE, tostring(message)))
    end
end

local function normalize(value)
    local normalized = tostring(value or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
    return normalized
end

local function plan(vip)
    return Config.Vips and Config.Vips[normalize(vip)] or nil
end

local function now()
    return os.time()
end

local function decode(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, result = pcall(json.decode, value)
    return ok and type(result) == 'table' and result or fallback
end

local function rentalDays(value)
    return math.max(1, math.floor(tonumber(value)
        or tonumber(Config.Rentals and Config.Rentals.durationDays)
        or 30))
end

local function rentalRunes(value)
    return math.max(0, math.floor(tonumber(value) or 0))
end

local function clone(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end

    local result = {}
    seen[value] = result
    for key, item in pairs(value) do result[clone(key, seen)] = clone(item, seen) end
    return result
end

local function notify(source, message, notifyType)
    if source and source > 0 then
        exports.qbx_core:Notify(source, tostring(message), notifyType or 'inform', 5000)
    else
        print(('[%s] %s'):format(RESOURCE, tostring(message)))
    end
end

local function playerFromSource(source)
    return source and exports.qbx_core:GetPlayer(tonumber(source)) or nil
end

local function onlinePlayerByCitizenId(citizenid)
    return exports.qbx_core:GetPlayerByCitizenId(tostring(citizenid))
end

local function citizenIdFrom(identifier)
    if type(identifier) == 'number' or tonumber(identifier) then
        local player = playerFromSource(tonumber(identifier))
        if player then return tostring(player.PlayerData.citizenid), player end
    end

    local citizenid = tostring(identifier or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if citizenid == '' then return nil end
    return citizenid, onlinePlayerByCitizenId(citizenid)
end

local function citizenExists(citizenid)
    return MySQL.scalar.await('SELECT 1 FROM players WHERE citizenid = ? LIMIT 1', { citizenid }) ~= nil
end

local function salaryConfig(vip)
    local cfg = plan(vip)
    local salary = cfg and cfg.salary or {}
    local interval = tonumber(salary.everySeconds)
    if not interval or interval < 1 then
        interval = math.max(1, tonumber(salary.everyMinutes) or 60) * 60
    end
    return math.max(0, math.floor(tonumber(salary.amount) or 0)), math.max(1, math.floor(interval)), tostring(salary.account or 'bank')
end

local function activeRows(citizenid, timestamp)
    return MySQL.query.await([[
        SELECT id, citizenid, vip, starts_at, expires_at, next_salary_at
        FROM ob_vip_memberships
        WHERE citizenid = ?
          AND active = 1
          AND starts_at <= ?
          AND (expires_at IS NULL OR expires_at > ?)
        ORDER BY expires_at IS NULL DESC, expires_at DESC, id ASC
    ]], { citizenid, timestamp, timestamp }) or {}
end

local function startOnlineSalarySession(citizenid, source)
    if not Config.Salary.onlineOnly then return true end

    citizenid = tostring(citizenid or '')
    source = tonumber(source)
    local player = source and playerFromSource(source)
    if citizenid == '' or not player or tostring(player.PlayerData.citizenid) ~= citizenid then return false end

    local timestamp = now()
    local rows = activeRows(citizenid, timestamp)
    for _, row in ipairs(rows) do
        local amount, interval = salaryConfig(row.vip)
        if amount > 0 then
            MySQL.update.await([[UPDATE ob_vip_memberships
                SET next_salary_at = ? WHERE id = ? AND active = 1]], {
                timestamp + interval, row.id
            })
        else
            MySQL.update.await('UPDATE ob_vip_memberships SET next_salary_at = NULL WHERE id = ?', { row.id })
        end
    end

    local previousCitizenid = salaryCitizenBySource[source]
    if previousCitizenid and previousCitizenid ~= citizenid then
        salarySessions[previousCitizenid] = nil
    end

    salarySessions[citizenid] = { source = source, startedAt = timestamp }
    salaryCitizenBySource[source] = citizenid
    debugLog(('Contagem de salario online iniciada para %s.'):format(citizenid))
    return true
end

local function stopOnlineSalarySession(source)
    source = tonumber(source)
    if not source then return end

    local citizenid = salaryCitizenBySource[source]
    salaryCitizenBySource[source] = nil
    if not citizenid then return end

    local session = salarySessions[citizenid]
    if session and tonumber(session.source) == source then
        salarySessions[citizenid] = nil
    end

    if Config.Salary.onlineOnly and databaseReady then
        MySQL.update('UPDATE ob_vip_memberships SET next_salary_at = NULL WHERE citizenid = ? AND active = 1', {
            citizenid
        })
    end
end

local function aggregateValue(current, value, mode)
    value = math.max(0, tonumber(value) or 0)
    if mode == 'sum' then return current + value end
    return math.max(current, value)
end

local function equippedBackpack(citizenid)
    local row = MySQL.single.await([[
        SELECT item_name FROM ob_vip_backpacks
        WHERE citizenid = ? AND equipped = 1
        LIMIT 1
    ]], { citizenid })
    if not row then return nil end

    local itemName = normalize(row.item_name)
    local cfg = Config.Backpacks and Config.Backpacks[itemName]
    if not cfg then return nil end
    return {
        item = itemName,
        label = cfg.label or itemName,
        bonusWeight = math.max(0, math.floor(tonumber(cfg.bonusWeight) or 0)),
    }
end

local function buildPayload(citizenid, rows, timestamp)
    local memberships = {}
    local benefits = {
        salaryTotal = 0,
        salaryEntries = {},
        vehicleDiscount = 0,
        fuelDiscount = 0,
        medicalDiscount = 0,
        inventoryWeight = 0,
        vipInventoryWeight = 0,
        backpackWeight = 0,
        backpack = nil,
        availableBackpacks = {},
        keepBackpackOnDeath = false,
        nameChanges = 0,
        discordRoleIds = {},
    }
    local roleSet = {}
    local highest

    for _, row in ipairs(rows) do
        local vip = normalize(row.vip)
        local cfg = plan(vip)

        if cfg then
            local amount, interval, account = salaryConfig(vip)
            local expiresAt = tonumber(row.expires_at)
            local membership = {
                id = tonumber(row.id),
                vip = vip,
                label = cfg.label or vip,
                priority = tonumber(cfg.priority) or 0,
                startsAt = tonumber(row.starts_at),
                expiresAt = expiresAt,
                remainingSeconds = expiresAt and math.max(0, expiresAt - timestamp) or nil,
                nextSalaryAt = tonumber(row.next_salary_at),
            }

            memberships[#memberships + 1] = membership
            benefits.salaryTotal = benefits.salaryTotal + amount
            benefits.salaryEntries[#benefits.salaryEntries + 1] = {
                membershipId = membership.id,
                vip = vip,
                label = membership.label,
                amount = amount,
                account = account,
                everySeconds = interval,
                nextSalaryAt = membership.nextSalaryAt,
            }
            benefits.vehicleDiscount = aggregateValue(
                benefits.vehicleDiscount,
                cfg.vehicleDiscount,
                Config.Stacking and Config.Stacking.vehicleDiscount
            )
            benefits.fuelDiscount = aggregateValue(
                benefits.fuelDiscount,
                cfg.fuelDiscount,
                Config.Stacking and Config.Stacking.fuelDiscount
            )
            benefits.medicalDiscount = aggregateValue(
                benefits.medicalDiscount,
                cfg.medicalDiscount,
                Config.Stacking and Config.Stacking.medicalDiscount
            )
            benefits.vipInventoryWeight = aggregateValue(
                benefits.vipInventoryWeight,
                cfg.inventoryWeight,
                Config.Stacking and Config.Stacking.inventoryWeight
            )
            benefits.nameChanges = benefits.nameChanges + math.max(0, math.floor(tonumber(cfg.nameChanges) or 0))

            local roleId = tostring(cfg.discordRoleId or '')
            if roleId ~= '' and not roleSet[roleId] then
                roleSet[roleId] = true
                benefits.discordRoleIds[#benefits.discordRoleIds + 1] = roleId
            end

            if not highest or membership.priority > highest.priority then
                highest = {
                    vip = membership.vip,
                    label = membership.label,
                    priority = membership.priority,
                    expiresAt = membership.expiresAt,
                    remainingSeconds = membership.remainingSeconds,
                }
            end
        end
    end

    local backpack = equippedBackpack(citizenid)
    if backpack then
        benefits.backpack = backpack
        benefits.backpackWeight = backpack.bonusWeight
    end
    benefits.inventoryWeight = benefits.vipInventoryWeight + benefits.backpackWeight

    return {
        active = #memberships > 0,
        citizenid = citizenid,
        highest = highest,
        memberships = memberships,
        benefits = benefits,
        syncedAt = timestamp,
    }
end

local function applyInventoryWeight(source, bonus, attempt)
    if not Config.Inventory or Config.Inventory.enabled == false then return end
    if GetResourceState('ox_inventory') ~= 'started' or GetPlayerPing(source) <= 0 then return end

    local inventory = exports.ox_inventory:GetInventory(source)
    if not inventory then
        attempt = (attempt or 0) + 1
        if attempt <= (tonumber(Config.Inventory.retryCount) or 10) then
            SetTimeout(tonumber(Config.Inventory.retryDelayMs) or 500, function()
                applyInventoryWeight(source, bonus, attempt)
            end)
        end
        return
    end

    local state = inventoryState[source]
    if not state then
        local previousBonus = tonumber(Player(source).state.obVipInventoryBonus) or 0
        state = {
            baseWeight = math.max(0, (tonumber(inventory.maxWeight) or GetConvarInt('inventory:weight', 30000)) - previousBonus),
            appliedBonus = previousBonus,
        }
        inventoryState[source] = state
    end

    bonus = math.max(0, math.floor(tonumber(bonus) or 0))
    exports.ox_inventory:SetMaxWeight(source, state.baseWeight + bonus)
    state.appliedBonus = bonus
    Player(source).state:set('obVipInventoryBonus', bonus, true)
end

local function createEntitlement(membershipId, citizenid, vip, kind, slotIndex, itemName, amount, metadata)
    MySQL.insert.await([[
        INSERT IGNORE INTO ob_vip_entitlements
            (membership_id, citizenid, vip, benefit_kind, slot_index, item_name, amount, status, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', ?)
    ]], {
        membershipId,
        citizenid,
        vip,
        kind,
        slotIndex,
        itemName,
        math.max(0, math.floor(tonumber(amount) or 0)),
        metadata and json.encode(metadata) or nil,
    })
end

local function ensureMembershipEntitlements(row)
    local vip = normalize(row.vip)
    local cfg = plan(vip)
    if not cfg then return end

    local membershipId = tonumber(row.id)
    local citizenid = tostring(row.citizenid)
    local expiresAt = tonumber(row.expires_at)
    local initialMoney = cfg.initialMoney or {}
    local initialAmount = math.max(0, math.floor(tonumber(initialMoney.amount) or 0))

    if initialAmount > 0 then
        createEntitlement(membershipId, citizenid, vip, 'money', 1, tostring(initialMoney.account or 'bank'), initialAmount)
    end

    local nameChanges = math.max(0, math.floor(tonumber(cfg.nameChanges) or 0))
    if nameChanges > 0 then
        createEntitlement(membershipId, citizenid, vip, 'item', 2, 'troca_nome', nameChanges, {
            membershipId = membershipId,
            vip = vip,
            expiresAt = expiresAt,
            benefit = 'name_change',
        })
    end

    local vehicleCount = math.max(0, math.floor(tonumber(cfg.vehicles and cfg.vehicles.count) or 0))
    for slot = 1, vehicleCount do
        createEntitlement(membershipId, citizenid, vip, 'vehicle', slot, nil, 1, {
            membershipExpiresAt = expiresAt,
            durationDays = rentalDays(cfg.vehicles and cfg.vehicles.durationDays),
            renewalRunes = rentalRunes(cfg.vehicles and cfg.vehicles.renewalRunes),
        })
    end

    local property = cfg.property
    if property and property.enabled ~= false and normalize(property.tier or vip) ~= '' then
        createEntitlement(membershipId, citizenid, vip, 'property', 1, nil, 1, {
            membershipExpiresAt = expiresAt,
            tier = normalize(property.tier or vip),
            durationDays = rentalDays(property.durationDays),
            renewalRunes = rentalRunes(property.renewalRunes),
        })
    end
end

local function processPropertyEntitlements(citizenid)
    if GetResourceState('ob_housing') ~= 'started' then return end

    local timestamp = now()
    local rows = MySQL.query.await([[
        SELECT entitlement.id, entitlement.membership_id, entitlement.vip, entitlement.metadata
        FROM ob_vip_entitlements entitlement
        INNER JOIN ob_vip_memberships membership ON membership.id = entitlement.membership_id
        WHERE entitlement.citizenid = ?
          AND entitlement.status = 'pending'
          AND entitlement.benefit_kind = 'property'
          AND membership.active = 1
          AND membership.starts_at <= ?
          AND (membership.expires_at IS NULL OR membership.expires_at > ?)
        ORDER BY entitlement.id ASC
    ]], { citizenid, timestamp, timestamp }) or {}

    for _, entitlement in ipairs(rows) do
        local cfg = plan(entitlement.vip)
        local property = cfg and cfg.property
        if property and property.enabled ~= false then
            local metadata = decode(entitlement.metadata, {})
            local durationDays = rentalDays(metadata.durationDays or property.durationDays)
            local renewalPrice = rentalRunes(metadata.renewalRunes or property.renewalRunes)
            local tier = normalize(metadata.tier or property.tier or entitlement.vip)
            local token = ('property:%s:%s'):format(entitlement.id, GetGameTimer())
            local reserved = MySQL.update.await([[
                UPDATE ob_vip_entitlements
                SET status = 'processing', claim_token = ?, error = NULL
                WHERE id = ? AND citizenid = ? AND status = 'pending'
            ]], { token, entitlement.id, citizenid }) or 0

            if reserved == 1 then
                local called, result = pcall(function()
                    return exports.ob_housing:GrantVipTierProperty(citizenid, tier, durationDays, {
                        vip = normalize(entitlement.vip),
                        tier = tier,
                        membershipId = tonumber(entitlement.membership_id),
                        entitlementId = tonumber(entitlement.id),
                        durationDays = durationDays,
                        renewalRunes = renewalPrice,
                    })
                end)
                local delivered = called and type(result) == 'table' and result.ok == true

                if delivered then
                    MySQL.update.await([[
                        UPDATE ob_vip_entitlements
                        SET status = 'claimed', claimed_at = ?, claim_token = NULL,
                            selection = ?, error = NULL
                        WHERE id = ? AND status = 'processing' AND claim_token = ?
                    ]], { timestamp, result.property and result.property.key or tier, entitlement.id, token })
                    TriggerEvent('ob_vip:server:propertyGranted', citizenid, entitlement.id, result)
                else
                    local reason = called and type(result) == 'table' and result.error or result
                    MySQL.update.await([[
                        UPDATE ob_vip_entitlements
                        SET status = 'pending', claim_token = NULL, error = ?
                        WHERE id = ? AND status = 'processing' AND claim_token = ?
                    ]], { tostring(reason or 'mansao vip indisponivel'):sub(1, 160), entitlement.id, token })
                end
            end
        end
    end
end

local function processImmediateEntitlements(citizenid, player)
    if not player then return end
    local source = tonumber(player.PlayerData.source)
    local timestamp = now()
    local rows = MySQL.query.await([[
        SELECT entitlement.*
        FROM ob_vip_entitlements entitlement
        INNER JOIN ob_vip_memberships membership ON membership.id = entitlement.membership_id
        WHERE entitlement.citizenid = ?
          AND entitlement.status = 'pending'
          AND entitlement.benefit_kind IN ('money', 'item')
          AND membership.active = 1
          AND membership.starts_at <= ?
          AND (membership.expires_at IS NULL OR membership.expires_at > ?)
        ORDER BY entitlement.id ASC
    ]], { citizenid, timestamp, timestamp }) or {}

    local inventory = GetResourceState('ox_inventory') == 'started' and exports.ox_inventory:GetInventory(source) or nil
    for _, entitlement in ipairs(rows) do
        local kind = tostring(entitlement.benefit_kind)
        if kind ~= 'item' or inventory then
            local token = ('%s:%s:%s'):format(source, entitlement.id, GetGameTimer())
            local claimed = MySQL.update.await([[
                UPDATE ob_vip_entitlements
                SET status = 'processing', claim_token = ?, error = NULL
                WHERE id = ? AND citizenid = ? AND status = 'pending'
            ]], { token, entitlement.id, citizenid }) or 0

            if claimed == 1 then
                local delivered = false
                local errorMessage
                local amount = math.max(1, math.floor(tonumber(entitlement.amount) or 1))

                if kind == 'money' then
                    local account = tostring(entitlement.item_name or 'bank')
                    delivered = player.Functions.AddMoney(account, amount, ('vip_initial:%s:%s'):format(entitlement.vip, entitlement.id)) == true
                    errorMessage = delivered and nil or 'qbx_core recusou o pagamento inicial'
                elseif kind == 'item' then
                    local itemName = normalize(entitlement.item_name)
                    if exports.ox_inventory:CanCarryItem(source, itemName, amount) then
                        delivered = exports.ox_inventory:AddItem(source, itemName, amount) == true
                        errorMessage = delivered and nil or 'ox_inventory recusou a entrega do item'
                    else
                        errorMessage = 'sem espaco no inventario'
                    end
                end

                if delivered then
                    MySQL.update.await([[
                        UPDATE ob_vip_entitlements
                        SET status = 'claimed', claimed_at = ?, claim_token = NULL, error = NULL
                        WHERE id = ? AND status = 'processing' AND claim_token = ?
                    ]], { timestamp, entitlement.id, token })
                    if kind == 'money' then
                        notify(source, ('$%s do beneficio inicial %s foram depositados.'):format(amount, plan(entitlement.vip).label), 'success')
                    else
                        notify(source, ('Beneficio %s recebido no inventario.'):format(entitlement.item_name), 'success')
                    end
                else
                    MySQL.update.await([[
                        UPDATE ob_vip_entitlements
                        SET status = 'pending', claim_token = NULL, error = ?
                        WHERE id = ? AND status = 'processing' AND claim_token = ?
                    ]], { tostring(errorMessage or 'falha desconhecida'):sub(1, 160), entitlement.id, token })
                end
            end
        end
    end
end

local function retryImmediateEntitlements(timestamp)
    local rows = MySQL.query.await([[
        SELECT DISTINCT entitlement.citizenid
        FROM ob_vip_entitlements entitlement
        INNER JOIN ob_vip_memberships membership ON membership.id = entitlement.membership_id
        WHERE entitlement.status = 'pending'
          AND entitlement.benefit_kind IN ('money', 'item')
          AND membership.active = 1
          AND membership.starts_at <= ?
          AND (membership.expires_at IS NULL OR membership.expires_at > ?)
        LIMIT 250
    ]], { timestamp, timestamp }) or {}

    for _, row in ipairs(rows) do
        local citizenid = tostring(row.citizenid)
        if onlinePlayerByCitizenId(citizenid) then syncCitizen(citizenid) end
    end
end

local function backfillActivePropertyEntitlements(timestamp)
    local rows = MySQL.query.await([[
        SELECT membership.id, membership.citizenid, membership.vip, membership.expires_at
        FROM ob_vip_memberships membership
        LEFT JOIN ob_vip_entitlements entitlement
          ON entitlement.membership_id = membership.id
         AND entitlement.benefit_kind = 'property'
         AND entitlement.slot_index = 1
        WHERE membership.active = 1
          AND membership.starts_at <= ?
          AND (membership.expires_at IS NULL OR membership.expires_at > ?)
          AND entitlement.id IS NULL
        ORDER BY membership.id ASC
    ]], { timestamp, timestamp }) or {}

    local created = 0
    for _, membership in ipairs(rows) do
        local vip = normalize(membership.vip)
        local cfg = plan(vip)
        local property = cfg and cfg.property
        local tier = property and normalize(property.tier or vip) or ''

        if property and property.enabled ~= false and tier ~= '' then
            createEntitlement(
                tonumber(membership.id),
                tostring(membership.citizenid),
                vip,
                'property',
                1,
                nil,
                1,
                {
                    membershipExpiresAt = tonumber(membership.expires_at),
                    tier = tier,
                    durationDays = rentalDays(property.durationDays),
                    renewalRunes = rentalRunes(property.renewalRunes),
                }
            )
            created = created + 1
        end
    end

    if created > 0 then
        print(('^3[%s]^7 %d beneficio(s) de mansao VIP antigo(s) foram preparados.'):format(RESOURCE, created))
    end
    return created
end

local function retryPropertyEntitlements(timestamp)
    if GetResourceState('ob_housing') ~= 'started' then return end
    local rows = MySQL.query.await([[
        SELECT DISTINCT entitlement.citizenid
        FROM ob_vip_entitlements entitlement
        INNER JOIN ob_vip_memberships membership ON membership.id = entitlement.membership_id
        WHERE entitlement.status = 'pending'
          AND entitlement.benefit_kind = 'property'
          AND membership.active = 1
          AND membership.starts_at <= ?
          AND (membership.expires_at IS NULL OR membership.expires_at > ?)
        LIMIT 250
    ]], { timestamp, timestamp }) or {}

    for _, row in ipairs(rows) do processPropertyEntitlements(tostring(row.citizenid)) end
end

syncCitizen = function(citizenid)
    if not databaseReady then return nil end

    local timestamp = now()
    local rows = activeRows(citizenid, timestamp)
    for _, row in ipairs(rows) do ensureMembershipEntitlements(row) end
    processPropertyEntitlements(citizenid)

    local player = onlinePlayerByCitizenId(citizenid)
    if player then processImmediateEntitlements(citizenid, player) end

    local payload = buildPayload(citizenid, rows, timestamp)
    cache[citizenid] = payload

    if player then
        local source = player.PlayerData.source
        Player(source).state:set('obVip', payload, true)
        applyInventoryWeight(source, payload.benefits.inventoryWeight)
        TriggerClientEvent('ob_vip:client:updated', source, payload)
    end

    TriggerEvent('ob_vip:server:membershipChanged', citizenid, payload)
    return payload
end

local function getPayload(identifier, forceRefresh)
    local citizenid = citizenIdFrom(identifier)
    if not citizenid then return nil end
    if forceRefresh or not cache[citizenid] then return syncCitizen(citizenid) end
    return cache[citizenid]
end

local function addVip(identifier, vip, days, options)
    if not databaseReady then return false, 'O banco de dados do VIP ainda nao esta pronto.' end

    local citizenid = citizenIdFrom(identifier)
    vip = normalize(vip)
    local cfg = plan(vip)
    days = tonumber(days)

    if not citizenid or not citizenExists(citizenid) then return false, 'CitizenID nao encontrado.' end
    if not cfg then return false, ('VIP "%s" nao existe na Config.Vips.'):format(vip) end
    if not days or days < 0 then return false, 'Informe uma quantidade de dias valida.' end

    local timestamp = now()
    local salaryAmount, interval = salaryConfig(vip)
    local expiresAt = days == 0 and nil or timestamp + math.floor(days * DAY_SECONDS)
    local nextSalaryAt = salaryAmount > 0 and (Config.Salary.payImmediately and timestamp or timestamp + interval) or nil
    options = type(options) == 'table' and options or {}
    local grantedBy = options.grantedBy and tostring(options.grantedBy) or nil
    local grantReason = options.reason and tostring(options.reason):sub(1, 120) or nil

    -- Store purchases may be retried after a database or resource interruption.
    -- Reuse the membership tied to the same order instead of stacking it twice.
    if grantedBy and grantReason then
        local existing = MySQL.single.await([[
            SELECT id, starts_at, expires_at
            FROM ob_vip_memberships
            WHERE citizenid = ? AND vip = ? AND granted_by = ? AND grant_reason = ?
            ORDER BY id DESC
            LIMIT 1
        ]], { citizenid, vip, grantedBy, grantReason })

        if existing then
            local payload = syncCitizen(citizenid)
            return true, {
                id = tonumber(existing.id),
                citizenid = citizenid,
                vip = vip,
                startsAt = tonumber(existing.starts_at),
                expiresAt = tonumber(existing.expires_at),
                payload = payload,
                reused = true,
            }
        end
    end

    local id = MySQL.insert.await([[
        INSERT INTO ob_vip_memberships
            (citizenid, vip, starts_at, expires_at, next_salary_at, active, granted_by, grant_reason, metadata)
        VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)
    ]], {
        citizenid,
        vip,
        timestamp,
        expiresAt,
        nextSalaryAt,
        grantedBy,
        grantReason,
        options.metadata and json.encode(options.metadata) or nil,
    })

    if not id then return false, 'Nao foi possivel registrar o VIP.' end

    local payload = syncCitizen(citizenid)
    TriggerEvent('ob_vip:server:membershipAdded', citizenid, vip, tonumber(id), payload)
    return true, {
        id = tonumber(id),
        citizenid = citizenid,
        vip = vip,
        startsAt = timestamp,
        expiresAt = expiresAt,
        payload = payload,
    }
end

local function removeVip(identifier, vipOrMembershipId)
    if not databaseReady then return false, 'O banco de dados do VIP ainda nao esta pronto.' end

    local citizenid = citizenIdFrom(identifier)
    if not citizenid then return false, 'CitizenID invalido.' end

    local affected
    local membershipId = tonumber(vipOrMembershipId)
    if membershipId then
        affected = MySQL.update.await([[
            UPDATE ob_vip_memberships
            SET active = 0
            WHERE id = ? AND citizenid = ? AND active = 1
        ]], { membershipId, citizenid }) or 0
    else
        local vip = normalize(vipOrMembershipId)
        if not plan(vip) then return false, 'Informe um VIP ou id de concessao valido.' end
        affected = MySQL.update.await([[
            UPDATE ob_vip_memberships
            SET active = 0
            WHERE citizenid = ? AND vip = ? AND active = 1
        ]], { citizenid, vip }) or 0
    end

    if affected < 1 then return false, 'Nenhum VIP ativo correspondente foi encontrado.' end
    local payload = syncCitizen(citizenid)
    TriggerEvent('ob_vip:server:membershipRemoved', citizenid, vipOrMembershipId, payload)
    return true, payload
end

local function clearVips(identifier)
    if not databaseReady then return false, 'O banco de dados do VIP ainda nao esta pronto.' end
    local citizenid = citizenIdFrom(identifier)
    if not citizenid then return false, 'CitizenID invalido.' end

    local affected = MySQL.update.await(
        'UPDATE ob_vip_memberships SET active = 0 WHERE citizenid = ? AND active = 1',
        { citizenid }
    ) or 0
    local payload = syncCitizen(citizenid)
    if affected > 0 then TriggerEvent('ob_vip:server:membershipsCleared', citizenid, payload) end
    return affected > 0, payload
end

local function calculateDiscount(identifier, amount, benefit)
    amount = math.max(0, tonumber(amount) or 0)
    local payload = getPayload(identifier)
    local percent = payload and tonumber(payload.benefits[benefit]) or 0
    percent = math.min(100, math.max(0, percent))
    local discount = math.floor(amount * (percent / 100) + 0.5)
    return math.max(0, amount - discount), discount, percent
end

local function backpackKeepItems(identifier)
    return {}
end

local function handleRespawn(identifier)
    local citizenid = citizenIdFrom(identifier)
    if not citizenid then return {} end

    MySQL.update.await('UPDATE ob_vip_backpacks SET equipped = 0 WHERE citizenid = ?', { citizenid })
    syncCitizen(citizenid)
    return {}
end

local function applyConsumedBackpack(source, itemName)
    local player = playerFromSource(source)
    itemName = normalize(itemName)
    local backpack = Config.Backpacks and Config.Backpacks[itemName]
    if not player or not backpack then return false, 'Mochila invalida.' end

    local citizenid = tostring(player.PlayerData.citizenid)
    MySQL.update.await([[
        INSERT INTO ob_vip_backpacks (citizenid, item_name, equipped)
        VALUES (?, ?, 1)
        ON DUPLICATE KEY UPDATE item_name = VALUES(item_name), equipped = VALUES(equipped)
    ]], { citizenid, itemName })

    syncCitizen(citizenid)
    return true, ('%s consumida. O bonus permanece ate a morte.'):format(backpack.label or itemName)
end

exports('useBackpack', function(event, item, inventory)
    local source = inventory and tonumber(inventory.id)
    local itemName = item and normalize(item.name)
    local backpack = itemName and Config.Backpacks and Config.Backpacks[itemName]

    if event == 'usingItem' then
        if not source or not playerFromSource(source) or not backpack then return false end
        local player = playerFromSource(source)
        local current = equippedBackpack(tostring(player.PlayerData.citizenid))
        if current and current.item == itemName then
            notify(source, ('%s ja esta ativa.'):format(backpack.label or itemName), 'error')
            return false
        end
        return true
    end

    if event == 'usedItem' and source and itemName then
        local success, message = applyConsumedBackpack(source, itemName)
        notify(source, message, success and 'success' or 'error')
    end
end)

local function vehicleCatalog(vip)
    local cfg = plan(vip)
    local catalog = {}
    for _, vehicle in ipairs(cfg and cfg.vehicles and cfg.vehicles.catalog or {}) do
        local imageName = tostring(vehicle.imageName or vehicle.model or ''):gsub('^%s+', ''):gsub('%s+$', '')
        local model = normalize(vehicle.model)
        if model ~= '' then
            local image = tostring(vehicle.image or '')
            if image == '' then
                local directory = tostring(Config.VehicleImageDirectory or 'web/imgs/vipstore'):gsub('/+$', '')
                image = ('%s/%s.png'):format(directory, imageName ~= '' and imageName or model)
            end

            catalog[#catalog + 1] = {
                model = model,
                label = tostring(vehicle.label or model),
                image = image,
            }
        end
    end
    return catalog
end

local function storeState(identifier)
    local citizenid = citizenIdFrom(identifier)
    if not citizenid then return { active = false, memberships = {}, benefits = {}, vehicleChoices = {} } end

    local payload = getPayload(citizenid, true)
    local timestamp = now()
    local rows = MySQL.query.await([[
        SELECT entitlement.id, entitlement.membership_id, entitlement.vip, entitlement.slot_index,
               membership.expires_at
        FROM ob_vip_entitlements entitlement
        INNER JOIN ob_vip_memberships membership ON membership.id = entitlement.membership_id
        WHERE entitlement.citizenid = ?
          AND entitlement.benefit_kind = 'vehicle'
          AND entitlement.status = 'pending'
          AND membership.active = 1
          AND membership.starts_at <= ?
          AND (membership.expires_at IS NULL OR membership.expires_at > ?)
        ORDER BY entitlement.membership_id ASC, entitlement.slot_index ASC
    ]], { citizenid, timestamp, timestamp }) or {}

    local choices = {}
    for _, row in ipairs(rows) do
        local cfg = plan(row.vip)
        if cfg then
            local vehicleCfg = cfg.vehicles or {}
            choices[#choices + 1] = {
                entitlementId = tonumber(row.id),
                membershipId = tonumber(row.membership_id),
                vip = normalize(row.vip),
                label = cfg.label or row.vip,
                slot = tonumber(row.slot_index),
                expiresAt = tonumber(row.expires_at),
                durationDays = rentalDays(vehicleCfg.durationDays),
                renewalRunes = rentalRunes(vehicleCfg.renewalRunes),
                vehicles = vehicleCatalog(row.vip),
            }
        end
    end

    return {
        active = payload and payload.active == true or false,
        memberships = payload and clone(payload.memberships) or {},
        benefits = payload and clone(payload.benefits) or {},
        vehicleChoices = choices,
    }
end

local function configuredGarage(requestedGarage)
    local garage = tostring(requestedGarage or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if garage == '' then
        garage = tostring(Config.VehicleGarage or ''):gsub('^%s+', ''):gsub('%s+$', '')
    end
    if garage == '' then return nil, 'Configure Config.VehicleGarage no ob_vip.' end
    if GetResourceState('qbx_garages') == 'started' then
        local ok, garages = pcall(function() return exports.qbx_garages:GetGarages() end)
        if not ok or type(garages) ~= 'table' or not garages[garage] then
            return nil, ('Garagem %s nao encontrada no qbx_garages.'):format(garage)
        end
    end
    return garage
end

local function uniqueVipPlate()
    for _ = 1, 25 do
        local plate = ('VIP%05d'):format(math.random(0, 99999))
        if not MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ? LIMIT 1', { plate }) then
            return plate
        end
    end
end

local function createVipVehicle(citizenid, model, garage, vehicleData)
    if GetResourceState('qbx_vehicles') == 'started' then
        local ok, vehicleId, vehicleError = pcall(function()
            return exports.qbx_vehicles:CreatePlayerVehicle({
                model = model,
                citizenid = citizenid,
                garage = garage,
                props = { fuelLevel = 100.0, engineHealth = 1000.0, bodyHealth = 1000.0 },
            })
        end)
        if ok and vehicleId then return tonumber(vehicleId), nil, 'qbx_vehicles' end
        return nil, ok and vehicleError or vehicleId
    end

    local plate = uniqueVipPlate()
    if not plate then return nil, 'Nao foi possivel gerar uma placa unica.' end
    local props = {
        model = tonumber(vehicleData.hash) or joaat(model),
        plate = plate,
        fuelLevel = 100.0,
        engineHealth = 1000.0,
        bodyHealth = 1000.0,
    }
    local vehicleId = MySQL.insert.await([[
        INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state, garage)
        VALUES ((SELECT license FROM players WHERE citizenid = ?), ?, ?, ?, ?, ?, 1, ?)
    ]], { citizenid, citizenid, model, props.model, json.encode(props), plate, garage })
    if not vehicleId then return nil, 'O banco recusou o registro do veiculo.' end
    return tonumber(vehicleId), nil, 'database'
end

local function deleteVipVehicle(vehicleId, provider)
    if provider == 'qbx_vehicles' and GetResourceState('qbx_vehicles') == 'started' then
        local ok = pcall(function() exports.qbx_vehicles:DeletePlayerVehicles('vehicleId', vehicleId) end)
        if ok then return end
    end
    MySQL.update.await('DELETE FROM player_vehicles WHERE id = ?', { vehicleId })
end

local function formatVehicleRental(row, timestamp)
    if not row then return nil end
    timestamp = timestamp or now()
    local expiresAt = tonumber(row.expires_at)
    local active = expiresAt and expiresAt > timestamp or false
    local sourceKind = normalize(row.source_kind or 'vip')
    return {
        managed = true,
        active = active,
        expired = not active,
        vehicleId = tonumber(row.vehicle_id),
        membershipId = tonumber(row.membership_id),
        entitlementId = tonumber(row.entitlement_id),
        vip = normalize(row.vip),
        model = normalize(row.model),
        startsAt = tonumber(row.starts_at),
        expiresAt = expiresAt,
        durationDays = rentalDays(row.duration_days),
        renewalRunes = rentalRunes(row.renewal_runes),
        renewalCount = math.max(0, math.floor(tonumber(row.renewal_count) or 0)),
        sourceKind = sourceKind,
        sourceId = tostring(row.source_id or ''),
        label = sourceKind == 'battlepass' and 'Veiculo do Passe' or 'Mensalidade VIP',
    }
end

local function vehicleRentalStates(identifier, vehicleIds)
    local citizenid = citizenIdFrom(identifier)
    if not citizenid or not databaseReady then return {} end

    local ids = {}
    local seen = {}
    for _, value in pairs(type(vehicleIds) == 'table' and vehicleIds or {}) do
        local vehicleId = tonumber(value)
        if vehicleId and not seen[vehicleId] then
            seen[vehicleId] = true
            ids[#ids + 1] = vehicleId
        end
    end
    if #ids == 0 then return {} end

    local placeholders = {}
    local parameters = { citizenid }
    for index, vehicleId in ipairs(ids) do
        placeholders[index] = '?'
        parameters[#parameters + 1] = vehicleId
    end
    local rows = MySQL.query.await(([=[
        SELECT vehicle_id, membership_id, entitlement_id, vip, model, starts_at, expires_at,
               duration_days, renewal_runes, renewal_count, source_kind, source_id
        FROM ob_vip_vehicle_rentals
        WHERE citizenid = ? AND vehicle_id IN (%s)
    ]=]):format(table.concat(placeholders, ',')), parameters) or {}

    local result = {}
    local timestamp = now()
    for _, row in ipairs(rows) do
        result[tostring(row.vehicle_id)] = formatVehicleRental(row, timestamp)
    end
    return result
end

local function getVehicleRental(identifier, vehicleId)
    local citizenid = citizenIdFrom(identifier)
    vehicleId = tonumber(vehicleId)
    if not citizenid or not vehicleId or not databaseReady then return nil end
    local row = MySQL.single.await([[
        SELECT vehicle_id, membership_id, entitlement_id, vip, model, starts_at, expires_at,
               duration_days, renewal_runes, renewal_count, source_kind, source_id
        FROM ob_vip_vehicle_rentals
        WHERE citizenid = ? AND vehicle_id = ?
        LIMIT 1
    ]], { citizenid, vehicleId })
    return formatVehicleRental(row)
end

local function canUseVehicle(identifier, vehicleId)
    if not databaseReady then return false, { validationUnavailable = true } end
    local rental = getVehicleRental(identifier, vehicleId)
    if not rental then return true, nil end
    return rental.active == true, rental
end

local function withRentalLock(key, callback)
    if rentalLocks[key] then return false, { ok = false, error = 'rental_busy' } end
    rentalLocks[key] = true
    local ok, result = pcall(callback)
    rentalLocks[key] = nil
    if not ok then
        print(('^1[%s] Falha na renovacao %s: %s^7'):format(RESOURCE, key, result))
        return false, { ok = false, error = 'renewal_failed' }
    end
    return result and result.ok == true, result
end

local function sourceVehicleRental(citizenid, sourceKind, sourceId)
    return MySQL.single.await([[
        SELECT rental.vehicle_id, rental.membership_id, rental.entitlement_id, rental.vip, rental.model,
               rental.starts_at, rental.expires_at, rental.duration_days, rental.renewal_runes,
               rental.renewal_count, rental.source_kind, rental.source_id,
               vehicle.plate, vehicle.garage, vehicle.id AS owned_vehicle_id
        FROM ob_vip_vehicle_rentals rental
        LEFT JOIN player_vehicles vehicle ON vehicle.id = rental.vehicle_id
        WHERE rental.citizenid = ? AND rental.source_kind = ? AND rental.source_id = ?
        LIMIT 1
    ]], { citizenid, sourceKind, sourceId })
end

local function grantRentalVehicle(identifier, options)
    if not databaseReady then return false, { ok = false, error = 'database_initializing' } end
    local citizenid = citizenIdFrom(identifier)
    if not citizenid or not citizenExists(citizenid) then
        return false, { ok = false, error = 'player_not_found' }
    end

    options = type(options) == 'table' and options or {}
    local model = normalize(options.model)
    local sourceKind = normalize(options.sourceKind or 'external'):gsub('[^%w_-]', ''):sub(1, 24)
    local sourceId = tostring(options.sourceId or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 120)
    if model == '' then return false, { ok = false, error = 'invalid_vehicle_model' } end
    if sourceKind == '' then sourceKind = 'external' end
    if sourceId == '' then return false, { ok = false, error = 'missing_source_id' } end

    return withRentalLock(('grant:%s:%s:%s'):format(citizenid, sourceKind, sourceId), function()
        local existing = sourceVehicleRental(citizenid, sourceKind, sourceId)
        if existing and tonumber(existing.owned_vehicle_id) then
            local rental = formatVehicleRental(existing)
            return {
                ok = true,
                reused = true,
                vehicleId = tonumber(existing.vehicle_id),
                model = normalize(existing.model),
                plate = existing.plate,
                garage = existing.garage,
                rental = rental,
            }
        elseif existing then
            MySQL.update.await('DELETE FROM ob_vip_vehicle_rentals WHERE vehicle_id = ?', { existing.vehicle_id })
        end

        local okVehicles, registeredVehicles = pcall(function() return exports.qbx_core:GetVehiclesByName() end)
        local vehicleData = okVehicles and registeredVehicles and registeredVehicles[model]
        if type(vehicleData) ~= 'table' then
            return { ok = false, error = 'vehicle_not_registered' }
        end

        local garage, garageError = configuredGarage(options.garage)
        if not garage then return { ok = false, error = 'garage_not_found', detail = garageError } end

        local durationDays = math.min(3650, rentalDays(options.durationDays))
        local renewalPrice = rentalRunes(options.renewalRunes)
        local timestamp = now()
        local expiresAt = timestamp + durationDays * DAY_SECONDS
        local vehicleId, vehicleError, vehicleProvider = createVipVehicle(citizenid, model, garage, vehicleData)
        if not vehicleId then
            return { ok = false, error = 'vehicle_create_failed', detail = vehicleError }
        end

        local inserted, affected = pcall(MySQL.update.await, [[
            INSERT INTO ob_vip_vehicle_rentals
                (vehicle_id, citizenid, membership_id, entitlement_id, vip, model, starts_at,
                 expires_at, duration_days, renewal_runes, source_kind, source_id)
            VALUES (?, ?, NULL, NULL, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            vehicleId,
            citizenid,
            normalize(options.vip or sourceKind),
            model,
            timestamp,
            expiresAt,
            durationDays,
            renewalPrice,
            sourceKind,
            sourceId,
        })

        if not inserted or tonumber(affected) ~= 1 then
            deleteVipVehicle(vehicleId, vehicleProvider)
            local raced = sourceVehicleRental(citizenid, sourceKind, sourceId)
            if raced and tonumber(raced.owned_vehicle_id) then
                return {
                    ok = true,
                    reused = true,
                    vehicleId = tonumber(raced.vehicle_id),
                    model = normalize(raced.model),
                    plate = raced.plate,
                    garage = raced.garage,
                    rental = formatVehicleRental(raced),
                }
            end
            return { ok = false, error = 'rental_create_failed' }
        end

        local plate = MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE id = ? LIMIT 1', { vehicleId })
        local rental = getVehicleRental(citizenid, vehicleId)
        TriggerEvent('ob_vip:server:rentalVehicleGranted', citizenid, vehicleId, model, sourceKind, sourceId)
        return {
            ok = true,
            vehicleId = tonumber(vehicleId),
            model = model,
            plate = plate,
            garage = garage,
            expiresAt = expiresAt,
            durationDays = durationDays,
            renewalRunes = renewalPrice,
            rental = rental,
        }
    end)
end

local function chargeRunes(player, amount, reason)
    amount = rentalRunes(amount)
    if amount == 0 then return true end
    local account = tostring(Config.Rentals and Config.Rentals.runesAccount or 'crypto')
    if (tonumber(player.Functions.GetMoney(account)) or 0) < amount then return false end
    return player.Functions.RemoveMoney(account, amount, reason) == true
end

local function refundRunes(player, amount, reason)
    amount = rentalRunes(amount)
    if amount == 0 then return end
    local account = tostring(Config.Rentals and Config.Rentals.runesAccount or 'crypto')
    player.Functions.AddMoney(account, amount, reason)
end

local function passRentalCooldown(source)
    source = tonumber(source)
    if not source then return true end
    local timestamp = GetGameTimer()
    local cooldown = math.max(250, math.floor(tonumber(Config.Rentals and Config.Rentals.renewalCooldownMs) or 1500))
    if rentalCooldowns[source] and timestamp - rentalCooldowns[source] < cooldown then return false end
    rentalCooldowns[source] = timestamp
    return true
end

local function recordRentalPayment(citizenid, kind, referenceId, vip, price, previousExpiry, expiresAt)
    local ok, errorMessage = pcall(MySQL.insert.await, [[
            INSERT INTO ob_vip_rental_payments
                (citizenid, rental_kind, reference_id, vip, runes, previous_expires_at, expires_at, paid_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ]], { citizenid, kind, tostring(referenceId), normalize(vip), rentalRunes(price), previousExpiry, expiresAt, now() })
    if not ok then debugLog(('Falha ao gravar historico da renovacao %s:%s: %s'):format(kind, referenceId, errorMessage)) end
end

local function renewVehicle(identifier, vehicleId)
    if not databaseReady then return false, { ok = false, error = 'database_initializing' } end
    local citizenid, player = citizenIdFrom(identifier)
    vehicleId = tonumber(vehicleId)
    if not citizenid or not player or not vehicleId then return false, { ok = false, error = 'player_not_loaded' } end
    if not passRentalCooldown(player.PlayerData.source) then return false, { ok = false, error = 'slow_down' } end

    return withRentalLock(('vehicle:%s'):format(vehicleId), function()
        local rental = getVehicleRental(citizenid, vehicleId)
        if not rental then return { ok = false, error = 'rental_not_found' } end
        if rental.active then return { ok = false, error = 'rental_active', rental = rental } end

        local price = rental.renewalRunes
        if not chargeRunes(player, price, ('vip_vehicle_renewal:%s'):format(vehicleId)) then
            return { ok = false, error = 'insufficient_runes', price = price }
        end

        local previousExpiry = rental.expiresAt
        local expiresAt = math.max(now(), previousExpiry or 0) + rental.durationDays * DAY_SECONDS
        local affected = MySQL.update.await([[
            UPDATE ob_vip_vehicle_rentals
            SET expires_at = ?, renewal_count = renewal_count + 1, last_renewed_at = ?
            WHERE vehicle_id = ? AND citizenid = ? AND expires_at = ?
        ]], { expiresAt, now(), vehicleId, citizenid, previousExpiry }) or 0
        if affected ~= 1 then
            refundRunes(player, price, ('vip_vehicle_renewal_refund:%s'):format(vehicleId))
            return { ok = false, error = 'renewal_failed' }
        end

        recordRentalPayment(citizenid, 'vehicle', vehicleId, rental.vip, price, previousExpiry, expiresAt)
        local updated = getVehicleRental(citizenid, vehicleId)
        TriggerEvent('ob_vip:server:vehicleRenewed', citizenid, vehicleId, updated)
        return { ok = true, rental = updated, price = price }
    end)
end

local function renewProperty(identifier, ownershipId)
    if not databaseReady then return false, { ok = false, error = 'database_initializing' } end
    local citizenid, player = citizenIdFrom(identifier)
    ownershipId = tonumber(ownershipId)
    if not citizenid or not player or not ownershipId then return false, { ok = false, error = 'player_not_loaded' } end
    if not passRentalCooldown(player.PlayerData.source) then return false, { ok = false, error = 'slow_down' } end
    if GetResourceState('ob_housing') ~= 'started' then return false, { ok = false, error = 'housing_unavailable' } end

    return withRentalLock(('property:%s'):format(ownershipId), function()
        local called, rental = pcall(function()
            return exports.ob_housing:GetVipRental(citizenid, ownershipId)
        end)
        if not called or type(rental) ~= 'table' or rental.managed ~= true then
            return { ok = false, error = 'rental_not_found' }
        end
        if rental.active then return { ok = false, error = 'rental_active', rental = rental } end

        local cfg = plan(rental.vip)
        local propertyCfg = cfg and cfg.property or {}
        local price = rentalRunes(rental.renewalRunes or propertyCfg.renewalRunes)
        local durationDays = rentalDays(rental.durationDays or propertyCfg.durationDays)
        if not chargeRunes(player, price, ('vip_property_renewal:%s'):format(ownershipId)) then
            return { ok = false, error = 'insufficient_runes', price = price }
        end

        local previousExpiry = tonumber(rental.expiresAt)
        local extended, result = pcall(function()
            return exports.ob_housing:ExtendVipProperty(citizenid, ownershipId, durationDays)
        end)
        if not extended or type(result) ~= 'table' or result.ok ~= true then
            refundRunes(player, price, ('vip_property_renewal_refund:%s'):format(ownershipId))
            return { ok = false, error = extended and result and result.error or 'renewal_failed' }
        end

        recordRentalPayment(citizenid, 'property', ownershipId, rental.vip, price, previousExpiry, result.expiresAt)
        result.renewalRunes = price
        result.durationDays = durationDays
        TriggerEvent('ob_vip:server:propertyRenewed', citizenid, ownershipId, result)
        return { ok = true, rental = result, price = price }
    end)
end

local function redeemVehicle(identifier, entitlementId, selectedModel)
    local citizenid, player = citizenIdFrom(identifier)
    if not citizenid or not player then return false, 'Entre com o personagem para resgatar o veiculo.' end

    entitlementId = tonumber(entitlementId)
    selectedModel = normalize(selectedModel)
    if not entitlementId or selectedModel == '' then return false, 'Escolha de veiculo invalida.' end

    local timestamp = now()
    local entitlement = MySQL.single.await([[
        SELECT entitlement.id, entitlement.membership_id, entitlement.vip, entitlement.slot_index
        FROM ob_vip_entitlements entitlement
        INNER JOIN ob_vip_memberships membership ON membership.id = entitlement.membership_id
        WHERE entitlement.id = ? AND entitlement.citizenid = ?
          AND entitlement.benefit_kind = 'vehicle' AND entitlement.status = 'pending'
          AND membership.active = 1 AND membership.starts_at <= ?
          AND (membership.expires_at IS NULL OR membership.expires_at > ?)
        LIMIT 1
    ]], { entitlementId, citizenid, timestamp, timestamp })
    if not entitlement then return false, 'Este resgate nao esta mais disponivel.' end

    local selected
    for _, vehicle in ipairs(vehicleCatalog(entitlement.vip)) do
        if vehicle.model == selectedModel then selected = vehicle break end
    end
    if not selected then return false, 'Este veiculo nao pertence ao catalogo do seu VIP.' end

    local okVehicles, registeredVehicles = pcall(function() return exports.qbx_core:GetVehiclesByName() end)
    local vehicleData = okVehicles and registeredVehicles and registeredVehicles[selectedModel]
    if type(vehicleData) ~= 'table' then
        return false, 'Modelo nao registrado no catalogo de veiculos do Qbox.'
    end
    local garage, garageError = configuredGarage()
    if not garage then return false, garageError end

    local token = ('vehicle:%s:%s:%s'):format(player.PlayerData.source, entitlementId, GetGameTimer())
    local reserved = MySQL.update.await([[
        UPDATE ob_vip_entitlements
        SET status = 'processing', claim_token = ?, selection = ?, error = NULL
        WHERE id = ? AND citizenid = ? AND status = 'pending'
    ]], { token, selectedModel, entitlementId, citizenid }) or 0
    if reserved ~= 1 then return false, 'Este resgate ja esta sendo processado.' end

    local vehicleId, vehicleError, vehicleProvider = createVipVehicle(citizenid, selectedModel, garage, vehicleData)
    if not vehicleId then
        MySQL.update.await([[
            UPDATE ob_vip_entitlements SET status = 'pending', claim_token = NULL, selection = NULL, error = ?
            WHERE id = ? AND status = 'processing' AND claim_token = ?
        ]], { tostring(type(vehicleError) == 'table' and vehicleError.message or vehicleError or 'falha ao criar veiculo'):sub(1, 160), entitlementId, token })
        return false, 'Nao foi possivel registrar o veiculo na garagem.'
    end

    local vehicleCfg = plan(entitlement.vip).vehicles or {}
    local durationDays = rentalDays(vehicleCfg.durationDays)
    local renewalPrice = rentalRunes(vehicleCfg.renewalRunes)
    local rentalExpiresAt = timestamp + durationDays * DAY_SECONDS
    local rentalId = MySQL.insert.await([[
        INSERT INTO ob_vip_vehicle_rentals
            (vehicle_id, citizenid, membership_id, entitlement_id, vip, model, starts_at,
             expires_at, duration_days, renewal_runes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        vehicleId,
        citizenid,
        entitlement.membership_id,
        entitlement.id,
        normalize(entitlement.vip),
        selectedModel,
        timestamp,
        rentalExpiresAt,
        durationDays,
        renewalPrice,
    })
    if not rentalId then
        deleteVipVehicle(vehicleId, vehicleProvider)
        MySQL.update.await([[
            UPDATE ob_vip_entitlements SET status = 'pending', claim_token = NULL, selection = NULL,
                error = 'falha ao registrar validade do veiculo'
            WHERE id = ? AND status = 'processing' AND claim_token = ?
        ]], { entitlementId, token })
        return false, 'Nao foi possivel registrar a validade do veiculo; o resgate foi preservado.'
    end

    local finished = MySQL.update.await([[
        UPDATE ob_vip_entitlements
        SET status = 'claimed', claimed_at = ?, claim_token = NULL, error = NULL
        WHERE id = ? AND status = 'processing' AND claim_token = ?
    ]], { timestamp, entitlementId, token }) or 0
    if finished ~= 1 then
        MySQL.update.await('DELETE FROM ob_vip_vehicle_rentals WHERE vehicle_id = ?', { vehicleId })
        deleteVipVehicle(vehicleId, vehicleProvider)
        MySQL.update.await([[
            UPDATE ob_vip_entitlements SET status = 'pending', claim_token = NULL, selection = NULL,
                error = 'confirmacao do resgate falhou'
            WHERE id = ? AND claim_token = ?
        ]], { entitlementId, token })
        return false, 'O resgate nao foi confirmado; nenhum veiculo foi consumido.'
    end

    local owned
    if GetResourceState('qbx_vehicles') == 'started' then
        local ok, result = pcall(function()
            return exports.qbx_vehicles:GetPlayerVehicle(vehicleId, { citizenid = citizenid })
        end)
        if ok then owned = result end
    end
    local plate = owned and owned.props and owned.props.plate
        or MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE id = ? LIMIT 1', { vehicleId })
    TriggerEvent('ob_vip:server:vehicleRedeemed', citizenid, entitlementId, vehicleId, selectedModel)
    return true, {
        vehicleId = tonumber(vehicleId),
        model = selectedModel,
        label = selected.label,
        plate = plate,
        garage = garage,
        expiresAt = rentalExpiresAt,
        durationDays = durationDays,
        renewalRunes = renewalPrice,
    }
end


lib.callback.register('ob_vip:server:renewVehicle', function(source, vehicleId)
    local success, result = renewVehicle(source, vehicleId)
    return result or { ok = success == true }
end)

lib.callback.register('ob_vip:server:renewProperty', function(source, ownershipId)
    local success, result = renewProperty(source, ownershipId)
    return result or { ok = success == true }
end)

lib.callback.register('ob_vip:server:changeName', function(source, data)
    local player = playerFromSource(source)
    if not player then return { ok = false, message = 'Personagem indisponivel.' } end
    if nameChangeCooldown[source] and GetGameTimer() - nameChangeCooldown[source] < 5000 then
        return { ok = false, message = 'Aguarde antes de tentar novamente.' }
    end
    nameChangeCooldown[source] = GetGameTimer()

    local function cleanName(value)
        value = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
        if #value < 2 or #value > 24 or value:find('[%d<>]') or value:find('[%c]') then return nil end
        return value
    end

    local firstName = cleanName(data and data.firstName)
    local lastName = cleanName(data and data.lastName)
    if not firstName or not lastName then
        return { ok = false, message = 'Use nome e sobrenome validos, entre 2 e 24 caracteres.' }
    end
    if exports.ox_inventory:GetItemCount(source, 'troca_nome') < 1 then
        return { ok = false, message = 'Voce nao possui uma Troca de Nome.' }
    end
    if exports.ox_inventory:RemoveItem(source, 'troca_nome', 1) ~= true then
        return { ok = false, message = 'Nao foi possivel consumir a Troca de Nome.' }
    end

    local charinfo = clone(player.PlayerData.charinfo or {})
    charinfo.firstname = firstName
    charinfo.lastname = lastName
    local changed, changeError = pcall(function()
        player.Functions.SetPlayerData('charinfo', charinfo)
        player.Functions.Save()
    end)
    if not changed then
        exports.ox_inventory:AddItem(source, 'troca_nome', 1)
        debugLog(('Falha ao trocar nome de %s: %s'):format(player.PlayerData.citizenid, changeError))
        return { ok = false, message = 'A troca falhou e o item foi devolvido.' }
    end

    TriggerEvent('ob_vip:server:nameChanged', tostring(player.PlayerData.citizenid), firstName, lastName)
    return { ok = true, message = ('Nome alterado para %s %s.'):format(firstName, lastName) }
end)

local function processSalary(row, timestamp)
    local vip = normalize(row.vip)
    local amount, interval, account = salaryConfig(vip)
    if amount <= 0 or not plan(vip) then
        MySQL.update.await('UPDATE ob_vip_memberships SET next_salary_at = NULL WHERE id = ?', { row.id })
        return
    end

    local citizenid = tostring(row.citizenid)
    local dueAt = tonumber(row.next_salary_at) or timestamp
    local nextSalaryAt = timestamp + interval
    local identifier = citizenid
    local player = onlinePlayerByCitizenId(citizenid)

    if Config.Salary.onlineOnly then
        local session = salarySessions[citizenid]
        if not player or not session
            or tonumber(session.source) ~= tonumber(player.PlayerData.source)
        then
            return
        end
        identifier = player.PlayerData.source
    end

    local claimed = MySQL.update.await([[
        UPDATE ob_vip_memberships
        SET next_salary_at = ?
        WHERE id = ? AND active = 1 AND next_salary_at = ?
          AND starts_at <= ? AND (expires_at IS NULL OR expires_at > ?)
    ]], { nextSalaryAt, row.id, dueAt, timestamp, timestamp }) or 0

    if claimed ~= 1 then return end

    local paid = exports.qbx_core:AddMoney(identifier, account, amount, ('vip_salary:%s:%s'):format(vip, row.id)) == true
    MySQL.insert.await([[
        INSERT INTO ob_vip_salary_history
            (membership_id, citizenid, vip, amount, account, scheduled_at, paid_at, status, error)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        row.id, citizenid, vip, amount, account, dueAt,
        paid and timestamp or nil,
        paid and 'paid' or 'failed',
        paid and nil or 'qbx_core recusou o pagamento',
    })

    if not paid then
        MySQL.update.await(
            'UPDATE ob_vip_memberships SET next_salary_at = ? WHERE id = ? AND next_salary_at = ?',
            { dueAt, row.id, nextSalaryAt }
        )
        return
    end

    if player and Config.Salary.notify then
        notify(player.PlayerData.source, ('Salario VIP %s: $%s depositados.'):format(plan(vip).label or vip, amount), 'success')
    end

    debugLog(('Salario %s de %s pago para %s.'):format(amount, vip, citizenid))
    return citizenid
end

local function dueSalaryRows(timestamp)
    if Config.Salary.onlineOnly then
        local citizenids = {}
        for _, player in pairs(exports.qbx_core:GetQBPlayers()) do
            citizenids[#citizenids + 1] = tostring(player.PlayerData.citizenid)
        end
        if #citizenids == 0 then return {} end

        local placeholders = {}
        local params = { timestamp, timestamp, timestamp }
        for i = 1, #citizenids do
            placeholders[i] = '?'
            params[#params + 1] = citizenids[i]
        end

        local limit = math.max(1, math.floor(tonumber(Config.Salary.maxPaymentsPerCycle) or 250))
        return MySQL.query.await(([=[
            SELECT id, citizenid, vip, next_salary_at
            FROM ob_vip_memberships
            WHERE active = 1 AND starts_at <= ?
              AND (expires_at IS NULL OR expires_at > ?)
              AND next_salary_at IS NOT NULL AND next_salary_at <= ?
              AND citizenid IN (%s)
            ORDER BY next_salary_at ASC
            LIMIT %d
        ]=]):format(table.concat(placeholders, ','), limit), params) or {}
    end

    local limit = math.max(1, math.floor(tonumber(Config.Salary.maxPaymentsPerCycle) or 250))
    return MySQL.query.await(([=[
        SELECT id, citizenid, vip, next_salary_at
        FROM ob_vip_memberships
        WHERE active = 1 AND starts_at <= ?
          AND (expires_at IS NULL OR expires_at > ?)
          AND next_salary_at IS NOT NULL AND next_salary_at <= ?
        ORDER BY next_salary_at ASC
        LIMIT %d
    ]=]):format(limit), { timestamp, timestamp, timestamp }) or {}
end

local function processExpirations(timestamp)
    local rows = MySQL.query.await([[
        SELECT DISTINCT citizenid
        FROM ob_vip_memberships
        WHERE active = 1 AND expires_at IS NOT NULL AND expires_at <= ?
    ]], { timestamp }) or {}

    if #rows == 0 then return end
    MySQL.update.await(
        'UPDATE ob_vip_memberships SET active = 0 WHERE active = 1 AND expires_at IS NOT NULL AND expires_at <= ?',
        { timestamp }
    )

    for _, row in ipairs(rows) do syncCitizen(tostring(row.citizenid)) end
end

local function runScheduler()
    while true do
        Wait(math.max(5, tonumber(Config.Salary.checkIntervalSeconds) or 30) * 1000)
        if databaseReady then
            local timestamp = now()
            processExpirations(timestamp)
            retryImmediateEntitlements(timestamp)
            retryPropertyEntitlements(timestamp)
            local refreshed = {}
            for _, row in ipairs(dueSalaryRows(timestamp)) do
                local citizenid = processSalary(row, timestamp)
                if citizenid then refreshed[citizenid] = true end
            end
            for citizenid in pairs(refreshed) do syncCitizen(citizenid) end
        end
    end
end

local function ensureVehicleRentalSchema()
    local columns = MySQL.query.await('SHOW COLUMNS FROM ob_vip_vehicle_rentals') or {}
    local byName = {}
    for _, column in ipairs(columns) do byName[tostring(column.Field)] = column end

    if byName.membership_id and tostring(byName.membership_id.Null):upper() ~= 'YES' then
        MySQL.query.await('ALTER TABLE ob_vip_vehicle_rentals MODIFY COLUMN membership_id BIGINT UNSIGNED NULL')
    end
    if byName.entitlement_id and tostring(byName.entitlement_id.Null):upper() ~= 'YES' then
        MySQL.query.await('ALTER TABLE ob_vip_vehicle_rentals MODIFY COLUMN entitlement_id BIGINT UNSIGNED NULL')
    end
    if not byName.source_kind then
        MySQL.query.await("ALTER TABLE ob_vip_vehicle_rentals ADD COLUMN source_kind VARCHAR(24) NOT NULL DEFAULT 'vip' AFTER last_renewed_at")
    end
    if not byName.source_id then
        MySQL.query.await('ALTER TABLE ob_vip_vehicle_rentals ADD COLUMN source_id VARCHAR(120) NULL AFTER source_kind')
    end

    local indexes = MySQL.query.await('SHOW INDEX FROM ob_vip_vehicle_rentals') or {}
    local hasSourceIndex = false
    for _, index in ipairs(indexes) do
        if tostring(index.Key_name) == 'uq_ob_vip_vehicle_source' then
            hasSourceIndex = true
            break
        end
    end
    if not hasSourceIndex then
        MySQL.query.await([[
            ALTER TABLE ob_vip_vehicle_rentals
            ADD UNIQUE KEY uq_ob_vip_vehicle_source (citizenid, source_kind, source_id)
        ]])
    end
end

local function createTables()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ob_vip_memberships (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            citizenid VARCHAR(64) NOT NULL,
            vip VARCHAR(50) NOT NULL,
            starts_at BIGINT UNSIGNED NOT NULL,
            expires_at BIGINT UNSIGNED DEFAULT NULL,
            next_salary_at BIGINT UNSIGNED DEFAULT NULL,
            active TINYINT(1) NOT NULL DEFAULT 1,
            granted_by VARCHAR(64) DEFAULT NULL,
            grant_reason VARCHAR(120) DEFAULT NULL,
            metadata LONGTEXT DEFAULT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_ob_vip_citizen_active (citizenid, active, expires_at),
            KEY idx_ob_vip_salary_due (active, next_salary_at, expires_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ob_vip_salary_history (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            membership_id BIGINT UNSIGNED NOT NULL,
            citizenid VARCHAR(64) NOT NULL,
            vip VARCHAR(50) NOT NULL,
            amount BIGINT UNSIGNED NOT NULL,
            account VARCHAR(20) NOT NULL,
            scheduled_at BIGINT UNSIGNED NOT NULL,
            paid_at BIGINT UNSIGNED DEFAULT NULL,
            status VARCHAR(20) NOT NULL,
            error VARCHAR(160) DEFAULT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_ob_vip_salary_citizen (citizenid, created_at),
            KEY idx_ob_vip_salary_membership (membership_id, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ob_vip_entitlements (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            membership_id BIGINT UNSIGNED NOT NULL,
            citizenid VARCHAR(64) NOT NULL,
            vip VARCHAR(50) NOT NULL,
            benefit_kind VARCHAR(24) NOT NULL,
            slot_index INT UNSIGNED NOT NULL DEFAULT 1,
            item_name VARCHAR(80) DEFAULT NULL,
            amount BIGINT UNSIGNED NOT NULL DEFAULT 1,
            status VARCHAR(20) NOT NULL DEFAULT 'pending',
            claim_token VARCHAR(100) DEFAULT NULL,
            selection VARCHAR(80) DEFAULT NULL,
            metadata LONGTEXT DEFAULT NULL,
            error VARCHAR(160) DEFAULT NULL,
            claimed_at BIGINT UNSIGNED DEFAULT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY uq_ob_vip_entitlement (membership_id, benefit_kind, slot_index),
            KEY idx_ob_vip_entitlement_pending (citizenid, status, benefit_kind),
            KEY idx_ob_vip_entitlement_membership (membership_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ob_vip_backpacks (
            citizenid VARCHAR(64) NOT NULL,
            item_name VARCHAR(80) NOT NULL,
            equipped TINYINT(1) NOT NULL DEFAULT 1,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (citizenid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ob_vip_vehicle_rentals (
            vehicle_id INT UNSIGNED NOT NULL,
            citizenid VARCHAR(64) NOT NULL,
            membership_id BIGINT UNSIGNED NULL,
            entitlement_id BIGINT UNSIGNED NULL,
            vip VARCHAR(50) NOT NULL,
            model VARCHAR(80) NOT NULL,
            starts_at BIGINT UNSIGNED NOT NULL,
            expires_at BIGINT UNSIGNED NOT NULL,
            duration_days SMALLINT UNSIGNED NOT NULL DEFAULT 30,
            renewal_runes BIGINT UNSIGNED NOT NULL DEFAULT 0,
            renewal_count INT UNSIGNED NOT NULL DEFAULT 0,
            last_renewed_at BIGINT UNSIGNED DEFAULT NULL,
            source_kind VARCHAR(24) NOT NULL DEFAULT 'vip',
            source_id VARCHAR(120) DEFAULT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (vehicle_id),
            UNIQUE KEY uq_ob_vip_vehicle_entitlement (entitlement_id),
            UNIQUE KEY uq_ob_vip_vehicle_source (citizenid, source_kind, source_id),
            KEY idx_ob_vip_vehicle_citizen (citizenid, expires_at),
            KEY idx_ob_vip_vehicle_membership (membership_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    ensureVehicleRentalSchema()

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ob_vip_rental_payments (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            citizenid VARCHAR(64) NOT NULL,
            rental_kind VARCHAR(20) NOT NULL,
            reference_id VARCHAR(64) NOT NULL,
            vip VARCHAR(50) NOT NULL,
            runes BIGINT UNSIGNED NOT NULL,
            previous_expires_at BIGINT UNSIGNED DEFAULT NULL,
            expires_at BIGINT UNSIGNED NOT NULL,
            paid_at BIGINT UNSIGNED NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_ob_vip_rental_citizen (citizenid, created_at),
            KEY idx_ob_vip_rental_reference (rental_kind, reference_id, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    MySQL.update.await([[
        UPDATE ob_vip_entitlements
        SET status = 'pending', claim_token = NULL, error = 'reserva recuperada apos reinicio'
        WHERE status = 'processing'
    ]])

    MySQL.update.await([[
        UPDATE ob_vip_entitlements
        SET status = 'cancelled', claim_token = NULL, error = 'mochila removida dos beneficios VIP'
        WHERE benefit_kind = 'item'
          AND item_name IN ('mochila_pequena', 'mochila_media', 'mochila_grande')
          AND status IN ('pending', 'processing')
    ]])
end

local function migrateClaimedVehicleRentals()
    local rows = MySQL.query.await([[
        SELECT entitlement.id, entitlement.membership_id, entitlement.citizenid,
               entitlement.vip, entitlement.selection, entitlement.claimed_at,
               membership.starts_at
        FROM ob_vip_entitlements entitlement
        INNER JOIN ob_vip_memberships membership ON membership.id = entitlement.membership_id
        LEFT JOIN ob_vip_vehicle_rentals rental ON rental.entitlement_id = entitlement.id
        WHERE entitlement.benefit_kind = 'vehicle'
          AND entitlement.status = 'claimed'
          AND entitlement.selection IS NOT NULL
          AND entitlement.selection <> ''
          AND rental.entitlement_id IS NULL
        ORDER BY entitlement.claimed_at DESC, entitlement.id DESC
    ]]) or {}

    local migrated = 0
    local migrationTimestamp = now()
    for _, entitlement in ipairs(rows) do
        local vehicleId = MySQL.scalar.await([[
            SELECT vehicle.id
            FROM player_vehicles vehicle
            LEFT JOIN ob_vip_vehicle_rentals rental ON rental.vehicle_id = vehicle.id
            WHERE vehicle.citizenid = ? AND LOWER(vehicle.vehicle) = ? AND rental.vehicle_id IS NULL
            ORDER BY vehicle.id DESC
            LIMIT 1
        ]], { tostring(entitlement.citizenid), normalize(entitlement.selection) })
        local cfg = plan(entitlement.vip)
        if vehicleId and cfg and cfg.vehicles then
            local durationDays = rentalDays(cfg.vehicles.durationDays)
            -- Existing claims only become rentals when this migration runs, so their
            -- first 30-day period must start now instead of being backdated.
            local startsAt = migrationTimestamp
            local inserted = MySQL.insert.await([[
                INSERT IGNORE INTO ob_vip_vehicle_rentals
                    (vehicle_id, citizenid, membership_id, entitlement_id, vip, model, starts_at,
                     expires_at, duration_days, renewal_runes)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]], {
                vehicleId,
                tostring(entitlement.citizenid),
                entitlement.membership_id,
                entitlement.id,
                normalize(entitlement.vip),
                normalize(entitlement.selection),
                startsAt,
                startsAt + durationDays * DAY_SECONDS,
                durationDays,
                rentalRunes(cfg.vehicles.renewalRunes),
            })
            if inserted then migrated = migrated + 1 end
        end
    end

    if migrated > 0 then
        print(('^3[%s]^7 %d veiculo(s) VIP antigo(s) receberam validade mensal.'):format(RESOURCE, migrated))
    end
end

local function repairBackdatedVehicleRentals()
    local timestamp = now()
    local repaired = MySQL.update.await([[
        UPDATE ob_vip_vehicle_rentals
        SET starts_at = ?, expires_at = ? + (duration_days * ?)
        WHERE renewal_count = 0
          AND last_renewed_at IS NULL
          AND starts_at < UNIX_TIMESTAMP(created_at) - 300
    ]], { timestamp, timestamp, DAY_SECONDS }) or 0

    if repaired > 0 then
        print(('^3[%s]^7 %d mensalidade(s) VIP migrada(s) foram corrigidas.'):format(RESOURCE, repaired))
    end
end

local function migrateVipPropertyRentals()
    local queried, rows = pcall(MySQL.query.await, [[
        SELECT ownership.id, ownership.metadata, property.vip_tier
        FROM ob_property_ownerships ownership
        INNER JOIN ob_properties property ON property.id = ownership.property_id
        WHERE ownership.acquisition = 'vip' AND ownership.expires_at IS NOT NULL
    ]])
    if not queried or type(rows) ~= 'table' then return end

    for _, row in ipairs(rows) do
        local metadata = decode(row.metadata, {})
        local vip = normalize(metadata.vip)
        if vip == '' then vip = normalize(tostring(row.vip_tier or ''):match('^[^,]+')) end
        local cfg = plan(vip)
        if cfg and cfg.property then
            local changed = false
            if not tonumber(metadata.durationDays) then
                metadata.durationDays = rentalDays(cfg.property.durationDays)
                changed = true
            end
            if not tonumber(metadata.renewalRunes) then
                metadata.renewalRunes = rentalRunes(cfg.property.renewalRunes)
                changed = true
            end
            if normalize(metadata.vip) == '' then
                metadata.vip = vip
                changed = true
            end
            if changed then
                MySQL.update.await('UPDATE ob_property_ownerships SET metadata = ? WHERE id = ?', {
                    json.encode(metadata), row.id
                })
            end
        end
    end
end

local function commandIdentifier(value)
    local citizenid = citizenIdFrom(value)
    if not citizenid then return nil, 'Jogador ou CitizenID invalido.' end
    return citizenid
end

if Config.Commands and Config.Commands.enabled then
    lib.addCommand('setvip', {
        help = 'Adiciona uma concessao de VIP a um personagem.',
        params = {
            { name = 'jogador', help = 'ID online ou CitizenID', type = 'string' },
            { name = 'vip', help = 'Nome do VIP na Config.Vips', type = 'string' },
            { name = 'dias', help = 'Duracao em dias; 0 deixa permanente', type = 'number' },
        },
        restricted = Config.Commands.permission,
    }, function(source, args)
        local citizenid, errorMessage = commandIdentifier(args.jogador)
        if not citizenid then return notify(source, errorMessage, 'error') end

        local grantedBy = source > 0 and (citizenIdFrom(source) or ('source:%s'):format(source)) or 'console'
        local success, result = addVip(citizenid, args.vip, args.dias, {
            grantedBy = grantedBy,
            reason = 'comando setvip',
        })

        if not success then return notify(source, result, 'error') end
        local expiration = result.expiresAt and os.date('%d/%m/%Y %H:%M', result.expiresAt) or 'permanente'
        notify(source, ('VIP %s adicionado a %s ate %s. Concessao #%s.'):format(result.vip, citizenid, expiration, result.id), 'success')
    end)

    lib.addCommand('removevip', {
        help = 'Remove concessoes ativas de VIP de um personagem.',
        params = {
            { name = 'jogador', help = 'ID online ou CitizenID', type = 'string' },
            { name = 'vip', help = 'Nome do VIP ou id da concessao', type = 'string' },
        },
        restricted = Config.Commands.permission,
    }, function(source, args)
        local citizenid, errorMessage = commandIdentifier(args.jogador)
        if not citizenid then return notify(source, errorMessage, 'error') end
        local success, result = removeVip(citizenid, args.vip)
        notify(source, success and ('VIP removido de %s.'):format(citizenid) or result, success and 'success' or 'error')
    end)

    lib.addCommand('listvips', {
        help = 'Lista os VIPs ativos de um personagem.',
        params = {
            { name = 'jogador', help = 'ID online ou CitizenID', type = 'string' },
        },
        restricted = Config.Commands.permission,
    }, function(source, args)
        local citizenid, errorMessage = commandIdentifier(args.jogador)
        if not citizenid then return notify(source, errorMessage, 'error') end
        local payload = getPayload(citizenid, true)
        if not payload or #payload.memberships == 0 then
            return notify(source, ('%s nao possui VIP ativo.'):format(citizenid), 'inform')
        end

        local descriptions = {}
        for _, membership in ipairs(payload.memberships) do
            descriptions[#descriptions + 1] = ('#%s %s (%s)'):format(
                membership.id,
                membership.label,
                membership.expiresAt and os.date('%d/%m/%Y %H:%M', membership.expiresAt) or 'permanente'
            )
        end
        notify(source, table.concat(descriptions, ' | '), 'inform')
    end)
end

RegisterNetEvent('ob_vip:server:requestRefresh', function()
    local source = source
    local timestamp = GetGameTimer()
    if refreshCooldown[source] and timestamp - refreshCooldown[source] < 3000 then return end
    refreshCooldown[source] = timestamp

    local player = playerFromSource(source)
    if player then syncCitizen(tostring(player.PlayerData.citizenid)) end
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if not player or not player.PlayerData then return end
    local source = player.PlayerData.source
    local citizenid = tostring(player.PlayerData.citizenid)
    SetTimeout(750, function()
        if GetPlayerPing(source) <= 0 then return end

        if Config.Salary.onlineOnly and databaseReady then
            local ok, err = pcall(startOnlineSalarySession, citizenid, source)
            if not ok then
                print(('^1[%s] Falha ao iniciar salario online de %s: %s^7'):format(RESOURCE, citizenid, tostring(err)))
            end
        end

        syncCitizen(citizenid)
    end)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(source)
    stopOnlineSalarySession(source)
    local state = inventoryState[source]
    if state and GetResourceState('ox_inventory') == 'started' and GetPlayerPing(source) > 0 then
        local inventory = exports.ox_inventory:GetInventory(source)
        if inventory then exports.ox_inventory:SetMaxWeight(source, state.baseWeight) end
    end
    if GetPlayerPing(source) > 0 then
        Player(source).state:set('obVipInventoryBonus', 0, true)
        Player(source).state:set('obVip', nil, true)
    end
    refreshCooldown[source] = nil
    nameChangeCooldown[source] = nil
    rentalCooldowns[source] = nil
    inventoryState[source] = nil
end)

AddEventHandler('playerDropped', function()
    stopOnlineSalarySession(source)
    refreshCooldown[source] = nil
    nameChangeCooldown[source] = nil
    rentalCooldowns[source] = nil
    inventoryState[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE or GetResourceState('ox_inventory') ~= 'started' then return end
    for source, state in pairs(inventoryState) do
        if GetPlayerPing(source) > 0 then
            exports.ox_inventory:SetMaxWeight(source, state.baseWeight)
            Player(source).state:set('obVipInventoryBonus', 0, true)
            Player(source).state:set('obVip', nil, true)
        end
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= 'ob_housing' or not databaseReady then return end
    SetTimeout(750, function() retryPropertyEntitlements(now()) end)
end)

exports('AddVip', addVip)
exports('SetVip', addVip)
exports('RemoveVip', removeVip)
exports('ClearVips', clearVips)
exports('RefreshPlayer', syncCitizen)
exports('GetStoreState', storeState)
exports('RedeemVehicle', redeemVehicle)
exports('GrantRentalVehicle', grantRentalVehicle)
exports('GetVehicleRentalStates', vehicleRentalStates)
exports('GetVehicleRental', getVehicleRental)
exports('CanUseVehicle', canUseVehicle)
exports('RenewVehicle', renewVehicle)
exports('RenewProperty', renewProperty)
exports('HandleRespawn', handleRespawn)
exports('GetBackpackKeepItems', backpackKeepItems)

exports('IsVip', function(identifier)
    local payload = getPayload(identifier)
    return payload and payload.active == true or false
end)

exports('HasVip', function(identifier, vip)
    local payload = getPayload(identifier)
    if not payload then return false end
    if not vip then return payload.active == true end
    vip = normalize(vip)
    for _, membership in ipairs(payload.memberships) do
        if membership.vip == vip then return true end
    end
    return false
end)

exports('GetVips', function(identifier, forceRefresh)
    local payload = getPayload(identifier, forceRefresh == true)
    return payload and clone(payload.memberships) or {}
end)

exports('GetHighestVip', function(identifier)
    local payload = getPayload(identifier)
    return payload and clone(payload.highest) or nil
end)

exports('GetBenefits', function(identifier, forceRefresh)
    local payload = getPayload(identifier, forceRefresh == true)
    return payload and clone(payload.benefits) or nil
end)

exports('GetSalaryTotal', function(identifier)
    local payload = getPayload(identifier)
    return payload and tonumber(payload.benefits.salaryTotal) or 0
end)

exports('GetSalaryEntries', function(identifier)
    local payload = getPayload(identifier)
    return payload and clone(payload.benefits.salaryEntries) or {}
end)

exports('GetVehicleDiscount', function(identifier)
    local payload = getPayload(identifier)
    return payload and tonumber(payload.benefits.vehicleDiscount) or 0
end)

exports('CalculateVehicleDiscount', function(identifier, amount)
    return calculateDiscount(identifier, amount, 'vehicleDiscount')
end)

exports('GetFuelDiscount', function(identifier)
    local payload = getPayload(identifier)
    return payload and tonumber(payload.benefits.fuelDiscount) or 0
end)

exports('CalculateFuelDiscount', function(identifier, amount)
    return calculateDiscount(identifier, amount, 'fuelDiscount')
end)

exports('GetMedicalDiscount', function(identifier)
    local payload = getPayload(identifier)
    return payload and tonumber(payload.benefits.medicalDiscount) or 0
end)

exports('CalculateMedicalDiscount', function(identifier, amount)
    return calculateDiscount(identifier, amount, 'medicalDiscount')
end)

exports('GetInventoryBonus', function(identifier)
    local payload = getPayload(identifier)
    return payload and tonumber(payload.benefits.inventoryWeight) or 0
end)

exports('GetVipInventoryBonus', function(identifier)
    local payload = getPayload(identifier)
    return payload and tonumber(payload.benefits.vipInventoryWeight) or 0
end)

exports('GetBackpackBonus', function(identifier)
    local payload = getPayload(identifier)
    return payload and tonumber(payload.benefits.backpackWeight) or 0
end)

exports('GetDiscordRoleIds', function(identifier)
    local payload = getPayload(identifier)
    return payload and clone(payload.benefits.discordRoleIds) or {}
end)

MySQL.ready(function()
    local tablesReady, tablesError = pcall(createTables)
    if not tablesReady then
        print(('^1[%s] Falha ao preparar o banco; sistema VIP indisponivel: %s^7'):format(RESOURCE, tostring(tablesError)))
        return
    end

    local startupSteps = {
        { name = 'correcao das mensalidades migradas', callback = repairBackdatedVehicleRentals },
        { name = 'migracao dos veiculos antigos', callback = migrateClaimedVehicleRentals },
        { name = 'migracao das propriedades VIP', callback = migrateVipPropertyRentals },
        { name = 'preparo das propriedades ativas', callback = function() backfillActivePropertyEntitlements(now()) end },
    }

    for _, step in ipairs(startupSteps) do
        local ok, err = pcall(step.callback)
        if not ok then
            print(('^1[%s] Falha opcional em %s: %s^7'):format(RESOURCE, step.name, tostring(err)))
        end
    end

    databaseReady = true

    CreateThread(runScheduler)
    SetTimeout(1000, function()
        for _, player in pairs(exports.qbx_core:GetQBPlayers()) do
            local citizenid = tostring(player.PlayerData.citizenid)
            local salaryOk, salaryError = pcall(startOnlineSalarySession, citizenid, player.PlayerData.source)
            if not salaryOk then
                print(('^1[%s] Falha ao iniciar salario online de %s: %s^7'):format(
                    RESOURCE,
                    citizenid,
                    tostring(salaryError)
                ))
            end

            local ok, err = pcall(syncCitizen, citizenid)
            if not ok then
                print(('^1[%s] Falha ao sincronizar %s: %s^7'):format(
                    RESOURCE,
                    citizenid,
                    tostring(err)
                ))
            end
        end
        local ok, err = pcall(retryPropertyEntitlements, now())
        if not ok then print(('^1[%s] Falha ao entregar propriedades pendentes: %s^7'):format(RESOURCE, tostring(err))) end
    end)

    print(('^2[%s]^7 Banco pronto e sistema iniciado.'):format(RESOURCE))
end)
