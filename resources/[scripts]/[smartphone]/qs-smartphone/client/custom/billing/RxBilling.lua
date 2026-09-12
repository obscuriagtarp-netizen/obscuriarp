if Config.Billing ~= 'RxBilling' then
    return
end

Billing.register('RxBilling', {
    payBill = function(billId)
        local invoice = exports.RxBilling:PayInvoice(billId)
        return invoice and true or false
    end,
})
