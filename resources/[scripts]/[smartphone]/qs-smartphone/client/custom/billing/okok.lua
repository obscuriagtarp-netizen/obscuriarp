if Config.Billing ~= 'okok' then
    return
end

Billing.register('okok', {
    payBill = function(billId)
        TriggerServerEvent('okokBilling:PayInvoice', billId)
        Wait(250)
        return true
    end,
})
