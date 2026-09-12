local oxmysql = exports.oxmysql
local ticketsReady = false

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

local function trim(value, maxLength)
    value = tostring(value or "")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if maxLength and #value > maxLength then value = value:sub(1, maxLength) end
    return value ~= "" and value or nil
end

local function formatDate(timestamp)
    timestamp = tonumber(timestamp) or 0
    if timestamp <= 0 then return "-" end
    return os.date("%d/%m/%Y %H:%M:%S", timestamp)
end

local function sanitizeCodeBlock(value)
    return tostring(value or ""):gsub("```", "` ` `")
end

local function chunkText(text, maxLength)
    local chunks = {}
    text = tostring(text or "")
    maxLength = tonumber(maxLength) or 1800

    while #text > maxLength do
        local cut = maxLength
        local newline = text:sub(1, maxLength):match("^.*()\n")
        if newline and newline > 100 then cut = newline end
        chunks[#chunks + 1] = text:sub(1, cut)
        text = text:sub(cut + 1)
    end

    if text ~= "" then chunks[#chunks + 1] = text end
    return chunks
end

local function ensureTickets()
    if ticketsReady then return end
    query([[
        CREATE TABLE IF NOT EXISTS `magic_pause_tickets` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `passport` VARCHAR(80) NOT NULL,
            `player_name` VARCHAR(120) NOT NULL DEFAULT '',
            `category` VARCHAR(40) NOT NULL DEFAULT 'support',
            `title` VARCHAR(120) NOT NULL DEFAULT '',
            `status` VARCHAR(30) NOT NULL DEFAULT 'open',
            `assigned_passport` VARCHAR(80) DEFAULT NULL,
            `assigned_name` VARCHAR(120) DEFAULT NULL,
            `created_at` BIGINT NOT NULL,
            `updated_at` BIGINT NOT NULL,
            `closed_at` BIGINT DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `passport_status` (`passport`, `status`),
            KEY `status_updated` (`status`, `updated_at`),
            KEY `category_updated` (`category`, `updated_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    query([[
        CREATE TABLE IF NOT EXISTS `magic_pause_ticket_messages` (
            `id` BIGINT NOT NULL AUTO_INCREMENT,
            `ticket_id` INT NOT NULL,
            `passport` VARCHAR(80) NOT NULL,
            `player_name` VARCHAR(120) NOT NULL DEFAULT '',
            `staff` TINYINT(1) NOT NULL DEFAULT 0,
            `message` TEXT NOT NULL,
            `created_at` BIGINT NOT NULL,
            PRIMARY KEY (`id`),
            KEY `ticket_created` (`ticket_id`, `created_at`),
            CONSTRAINT `fk_magic_pause_ticket_messages`
                FOREIGN KEY (`ticket_id`) REFERENCES `magic_pause_tickets` (`id`)
                ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    ticketsReady = true
end

local function cfg()
    return Config.Tickets or {}
end

local function transcriptCfg()
    return cfg().transcript or {}
end

local function discordWebhook()
    local webhook = tostring(transcriptCfg().webhook or "")
    webhook = webhook:gsub("^%s+", ""):gsub("%s+$", "")
    return webhook ~= "" and webhook or nil
end

local function categories()
    return cfg().categories or {}
end

local function statuses()
    return cfg().statuses or {}
end

local function closedRetentionSeconds()
    local days = tonumber(cfg().closedRetentionDays) or 2
    if days < 1 then days = 2 end
    return math.floor(days * 86400)
end

local function purgeExpiredClosedTickets()
    local cutoff = now() - closedRetentionSeconds()
    update("DELETE FROM magic_pause_tickets WHERE status = 'closed' AND closed_at IS NOT NULL AND closed_at < ?", { cutoff })
end

local function categoryExists(category)
    category = tostring(category or "")
    for _, row in ipairs(categories()) do
        if tostring(row.id) == category then return true end
    end
    return false
end

local function statusExists(status)
    status = tostring(status or "")
    for _, row in ipairs(statuses()) do
        if tostring(row.id) == status then return true end
    end
    return false
end

local function ticketPayload(row, viewerIsStaff)
    if not row then return nil end
    local lastMessageStaff = row.last_message_staff
    if lastMessageStaff ~= nil then
        lastMessageStaff = lastMessageStaff == true or lastMessageStaff == 1 or lastMessageStaff == "1"
    end

    local unread = false
    if lastMessageStaff ~= nil and tostring(row.status or "") ~= "closed" then
        unread = viewerIsStaff and not lastMessageStaff or (not viewerIsStaff and lastMessageStaff)
    end

    return {
        id = tonumber(row.id),
        passport = row.passport,
        playerName = row.player_name or "",
        category = row.category or "support",
        title = row.title or "",
        status = row.status or "open",
        assignedPassport = row.assigned_passport,
        assignedName = row.assigned_name,
        createdAt = tonumber(row.created_at) or 0,
        updatedAt = tonumber(row.updated_at) or 0,
        closedAt = tonumber(row.closed_at) or nil,
        lastMessageStaff = lastMessageStaff,
        unread = unread
    }
end

local function messagePayload(row)
    if not row then return nil end
    return {
        id = tonumber(row.id),
        ticketId = tonumber(row.ticket_id),
        passport = row.passport,
        playerName = row.player_name or "",
        staff = row.staff == true or row.staff == 1 or row.staff == "1",
        message = row.message or "",
        createdAt = tonumber(row.created_at) or 0
    }
end

local function fetchMessages(ticketId)
    local messages = {}
    for _, row in ipairs(query("SELECT * FROM magic_pause_ticket_messages WHERE ticket_id = ? ORDER BY created_at ASC, id ASC", { ticketId })) do
        messages[#messages + 1] = messagePayload(row)
    end
    return messages
end

local function buildTranscript(ticket, messages, staffName)
    local lines = {
        ("Ticket #%s - %s"):format(ticket.id or "-", ticket.title or "-"),
        ("Category: %s"):format(ticket.category or "-"),
        ("Status: %s"):format(ticket.status or "-"),
        ("Created by: %s (%s)"):format(ticket.player_name or "-", ticket.passport or "-"),
        ("Assigned to: %s"):format(ticket.assigned_name or "-"),
        ("Created at: %s"):format(formatDate(ticket.created_at)),
        ("Updated at: %s"):format(formatDate(ticket.updated_at)),
        ("Transcripted by: %s"):format(staffName or "-"),
        "",
        "Messages:"
    }

    if #messages == 0 then
        lines[#lines + 1] = "- No messages registered."
    else
        for _, message in ipairs(messages) do
            local role = message.staff and "Staff" or "Player"
            lines[#lines + 1] = ("[%s] %s - %s: %s"):format(
                formatDate(message.createdAt),
                role,
                message.playerName or "-",
                sanitizeCodeBlock(message.message)
            )
        end
    end

    return table.concat(lines, "\n")
end

local function sendDiscordPayload(payload, cb)
    local webhook = discordWebhook()
    if not webhook then return cb(false, "webhook") end

    PerformHttpRequest(webhook, function(status)
        status = tonumber(status) or 0
        cb(status >= 200 and status < 300, status)
    end, "POST", json.encode(payload), { ["Content-Type"] = "application/json" })
end

local function sendTranscriptToDiscord(ticket, messages, staffName, cb)
    local transcript = transcriptCfg()
    local username = tostring(transcript.username or "Obscuria Tickets")
    local avatar = tostring(transcript.avatar or "")
    local text = buildTranscript(ticket, messages, staffName)
    local chunks = chunkText(text, 1750)

    local summary = {
        username = username,
        embeds = {{
            title = ("Ticket #%s Transcript"):format(ticket.id or "-"),
            color = 5197055,
            fields = {
                { name = "Subject", value = tostring(ticket.title or "-"):sub(1, 1024), inline = false },
                { name = "Player", value = ("%s (%s)"):format(ticket.player_name or "-", ticket.passport or "-"), inline = true },
                { name = "Assigned to", value = tostring(ticket.assigned_name or "-"), inline = true },
                { name = "Transcripted by", value = tostring(staffName or "-"), inline = true },
                { name = "Created at", value = formatDate(ticket.created_at), inline = true },
                { name = "Messages", value = tostring(#messages), inline = true }
            },
            footer = { text = "Obscuria" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }

    if avatar ~= "" then summary.avatar_url = avatar end

    sendDiscordPayload(summary, function(ok, reason)
        if not ok then return cb(false, reason) end

        local index = 1
        local function sendNext()
            local chunk = chunks[index]
            if not chunk then return cb(true) end

            local payload = {
                username = username,
                content = ("```txt\n%s\n```"):format(chunk)
            }
            if avatar ~= "" then payload.avatar_url = avatar end

            sendDiscordPayload(payload, function(chunkOk, chunkReason)
                if not chunkOk then return cb(false, chunkReason) end
                index = index + 1
                sendNext()
            end)
        end

        sendNext()
    end)
end

local function ticketVisible(src, ticket)
    if not ticket then return false end
    if Utils.isStaff(src) then return true end
    return tostring(ticket.passport or "") == tostring(Utils.getPassport(src))
end

local function fetchTicket(src, id)
    ensureTickets()
    local ticket = single("SELECT * FROM magic_pause_tickets WHERE id = ? LIMIT 1", { tonumber(id) or 0 })
    if not ticketVisible(src, ticket) then return nil end
    return ticket
end

local function buildPayload(src, selectedId)
    ensureTickets()
    purgeExpiredClosedTickets()
    local isStaff = Utils.isStaff(src)
    local limit = math.max(1, math.min(tonumber(cfg().listLimit) or 80, 200))
    local rows

    if isStaff then
        rows = query(([[
            SELECT t.*, lm.staff AS last_message_staff
            FROM magic_pause_tickets t
            LEFT JOIN (
                SELECT m.ticket_id, m.staff
                FROM magic_pause_ticket_messages m
                INNER JOIN (
                    SELECT ticket_id, MAX(id) AS id
                    FROM magic_pause_ticket_messages
                    GROUP BY ticket_id
                ) latest_message ON latest_message.id = m.id
            ) lm ON lm.ticket_id = t.id
            ORDER BY
                CASE WHEN t.status != 'closed' AND COALESCE(lm.staff, 1) = 0 THEN 0 ELSE 1 END,
                FIELD(t.status, 'open', 'waiting', 'answered', 'closed'),
                t.updated_at DESC
            LIMIT %d
        ]]):format(limit))
    else
        rows = query(([[
            SELECT t.*, lm.staff AS last_message_staff
            FROM magic_pause_tickets t
            LEFT JOIN (
                SELECT m.ticket_id, m.staff
                FROM magic_pause_ticket_messages m
                INNER JOIN (
                    SELECT ticket_id, MAX(id) AS id
                    FROM magic_pause_ticket_messages
                    GROUP BY ticket_id
                ) latest_message ON latest_message.id = m.id
            ) lm ON lm.ticket_id = t.id
            WHERE t.passport = ?
            ORDER BY
                CASE WHEN t.status != 'closed' AND COALESCE(lm.staff, 0) = 1 THEN 0 ELSE 1 END,
                t.updated_at DESC
            LIMIT %d
        ]]):format(limit), { Utils.getPassport(src) })
    end

    local tickets = {}
    for _, row in ipairs(rows) do
        tickets[#tickets + 1] = ticketPayload(row, isStaff)
    end

    local selected = nil
    selectedId = tonumber(selectedId)
    if selectedId then
        selected = fetchTicket(src, selectedId)
    end
    if not selected and rows[1] then selected = rows[1] end

    local messages = {}
    if selected then
        messages = fetchMessages(selected.id)
    end

    return {
        ok = true,
        isStaff = isStaff,
        profile = {
            passport = Utils.getPassport(src),
            name = Utils.getName(src),
            coins = Utils.getCoins(src)
        },
        locale = Utils.localePayload(),
        config = {
            categories = categories(),
            statuses = statuses(),
            maxOpenPerPlayer = tonumber(cfg().maxOpenPerPlayer) or 3,
            maxTitleLength = tonumber(cfg().maxTitleLength) or 80,
            maxMessageLength = tonumber(cfg().maxMessageLength) or 900
        },
        tickets = tickets,
        selectedTicket = ticketPayload(selected, isStaff),
        messages = messages
    }
end

local function respond(src, token, ok, message, extra)
    local payload = extra or {}
    payload.ok = ok == true
    payload.message = message or Utils.t(payload.ok and "common.success" or "common.error")
    payload.payload = buildPayload(src, payload.selectedTicketId)
    TriggerClientEvent("MagicPause:client:serverResponse", src, token, payload)
end

RegisterNetEvent("MagicPause:server:getTickets", function(token, data)
    local src = source
    TriggerClientEvent("MagicPause:client:serverResponse", src, token, buildPayload(src, data and data.ticketId))
end)

RegisterNetEvent("MagicPause:server:createTicket", function(token, data)
    local src = source
    ensureTickets()

    local maxTitle = tonumber(cfg().maxTitleLength) or 80
    local maxMessage = tonumber(cfg().maxMessageLength) or 900
    local category = trim(data and data.category, 40) or "support"
    local title = trim(data and data.title, maxTitle)
    local message = trim(data and data.message, maxMessage)

    if not categoryExists(category) then category = "support" end
    if not title then return respond(src, token, false, Utils.t("tickets.errors.title")) end
    if not message then return respond(src, token, false, Utils.t("tickets.errors.message")) end

    local passport = Utils.getPassport(src)
    local maxOpen = tonumber(cfg().maxOpenPerPlayer) or 3
    local opened = single("SELECT COUNT(*) as count FROM magic_pause_tickets WHERE passport = ? AND status != 'closed'", { passport }) or {}
    if maxOpen > 0 and (tonumber(opened.count) or 0) >= maxOpen then
        return respond(src, token, false, Utils.t("tickets.errors.limit", { count = maxOpen }))
    end

    local ts = now()
    local ticketId = insert([[
        INSERT INTO magic_pause_tickets(passport, player_name, category, title, status, created_at, updated_at)
        VALUES(?, ?, ?, ?, 'open', ?, ?)
    ]], { passport, Utils.getName(src), category, title, ts, ts })

    insert([[
        INSERT INTO magic_pause_ticket_messages(ticket_id, passport, player_name, staff, message, created_at)
        VALUES(?, ?, ?, 0, ?, ?)
    ]], { ticketId, passport, Utils.getName(src), message, ts })

    respond(src, token, true, Utils.t("tickets.created"), { selectedTicketId = ticketId })
end)

RegisterNetEvent("MagicPause:server:replyTicket", function(token, data)
    local src = source
    ensureTickets()

    local ticket = fetchTicket(src, data and data.ticketId)
    if not ticket then return respond(src, token, false, Utils.t("tickets.errors.notFound")) end
    if tostring(ticket.status or "") == "closed" then return respond(src, token, false, Utils.t("tickets.errors.closed")) end

    local message = trim(data and data.message, tonumber(cfg().maxMessageLength) or 900)
    if not message then return respond(src, token, false, Utils.t("tickets.errors.message")) end

    local isStaff = Utils.isStaff(src)
    local status = isStaff and "answered" or "waiting"
    local ts = now()
    insert([[
        INSERT INTO magic_pause_ticket_messages(ticket_id, passport, player_name, staff, message, created_at)
        VALUES(?, ?, ?, ?, ?, ?)
    ]], { ticket.id, Utils.getPassport(src), Utils.getName(src), isStaff and 1 or 0, message, ts })

    update("UPDATE magic_pause_tickets SET status = ?, updated_at = ? WHERE id = ?", { status, ts, ticket.id })
    respond(src, token, true, Utils.t("tickets.replied"), { selectedTicketId = ticket.id })
end)

RegisterNetEvent("MagicPause:server:setTicketStatus", function(token, data)
    local src = source
    if not Utils.isStaff(src) then return respond(src, token, false, Utils.t("common.noPermission")) end

    local ticket = fetchTicket(src, data and data.ticketId)
    if not ticket then return respond(src, token, false, Utils.t("tickets.errors.notFound")) end

    local status = trim(data and data.status, 30) or "open"
    if not statusExists(status) then return respond(src, token, false, Utils.t("tickets.errors.status")) end

    local ts = now()
    if status == "closed" then
        update("UPDATE magic_pause_tickets SET status = ?, updated_at = ?, closed_at = ? WHERE id = ?", {
            status,
            ts,
            ts,
            ticket.id
        })
    else
        update("UPDATE magic_pause_tickets SET status = ?, updated_at = ?, closed_at = NULL WHERE id = ?", {
            status,
            ts,
            ticket.id
        })
    end

    respond(src, token, true, Utils.t("tickets.statusChanged"), { selectedTicketId = ticket.id })
end)

RegisterNetEvent("MagicPause:server:claimTicket", function(token, data)
    local src = source
    if not Utils.isStaff(src) then return respond(src, token, false, Utils.t("common.noPermission")) end

    local ticket = fetchTicket(src, data and data.ticketId)
    if not ticket then return respond(src, token, false, Utils.t("tickets.errors.notFound")) end

    local ts = now()
    local staffPassport = Utils.getPassport(src)
    local staffName = Utils.getName(src)
    local previousAssigned = tostring(ticket.assigned_passport or "")
    update([[
        UPDATE magic_pause_tickets
        SET assigned_passport = ?, assigned_name = ?, updated_at = ?
        WHERE id = ?
    ]], { staffPassport, staffName, ts, ticket.id })

    if previousAssigned ~= tostring(staffPassport or "") then
        insert([[
            INSERT INTO magic_pause_ticket_messages(ticket_id, passport, player_name, staff, message, created_at)
            VALUES(?, ?, ?, 1, ?, ?)
        ]], {
            ticket.id,
            staffPassport,
            staffName,
            Utils.t("tickets.claimedBy", { name = staffName }),
            ts
        })
    end

    respond(src, token, true, Utils.t("tickets.claimed"), { selectedTicketId = ticket.id })
end)

RegisterNetEvent("MagicPause:server:transcriptTicket", function(token, data)
    local src = source
    if not Utils.isStaff(src) then return respond(src, token, false, Utils.t("common.noPermission")) end

    ensureTickets()

    local ticket = fetchTicket(src, data and data.ticketId)
    if not ticket then return respond(src, token, false, Utils.t("tickets.errors.notFound")) end
    if not discordWebhook() then return respond(src, token, false, Utils.t("tickets.errors.transcriptWebhook")) end

    local messages = fetchMessages(ticket.id)
    local staffName = Utils.getName(src)

    sendTranscriptToDiscord(ticket, messages, staffName, function(ok)
        if not ok then
            return respond(src, token, false, Utils.t("tickets.errors.transcriptFailed"), { selectedTicketId = ticket.id })
        end

        if transcriptCfg().deleteAfterSend ~= false then
            update("DELETE FROM magic_pause_tickets WHERE id = ?", { ticket.id })
        end

        respond(src, token, true, Utils.t("tickets.transcriptSent"), {})
    end)
end)
