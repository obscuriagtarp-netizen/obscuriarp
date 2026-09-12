if Config.Billing ~= 'qs' then
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
        [[SELECT id, invoice_value, notes, status, society_name, author_name
          FROM qs_billing
          WHERE receiver_identifier = ?
          ORDER BY CASE
            WHEN status = "unpaid" THEN 1
            WHEN status = "autopaid" THEN 2
            WHEN status = "paid" THEN 3
            WHEN status = "cancelled" THEN 4
            ELSE 5
          END ASC, id DESC]],
        { identifier }
    ) or {}

    local out = {}
    for i = 1, #invoices do
        local v = invoices[i]
        -- Only show unpaid (fixed vs reference which skipped unpaid)
        if v.status == 'unpaid' then
            local title = v.society_name or v.author_name or 'Invoice'
            out[#out + 1] = {
                id = v.id,
                title = title,
                subtitle = v.notes or 'No reason',
                price = v.invoice_value,
                job = type(title) == 'string' and title:lower() or nil,
            }
        end
    end
    return out
end

Billing.register('qs', {
    getBills = getBills,
    payBill = function()
        return false
    end,
})
