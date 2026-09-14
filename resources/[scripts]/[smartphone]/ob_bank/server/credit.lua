ObBankCredit = ObBankCredit or {}

local RESOURCE = GetCurrentResourceName()
local creditLocks = {}
local blockedAccounts = {}
local paymentBypass = {}
local blockedNotifications = {}
local hookId
local creditReady = false

local function creditConfig()
    return Config.Credit or {}
end

local function clean(value, maximum)
    value = tostring(value or ''):gsub('[%z\1-\31\127]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    return value:sub(1, maximum or 120)
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function playerFromIdentifier(identifier)
    if type(identifier) == 'number' then
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(identifier) end)
        return ok and player or nil
    end

    local key = clean(identifier, 64)
    if key == '' then return nil end
    local ok, player = pcall(function() return exports.qbx_core:GetPlayerByCitizenId(key) end)
    return ok and player or nil
end

local function citizenIdFromIdentifier(identifier)
    local player = playerFromIdentifier(identifier)
    if player and player.PlayerData and player.PlayerData.citizenid then
        return tostring(player.PlayerData.citizenid), player
    end
    if type(identifier) == 'string' then
        local citizenid = clean(identifier, 64)
        if citizenid ~= '' then return citizenid, nil end
    end
end

local function bankBalance(citizenid, player)
    if player and player.PlayerData then
        return math.max(0, math.floor(tonumber(player.PlayerData.money and player.PlayerData.money.bank) or 0))
    end

    local row = MySQL.single.await('SELECT money FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
    if not row then return 0 end
    local money = row.money
    if type(money) == 'string' then
        local ok, decoded = pcall(json.decode, money)
        money = ok and decoded or {}
    end
    return math.max(0, math.floor(tonumber(type(money) == 'table' and money.bank or 0) or 0))
end

local function accountExists(citizenid)
    local cfg = creditConfig()
    local defaultLimit = 0
    for _, tier in ipairs(cfg.limits or {}) do
        if (tonumber(cfg.defaultScore) or 350) >= (tonumber(tier.score) or 0) then
            defaultLimit = math.max(0, math.floor(tonumber(tier.amount) or 0))
            break
        end
    end

    MySQL.query.await([[
        INSERT INTO ob_bank_credit_accounts (citizenid, score, credit_limit, status)
        VALUES (?, ?, ?, 'active')
        ON DUPLICATE KEY UPDATE citizenid = VALUES(citizenid)
    ]], { citizenid, tonumber(cfg.defaultScore) or 350, defaultLimit })
end

local function outstandingFor(citizenid)
    return math.max(0, math.floor(tonumber(MySQL.scalar.await([[
        SELECT COALESCE(SUM(GREATEST(0, principal + interest - paid_amount)), 0)
        FROM ob_bank_credit_invoices
        WHERE citizenid = ? AND status IN ('open', 'overdue')
    ]], { citizenid })) or 0))
end

local function limitForScore(score)
    for _, tier in ipairs(creditConfig().limits or {}) do
        if score >= (tonumber(tier.score) or 0) then
            return math.max(0, math.floor(tonumber(tier.amount) or 0))
        end
    end
    return 0
end

local function legacyMovement(citizenid, since)
    local ok, row = pcall(MySQL.single.await,
        'SELECT transactions FROM player_transactions WHERE id = ? LIMIT 1', { citizenid })
    if not ok or not row or not row.transactions then return 0, 0 end

    local decodedOk, transactions = pcall(json.decode, row.transactions)
    if not decodedOk or type(transactions) ~= 'table' then return 0, 0 end

    local count, volume = 0, 0
    for _, transaction in ipairs(transactions) do
        if (tonumber(transaction.time) or 0) >= since then
            count = count + 1
            volume = volume + math.abs(tonumber(transaction.amount) or 0)
        end
    end
    return count, volume
end

local function refreshScore(citizenid, player, force)
    accountExists(citizenid)
    local cfg = creditConfig()
    local row = MySQL.single.await([[
        SELECT score, credit_limit, status, UNIX_TIMESTAMP(last_scored_at) AS last_scored_at
        FROM ob_bank_credit_accounts WHERE citizenid = ? LIMIT 1
    ]], { citizenid })
    if not row then return end

    local refreshSeconds = math.max(60, (tonumber(cfg.scoreRefreshMinutes) or 30) * 60)
    if not force and tonumber(row.last_scored_at) and os.time() - tonumber(row.last_scored_at) < refreshSeconds then
        return row
    end

    local windowDays = math.max(1, math.floor(tonumber(cfg.movementWindowDays) or 30))
    local pixOk, pix = pcall(MySQL.single.await, ([=[
        SELECT COUNT(*) AS movement_count, COALESCE(SUM(amount), 0) AS movement_volume
        FROM ob_bank_pix
        WHERE status = 'completed' AND (sender_citizenid = ? OR recipient_citizenid = ?)
          AND created_at >= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL %d DAY)
    ]=]):format(windowDays), { citizenid, citizenid })
    pix = pixOk and pix or {}

    local since = os.time() - (windowDays * 86400)
    local legacyCount, legacyVolume = legacyMovement(citizenid, since)
    local movementCount = (tonumber(pix.movement_count) or 0) + legacyCount
    local movementVolume = (tonumber(pix.movement_volume) or 0) + legacyVolume
    local balance = bankBalance(citizenid, player)
    local weights = cfg.score or {}
    local score = tonumber(cfg.defaultScore) or 350

    for _, step in ipairs(weights.balanceSteps or {}) do
        if balance >= (tonumber(step.amount) or 0) then
            score = score + (tonumber(step.points) or 0)
            break
        end
    end

    score = score + math.min(tonumber(weights.movementCountCap) or 100,
        movementCount * (tonumber(weights.movementCountPoints) or 5))
    score = score + math.min(tonumber(weights.movementVolumeCap) or 150,
        math.floor(movementVolume / math.max(1, tonumber(weights.movementVolumeDivisor) or 2000)))

    local payment = MySQL.single.await([[
        SELECT
            SUM(CASE WHEN status = 'paid' THEN 1 ELSE 0 END) AS paid_count,
            SUM(CASE WHEN status = 'overdue' AND principal + interest > paid_amount THEN 1 ELSE 0 END) AS overdue_count,
            COALESCE(MAX(CASE WHEN status = 'overdue' THEN TIMESTAMPDIFF(DAY, due_at, CURRENT_TIMESTAMP) ELSE 0 END), 0) AS overdue_days
        FROM ob_bank_credit_invoices WHERE citizenid = ?
    ]], { citizenid }) or {}

    score = score + math.min(tonumber(weights.paidInvoiceCap) or 100,
        (tonumber(payment.paid_count) or 0) * (tonumber(weights.paidInvoicePoints) or 25))
    score = score - ((tonumber(payment.overdue_count) or 0) * (tonumber(weights.overdueInvoicePenalty) or 150))
    score = score - math.min(tonumber(weights.overduePenaltyCap) or 400,
        (tonumber(payment.overdue_days) or 0) * (tonumber(weights.overdueDayPenalty) or 15))
    score = math.floor(clamp(score, 0, 1000))

    local outstanding = outstandingFor(citizenid)
    local creditLimit = math.max(outstanding, limitForScore(score))
    MySQL.update.await([[
        UPDATE ob_bank_credit_accounts
        SET score = ?, credit_limit = ?, last_scored_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
        WHERE citizenid = ?
    ]], { score, creditLimit, citizenid })

    row.score = score
    row.credit_limit = creditLimit
    return row
