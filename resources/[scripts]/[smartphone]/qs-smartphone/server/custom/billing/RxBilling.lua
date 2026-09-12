if Config.Billing ~= 'RxBilling' then
    return
end

---@param source number
---@return table[]
local function getBills(source)
    local identifier = sfr:getIdentifier(source)
    if not identifier then
        return {}
    end

    local invoices = exports.RxBilling:GetPlayerInvoices(identifier, 'incoming')
    local out = {}
    if type(invoices) ~= 'table' then
        return out
    end

    for _, v in pairs(invoices) do
        if v.status == 'pending' then
            out[#out + 1] = {
                id = v.id,
                title = v.job or v.sender_name or 'Invoice',
                subtitle = v.reason or 'No reason',
                price = v.amount,
                job = type(v.job) == 'string' and v.job:lower() or nil,
                avatar = v.avatar,
            }
        end
    end
    return out
end

Billing.register('RxBilling', {
    getBills = getBills,
    payBill = function()
        return false
    end,
})
