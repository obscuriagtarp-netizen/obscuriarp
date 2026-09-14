local RESOURCE = GetCurrentResourceName()
local ready = false
local transferLocks = {}
local requestTimes = {}

local function log(message, ...)
    if not Config.Debug then return end
    print(('^5[%s]^7 %s'):format(RESOURCE, message:format(...)))
end

local function trim(value)
    return tostring(value or ''):gsub('[%z\1-\31\127]', ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function limitedText(value, maximum)
    return trim(value):sub(1, maximum)
end

local function characterName(charinfo, fallback)
    if type(charinfo) == 'string' then
        local ok, decoded = pcall(json.decode, charinfo)
        charinfo = ok and decoded or nil
    end
    charinfo = type(charinfo) == 'table' and charinfo or {}
    local name = trim(('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''))
    return name ~= '' and name or trim(fallback or 'Cidadao')
end

local function onlinePlayer(source)
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(tonumber(source)) end)
    return ok and player or nil
end

local function onlinePlayerByCitizenId(citizenid)
    local ok, player = pcall(function() return exports.qbx_core:GetPlayerByCitizenId(tostring(citizenid)) end)
    return ok and player or nil
end

local function identityFromPlayer(player)
    local data = player and player.PlayerData
    if not data or not data.citizenid then return nil end
    return {
        citizenid = tostring(data.citizenid),
        name = characterName(data.charinfo, data.name),
        online = player.Offline ~= true,
        source = player.Offline ~= true and tonumber(data.source) or nil,
    }
end

local function identityByCitizenId(citizenid)
    citizenid = limitedText(citizenid, 64)
    if citizenid == '' then return nil end

    local online = onlinePlayerByCitizenId(citizenid)
    if online then return identityFromPlayer(online) end

    local row = MySQL.single.await('SELECT citizenid, name, charinfo FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
    if not row then return nil end
    return {
        citizenid = tostring(row.citizenid),
        name = characterName(row.charinfo, row.name),
        online = false,
        source = nil,
    }
end

local function resolveRecipient(value)
    local key = limitedText(value, 64)
    if key == '' then return nil end

    if key:match('^%d+$') then
        local player = onlinePlayer(tonumber(key))
        if player then return identityFromPlayer(player) end
    end

    return identityByCitizenId(key)
end

local function senderContext(source)
    local player = onlinePlayer(source)
    local identity = identityFromPlayer(player)
    if not player or not identity then return nil end
    identity.balance = math.max(0, math.floor(tonumber(player.PlayerData.money and player.PlayerData.money.bank) or 0))
    return player, identity
end

local function transferId(source)
    return ('PIX-%s-%s-%06d'):format(os.time(), tostring(source), math.random(0, 999999))
end

local function receipt(row, balance)
    return {
        id = tostring(row.transfer_id),
        amount = tonumber(row.amount) or 0,
        description = tostring(row.description or ''),
        recipient = {
            citizenid = tostring(row.recipient_citizenid),
            name = tostring(row.recipient_name),
        },
        sender = {
            citizenid = tostring(row.sender_citizenid),
            name = tostring(row.sender_name),
        },
        createdAt = tonumber(row.created_at_unix) or os.time(),
        balance = balance,
    }
end

local function favoriteRows(citizenid)
    local rows = MySQL.query.await([[
        SELECT recipient_citizenid, recipient_name, nickname, UNIX_TIMESTAMP(created_at) AS created_at_unix
        FROM ob_bank_pix_favorites
        WHERE owner_citizenid = ?
        ORDER BY nickname <> '' DESC, nickname ASC, recipient_name ASC
    ]], { citizenid }) or {}

    local result = {}
    for _, row in ipairs(rows) do
        result[#result + 1] = {
            citizenid = tostring(row.recipient_citizenid),
            name = tostring(row.recipient_name),
            nickname = tostring(row.nickname or ''),
            createdAt = tonumber(row.created_at_unix),
        }
    end
    return result
end

local function pixHistory(citizenid)
    local limit = math.max(10, math.min(150, tonumber(Config.HistoryLimit) or 60))
    local rows = MySQL.query.await(([=[
        SELECT transfer_id, sender_citizenid, sender_name, recipient_citizenid, recipient_name,
               amount, description, UNIX_TIMESTAMP(created_at) AS created_at_unix
        FROM ob_bank_pix
        WHERE status = 'completed' AND (sender_citizenid = ? OR recipient_citizenid = ?)
        ORDER BY id DESC
        LIMIT %d
    ]=]):format(limit), { citizenid, citizenid }) or {}

    local result, known = {}, {}
    for _, row in ipairs(rows) do
        local outgoing = tostring(row.sender_citizenid) == citizenid
        local id = tostring(row.transfer_id)
        known[id] = true
        result[#result + 1] = {
            id = id,
            kind = 'pix',
            direction = outgoing and 'out' or 'in',
            title = outgoing and 'Pix enviado' or 'Pix recebido',
            counterparty = outgoing and tostring(row.recipient_name) or tostring(row.sender_name),
            counterpartyCitizenId = outgoing and tostring(row.recipient_citizenid) or tostring(row.sender_citizenid),
            amount = tonumber(row.amount) or 0,
            description = tostring(row.description or ''),
            createdAt = tonumber(row.created_at_unix) or os.time(),
        }
    end

    local legacyOk, legacy = pcall(MySQL.single.await,
        'SELECT transactions FROM player_transactions WHERE id = ? LIMIT 1', { citizenid })
    if not legacyOk then legacy = nil end
    if legacy and legacy.transactions then
        local ok, transactions = pcall(json.decode, legacy.transactions)
        if ok and type(transactions) == 'table' then
            for _, item in ipairs(transactions) do
                local id = tostring(item.trans_id or '')
                if id == '' then id = ('bank:%s:%s'):format(tostring(item.time or 0), tostring(item.amount or 0)) end
                if not known[id] then
                    local incoming = tostring(item.trans_type or '') == 'deposit'
                    result[#result + 1] = {
                        id = id,
                        kind = 'bank',
                        direction = incoming and 'in' or 'out',
                        title = tostring(item.title or (incoming and 'Entrada' or 'Saida')),
                        counterparty = tostring(incoming and item.issuer or item.receiver or 'Banco'),
                        amount = math.abs(tonumber(item.amount) or 0),
                        description = tostring(item.message or ''),
                        createdAt = tonumber(item.time) or 0,
                    }
                    known[id] = true
                end
            end
        end
    end

    table.sort(result, function(a, b) return a.createdAt > b.createdAt end)
    while #result > limit do table.remove(result) end
    return result
end

local function recentRecipients(citizenid)
    local scanLimit = math.max(20, (tonumber(Config.RecentLimit) or 8) * 5)
    local rows = MySQL.query.await(([=[
        SELECT recipient_citizenid, recipient_name, UNIX_TIMESTAMP(created_at) AS created_at_unix
        FROM ob_bank_pix
        WHERE sender_citizenid = ? AND status = 'completed'
        ORDER BY id DESC
        LIMIT %d
    ]=]):format(scanLimit), { citizenid }) or {}

    local result, seen = {}, {}
    for _, row in ipairs(rows) do
        local target = tostring(row.recipient_citizenid)
        if not seen[target] then
            seen[target] = true
            result[#result + 1] = {
                citizenid = target,
                name = tostring(row.recipient_name),
                createdAt = tonumber(row.created_at_unix),
            }
            if #result >= (tonumber(Config.RecentLimit) or 8) then break end
        end
    end
    return result
end

local function dashboard(source)
    local _, identity = senderContext(source)
    if not identity then return { ok = false, error = 'Personagem nao encontrado.' } end

    local credit = ObBankCredit and ObBankCredit.GetState(source, false) or nil

    local unresolved = MySQL.scalar.await([[
        SELECT COUNT(*) FROM ob_bank_pix
        WHERE sender_citizenid = ? AND status IN ('processing', 'debited', 'manual_review')
    ]], { identity.citizenid }) or 0

    return {
        ok = true,
        data = {
            account = identity,
            history = pixHistory(identity.citizenid),
            recent = recentRecipients(identity.citizenid),
            favorites = favoriteRows(identity.citizenid),
            credit = credit,
            transferBlocked = tonumber(unresolved) > 0 or (credit and credit.blocked == true),
        }
    }
end

local function transfer(source, payload)
    local player, sender = senderContext(source)
    if not player or not sender then return { ok = false, error = 'Personagem nao encontrado.' } end
    if transferLocks[sender.citizenid] then return { ok = false, error = 'Ja existe um Pix sendo processado.' } end

    if ObBankCredit and ObBankCredit.IsBlocked(source) then
        return { ok = false, error = 'Sua conta esta bloqueada. Quite a fatura do cartao para liberar as movimentacoes.' }
    end

    transferLocks[sender.citizenid] = true
    local succeeded, response = xpcall(function()
        payload = type(payload) == 'table' and payload or {}
        local requestId = limitedText(payload.requestId, 64)
        if not requestId:match('^[%w%-_:]+$') or #requestId < 16 then
            return { ok = false, error = 'Identificador da operacao invalido.' }
        end

        local amountNumber = tonumber(payload.amount)
        local amount = amountNumber and math.floor(amountNumber) or 0
        if not amountNumber or amountNumber ~= amount then return { ok = false, error = 'Informe um valor inteiro valido.' } end
        if amount < Config.Transfer.minimum or amount > Config.Transfer.maximum then
            return { ok = false, error = ('O Pix deve ficar entre $%s e $%s.'):format(Config.Transfer.minimum, Config.Transfer.maximum) }
        end

        local recipient = resolveRecipient(payload.target)
        if not recipient then return { ok = false, error = 'Destinatario nao encontrado.' } end
        if recipient.citizenid == sender.citizenid then return { ok = false, error = 'Voce nao pode enviar um Pix para si mesmo.' } end

        local previous = MySQL.single.await([[
            SELECT *, UNIX_TIMESTAMP(created_at) AS created_at_unix
            FROM ob_bank_pix WHERE sender_citizenid = ? AND request_id = ? LIMIT 1
        ]], { sender.citizenid, requestId })
        if previous then
            if previous.status == 'completed' then
                return { ok = true, data = { receipt = receipt(previous, sender.balance), duplicate = true } }
            end
            return { ok = false, error = previous.status == 'manual_review'
                and 'Este Pix esta em analise para evitar cobranca duplicada.'
                or 'Este Pix ja esta sendo processado.' }
        end

        local unresolved = tonumber(MySQL.scalar.await([[
            SELECT COUNT(*) FROM ob_bank_pix
            WHERE sender_citizenid = ? AND status IN ('processing', 'debited', 'manual_review')
        ]], { sender.citizenid })) or 0
        if unresolved > 0 then
            return { ok = false, error = 'Existe um Pix anterior em analise. Aguarde a equipe concluir antes de tentar novamente.' }
        end

        local description = limitedText(payload.description, tonumber(Config.Transfer.descriptionMaxLength) or 80)
        local id = transferId(source)
        local inserted, insertId = pcall(MySQL.insert.await, [[
            INSERT INTO ob_bank_pix
                (transfer_id, request_id, sender_citizenid, sender_name, recipient_citizenid,
                 recipient_name, amount, description, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'processing')
        ]], { id, requestId, sender.citizenid, sender.name, recipient.citizenid, recipient.name, amount, description })
        if not inserted or not insertId then
            local duplicate = MySQL.single.await([[
                SELECT *, UNIX_TIMESTAMP(created_at) AS created_at_unix
                FROM ob_bank_pix WHERE sender_citizenid = ? AND request_id = ? LIMIT 1
            ]], { sender.citizenid, requestId })
            if duplicate and duplicate.status == 'completed' then
                return { ok = true, data = { receipt = receipt(duplicate, sender.balance), duplicate = true } }
            end
            return { ok = false, error = 'Nao foi possivel reservar esta transferencia.' }
        end

        local reason = ('ob_bank_pix:%s'):format(id)
        if exports.qbx_core:RemoveMoney(source, 'bank', amount, reason .. ':debit') ~= true then
            MySQL.update.await("UPDATE ob_bank_pix SET status = 'failed', failure_reason = ? WHERE id = ?", {
                'saldo insuficiente', insertId
            })
            return { ok = false, error = 'Saldo insuficiente para concluir o Pix.' }
        end

        local debitMarked = MySQL.update.await("UPDATE ob_bank_pix SET status = 'debited' WHERE id = ? AND status = 'processing'", { insertId }) or 0
        if debitMarked < 1 then
            exports.qbx_core:AddMoney(source, 'bank', amount, reason .. ':reservation_refund')
            return { ok = false, error = 'A transferencia foi cancelada e o valor devolvido.' }
        end

        if exports.qbx_core:AddMoney(recipient.citizenid, 'bank', amount, reason .. ':credit') ~= true then
            local refunded = exports.qbx_core:AddMoney(source, 'bank', amount, reason .. ':delivery_refund') == true
            MySQL.update.await("UPDATE ob_bank_pix SET status = ?, failure_reason = ? WHERE id = ?", {
                refunded and 'failed' or 'manual_review',
                refunded and 'falha ao creditar; valor devolvido' or 'falha ao creditar e ao devolver',
                insertId
            })
            return { ok = false, error = refunded
                and 'Nao foi possivel creditar o destinatario. O valor foi devolvido.'
                or 'A operacao entrou em analise. Nao tente novamente agora.' }
        end

        local completed = 0
        for _ = 1, 3 do
            local ok, affected = pcall(MySQL.update.await, [[
                UPDATE ob_bank_pix SET status = 'completed', completed_at = CURRENT_TIMESTAMP, failure_reason = NULL
                WHERE id = ? AND status = 'debited'
            ]], { insertId })
            if ok and (tonumber(affected) or 0) > 0 then completed = affected break end
            Wait(50)
        end
        if completed == 0 then
            print(('^1[%s] Pix %s foi creditado, mas o comprovante requer revisao manual.^7'):format(RESOURCE, id))
        end

        if GetResourceState('Renewed-Banking') == 'started' then
            pcall(function()
                exports['Renewed-Banking']:handleTransaction(sender.citizenid, 'Pix enviado', amount,
                    description ~= '' and description or 'Transferencia Pix', sender.name, recipient.name, 'withdraw', id)
                exports['Renewed-Banking']:handleTransaction(recipient.citizenid, 'Pix recebido', amount,
                    description ~= '' and description or 'Transferencia Pix', sender.name, recipient.name, 'deposit', id)
            end)
        end

        local targetPlayer = onlinePlayerByCitizenId(recipient.citizenid)
        if targetPlayer and targetPlayer.PlayerData.source then
            exports.qbx_core:Notify(targetPlayer.PlayerData.source,
                ('Voce recebeu um Pix de $%s de %s.'):format(amount, sender.name), 'success', 6000)
        end

        local row = {
            transfer_id = id,
            sender_citizenid = sender.citizenid,
            sender_name = sender.name,
            recipient_citizenid = recipient.citizenid,
            recipient_name = recipient.name,
            amount = amount,
            description = description,
            created_at_unix = os.time(),
        }
        local newBalance = math.max(0, sender.balance - amount)
        return { ok = true, data = { receipt = receipt(row, newBalance), requiresReview = completed == 0 } }
    end, debug.traceback)

    transferLocks[sender.citizenid] = nil
    if not succeeded then
        print(('^1[%s] Falha inesperada no Pix de %s: %s^7'):format(RESOURCE, sender.citizenid, tostring(response)))
        return { ok = false, error = 'O Pix nao foi concluido. Verifique o saldo antes de tentar novamente.' }
    end
    return response
end

local function resolveAction(source, payload)
    local _, sender = senderContext(source)
    if not sender then return { ok = false, error = 'Personagem nao encontrado.' } end
    local recipient = resolveRecipient(type(payload) == 'table' and payload.target or nil)
    if not recipient then return { ok = false, error = 'Destinatario nao encontrado.' } end
    if recipient.citizenid == sender.citizenid then return { ok = false, error = 'Voce nao pode enviar para si mesmo.' } end
    return { ok = true, data = { recipient = recipient } }
end

local function saveFavorite(source, payload)
    local _, sender = senderContext(source)
    if not sender then return { ok = false, error = 'Personagem nao encontrado.' } end
    local recipient = resolveRecipient(type(payload) == 'table' and payload.target or nil)
    if not recipient then return { ok = false, error = 'Destinatario nao encontrado.' } end
    if recipient.citizenid == sender.citizenid then return { ok = false, error = 'Voce nao pode se favoritar.' } end

    local exists = MySQL.scalar.await([[
        SELECT 1 FROM ob_bank_pix_favorites WHERE owner_citizenid = ? AND recipient_citizenid = ? LIMIT 1
    ]], { sender.citizenid, recipient.citizenid })
    if not exists then
        local total = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM ob_bank_pix_favorites WHERE owner_citizenid = ?', { sender.citizenid })) or 0
        if total >= (tonumber(Config.FavoritesLimit) or 20) then
            return { ok = false, error = 'Limite de favoritos atingido.' }
        end
    end

    local nickname = limitedText(type(payload) == 'table' and payload.nickname or '', 40)
    MySQL.query.await([[
        INSERT INTO ob_bank_pix_favorites (owner_citizenid, recipient_citizenid, recipient_name, nickname)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE recipient_name = VALUES(recipient_name), nickname = VALUES(nickname)
    ]], { sender.citizenid, recipient.citizenid, recipient.name, nickname })
    return { ok = true, data = { favorites = favoriteRows(sender.citizenid) } }
end

local function deleteFavorite(source, payload)
    local _, sender = senderContext(source)
    if not sender then return { ok = false, error = 'Personagem nao encontrado.' } end
    local citizenid = limitedText(type(payload) == 'table' and payload.citizenid or '', 64)
    if citizenid == '' then return { ok = false, error = 'Favorito invalido.' } end
    MySQL.update.await('DELETE FROM ob_bank_pix_favorites WHERE owner_citizenid = ? AND recipient_citizenid = ?', {
        sender.citizenid, citizenid
    })
    return { ok = true, data = { favorites = favoriteRows(sender.citizenid) } }
end

local function creditState(source)
    if not ObBankCredit then return { ok = false, error = 'Credito indisponivel.' } end
    local state, err = ObBankCredit.GetState(source, true)
    return state and { ok = true, data = state } or { ok = false, error = err or 'Credito indisponivel.' }
end

local function payCredit(source, payload)
    if not ObBankCredit then return { ok = false, error = 'Credito indisponivel.' } end
    payload = type(payload) == 'table' and payload or {}
    local requestId = limitedText(payload.requestId, 96)
    if not requestId:match('^[%w%-_:]+$') or #requestId < 16 then
        return { ok = false, error = 'Identificador do pagamento invalido.' }
    end
    local result, err = ObBankCredit.Pay(source, payload.amount, requestId)
    return result and { ok = true, data = result } or { ok = false, error = err or 'Pagamento nao concluido.' }
end

local handlers = {
    bootstrap = function(source) return dashboard(source) end,
    resolve = resolveAction,
    transfer = transfer,
    favorite_save = saveFavorite,
    favorite_delete = deleteFavorite,
    credit_state = creditState,
    credit_pay = payCredit,
}

RegisterNetEvent('ob_bank:server:request', function(token, action, payload)
    local source = source
    token = limitedText(token, 96)
    action = limitedText(action, 32)
    if token == '' then return end

    local function respond(result)
        TriggerClientEvent('ob_bank:client:response', source, token, result)
    end
    if not ready then return respond({ ok = false, error = 'O banco ainda esta inicializando.' }) end

    local handler = handlers[action]
    if not handler then return respond({ ok = false, error = 'Operacao bancaria invalida.' }) end

    local current = GetGameTimer()
    local interval = action == 'transfer' and (tonumber(Config.Transfer.cooldownMs) or 1500) or 150
    requestTimes[source] = requestTimes[source] or {}
    local previous = requestTimes[source][action] or 0
    if previous > 0 and current - previous < interval then
        return respond({ ok = false, error = 'Aguarde um instante antes de tentar novamente.' })
    end
    requestTimes[source][action] = current

    local ok, result = xpcall(handler, debug.traceback, source, payload)
    if not ok then
        print(('^1[%s] Erro na operacao %s: %s^7'):format(RESOURCE, action, tostring(result)))
        return respond({ ok = false, error = 'Nao foi possivel concluir a operacao.' })
    end
    respond(type(result) == 'table' and result or { ok = false, error = 'Resposta bancaria invalida.' })
end)

AddEventHandler('playerDropped', function()
    requestTimes[source] = nil
end)

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ob_bank_pix (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            transfer_id VARCHAR(64) NOT NULL,
            request_id VARCHAR(64) NOT NULL,
            sender_citizenid VARCHAR(64) NOT NULL,
            sender_name VARCHAR(120) NOT NULL,
            recipient_citizenid VARCHAR(64) NOT NULL,
            recipient_name VARCHAR(120) NOT NULL,
            amount BIGINT UNSIGNED NOT NULL,
            description VARCHAR(80) NOT NULL DEFAULT '',
            status VARCHAR(24) NOT NULL DEFAULT 'processing',
            failure_reason VARCHAR(255) DEFAULT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            completed_at TIMESTAMP NULL DEFAULT NULL,
            PRIMARY KEY (id),
            UNIQUE KEY uq_ob_bank_pix_transfer (transfer_id),
            UNIQUE KEY uq_ob_bank_pix_request (sender_citizenid, request_id),
            KEY idx_ob_bank_pix_sender (sender_citizenid, created_at),
            KEY idx_ob_bank_pix_recipient (recipient_citizenid, created_at),
            KEY idx_ob_bank_pix_status (status, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ob_bank_pix_favorites (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            owner_citizenid VARCHAR(64) NOT NULL,
            recipient_citizenid VARCHAR(64) NOT NULL,
            recipient_name VARCHAR(120) NOT NULL,
            nickname VARCHAR(40) NOT NULL DEFAULT '',
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY uq_ob_bank_favorite (owner_citizenid, recipient_citizenid),
            KEY idx_ob_bank_favorite_owner (owner_citizenid, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    local timeout = math.max(30, tonumber(Config.Transfer.unresolvedTimeoutSeconds) or 120)
    local affected = MySQL.update.await(([=[
        UPDATE ob_bank_pix
        SET status = 'manual_review', failure_reason = 'resource interrompido durante a transferencia'
        WHERE status IN ('processing', 'debited')
          AND created_at < DATE_SUB(CURRENT_TIMESTAMP, INTERVAL %d SECOND)
    ]=]):format(timeout)) or 0
    if affected > 0 then
        print(('^3[%s]^7 %d Pix pendente(s) separado(s) para revisao; nenhum foi repetido automaticamente.'):format(RESOURCE, affected))
    end

    ready = true
    print(('^2[%s]^7 Banco pronto.'):format(RESOURCE))
    log('limite por Pix: %s', Config.Transfer.maximum)
end)