end

local function updateBlockedCache(citizenid)
    local row = MySQL.single.await([[
        SELECT status, blocked_reason FROM ob_bank_credit_accounts WHERE citizenid = ? LIMIT 1
    ]], { citizenid })
    blockedAccounts[citizenid] = row and row.status == 'blocked' or false
    return blockedAccounts[citizenid] == true, row and row.blocked_reason or nil
end

local function applyMaintenance(citizenid)
    accountExists(citizenid)
    MySQL.update.await([[
        UPDATE ob_bank_credit_invoices
        SET status = CASE WHEN principal + interest <= paid_amount THEN 'paid' ELSE 'overdue' END,
            paid_at = CASE WHEN principal + interest <= paid_amount THEN COALESCE(paid_at, CURRENT_TIMESTAMP) ELSE paid_at END,
            interest_last_applied = CASE
                WHEN principal + interest > paid_amount THEN COALESCE(interest_last_applied, DATE(due_at))
                ELSE interest_last_applied
            END,
            updated_at = CURRENT_TIMESTAMP
        WHERE citizenid = ? AND status = 'open' AND due_at <= CURRENT_TIMESTAMP
    ]], { citizenid })

    local invoices = MySQL.query.await([[
        SELECT id, principal, interest, paid_amount,
               GREATEST(0, DATEDIFF(CURRENT_DATE, COALESCE(interest_last_applied, DATE(due_at)))) AS interest_days
        FROM ob_bank_credit_invoices
        WHERE citizenid = ? AND status = 'overdue' AND principal + interest > paid_amount
    ]], { citizenid }) or {}

    local interestRate = math.max(0, tonumber(creditConfig().dailyInterestPercent) or 1.0) / 100
    for _, invoice in ipairs(invoices) do
        local days = math.max(0, math.floor(tonumber(invoice.interest_days) or 0))
        local unpaid = math.max(0, (tonumber(invoice.principal) or 0) + (tonumber(invoice.interest) or 0) - (tonumber(invoice.paid_amount) or 0))
        if days > 0 and unpaid > 0 and interestRate > 0 then
            local interest = math.max(1, math.floor((unpaid * interestRate * days) + 0.5))
            local transactionId = ('INT-%s-%s'):format(invoice.id, os.date('%Y%m%d'))
            MySQL.transaction.await({
                {
                    query = [[
                        INSERT IGNORE INTO ob_bank_credit_transactions
                            (transaction_id, citizenid, invoice_id, transaction_type, amount, merchant, description)
                        VALUES (?, ?, ?, 'interest', ?, 'Obscuria Bank', ?)
                    ]],
                    values = { transactionId, citizenid, invoice.id, interest, ('Juros de %d dia(s) em atraso'):format(days) }
                },
                {
                    query = [[
                        UPDATE ob_bank_credit_invoices
                        SET interest = interest + ?, interest_last_applied = CURRENT_DATE, updated_at = CURRENT_TIMESTAMP
                        WHERE id = ? AND interest_last_applied < CURRENT_DATE
                    ]],
                    values = { interest, invoice.id }
                }
            })
        end
    end

    local overdueDays = tonumber(MySQL.scalar.await([[
        SELECT COALESCE(MAX(TIMESTAMPDIFF(DAY, due_at, CURRENT_TIMESTAMP)), 0)
        FROM ob_bank_credit_invoices
        WHERE citizenid = ? AND status = 'overdue' AND principal + interest > paid_amount
    ]], { citizenid })) or 0
    local blockAfter = math.max(1, math.floor(tonumber(creditConfig().blockAfterOverdueDays) or 10))

    if overdueDays >= blockAfter then
        MySQL.update.await([[
            UPDATE ob_bank_credit_accounts
            SET status = 'blocked', blocked_reason = 'overdue', blocked_at = COALESCE(blocked_at, CURRENT_TIMESTAMP), updated_at = CURRENT_TIMESTAMP
            WHERE citizenid = ?
        ]], { citizenid })
    else
        MySQL.update.await([[
            UPDATE ob_bank_credit_accounts
            SET status = 'active', blocked_reason = NULL, blocked_at = NULL, updated_at = CURRENT_TIMESTAMP
            WHERE citizenid = ? AND status = 'blocked' AND blocked_reason = 'overdue'
        ]], { citizenid })
    end
    updateBlockedCache(citizenid)
