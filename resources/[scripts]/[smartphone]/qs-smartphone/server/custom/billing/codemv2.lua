if Config.Billing ~= 'codemv2' then
    return
end

---@param source number
---@return table[]
local function getBills(source)
    local bills = exports['codem-billingv2']:GetPlayerUnpaidBillings(source)
    local out = {}
    if type(bills) ~= 'table' then
        return out
    end

    for _, v in pairs(bills) do
        out[#out + 1] = {
            id = v.invoiceid,
            title = v.job or v.sender or 'Invoice',
            subtitle = v.reason or 'No reason',
            price = v.amount,
            job = type(v.job) == 'string' and v.job:lower() or nil,
            avatar = v.avatar,
        }
    end
    return out
end

RegisterNetEvent('codemBilling:PayInvoice', function(invoiceId)
    local src = source
    exports['codem-billingv2']:PayBilling(src, invoiceId)
end)

Billing.register('codemv2', {
    getBills = getBills,
    payBill = function(source, billId)
        exports['codem-billingv2']:PayBilling(source, billId)
        return true
    end,
})
