if Config.Billing ~= 'codemv2' then
    return
end

Billing.register('codemv2', {
    payBill = function(billId)
        TriggerServerEvent('codemBilling:PayInvoice', billId)
        Wait(250)
        return true
    end,
})