end

local function creditHistory(citizenid)
    local limit = clamp(math.floor(tonumber(creditConfig().historyLimit) or 30), 10, 100)
    local rows = MySQL.query.await(([=[
        SELECT transaction_id, transaction_type, amount, merchant, description,
               UNIX_TIMESTAMP(created_at) AS created_at_unix
        FROM ob_bank_credit_transactions
        WHERE citizenid = ?
        ORDER BY id DESC LIMIT %d
    ]=]):format(limit), { citizenid }) or {}
    local result = {}
    for _, row in ipairs(rows) do
        result[#result + 1] = {
            id = tostring(row.transaction_id),
            type = tostring(row.transaction_type),
            amount = math.floor(tonumber(row.amount) or 0),
            merchant = tostring(row.merchant or 'Obscuria'),
            description = tostring(row.description or ''),
            createdAt = tonumber(row.created_at_unix) or os.time(),
        }
    end
    return result
end

local function syncPlayerState(identifier, state)
    local player = playerFromIdentifier(identifier)
    local source = player and tonumber(player.PlayerData.source)
    if not source or source <= 0 then return end
    state = state or ObBankCredit.GetState(identifier, false)
    if not state then return end
    Player(source).state:set('obCreditAvailable', state.available or 0, true)
    Player(source).state:set('obAccountBlocked', state.blocked == true, true)
