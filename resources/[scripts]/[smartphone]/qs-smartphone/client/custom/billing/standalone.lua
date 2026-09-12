if Config.Billing ~= 'standalone' then
    return
end

Billing.register('standalone', {
    payBill = function(billId)
        local result = lib.callback.await('phone:wallet:payBill', false, { id = billId })
        return type(result) == 'table' and result.success == true
    end,
})
