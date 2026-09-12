if Config.Billing ~= 'qs' then
    return
end

Billing.register('qs', {
    payBill = function()
        TriggerEvent('qs-billing:client:Notify', 'You must go to pay it presentialy or in your invoice tablet', 'info')
        return true
    end,
})