end

function ObBankCredit.GetState(identifier, refresh)
    if creditConfig().enabled == false then return nil, 'Crédito indisponível.' end
    if not creditReady then return nil, 'O crédito ainda está inicializando.' end
    local citizenid, player = citizenIdFromIdentifier(identifier)
    if not citizenid then return nil, 'Personagem não encontrado.' end

    accountExists(citizenid)
    applyMaintenance(citizenid)
    refreshScore(citizenid, player, refresh == true)

    local account = MySQL.single.await([[
        SELECT score, credit_limit, status, blocked_reason, UNIX_TIMESTAMP(blocked_at) AS blocked_at
        FROM ob_bank_credit_accounts WHERE citizenid = ? LIMIT 1
    ]], { citizenid })
    if not account then return nil, 'Conta de crédito não encontrada.' end

    local invoice = MySQL.single.await([[
        SELECT
            COALESCE(SUM(GREATEST(0, principal + interest - paid_amount)), 0) AS total_due,
            COALESCE(SUM(GREATEST(0, principal - paid_amount)), 0) AS principal_due,
            COALESCE(SUM(interest), 0) AS interest_total,
            MIN(CASE WHEN principal + interest > paid_amount THEN due_at END) AS due_at,
            UNIX_TIMESTAMP(MIN(CASE WHEN principal + interest > paid_amount THEN due_at END)) AS due_at_unix,
            COALESCE(MAX(CASE WHEN status = 'overdue' THEN TIMESTAMPDIFF(DAY, due_at, CURRENT_TIMESTAMP) ELSE 0 END), 0) AS overdue_days
        FROM ob_bank_credit_invoices
        WHERE citizenid = ? AND status IN ('open', 'overdue')
    ]], { citizenid }) or {}

    local used = math.max(0, math.floor(tonumber(invoice.total_due) or 0))
    local creditLimit = math.max(0, math.floor(tonumber(account.credit_limit) or 0))
    local dueAt = tonumber(invoice.due_at_unix)
    local state = {
        citizenid = citizenid,
        score = math.floor(tonumber(account.score) or 0),
        limit = creditLimit,
        used = used,
        available = math.max(0, creditLimit - used),
        totalDue = used,
        principalDue = math.max(0, math.floor(tonumber(invoice.principal_due) or 0)),
        interest = math.max(0, math.floor(tonumber(invoice.interest_total) or 0)),
        dueAt = dueAt,
        daysUntilDue = dueAt and math.ceil((dueAt - os.time()) / 86400) or nil,
        overdueDays = math.max(0, math.floor(tonumber(invoice.overdue_days) or 0)),
        status = tostring(account.status or 'active'),
        blocked = account.status == 'blocked',
        blockedReason = account.blocked_reason,
        blockedAt = tonumber(account.blocked_at),
        cycleDays = math.max(1, math.floor(tonumber(creditConfig().cycleDays) or 7)),
        blockAfterDays = math.max(1, math.floor(tonumber(creditConfig().blockAfterOverdueDays) or 10)),
        dailyInterestPercent = tonumber(creditConfig().dailyInterestPercent) or 1.0,
        history = creditHistory(citizenid),
    }
    return state
