if Config.Billing ~= 'standalone' then
    return
end

---@param source number
---@return table[]
local function getBills(source)
    local identifier = sfr:getIdentifier(source)
    if not identifier then
        return {}
    end

    local rows = MySQL.query.await(
        'SELECT id, sender, job, title, subtitle, price, avatar FROM qs_phone_bills WHERE identifier = ? ORDER BY id DESC',
        { identifier }
    ) or {}

    local out = {}
    for i = 1, #rows do
        local row = rows[i]
        out[#out + 1] = {
            id = row.id,
            title = row.title,
            subtitle = row.subtitle,
            price = row.price,
            avatar = row.avatar,
            job = row.job,
            sender = row.sender,
        }
    end
    return out
end

---@param source number
---@param billId number
---@return boolean
local function payBill(source, billId)
    local identifier = sfr:getIdentifier(source)
    if not identifier then
        return false
    end

    local rows = MySQL.query.await(
        'SELECT id, price FROM qs_phone_bills WHERE id = ? AND identifier = ? LIMIT 1',
        { billId, identifier }
    )
    local bill = rows and rows[1]
    if not bill then
        return false
    end

    local price = math.floor(tonumber(bill.price) or 0)
    if price <= 0 then
        MySQL.update.await('DELETE FROM qs_phone_bills WHERE id = ? AND identifier = ?', { billId, identifier })
        return true
    end

    if not sfr:removeAccountMoney(source, Config.Wallet.account, price) then
        return false
    end

    MySQL.update.await('DELETE FROM qs_phone_bills WHERE id = ? AND identifier = ?', { billId, identifier })
    return true
end

---@param targetIdentifier string
---@param data table
---@return number|false
local function createBill(targetIdentifier, data)
    local price = math.floor(tonumber(data.price) or 0)
    if price < 0 then
        return false
    end

    local job = type(data.job) == 'string' and data.job ~= '' and data.job or nil
    local title = type(data.title) == 'string' and data.title or ''
    local subtitle = type(data.subtitle) == 'string' and data.subtitle or nil
    local avatar = type(data.avatar) == 'string' and data.avatar ~= '' and data.avatar or nil
    local sender = type(data.sender) == 'string' and data.sender or ''

    if title == '' and job and Config.BillingJobs and Config.BillingJobs[job] then
        title = Config.BillingJobs[job].label or job
    end
    if title == '' then
        title = 'Invoice'
    end

    local insertId = MySQL.insert.await([[
        INSERT INTO qs_phone_bills (identifier, sender, job, title, subtitle, price, avatar)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        targetIdentifier,
        sender,
        job,
        title:sub(1, 80),
        subtitle and subtitle:sub(1, 120) or nil,
        price,
        avatar and avatar:sub(1, 512) or nil,
    })

    return tonumber(insertId) or false
end

Billing.register('standalone', {
    getBills = getBills,
    payBill = payBill,
    createBill = createBill,
})

RegisterCommand('sendbill', function(source, args)
    local job = sfr:getJobName(source)
    local allowed = false
    if type(Config.BillJobs) == 'table' then
        for i = 1, #Config.BillJobs do
            if Config.BillJobs[i] == job then
                allowed = true
                break
            end
        end
    end
    if not allowed then
        Notification(source, 'You are not allowed to send bills.', 'error')
        return
    end

    local target = tonumber(args[1])
    local price = tonumber(args[2])
    local reason = table.concat(args, ' ', 3)
    if reason == '' then
        reason = 'No reason'
    end
    if not target or not price then
        Notification(source, 'Usage: /sendbill [id] [price] [reason]', 'error')
        return
    end

    local targetIdentifier = sfr:getIdentifier(target)
    if not targetIdentifier then
        Notification(source, 'Player not found.', 'error')
        return
    end

    local senderIdentifier = sfr:getIdentifier(source) or ''
    local billId = createBill(targetIdentifier, {
        title = (Config.BillingJobs and Config.BillingJobs[job] and Config.BillingJobs[job].label) or job or 'Invoice',
        subtitle = reason,
        price = price,
        job = job,
        sender = senderIdentifier,
    })

    if not billId then
        Notification(source, 'Failed to create bill.', 'error')
        return
    end

    Notification(source, ('Bill sent to %s'):format(GetPlayerName(target) or tostring(target)), 'success')

    local scopeId = exports[GetCurrentResourceName()]:getPhoneScopeIdentifier(target)
    if scopeId then
        PhonePushNotification(scopeId, {
            appId = 'wallet',
            appName = 'Wallet',
            title = 'New invoice',
            text = ('You received a bill of $%s'):format(math.floor(price)),
            closeTimeout = 5000,
        })
    end
end, false)
