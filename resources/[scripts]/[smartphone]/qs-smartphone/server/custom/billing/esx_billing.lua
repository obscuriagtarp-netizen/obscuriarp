if Config.Billing ~= 'esx_billing' then
    return
end

---@param source number
---@return table[]
local function getBills(source)
    local identifier = sfr:getIdentifier(source)
    if not identifier then
        return {}
    end

    local invoices = MySQL.query.await(
        'SELECT amount, id, label, sender, target_type, target FROM billing WHERE identifier = ?',
        { identifier }
    ) or {}

    local out = {}
    for i = 1, #invoices do
        local v = invoices[i]
        local label = v.label or 'No reason'
        local title = 'Invoice'
        if type(v.target) == 'string' and v.target ~= '' then
            title = v.target
        elseif type(v.sender) == 'string' and v.sender ~= '' then
            title = v.sender
        end
        out[#out + 1] = {
            id = v.id,
            title = title,
            subtitle = label,
            price = v.amount,
            job = type(title) == 'string' and title:lower() or nil,
            sender = v.sender,
        }
    end
    return out
end

Billing.register('esx_billing', {
    getBills = getBills,
    payBill = function()
        return false
    end,
})