end

function ObBankCredit.CanCharge(identifier, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then return false, 'Valor inválido.' end
    local state, err = ObBankCredit.GetState(identifier, false)
    if not state then return false, err end
    if state.blocked then return false, 'Conta bloqueada por atraso.' end
    if state.score < (tonumber(creditConfig().minimumScore) or 200) then return false, 'Score insuficiente.' end
    if amount > state.available then return false, 'Limite insuficiente.' end
    return true, state
end

function ObBankCredit.Charge(identifier, amount, merchant, description, requestId)
    local citizenid = citizenIdFromIdentifier(identifier)
    amount = math.floor(tonumber(amount) or 0)
    merchant = clean(merchant ~= '' and merchant or 'Compra', 100)
    description = clean(description ~= '' and description or merchant, 180)
    requestId = clean(requestId, 96)
    if not citizenid or amount < 1 or amount > (tonumber(creditConfig().maximumCharge) or 1000000) then return false end
    if requestId == '' then requestId = ('CARD-%s-%s-%06d'):format(os.time(), citizenid, math.random(0, 999999)) end
    if creditLocks[citizenid] then return false end

    creditLocks[citizenid] = true
    local ok, result = xpcall(function()
        local previous = MySQL.single.await([[
            SELECT transaction_id, amount FROM ob_bank_credit_transactions
            WHERE transaction_id = ? AND citizenid = ? AND transaction_type = 'charge' LIMIT 1
        ]], { requestId, citizenid })
        if previous then return tonumber(previous.amount) == amount end

        local allowed, state = ObBankCredit.CanCharge(identifier, amount)
        if not allowed then return false end
        local cycleDays = math.max(1, math.floor(tonumber(creditConfig().cycleDays) or 7))
        local invoice = MySQL.single.await([[
            SELECT id FROM ob_bank_credit_invoices
            WHERE citizenid = ? AND status = 'open' AND due_at > CURRENT_TIMESTAMP
            ORDER BY due_at ASC LIMIT 1
        ]], { citizenid })
        local invoiceId = invoice and tonumber(invoice.id)
        if not invoiceId then
            invoiceId = MySQL.insert.await(([=[
                INSERT INTO ob_bank_credit_invoices (citizenid, cycle_start, due_at, status)
                VALUES (?, CURRENT_TIMESTAMP, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL %d DAY), 'open')
            ]=]):format(cycleDays), { citizenid })
        end
        if not invoiceId then return false end

        local committed = MySQL.transaction.await({
            {
                query = [[
                    INSERT INTO ob_bank_credit_transactions
                        (transaction_id, citizenid, invoice_id, transaction_type, amount, merchant, description)
                    VALUES (?, ?, ?, 'charge', ?, ?, ?)
                ]],
                values = { requestId, citizenid, invoiceId, amount, merchant, description }
            },
            {
                query = [[
                    UPDATE ob_bank_credit_invoices SET principal = principal + ?, updated_at = CURRENT_TIMESTAMP
                    WHERE id = ? AND citizenid = ? AND status = 'open'
                ]],
                values = { amount, invoiceId, citizenid }
            }
        })
        if not committed then return false end

        state.used = state.used + amount
        state.available = math.max(0, state.limit - state.used)
        syncPlayerState(identifier, state)
        return true
    end, debug.traceback)
    creditLocks[citizenid] = nil
    if not ok then
        print(('^1[%s]^7 Falha ao cobrar crédito de %s: %s'):format(RESOURCE, citizenid, tostring(result)))
        return false
    end
    return result == true
end

