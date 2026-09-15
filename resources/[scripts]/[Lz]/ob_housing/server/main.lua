local RESOURCE = GetCurrentResourceName()
local databaseReady = false
local starterPropertyId
local sessions = {}
local propertyLocks = {}
local purchaseLocks = {}
local actionCooldowns = {}
local bellCooldowns = {}
local bellRequests = {}
local pendingBellByOwner = {}
local visitorInvites = {}
local bellSequence = 0
local previewSequence = 0
local registeredStashes = {}
local inventoryHookRegistered = false

local ACTIVE_OWNER_SQL = '(ownership.expires_at IS NULL OR ownership.expires_at > UNIX_TIMESTAMP())'

local function debugLog(message)
    if Config.Debug then
        print(('^5[%s]^7 %s'):format(RESOURCE, tostring(message)))
    end
end

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function asBoolean(value)
    return value == true or value == 1 or value == '1' or value == 'true'
end

local function boundedInteger(value, minimum, maximum, fallback)
    value = math.floor(tonumber(value) or fallback or minimum)
    return math.max(minimum, math.min(maximum, value))
end

local function decode(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, result = pcall(json.decode, value)
    return ok and type(result) == 'table' and result or fallback
end

local function coordinates(value, heading)
    if type(value) ~= 'table' and type(value) ~= 'vector3' and type(value) ~= 'vector4' then return nil end
    local x, y, z = tonumber(value.x or value[1]), tonumber(value.y or value[2]), tonumber(value.z or value[3])
    if not x or not y or not z then return nil end
    local result = { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
    if heading then result.h = (tonumber(value.h or value.w or value[4]) or 0.0) + 0.0 end
    return result
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

local function safeGallery(value)
    local gallery = decode(value, {})
    local clean = {}
    local maximum = boundedInteger(Config.Images and Config.Images.maxPerProperty, 1, 20, 8)
    local maxLength = boundedInteger(Config.Images and Config.Images.maxLength, 50, 1000, 500)

    for index = 1, math.min(#gallery, maximum) do
        local image = trim(gallery[index])
        local validRelative = image:match('^images/[A-Za-z0-9_%.%-%/]+$') ~= nil
        local validHttps = image:match('^https://') ~= nil
        if #image <= maxLength and not image:find('..', 1, true) and (validRelative or validHttps) then
            clean[#clean + 1] = image
        end
    end
    return clean
end

local function isAdmin(source)
    source = tonumber(source)
    if not source or source <= 0 then return true end
    for _, permission in ipairs(Config.AdminPermissions or {}) do
        if IsPlayerAceAllowed(source, permission) then return true end
    end
    return false
end

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(tonumber(source))
end

local function getCitizenId(source)
    local player = getPlayer(source)
    return player and tostring(player.PlayerData.citizenid), player
end

local function citizenExists(citizenid)
    return MySQL.scalar.await('SELECT 1 FROM players WHERE citizenid = ? LIMIT 1', { citizenid }) ~= nil
end

local function notify(source, message, notifyType)
    if source and tonumber(source) and tonumber(source) > 0 and GetPlayerPing(tonumber(source)) > 0 then
        exports.qbx_core:Notify(tonumber(source), tostring(message), notifyType or 'inform', 5000)
    end
end

local function audit(actor, action, propertyId, citizenid, details)
    MySQL.insert.await([[
        INSERT INTO ob_property_audit (actor, action, property_id, target_citizenid, details)
        VALUES (?, ?, ?, ?, ?)
    ]], {
        trim(actor) ~= '' and trim(actor) or 'system',
        trim(action),
        tonumber(propertyId),
        trim(citizenid) ~= '' and trim(citizenid) or nil,
        details and json.encode(details) or nil
    })
end

local function presetInterior(presetKey)
    local preset = Config.Interiors and Config.Interiors[presetKey]
    if not preset then return nil end
    return {
        provider = preset.provider,
        exportName = preset.exportName,
        entry = coordinates(preset.entry, true),
        exit = coordinates(preset.exit or preset.entry, true),
        stash = coordinates(preset.stash, false),
        wardrobe = coordinates(preset.wardrobe, false)
    }
end

local function mergeInterior(presetKey, supplied)
    local interior = presetInterior(presetKey)
    if not interior then return nil end
    supplied = type(supplied) == 'table' and supplied or {}
    interior.entry = coordinates(supplied.entry, true) or interior.entry
    interior.exit = coordinates(supplied.exit, true) or interior.exit
    interior.stash = coordinates(supplied.stash, false) or interior.stash
    interior.wardrobe = coordinates(supplied.wardrobe, false) or interior.wardrobe
    return interior
end

local function formatProperty(row)
    if not row then return nil end
    local ownerCount = tonumber(row.owner_count) or tonumber(row.ownerCount) or 0
    local mode = tostring(row.ownership_mode or 'unique')
    return {
        id = tonumber(row.id),
        key = tostring(row.property_key),
        type = tostring(row.type),
        ownershipMode = mode,
        label = tostring(row.label),
        description = tostring(row.description or ''),
        price = tonumber(row.price) or 0,
        paymentAccount = tostring(row.payment_account or 'bank'),
        purchasable = asBoolean(row.purchasable),
        starter = asBoolean(row.is_starter),
        listed = asBoolean(row.is_listed),
        status = tostring(row.status or 'available'),
        vipTier = row.vip_tier and tostring(row.vip_tier) or nil,
        presetKey = tostring(row.preset_key),
        entrance = coordinates(decode(row.entrance, {}), true),
        interior = decode(row.interior, {}),
        gallery = safeGallery(row.gallery),
        stashSlots = tonumber(row.stash_slots) or 30,
        stashWeight = tonumber(row.stash_weight) or 50000,
        ownerCount = ownerCount,
        available = mode == 'instanced' or ownerCount == 0,
        createdAt = row.created_at,
        updatedAt = row.updated_at,
        ownershipId = tonumber(row.ownership_id),
        ownerCitizenId = row.owner_citizenid and tostring(row.owner_citizenid) or nil,
        acquisition = row.acquisition and tostring(row.acquisition) or nil,
        expiresAt = tonumber(row.expires_at),
        accessRole = row.access_role and tostring(row.access_role) or nil
    }
end

local function propertySelect(whereClause, parameters)
    local rows = MySQL.query.await(([=[
        SELECT property.*,
            (SELECT COUNT(*) FROM ob_property_ownerships ownership
             WHERE ownership.property_id = property.id AND %s) AS owner_count
        FROM ob_properties property
        %s
    ]=]):format(ACTIVE_OWNER_SQL, whereClause or ''), parameters or {}) or {}
    local result = {}
    for _, row in ipairs(rows) do result[#result + 1] = formatProperty(row) end
    return result
end

local function getProperty(identifier)
    local numericId = tonumber(identifier)
    local where = numericId and 'WHERE property.id = ? LIMIT 1' or 'WHERE property.property_key = ? LIMIT 1'
    local rows = propertySelect(where, { numericId or trim(identifier):lower() })
    return rows[1]
end

local function catalogProperties()
    return propertySelect([[
        WHERE property.status = 'available'
          AND property.is_listed = 1
          AND property.is_starter = 0
        ORDER BY property.type ASC, property.price ASC, property.label ASC
    ]])
end

local function adminProperties()
    return propertySelect('ORDER BY property.updated_at DESC, property.id DESC')
end

local function playerProperties(citizenid)
    local rows = MySQL.query.await(([=[
        SELECT property.*, ownership.id AS ownership_id,
               ownership.citizenid AS owner_citizenid, ownership.acquisition,
               ownership.expires_at, 'owner' AS access_role
        FROM ob_property_ownerships ownership
        INNER JOIN ob_properties property ON property.id = ownership.property_id
        WHERE ownership.citizenid = ? AND %s

        UNION ALL

        SELECT property.*, ownership.id AS ownership_id,
               ownership.citizenid AS owner_citizenid, ownership.acquisition,
               ownership.expires_at, access.role AS access_role
        FROM ob_property_access access
        INNER JOIN ob_property_ownerships ownership ON ownership.id = access.ownership_id
        INNER JOIN ob_properties property ON property.id = ownership.property_id
        WHERE access.citizenid = ? AND %s
        ORDER BY label ASC
    ]=]):format(ACTIVE_OWNER_SQL, ACTIVE_OWNER_SQL), { citizenid, citizenid }) or {}

    local result = {}
    for _, row in ipairs(rows) do result[#result + 1] = formatProperty(row) end
    return result
end

local function publicEntrances()
    local rows = MySQL.query.await([[
        SELECT id, property_key, label, type, ownership_mode, is_starter, entrance
        FROM ob_properties
        WHERE status = 'available'
        ORDER BY id ASC
    ]]) or {}
    local result = {}
    for _, row in ipairs(rows) do
        local entrance = coordinates(decode(row.entrance, {}), true)
        if entrance then
            result[#result + 1] = {
                id = tonumber(row.id),
                key = tostring(row.property_key),
                label = tostring(row.label),
                type = tostring(row.type),
                ownershipMode = tostring(row.ownership_mode or 'unique'),
                starter = asBoolean(row.is_starter),
                entrance = entrance
            }
        end
    end
    return result
end

local function broadcastProperties(target)
    if not databaseReady then return end
    TriggerClientEvent('ob_housing:client:syncProperties', target or -1, publicEntrances())
end

local function acquirePropertyLock(propertyId, callback)
    propertyId = tonumber(propertyId)
    if propertyLocks[propertyId] then return { ok = false, error = 'property_busy' } end
    propertyLocks[propertyId] = true
    local ok, result = pcall(callback)
    propertyLocks[propertyId] = nil
    if not ok then
        print(('^1[%s] Falha na operação do imóvel %s: %s^7'):format(RESOURCE, propertyId, result))
        return { ok = false, error = 'internal_error' }
    end
    return result
end

local function acquirePurchaseLock(citizenid, callback)
    if purchaseLocks[citizenid] then return { ok = false, error = 'property_busy' } end
    purchaseLocks[citizenid] = true
    local ok, result = pcall(callback)
    purchaseLocks[citizenid] = nil
    if not ok then
        print(('^1[%s] Falha na compra de %s: %s^7'):format(RESOURCE, citizenid, result))
        return { ok = false, error = 'internal_error' }
    end
    return result
end

local function grantProperty(citizenid, propertyIdentifier, options)
    if not databaseReady then return { ok = false, error = 'database_initializing' } end
    citizenid = trim(citizenid)
    options = type(options) == 'table' and options or {}
    if citizenid == '' or not citizenExists(citizenid) then return { ok = false, error = 'citizen_not_found' } end

    local property = getProperty(propertyIdentifier)
    if not property then return { ok = false, error = 'property_not_found' } end

    return acquirePropertyLock(property.id, function()
        property = getProperty(property.id)
        if property.ownershipMode == 'unique' then
            local occupiedByOther = MySQL.scalar.await(([=[
                SELECT 1 FROM ob_property_ownerships ownership
                WHERE ownership.property_id = ? AND ownership.citizenid <> ? AND %s
                LIMIT 1
            ]=]):format(ACTIVE_OWNER_SQL), { property.id, citizenid })
            if occupiedByOther then return { ok = false, error = 'property_unavailable' } end
        end

        local existing = MySQL.single.await([[
            SELECT id, acquisition, expires_at FROM ob_property_ownerships
            WHERE property_id = ? AND citizenid = ? LIMIT 1
        ]], { property.id, citizenid })

        local existingExpiry = existing and tonumber(existing.expires_at)
        local existingActive = existing and (existing.expires_at == nil or existingExpiry > os.time())
        local requestedDuration = tonumber(options.durationDays)
        local requestedExpiry = tonumber(options.expiresAt)
        if requestedDuration and (requestedDuration < 0 or requestedDuration > 36500) then
            return { ok = false, error = 'invalid_expiry' }
        end
        if options.expiresAt ~= nil and (not requestedExpiry or requestedExpiry <= os.time()) then
            return { ok = false, error = 'invalid_expiry' }
        end
        if existingActive
            and not options.force
            and not (requestedDuration and requestedDuration > 0)
            and not (requestedExpiry and requestedExpiry > 0)
        then
            return {
                ok = true,
                alreadyOwned = true,
                ownershipId = tonumber(existing.id),
                expiresAt = existingExpiry,
                property = property
            }
        end

        local durationDays = requestedDuration
        local expiresAt
        if durationDays and durationDays > 0 then
            local currentExpiry = existingExpiry
            if existing and existing.expires_at == nil then
                expiresAt = nil
            else
                expiresAt = math.max(os.time(), currentExpiry or 0) + math.floor(durationDays * 86400)
            end
        elseif requestedExpiry and requestedExpiry > os.time() then
            expiresAt = math.floor(requestedExpiry)
        end

        local acquisition = trim(options.acquisition)
        if acquisition == '' then acquisition = 'admin' end
        local metadata = type(options.metadata) == 'table' and json.encode(options.metadata) or nil
        local ownershipId

        if existing then
            ownershipId = tonumber(existing.id)
            MySQL.update.await([[
                UPDATE ob_property_ownerships
                SET acquisition = ?, expires_at = ?, metadata = ?
                WHERE id = ?
            ]], { acquisition, expiresAt, metadata, ownershipId })
        else
            ownershipId = MySQL.insert.await([[
                INSERT INTO ob_property_ownerships
                    (property_id, citizenid, acquisition, expires_at, metadata)
                VALUES (?, ?, ?, ?, ?)
            ]], { property.id, citizenid, acquisition, expiresAt, metadata })
        end

        if not ownershipId then return { ok = false, error = 'grant_failed' } end
        audit(options.actor or 'export', 'grant', property.id, citizenid, {
            acquisition = acquisition,
            expiresAt = expiresAt,
            ownershipId = ownershipId
        })
        TriggerEvent('ob_housing:server:granted', citizenid, property.key, ownershipId, acquisition)
        broadcastProperties()
        return {
            ok = true,
            ownershipId = tonumber(ownershipId),
            expiresAt = expiresAt,
            property = property
        }
    end)
end

local function forceSessionExit(playerSource, reason)
    local session = sessions[playerSource]
    if not session then return end
    if GetPlayerPing(playerSource) > 0 then
        TriggerClientEvent('ob_housing:client:forceExit', playerSource, session.entrance, reason)
        SetPlayerRoutingBucket(playerSource, 0)
        Player(playerSource).state:set('inProperty', false, true)
        Player(playerSource).state:set('inApartment', false, true)
    end
    sessions[playerSource] = nil
end

local function schedulePreviewExpiry(playerSource, maximum)
    local session = sessions[playerSource]
    if not session or not session.preview then return end
    previewSequence = previewSequence + 1
    local token = previewSequence
    session.previewToken = token
    SetTimeout(maximum * 1000, function()
        local active = sessions[playerSource]
        if active and active.preview and active.previewToken == token then
            forceSessionExit(playerSource, 'preview_expired')
        end
    end)
end

local function revokeProperty(citizenid, propertyIdentifier, reason, actor)
    if not databaseReady then return { ok = false, error = 'database_initializing' } end
    citizenid = trim(citizenid)
    local property = getProperty(propertyIdentifier)
    if not property then return { ok = false, error = 'property_not_found' } end

    local ownership = MySQL.single.await([[
        SELECT id FROM ob_property_ownerships WHERE property_id = ? AND citizenid = ? LIMIT 1
    ]], { property.id, citizenid })
    if not ownership then return { ok = false, error = 'ownership_not_found' } end

    MySQL.query.await('DELETE FROM ob_property_access WHERE ownership_id = ?', { ownership.id })
    local changed = MySQL.update.await('DELETE FROM ob_property_ownerships WHERE id = ?', { ownership.id }) or 0
    if changed < 1 then return { ok = false, error = 'revoke_failed' } end

    for source, session in pairs(sessions) do
        if tonumber(session.ownershipId) == tonumber(ownership.id) then
            forceSessionExit(source)
        end
    end

    audit(actor or 'export', 'revoke', property.id, citizenid, { reason = trim(reason) })
    broadcastProperties()
    return { ok = true }
end

local function ensureStarterApartment(citizenid)
    if not Config.StarterApartment or Config.StarterApartment.enabled == false then
        return { ok = false, error = 'starter_disabled' }
    end
    return grantProperty(citizenid, Config.StarterApartment.propertyKey, {
        acquisition = 'starter',
        actor = 'system'
    })
end

local function resolveAccess(citizenid, propertyId)
    return MySQL.single.await(([=[
        SELECT ownership.id, ownership.citizenid AS owner_citizenid,
               ownership.expires_at, 'owner' AS access_role
        FROM ob_property_ownerships ownership
        WHERE ownership.property_id = ? AND ownership.citizenid = ? AND %s

        UNION ALL

        SELECT ownership.id, ownership.citizenid AS owner_citizenid,
               ownership.expires_at, access.role AS access_role
        FROM ob_property_access access
        INNER JOIN ob_property_ownerships ownership ON ownership.id = access.ownership_id
        WHERE ownership.property_id = ? AND access.citizenid = ? AND %s
        LIMIT 1
    ]=]):format(ACTIVE_OWNER_SQL, ACTIVE_OWNER_SQL), {
        propertyId, citizenid, propertyId, citizenid
    })
end

local function setHousingState(source, property, value)
    local state = Player(source).state
    state:set('inProperty', value and property.key or false, true)
    state:set('inApartment', value and property.type == 'apartment' or false, true)
end

local function isNear(source, target, maximumDistance)
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 or not target then return false end
    local current = GetEntityCoords(ped)
    local destination = vec3(target.x + 0.0, target.y + 0.0, target.z + 0.0)
    return #(current - destination) <= maximumDistance
end

local function playerDisplayName(source, encodedCharinfo)
    local player = source and getPlayer(source)
    local charinfo = player and player.PlayerData and player.PlayerData.charinfo or decode(encodedCharinfo, {})
    local name = trim(('%s %s'):format(charinfo and charinfo.firstname or '', charinfo and charinfo.lastname or ''))
    if name ~= '' then return name end
    return source and GetPlayerName(source) or 'Morador'
end

local function onlineSourceByCitizenId(citizenid)
    local player = exports.qbx_core:GetPlayerByCitizenId(tostring(citizenid))
    local source = player and player.PlayerData and tonumber(player.PlayerData.source)
    if source and GetPlayerPing(source) > 0 then return source end
end

local function activeOwnership(ownershipId, propertyId)
    return MySQL.single.await(([=[
        SELECT ownership.id, ownership.citizenid AS owner_citizenid,
               ownership.expires_at, 'visitor' AS access_role
        FROM ob_property_ownerships ownership
        WHERE ownership.id = ? AND ownership.property_id = ? AND %s
        LIMIT 1
    ]=]):format(ACTIVE_OWNER_SQL), { tonumber(ownershipId), tonumber(propertyId) })
end

local function clearBellRequest(requestId)
    local request = bellRequests[requestId]
    if not request then return end
    if pendingBellByOwner[request.ownerSource] == requestId then
        pendingBellByOwner[request.ownerSource] = nil
    end
    bellRequests[requestId] = nil
end

local function entranceOptions(source, propertyIdentifier)
    if not Config.Visitors or Config.Visitors.enabled == false then
        return { ok = false, error = 'visitor_disabled' }
    end

    local citizenid = getCitizenId(source)
    local property = getProperty(propertyIdentifier)
    if not citizenid then return { ok = false, error = 'player_not_loaded' } end
    if not property or property.status ~= 'available' then return { ok = false, error = 'property_not_found' } end
    if not isNear(source, property.entrance, Config.Interaction.serverValidationDistance) then
        return { ok = false, error = 'too_far' }
    end

    local access = resolveAccess(citizenid, property.id)
    local maximum = boundedInteger(Config.Visitors.maxResidentsListed, 1, 100, 40)
    local rows = MySQL.query.await(([=[
        SELECT ownership.id, ownership.citizenid, players.charinfo
        FROM ob_property_ownerships ownership
        LEFT JOIN players ON players.citizenid = ownership.citizenid
        WHERE ownership.property_id = ? AND %s
        ORDER BY ownership.created_at DESC
        LIMIT ?
    ]=]):format(ACTIVE_OWNER_SQL), { property.id, maximum }) or {}

    local owners = {}
    for _, row in ipairs(rows) do
        local ownerSource = onlineSourceByCitizenId(row.citizenid)
        local isCurrentAccess = access and tonumber(access.id) == tonumber(row.id)
        if not isCurrentAccess and (ownerSource or property.ownershipMode == 'unique') then
            owners[#owners + 1] = {
                ownershipId = tonumber(row.id),
                name = playerDisplayName(ownerSource, row.charinfo),
                online = ownerSource ~= nil
            }
        end
    end

    return {
        ok = true,
        property = property,
        access = access and {
            ownershipId = tonumber(access.id),
            role = tostring(access.access_role)
        } or nil,
        owners = owners
    }
end

local function ringBell(source, propertyIdentifier, ownershipId)
    if not Config.Visitors or Config.Visitors.enabled == false then
        return { ok = false, error = 'visitor_disabled' }
    end

    local citizenid = getCitizenId(source)
    local property = getProperty(propertyIdentifier)
    if not citizenid then return { ok = false, error = 'player_not_loaded' } end
    if not property or property.status ~= 'available' then return { ok = false, error = 'property_not_found' } end
    if not isNear(source, property.entrance, Config.Interaction.serverValidationDistance) then
        return { ok = false, error = 'too_far' }
    end

    local ownership = activeOwnership(ownershipId, property.id)
    if not ownership then return { ok = false, error = 'ownership_not_found' } end
    if tostring(ownership.owner_citizenid) == citizenid then return { ok = false, error = 'already_owner' } end

    local ownerSource = onlineSourceByCitizenId(ownership.owner_citizenid)
    if not ownerSource then return { ok = false, error = 'resident_offline' } end

    local now = os.time()
    local cooldownKey = ('%s:%s'):format(source, ownership.id)
    if (bellCooldowns[cooldownKey] or 0) > now then return { ok = false, error = 'bell_cooldown' } end
    local currentRequestId = pendingBellByOwner[ownerSource]
    if currentRequestId then
        local current = bellRequests[currentRequestId]
        if current and current.expiresAt > now then return { ok = false, error = 'owner_busy' } end
        clearBellRequest(currentRequestId)
    end

    bellSequence = bellSequence + 1
    local requestId = ('%s:%s:%s'):format(ownerSource, now, bellSequence)
    local timeout = boundedInteger(Config.Visitors.requestTimeoutSeconds, 10, 120, 30)
    bellRequests[requestId] = {
        ownerSource = ownerSource,
        visitorSource = source,
        visitorCitizenId = citizenid,
        ownershipId = tonumber(ownership.id),
        propertyId = property.id,
        expiresAt = now + timeout
    }
    pendingBellByOwner[ownerSource] = requestId
    bellCooldowns[cooldownKey] = now + boundedInteger(Config.Visitors.cooldownSeconds, 5, 300, 20)

    TriggerClientEvent('ob_housing:client:bellRequest', ownerSource, {
        requestId = requestId,
        visitorName = playerDisplayName(source),
        propertyLabel = property.label,
        timeoutSeconds = timeout
    })

    SetTimeout(timeout * 1000, function()
        local pending = bellRequests[requestId]
        if not pending then return end
        clearBellRequest(requestId)
        if GetPlayerPing(pending.visitorSource) > 0 then
            TriggerClientEvent('ob_housing:client:bellResult', pending.visitorSource, 'expired')
        end
    end)

    return { ok = true, timeoutSeconds = timeout }
end

local function enterProperty(source, propertyIdentifier, preview, inviteToken)
    local citizenid = getCitizenId(source)
    if not citizenid then return { ok = false, error = 'player_not_loaded' } end
    local property = getProperty(propertyIdentifier)
    if not property or property.status ~= 'available' then return { ok = false, error = 'property_not_found' } end

    preview = preview == true and isAdmin(source)
    if not preview and not isNear(source, property.entrance, Config.Interaction.serverValidationDistance) then
        return { ok = false, error = 'too_far' }
    end

    local ownership
    if not preview then
        inviteToken = trim(inviteToken)
        if inviteToken ~= '' then
            local invite = visitorInvites[inviteToken]
            visitorInvites[inviteToken] = nil
            if not invite or invite.expiresAt < os.time()
                or invite.visitorSource ~= source
                or invite.visitorCitizenId ~= citizenid
                or invite.propertyId ~= property.id
            then
                return { ok = false, error = 'invite_expired' }
            end
            ownership = activeOwnership(invite.ownershipId, property.id)
            if not ownership then return { ok = false, error = 'ownership_not_found' } end
        else
            ownership = resolveAccess(citizenid, property.id)
        end
        if not ownership then return { ok = false, error = 'no_access' } end
    end

    local interior = mergeInterior(property.presetKey, property.interior)
    if not interior or not interior.entry or not interior.exit then
        return { ok = false, error = 'invalid_interior' }
    end

    if sessions[source] then SetPlayerRoutingBucket(source, 0) end
    local ownershipId = ownership and tonumber(ownership.id) or nil
    local bucket = preview
        and (Config.Routing.previewBucketBase + source)
        or (Config.Routing.propertyBucketBase + ownershipId)

    SetPlayerRoutingBucket(source, bucket)
    setHousingState(source, property, true)
    sessions[source] = {
        propertyId = property.id,
        propertyKey = property.key,
        propertyType = property.type,
        ownershipId = ownershipId,
        ownerCitizenId = ownership and tostring(ownership.owner_citizenid) or nil,
        accessRole = ownership and tostring(ownership.access_role) or 'preview',
        bucket = bucket,
        preview = preview,
        expiresAt = preview and (os.time() + boundedInteger(Config.InteriorPreview and Config.InteriorPreview.maxSeconds, 30, 1800, 300)) or nil,
        entrance = property.entrance,
        interior = interior,
        stashId = ownershipId and ('ob_housing_%s'):format(ownershipId) or nil
    }
    if preview then
        schedulePreviewExpiry(source, boundedInteger(Config.InteriorPreview and Config.InteriorPreview.maxSeconds, 30, 1800, 300))
    end

    return {
        ok = true,
        property = property,
        interior = interior,
        preview = preview,
        accessRole = sessions[source].accessRole,
        timeoutSeconds = preview and boundedInteger(Config.InteriorPreview and Config.InteriorPreview.maxSeconds, 30, 1800, 300) or nil
    }
end

local function previewInterior(source, presetKey)
    if not isAdmin(source) then return { ok = false, error = 'forbidden' } end
    if not Config.InteriorPreview or Config.InteriorPreview.enabled == false then
        return { ok = false, error = 'preview_disabled' }
    end

    presetKey = trim(presetKey)
    local preset = Config.Interiors and Config.Interiors[presetKey]
    local interior = presetInterior(presetKey)
    if not preset or not interior or not interior.entry or not interior.exit then
        return { ok = false, error = 'invalid_interior' }
    end

    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then return { ok = false, error = 'player_not_loaded' } end
    local coords = GetEntityCoords(ped)
    local returnPoint = {
        x = coords.x + 0.0,
        y = coords.y + 0.0,
        z = coords.z + 0.0,
        h = GetEntityHeading(ped) + 0.0
    }
    local maximum = boundedInteger(Config.InteriorPreview.maxSeconds, 30, 1800, 300)

    if sessions[source] then SetPlayerRoutingBucket(source, 0) end
    SetPlayerRoutingBucket(source, Config.Routing.previewBucketBase + source)
    local property = {
        id = 0,
        key = ('preview_%s'):format(presetKey),
        type = 'house',
        label = tostring(preset.label or presetKey),
        entrance = returnPoint
    }
    setHousingState(source, property, true)
    sessions[source] = {
        propertyId = nil,
        propertyKey = property.key,
        propertyType = property.type,
        ownershipId = nil,
        accessRole = 'preview',
        bucket = Config.Routing.previewBucketBase + source,
        preview = true,
        expiresAt = os.time() + maximum,
        entrance = returnPoint,
        interior = interior
    }
    schedulePreviewExpiry(source, maximum)

    return {
        ok = true,
        property = property,
        interior = interior,
        preview = true,
        accessRole = 'preview',
        timeoutSeconds = maximum
    }
end

local function exitProperty(source)
    local session = sessions[source]
    if not session then return { ok = false, error = 'not_inside' } end
    sessions[source] = nil
    SetPlayerRoutingBucket(source, 0)
    setHousingState(source, { key = session.propertyKey, type = session.propertyType }, false)
    return { ok = true, entrance = session.entrance }
end

local function registerSessionStash(source)
    local session = sessions[source]
    local canUseStash = session and (session.accessRole == 'owner' or session.accessRole == 'resident')
    if not canUseStash or session.preview or not session.stashId then
        return { ok = false, error = 'stash_unavailable' }
    end
    local citizenid = getCitizenId(source)
    if not citizenid or not resolveAccess(citizenid, session.propertyId) then
        return { ok = false, error = 'no_access' }
    end
    local property = getProperty(session.propertyId)
    if not property then return { ok = false, error = 'property_not_found' } end
    if not isNear(source, session.interior.stash, 3.5) then return { ok = false, error = 'too_far' } end

    if GetResourceState(Config.Resources.inventory) ~= 'started' then
        return { ok = false, error = 'inventory_unavailable' }
    end
    if not registeredStashes[session.stashId] then
        exports.ox_inventory:RegisterStash(
            session.stashId,
            ('Baú - %s'):format(property.label),
            property.stashSlots,
            property.stashWeight,
            false,
            nil,
            session.interior.stash
        )
        registeredStashes[session.stashId] = true
    end
    return { ok = true, stashId = session.stashId }
end

local function presetsForUi()
    local presets = {}
    for key, preset in pairs(Config.Interiors or {}) do
        presets[#presets + 1] = {
            key = key,
            label = preset.label or key,
            provider = preset.provider,
            interior = presetInterior(key)
        }
    end
    table.sort(presets, function(a, b) return a.label < b.label end)
    return presets
end

local function saveProperty(source, payload)
    if not isAdmin(source) then return { ok = false, error = 'forbidden' } end
    payload = type(payload) == 'table' and payload or {}
    local id = tonumber(payload.id)
    local key = trim(payload.key):lower()
    local label = trim(payload.label)
    local propertyType = payload.type == 'apartment' and 'apartment' or 'house'
    local ownershipMode = payload.ownershipMode == 'instanced' and 'instanced' or 'unique'
    local presetKey = trim(payload.presetKey)
    local entrance = coordinates(payload.entrance, true)
    local interior = mergeInterior(presetKey, payload.interior)

    if #key < 3 or #key > 64 or not key:match('^[a-z0-9_-]+$') then
        return { ok = false, error = 'invalid_key' }
    end
    if #label < 3 or #label > 80 then return { ok = false, error = 'invalid_label' } end
    if not entrance then return { ok = false, error = 'invalid_entrance' } end
    if not interior or not interior.entry or not interior.exit or not interior.stash then
        return { ok = false, error = 'invalid_interior' }
    end

    local description = trim(payload.description):sub(1, 500)
    local price = boundedInteger(payload.price, 0, 2000000000, 0)
    local account = trim(payload.paymentAccount)
    if account ~= 'cash' and account ~= 'bank' then account = Config.Purchase.defaultAccount or 'bank' end
    local gallery = safeGallery(payload.gallery)
    local vipTier = trim(payload.vipTier):lower()
    if vipTier == '' then vipTier = nil end
    local status = payload.status == 'disabled' and 'disabled' or 'available'
    local actorCitizen = getCitizenId(source) or ('source:%s'):format(source)
    local params = {
        key,
        propertyType,
        ownershipMode,
        label,
        description,
        price,
        account,
        not vipTier and asBoolean(payload.purchasable) and 1 or 0,
        asBoolean(payload.starter) and 1 or 0,
        asBoolean(payload.listed) and 1 or 0,
        status,
        vipTier,
        presetKey,
        json.encode(entrance),
        json.encode(interior),
        json.encode(gallery),
        boundedInteger(payload.stashSlots, 5, 200, 30),
        boundedInteger(payload.stashWeight, 5000, 2000000, 50000)
    }

    if id then
        params[#params + 1] = id
        local ok, changed = pcall(MySQL.update.await, [[
            UPDATE ob_properties SET
                property_key = ?, type = ?, ownership_mode = ?, label = ?, description = ?,
                price = ?, payment_account = ?, purchasable = ?, is_starter = ?, is_listed = ?,
                status = ?, vip_tier = ?, preset_key = ?, entrance = ?, interior = ?, gallery = ?,
                stash_slots = ?, stash_weight = ?
            WHERE id = ?
        ]], params)
        if not ok then
            debugLog(changed)
            return { ok = false, error = 'duplicate_key' }
        end
        changed = changed or 0
        if changed < 1 and not getProperty(id) then return { ok = false, error = 'property_not_found' } end
    else
        params[#params + 1] = actorCitizen
        local ok, inserted = pcall(MySQL.insert.await, [[
            INSERT INTO ob_properties
                (property_key, type, ownership_mode, label, description, price, payment_account,
                 purchasable, is_starter, is_listed, status, vip_tier, preset_key, entrance,
                 interior, gallery, stash_slots, stash_weight, created_by)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], params)
        if not ok then
            debugLog(inserted)
            return { ok = false, error = 'duplicate_key' }
        end
        id = tonumber(inserted)
    end

    local property = getProperty(id)
    audit(actorCitizen, 'save_property', id, nil, { key = key })
    broadcastProperties()
    return { ok = true, property = property }
end

local function archiveProperty(source, propertyId)
    if not isAdmin(source) then return { ok = false, error = 'forbidden' } end
    local property = getProperty(propertyId)
    if not property then return { ok = false, error = 'property_not_found' } end
    if property.starter then return { ok = false, error = 'starter_cannot_archive' } end
    MySQL.update.await("UPDATE ob_properties SET status = 'disabled', is_listed = 0 WHERE id = ?", { property.id })
    for playerSource, session in pairs(sessions) do
        if tonumber(session.propertyId) == property.id then forceSessionExit(playerSource) end
    end
    audit(getCitizenId(source) or ('source:%s'):format(source), 'archive_property', property.id)
    broadcastProperties()
    return { ok = true }
end

local function purchaseProperty(source, propertyId)
    if Config.Purchase.enabled == false then return { ok = false, error = 'purchases_disabled' } end
    local citizenid, player = getCitizenId(source)
    if not citizenid or not player then return { ok = false, error = 'player_not_loaded' } end
    local property = getProperty(propertyId)
    if not property or property.status ~= 'available' or not property.listed then
        return { ok = false, error = 'property_not_found' }
    end
    if not property.purchasable or property.vipTier then return { ok = false, error = 'not_for_sale' } end

    local current = resolveAccess(citizenid, property.id)
    if current then return { ok = false, error = 'already_owned' } end
    if property.type == 'house' then
        local amount = MySQL.scalar.await(([=[
            SELECT COUNT(*) FROM ob_property_ownerships ownership
            INNER JOIN ob_properties property ON property.id = ownership.property_id
            WHERE ownership.citizenid = ? AND property.type = 'house' AND %s
        ]=]):format(ACTIVE_OWNER_SQL), { citizenid }) or 0
        if tonumber(amount) >= Config.Purchase.maxHousesPerCitizen then
            return { ok = false, error = 'house_limit' }
        end
    end

    return acquirePurchaseLock(citizenid, function()
        return acquirePropertyLock(property.id, function()
            property = getProperty(property.id)
            if not property or property.status ~= 'available' or not property.listed then
                return { ok = false, error = 'property_not_found' }
            end
            if not property.purchasable or property.vipTier then
                return { ok = false, error = 'not_for_sale' }
            end
            if resolveAccess(citizenid, property.id) then return { ok = false, error = 'already_owned' } end
            if property.ownershipMode == 'unique' and not property.available then
                return { ok = false, error = 'property_unavailable' }
            end
            if property.type == 'house' then
                local amount = MySQL.scalar.await(([=[
                    SELECT COUNT(*) FROM ob_property_ownerships ownership
                    INNER JOIN ob_properties property ON property.id = ownership.property_id
                    WHERE ownership.citizenid = ? AND property.type = 'house' AND %s
                ]=]):format(ACTIVE_OWNER_SQL), { citizenid }) or 0
                if tonumber(amount) >= Config.Purchase.maxHousesPerCitizen then
                    return { ok = false, error = 'house_limit' }
                end
            end

            local paid = true
            if property.price > 0 then
                paid = player.Functions.RemoveMoney(
                    property.paymentAccount,
                    property.price,
                    ('ob_housing_purchase:%s'):format(property.key)
                ) == true
            end
            if not paid then return { ok = false, error = 'insufficient_funds' } end

            local metadata = json.encode({ price = property.price, account = property.paymentAccount })
            local expiredOwnership = MySQL.single.await([[
                SELECT id FROM ob_property_ownerships
                WHERE property_id = ? AND citizenid = ? LIMIT 1
            ]], { property.id, citizenid })
            local ownershipId
            if expiredOwnership then
                ownershipId = tonumber(expiredOwnership.id)
                local changed = MySQL.update.await([[
                    UPDATE ob_property_ownerships
                    SET acquisition = 'purchase', expires_at = NULL, metadata = ?
                    WHERE id = ?
                ]], { metadata, ownershipId }) or 0
                if changed < 1 then ownershipId = nil end
            else
                ownershipId = MySQL.insert.await([[
                    INSERT INTO ob_property_ownerships
                        (property_id, citizenid, acquisition, metadata)
                    VALUES (?, ?, 'purchase', ?)
                ]], { property.id, citizenid, metadata })
            end

            if not ownershipId then
                if property.price > 0 then
                    player.Functions.AddMoney(property.paymentAccount, property.price, 'ob_housing_purchase_refund')
                end
                return { ok = false, error = 'purchase_failed' }
            end

            audit(citizenid, 'purchase', property.id, citizenid, {
                price = property.price,
                account = property.paymentAccount,
                ownershipId = ownershipId
            })
            TriggerEvent('ob_housing:server:granted', citizenid, property.key, ownershipId, 'purchase')
            broadcastProperties()
            notify(source, ('Você adquiriu %s.'):format(property.label), 'success')
            return { ok = true, ownershipId = ownershipId, property = property }
        end)
    end)
end

local function listAccess(source, ownershipId)
    local citizenid = getCitizenId(source)
    local ownership = MySQL.single.await([[
        SELECT id, citizenid FROM ob_property_ownerships
        WHERE id = ? AND (expires_at IS NULL OR expires_at > UNIX_TIMESTAMP()) LIMIT 1
    ]], { tonumber(ownershipId) })
    if not ownership or (tostring(ownership.citizenid) ~= citizenid and not isAdmin(source)) then
        return { ok = false, error = 'forbidden' }
    end
    local rows = MySQL.query.await([[
        SELECT access.id, access.citizenid, access.role, access.created_at,
               players.charinfo
        FROM ob_property_access access
        LEFT JOIN players ON players.citizenid = access.citizenid
        WHERE access.ownership_id = ?
        ORDER BY access.created_at ASC
    ]], { ownership.id }) or {}
    for _, row in ipairs(rows) do
        local charinfo = decode(row.charinfo, {})
        row.name = trim(('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''))
        row.charinfo = nil
    end
    return { ok = true, access = rows }
end

local function listOwners(source, propertyId)
    if not isAdmin(source) then return { ok = false, error = 'forbidden' } end
    local property = getProperty(propertyId)
    if not property then return { ok = false, error = 'property_not_found' } end
    local rows = MySQL.query.await([[
        SELECT ownership.id, ownership.citizenid, ownership.acquisition,
               ownership.expires_at, ownership.created_at, players.charinfo
        FROM ob_property_ownerships ownership
        LEFT JOIN players ON players.citizenid = ownership.citizenid
        WHERE ownership.property_id = ?
        ORDER BY (ownership.expires_at IS NULL OR ownership.expires_at > UNIX_TIMESTAMP()) DESC,
                 ownership.created_at DESC
    ]], { property.id }) or {}
    for _, row in ipairs(rows) do
        local charinfo = decode(row.charinfo, {})
        row.name = trim(('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''))
        row.charinfo = nil
        row.active = row.expires_at == nil or tonumber(row.expires_at) > os.time()
    end
    return { ok = true, property = property, owners = rows }
end

local function grantAccess(source, ownershipId, targetCitizenId, role)
    local citizenid = getCitizenId(source)
    targetCitizenId = trim(targetCitizenId)
    local ownership = MySQL.single.await([[
        SELECT id, citizenid FROM ob_property_ownerships ownership
        WHERE id = ? AND (expires_at IS NULL OR expires_at > UNIX_TIMESTAMP()) LIMIT 1
    ]], { tonumber(ownershipId) })
    if not ownership or (tostring(ownership.citizenid) ~= citizenid and not isAdmin(source)) then
        return { ok = false, error = 'forbidden' }
    end
    if targetCitizenId == '' or not citizenExists(targetCitizenId) then return { ok = false, error = 'citizen_not_found' } end
    if targetCitizenId == tostring(ownership.citizenid) then return { ok = false, error = 'already_owner' } end
    role = role == 'guest' and 'guest' or 'resident'
    MySQL.insert.await([[
        INSERT INTO ob_property_access (ownership_id, citizenid, role, granted_by)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE role = VALUES(role), granted_by = VALUES(granted_by)
    ]], { ownership.id, targetCitizenId, role, citizenid })
    audit(citizenid, 'grant_access', nil, targetCitizenId, { ownershipId = ownership.id, role = role })
    return listAccess(source, ownership.id)
end

local function revokeAccess(source, accessId)
    local citizenid = getCitizenId(source)
    local access = MySQL.single.await([[
        SELECT access.id, access.citizenid, ownership.id AS ownership_id, ownership.citizenid AS owner_citizenid
        FROM ob_property_access access
        INNER JOIN ob_property_ownerships ownership ON ownership.id = access.ownership_id
        WHERE access.id = ? LIMIT 1
    ]], { tonumber(accessId) })
    if not access or (tostring(access.owner_citizenid) ~= citizenid and not isAdmin(source)) then
        return { ok = false, error = 'forbidden' }
    end
    MySQL.query.await('DELETE FROM ob_property_access WHERE id = ?', { access.id })
    for playerSource, session in pairs(sessions) do
        if tonumber(session.ownershipId) == tonumber(access.ownership_id)
            and getCitizenId(playerSource) == tostring(access.citizenid)
        then
            forceSessionExit(playerSource)
        end
    end
    audit(citizenid, 'revoke_access', nil, access.citizenid, { ownershipId = access.ownership_id })
    return listAccess(source, access.ownership_id)
end

local function throttle(source, action)
    local now = GetGameTimer()
    local key = ('%s:%s'):format(source, action)
    local previous = actionCooldowns[key] or 0
    if now - previous < (Config.Purchase.actionCooldownMs or 900) then return false end
    actionCooldowns[key] = now
    return true
end

RegisterNetEvent('ob_housing:server:answerBell', function(requestId, accepted)
    local source = source
    requestId = trim(requestId)
    local request = bellRequests[requestId]
    if not request or request.ownerSource ~= source then return end

    clearBellRequest(requestId)
    if request.expiresAt < os.time() or GetPlayerPing(request.visitorSource) <= 0 then return end
    if accepted ~= true then
        TriggerClientEvent('ob_housing:client:bellResult', request.visitorSource, 'denied')
        return
    end

    local ownership = activeOwnership(request.ownershipId, request.propertyId)
    local ownerCitizenId = getCitizenId(source)
    local visitorCitizenId = getCitizenId(request.visitorSource)
    local property = getProperty(request.propertyId)
    if not ownership or not ownerCitizenId or tostring(ownership.owner_citizenid) ~= ownerCitizenId
        or not visitorCitizenId or visitorCitizenId ~= request.visitorCitizenId
        or not property or property.status ~= 'available'
        or not isNear(request.visitorSource, property.entrance, Config.Interaction.serverValidationDistance + 2.0)
    then
        TriggerClientEvent('ob_housing:client:bellResult', request.visitorSource, 'expired')
        return
    end

    bellSequence = bellSequence + 1
    local token = ('%s:%s:%s:%s'):format(request.visitorSource, request.ownershipId, os.time(), bellSequence)
    local inviteTimeout = boundedInteger(Config.Visitors.inviteTimeoutSeconds, 5, 60, 15)
    visitorInvites[token] = {
        visitorSource = request.visitorSource,
        visitorCitizenId = visitorCitizenId,
        propertyId = request.propertyId,
        ownershipId = request.ownershipId,
        expiresAt = os.time() + inviteTimeout
    }
    SetTimeout(inviteTimeout * 1000, function()
        local invite = visitorInvites[token]
        if invite and invite.expiresAt <= os.time() then visitorInvites[token] = nil end
    end)

    TriggerClientEvent('ob_housing:client:bellAccepted', request.visitorSource, {
        token = token,
        propertyId = request.propertyId,
        ownerName = playerDisplayName(source)
    })
    notify(source, 'A visita foi autorizada.', 'success')
end)

lib.callback.register('ob_housing:server:request', function(source, action, data)
    if not databaseReady then return { ok = false, error = 'database_initializing' } end
    action = trim(action)
    data = type(data) == 'table' and data or {}
    local citizenid = getCitizenId(source)
    if not citizenid then return { ok = false, error = 'player_not_loaded' } end

    if action == 'bootstrap' or action == 'refresh' then
        if Config.StarterApartment.autoGrant then ensureStarterApartment(citizenid) end
        local admin = isAdmin(source)
        local mode = data.mode == 'admin' and admin and 'admin' or data.mode == 'mine' and 'mine' or 'catalog'
        return {
            ok = true,
            mode = mode,
            isAdmin = admin,
            catalog = catalogProperties(),
            mine = playerProperties(citizenid),
            admin = admin and adminProperties() or {},
            presets = presetsForUi(),
            entrances = publicEntrances(),
            imageLimit = Config.Images.maxPerProperty,
            fallbackImage = Config.Images.fallback
        }
    end

    if not throttle(source, action) then return { ok = false, error = 'slow_down' } end
    if action == 'purchase' then return purchaseProperty(source, data.propertyId) end
    if action == 'saveProperty' then return saveProperty(source, data) end
    if action == 'archiveProperty' then return archiveProperty(source, data.propertyId) end
    if action == 'grantProperty' then
        if not isAdmin(source) then return { ok = false, error = 'forbidden' } end
        return grantProperty(data.citizenid, data.propertyId, {
            acquisition = data.acquisition or 'admin',
            durationDays = tonumber(data.durationDays),
            actor = citizenid
        })
    end
    if action == 'revokeProperty' then
        if not isAdmin(source) then return { ok = false, error = 'forbidden' } end
        return revokeProperty(data.citizenid, data.propertyId, data.reason or 'admin', citizenid)
    end
    if action == 'listOwners' then return listOwners(source, data.propertyId) end
    if action == 'listAccess' then return listAccess(source, data.ownershipId) end
    if action == 'grantAccess' then return grantAccess(source, data.ownershipId, data.citizenid, data.role) end
    if action == 'revokeAccess' then return revokeAccess(source, data.accessId) end
    if action == 'entranceOptions' then return entranceOptions(source, data.propertyId) end
    if action == 'ringBell' then return ringBell(source, data.propertyId, data.ownershipId) end
    if action == 'enter' then return enterProperty(source, data.propertyId, false, data.inviteToken) end
    if action == 'preview' then return enterProperty(source, data.propertyId, true) end
    if action == 'previewPreset' then return previewInterior(source, data.presetKey) end
    if action == 'exit' then return exitProperty(source) end
    if action == 'openStash' then return registerSessionStash(source) end
    return { ok = false, error = 'unknown_action' }
end)

local function registerInventoryHook()
    if inventoryHookRegistered or GetResourceState(Config.Resources.inventory) ~= 'started' then return end
    exports.ox_inventory:registerHook('openInventory', function(payload)
        local inventoryId = tostring(payload.inventoryId or '')
        if not inventoryId:match('^ob_housing_%d+$') then return end
        local session = sessions[tonumber(payload.source)]
        return session ~= nil
            and session.preview ~= true
            and (session.accessRole == 'owner' or session.accessRole == 'resident')
            and session.stashId == inventoryId
    end, {
        inventoryFilter = { '^ob_housing_%d+$' },
        typeFilter = { stash = true }
    })
    inventoryHookRegistered = true
end

local schema = {
    [[CREATE TABLE IF NOT EXISTS `ob_properties` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `property_key` VARCHAR(64) NOT NULL,
        `type` ENUM('apartment','house') NOT NULL DEFAULT 'house',
        `ownership_mode` ENUM('unique','instanced') NOT NULL DEFAULT 'unique',
        `label` VARCHAR(80) NOT NULL,
        `description` VARCHAR(500) NOT NULL DEFAULT '',
        `price` INT UNSIGNED NOT NULL DEFAULT 0,
        `payment_account` VARCHAR(20) NOT NULL DEFAULT 'bank',
        `purchasable` TINYINT(1) NOT NULL DEFAULT 1,
        `is_starter` TINYINT(1) NOT NULL DEFAULT 0,
        `is_listed` TINYINT(1) NOT NULL DEFAULT 1,
        `status` ENUM('available','disabled') NOT NULL DEFAULT 'available',
        `vip_tier` VARCHAR(40) DEFAULT NULL,
        `preset_key` VARCHAR(64) NOT NULL,
        `entrance` LONGTEXT NOT NULL,
        `interior` LONGTEXT NOT NULL,
        `gallery` LONGTEXT DEFAULT NULL,
        `stash_slots` SMALLINT UNSIGNED NOT NULL DEFAULT 30,
        `stash_weight` INT UNSIGNED NOT NULL DEFAULT 50000,
        `created_by` VARCHAR(64) DEFAULT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), UNIQUE KEY `ux_ob_properties_key` (`property_key`),
        KEY `ix_ob_properties_catalog` (`status`,`is_listed`,`type`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `ob_property_ownerships` (
        `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        `property_id` INT UNSIGNED NOT NULL,
        `citizenid` VARCHAR(64) NOT NULL,
        `acquisition` VARCHAR(24) NOT NULL DEFAULT 'admin',
        `expires_at` BIGINT DEFAULT NULL,
        `metadata` LONGTEXT DEFAULT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), UNIQUE KEY `ux_ob_property_owner` (`property_id`,`citizenid`),
        KEY `ix_ob_property_owner_citizen` (`citizenid`,`expires_at`),
        KEY `ix_ob_property_owner_property` (`property_id`,`expires_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `ob_property_access` (
        `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        `ownership_id` BIGINT UNSIGNED NOT NULL,
        `citizenid` VARCHAR(64) NOT NULL,
        `role` ENUM('resident','guest') NOT NULL DEFAULT 'resident',
        `granted_by` VARCHAR(64) NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), UNIQUE KEY `ux_ob_property_access` (`ownership_id`,`citizenid`),
        KEY `ix_ob_property_access_citizen` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `ob_property_audit` (
        `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        `actor` VARCHAR(64) NOT NULL,
        `action` VARCHAR(48) NOT NULL,
        `property_id` INT UNSIGNED DEFAULT NULL,
        `target_citizenid` VARCHAR(64) DEFAULT NULL,
        `details` LONGTEXT DEFAULT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `ix_ob_property_audit_property` (`property_id`,`created_at`),
        KEY `ix_ob_property_audit_target` (`target_citizenid`,`created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]
}

local function seedStarterApartment()
    local starter = Config.StarterApartment
    if not starter or starter.enabled == false then return end
    local interior = presetInterior(starter.interior)
    if not interior then
        print(('^1[%s] Interior inicial inexistente: %s^7'):format(RESOURCE, tostring(starter.interior)))
        return
    end
    MySQL.insert.await([[
        INSERT INTO ob_properties
            (property_key, type, ownership_mode, label, description, price, payment_account,
             purchasable, is_starter, is_listed, status, preset_key, entrance, interior,
             gallery, stash_slots, stash_weight, created_by)
        VALUES (?, 'apartment', 'instanced', ?, ?, 0, 'bank', 0, 1, 0, 'available',
                ?, ?, ?, '[]', ?, ?, 'system')
        ON DUPLICATE KEY UPDATE
            type = 'apartment', ownership_mode = 'instanced', label = VALUES(label),
            description = VALUES(description), price = 0, payment_account = 'bank',
            purchasable = 0, is_starter = 1, is_listed = 0, status = 'available',
            vip_tier = NULL, preset_key = VALUES(preset_key), entrance = VALUES(entrance),
            interior = VALUES(interior), stash_slots = VALUES(stash_slots),
            stash_weight = VALUES(stash_weight)
    ]], {
        starter.propertyKey,
        starter.label,
        starter.description,
        starter.interior,
        json.encode(coordinates(starter.entrance, true)),
        json.encode(interior),
        starter.stashSlots,
        starter.stashWeight
    })
    starterPropertyId = MySQL.scalar.await('SELECT id FROM ob_properties WHERE property_key = ? LIMIT 1', {
        starter.propertyKey
    })
end

MySQL.ready(function()
    for _, query in ipairs(schema) do MySQL.query.await(query) end
    seedStarterApartment()
    databaseReady = true
    registerInventoryHook()
    broadcastProperties()
    print(('^2[%s]^7 Banco pronto. Apartamento inicial: %s'):format(RESOURCE, starterPropertyId or 'desativado'))
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if not databaseReady or not Config.StarterApartment.autoGrant then return end
    local citizenid = player and player.PlayerData and player.PlayerData.citizenid
    if not citizenid then return end
    local result = ensureStarterApartment(tostring(citizenid))
    if result.ok then broadcastProperties(player.PlayerData.source) end
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local source = source
    if not databaseReady then return end
    local citizenid = getCitizenId(source)
    if citizenid and Config.StarterApartment.autoGrant then ensureStarterApartment(citizenid) end
    broadcastProperties(source)
end)

CreateThread(function()
    while true do
        Wait(math.max(15, tonumber(Config.Access and Config.Access.expiryCheckSeconds) or 60) * 1000)
        if databaseReady then
            local now = os.time()
            for key, expiresAt in pairs(bellCooldowns) do
                if expiresAt <= now then bellCooldowns[key] = nil end
            end
            for token, invite in pairs(visitorInvites) do
                if invite.expiresAt <= now then visitorInvites[token] = nil end
            end
            for playerSource, session in pairs(sessions) do
                if session.preview and session.expiresAt and session.expiresAt <= now then
                    forceSessionExit(playerSource, 'preview_expired')
                elseif not session.preview and GetPlayerPing(playerSource) > 0 then
                    local citizenid = getCitizenId(playerSource)
                    local hasAccess
                    if session.accessRole == 'visitor' then
                        hasAccess = activeOwnership(session.ownershipId, session.propertyId) ~= nil
                    else
                        hasAccess = citizenid and resolveAccess(citizenid, session.propertyId) ~= nil
                    end
                    if not citizenid or not hasAccess then
                        forceSessionExit(playerSource, 'access_ended')
                    end
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local playerSource = source
    sessions[playerSource] = nil
    for key in pairs(actionCooldowns) do
        if key:match(('^%s:'):format(playerSource)) then actionCooldowns[key] = nil end
    end
    for requestId, request in pairs(bellRequests) do
        if request.ownerSource == playerSource or request.visitorSource == playerSource then
            local otherSource = request.ownerSource == playerSource and request.visitorSource or nil
            clearBellRequest(requestId)
            if otherSource and GetPlayerPing(otherSource) > 0 then
                TriggerClientEvent('ob_housing:client:bellResult', otherSource, 'expired')
            end
        end
    end
    for token, invite in pairs(visitorInvites) do
        if invite.visitorSource == playerSource then visitorInvites[token] = nil end
    end
    for key in pairs(bellCooldowns) do
        if key:match(('^%s:'):format(playerSource)) then bellCooldowns[key] = nil end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == Config.Resources.inventory then
        SetTimeout(500, registerInventoryHook)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == Config.Resources.inventory then
        inventoryHookRegistered = false
        registeredStashes = {}
        return
    end
    if resourceName ~= RESOURCE then return end
    for source in pairs(sessions) do
        if GetPlayerPing(source) > 0 then
            SetPlayerRoutingBucket(source, 0)
            Player(source).state:set('inProperty', false, true)
            Player(source).state:set('inApartment', false, true)
        end
    end
end)

exports('GrantProperty', grantProperty)
exports('GrantVipProperty', function(citizenid, propertyKey, vip, durationDays, metadata)
    metadata = type(metadata) == 'table' and clone(metadata) or {}
    metadata.vip = trim(vip):lower()
    return grantProperty(citizenid, propertyKey, {
        acquisition = 'vip',
        durationDays = durationDays,
        metadata = metadata,
        actor = 'ob_vip'
    })
end)
exports('RevokeProperty', revokeProperty)
exports('HasProperty', function(citizenid, propertyIdentifier)
    local property = getProperty(propertyIdentifier)
    if not property then return false end
    return resolveAccess(trim(citizenid), property.id) ~= nil
end)
exports('GetPlayerProperties', function(citizenid)
    return databaseReady and playerProperties(trim(citizenid)) or {}
end)
exports('GetProperty', function(propertyIdentifier)
    return databaseReady and getProperty(propertyIdentifier) or nil
end)
exports('EnsureStarterApartment', ensureStarterApartment)
exports('OpenCatalog', function(source)
    TriggerClientEvent('ob_housing:client:open', tonumber(source), 'catalog')
end)