function ObBankCredit.Pay(identifier, amount, requestId)
    local citizenid, player = citizenIdFromIdentifier(identifier)
    if not citizenid or not player or player.Offline == true then return nil, 'Entre na cidade para pagar a fatura.' end
    if creditLocks[citizenid] then return nil, 'Já existe uma operação em andamento.' end
    creditLocks[citizenid] = true

    local ok, result, err = xpcall(function()
        local state = ObBankCredit.GetState(identifier, true)
        if not state or state.totalDue < 1 then return nil, 'Não há fatura pendente.' end
        amount = math.floor(tonumber(amount) or state.totalDue)
        amount = math.min(amount, state.totalDue)
        if amount < 1 then return nil, 'Informe um valor válido.' end
        requestId = clean(requestId, 96)
        if requestId == '' then return nil, 'Identificador do pagamento inválido.' end

        local previous = MySQL.single.await([[
            SELECT amount FROM ob_bank_credit_transactions
            WHERE transaction_id = ? AND citizenid = ? AND transaction_type = 'payment' LIMIT 1
        ]], { requestId, citizenid })
        if previous then
            return { paid = tonumber(previous.amount) or amount, state = ObBankCredit.GetState(identifier, false), duplicate = true }
        end

        local balance = bankBalance(citizenid, player)
        if balance < amount then return nil, 'Saldo bancário insuficiente.' end

        local source = tonumber(player.PlayerData.source)
        paymentBypass[source] = true
        local removedOk, removed = pcall(function()
            return exports.qbx_core:RemoveMoney(source, 'bank', amount, ('ob_bank_credit_payment:%s'):format(requestId))
        end)
        paymentBypass[source] = nil
        if not removedOk or removed ~= true then return nil, 'Não foi possível debitar sua conta.' end

        local invoices = MySQL.query.await([[
            SELECT id, principal, interest, paid_amount
            FROM ob_bank_credit_invoices
            WHERE citizenid = ? AND status IN ('open', 'overdue') AND principal + interest > paid_amount
            ORDER BY due_at ASC, id ASC
        ]], { citizenid }) or {}
        local remaining = amount
        local queries = {}
        for _, invoice in ipairs(invoices) do
            if remaining <= 0 then break end
            local due = math.max(0, (tonumber(invoice.principal) or 0) + (tonumber(invoice.interest) or 0) - (tonumber(invoice.paid_amount) or 0))
            local allocated = math.min(remaining, due)
            if allocated > 0 then
                queries[#queries + 1] = {
                    query = [[
                        UPDATE ob_bank_credit_invoices
                        SET paid_amount = paid_amount + ?,
                            status = CASE WHEN paid_amount + ? >= principal + interest THEN 'paid' ELSE status END,
                            paid_at = CASE WHEN paid_amount + ? >= principal + interest THEN CURRENT_TIMESTAMP ELSE paid_at END,
                            updated_at = CURRENT_TIMESTAMP
                        WHERE id = ? AND citizenid = ?
                    ]],
                    values = { allocated, allocated, allocated, invoice.id, citizenid }
                }
                remaining = remaining - allocated
            end
        end
        queries[#queries + 1] = {
            query = [[
                INSERT INTO ob_bank_credit_transactions
                    (transaction_id, citizenid, invoice_id, transaction_type, amount, merchant, description)
                VALUES (?, ?, NULL, 'payment', ?, 'Obscuria Bank', 'Pagamento de fatura')
            ]],
            values = { requestId, citizenid, amount }
        }
        local committed = MySQL.transaction.await(queries)
        if not committed then
            paymentBypass[source] = true
            pcall(function() exports.qbx_core:AddMoney(source, 'bank', amount, ('ob_bank_credit_refund:%s'):format(requestId)) end)
            paymentBypass[source] = nil
            return nil, 'O pagamento falhou e o valor foi devolvido.'
        end

        applyMaintenance(citizenid)
        refreshScore(citizenid, player, true)
        local newState = ObBankCredit.GetState(identifier, false)
        syncPlayerState(identifier, newState)

        if GetResourceState('Renewed-Banking') == 'started' then
            local charinfo = player.PlayerData.charinfo or {}
            local name = clean(('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''), 100)
            pcall(function()
                exports['Renewed-Banking']:handleTransaction(citizenid, 'Fatura do cartão', amount,
                    'Pagamento da fatura de crédito', name, 'Obscuria Bank', 'withdraw', requestId)
            end)
        end
        return { paid = amount, state = newState }
    end, debug.traceback)

    creditLocks[citizenid] = nil
    if not ok then
        print(('^1[%s]^7 Falha ao pagar fatura de %s: %s'):format(RESOURCE, citizenid, tostring(result)))
        return nil, 'Não foi possível pagar a fatura.'
    end
    return result, err
end

function ObBankCredit.Refund(identifier, transactionId, description)
    local citizenid = citizenIdFromIdentifier(identifier)
    transactionId = clean(transactionId, 96)
    if not citizenid or transactionId == '' or creditLocks[citizenid] then return false end
    creditLocks[citizenid] = true
    local ok, result = xpcall(function()
        local charge = MySQL.single.await([[
            SELECT invoice_id, amount FROM ob_bank_credit_transactions
            WHERE transaction_id = ? AND citizenid = ? AND transaction_type = 'charge' LIMIT 1
        ]], { transactionId, citizenid })
        if not charge then return false end
        local refundId = ('REF-%s'):format(transactionId):sub(1, 96)
        local existing = MySQL.scalar.await('SELECT 1 FROM ob_bank_credit_transactions WHERE transaction_id = ? LIMIT 1', { refundId })
        if existing then return true end
        local amount = math.max(0, math.floor(tonumber(charge.amount) or 0))
        if amount < 1 then return false end
        local committed = MySQL.transaction.await({
            {
                query = [[
                    INSERT INTO ob_bank_credit_transactions
                        (transaction_id, citizenid, invoice_id, transaction_type, amount, merchant, description)
                    VALUES (?, ?, ?, 'refund', ?, 'Obscuria Bank', ?)
                ]],
                values = { refundId, citizenid, charge.invoice_id, amount, clean(description or 'Estorno de compra', 180) }
            },
            {
                query = [[
                    UPDATE ob_bank_credit_invoices
                    SET principal = GREATEST(0, principal - ?),
                        status = CASE WHEN GREATEST(0, principal - ?) + interest <= paid_amount THEN 'paid' ELSE status END,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE id = ? AND citizenid = ?
                ]],
                values = { amount, amount, charge.invoice_id, citizenid }
            }
        })
        if committed then syncPlayerState(identifier) end
        return committed == true
    end, debug.traceback)
    creditLocks[citizenid] = nil
    if not ok then
        print(('^1[%s]^7 Falha ao estornar crédito de %s: %s'):format(RESOURCE, citizenid, tostring(result)))
        return false
    end
    return result == true
end

function ObBankCredit.IsBlocked(identifier)
    if not creditReady then return false end
    local citizenid = citizenIdFromIdentifier(identifier)
    if not citizenid then return false end
    if blockedAccounts[citizenid] ~= nil then return blockedAccounts[citizenid] == true end
    applyMaintenance(citizenid)
    return blockedAccounts[citizenid] == true
end

exports('GetCreditState', function(identifier)
    local state, err = ObBankCredit.GetState(identifier, false)
    return state and { ok = true, data = state } or { ok = false, error = err }
end)
exports('CanChargeCredit', ObBankCredit.CanCharge)
exports('ChargeCredit', ObBankCredit.Charge)
exports('TryPayment', ObBankCredit.Charge)
exports('PayCreditInvoice', function(identifier, amount, requestId)
    local result, err = ObBankCredit.Pay(identifier, amount, requestId)
    return result and { ok = true, data = result } or { ok = false, error = err }
end)
exports('RefundCredit', ObBankCredit.Refund)
exports('IsAccountBlocked', ObBankCredit.IsBlocked)

local function registerMoneyHook()
    if hookId or GetResourceState('qbx_core') ~= 'started' then return end
    local ok, id = pcall(function()
        return exports.qbx_core:registerHook('removeMoney', function(payload)
            local source = tonumber(payload and payload.source)
            if not source or source <= 0 or payload.moneyType ~= 'bank' or paymentBypass[source] then return end
            local player = playerFromIdentifier(source)
            local citizenid = player and tostring(player.PlayerData.citizenid)
            if citizenid and blockedAccounts[citizenid] then
                local now = GetGameTimer()
                if now - (blockedNotifications[source] or 0) > 5000 then
                    blockedNotifications[source] = now
                    pcall(function()
                        exports.qbx_core:Notify(source, 'Sua conta está bloqueada. Quite a fatura do cartão para regularizar.', 'error', 6000)
                    end)
                end
                return false
            end
        end)
    end)
    if ok then hookId = id end
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local source = player and player.PlayerData and tonumber(player.PlayerData.source)
    if not source then return end
    SetTimeout(1500, function()
        local state = ObBankCredit.GetState(source, true)
        syncPlayerState(source, state)
    end)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(source)
    blockedNotifications[tonumber(source)] = nil
    paymentBypass[tonumber(source)] = nil
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == 'qbx_core' then SetTimeout(1000, registerMoneyHook) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == 'qbx_core' then hookId = nil end
end)

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ob_bank_credit_accounts (
            citizenid VARCHAR(64) NOT NULL,
            score SMALLINT UNSIGNED NOT NULL DEFAULT 350,
            credit_limit BIGINT UNSIGNED NOT NULL DEFAULT 0,
            status VARCHAR(16) NOT NULL DEFAULT 'active',
            blocked_reason VARCHAR(32) DEFAULT NULL,
            blocked_at TIMESTAMP NULL DEFAULT NULL,
            last_scored_at TIMESTAMP NULL DEFAULT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (citizenid),
            KEY idx_ob_credit_account_status (status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ob_bank_credit_invoices (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            citizenid VARCHAR(64) NOT NULL,
            cycle_start TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            due_at TIMESTAMP NOT NULL,
            principal BIGINT UNSIGNED NOT NULL DEFAULT 0,
            interest BIGINT UNSIGNED NOT NULL DEFAULT 0,
            paid_amount BIGINT UNSIGNED NOT NULL DEFAULT 0,
            status VARCHAR(16) NOT NULL DEFAULT 'open',
            interest_last_applied DATE DEFAULT NULL,
            paid_at TIMESTAMP NULL DEFAULT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_ob_credit_invoice_owner (citizenid, status, due_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ob_bank_credit_transactions (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            transaction_id VARCHAR(96) NOT NULL,
            citizenid VARCHAR(64) NOT NULL,
            invoice_id BIGINT UNSIGNED DEFAULT NULL,
            transaction_type VARCHAR(16) NOT NULL,
            amount BIGINT UNSIGNED NOT NULL,
            merchant VARCHAR(100) NOT NULL DEFAULT 'Obscuria',
            description VARCHAR(180) NOT NULL DEFAULT '',
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY uq_ob_credit_transaction (transaction_id),
            KEY idx_ob_credit_transaction_owner (citizenid, created_at),
            KEY idx_ob_credit_transaction_invoice (invoice_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    local blocked = MySQL.query.await("SELECT citizenid FROM ob_bank_credit_accounts WHERE status = 'blocked'") or {}
    for _, row in ipairs(blocked) do blockedAccounts[tostring(row.citizenid)] = true end
    creditReady = true
    registerMoneyHook()

    for _, source in ipairs(GetPlayers()) do
        local playerSource = tonumber(source)
        local state = ObBankCredit.GetState(playerSource, true)
        syncPlayerState(playerSource, state)
    end

    CreateThread(function()
        while true do
            Wait(600000)
            local rows = MySQL.query.await([[
                SELECT DISTINCT citizenid FROM ob_bank_credit_invoices
                WHERE status IN ('open', 'overdue') AND principal + interest > paid_amount
            ]]) or {}
            for _, row in ipairs(rows) do
                local citizenid = tostring(row.citizenid)
                local ok, err = pcall(applyMaintenance, citizenid)
                if not ok then print(('^1[%s]^7 Manutenção de crédito falhou para %s: %s'):format(RESOURCE, citizenid, err)) end
                local player = playerFromIdentifier(citizenid)
                if player then syncPlayerState(citizenid) end
            end
        end
    end)
end)
