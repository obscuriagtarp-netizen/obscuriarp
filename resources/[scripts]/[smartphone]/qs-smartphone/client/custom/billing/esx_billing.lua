if Config.Billing ~= 'esx_billing' then
    return
end

Billing.register('esx_billing', {
    payBill = function(billId)
        local co = coroutine.running()
        if not co then
            return false
        end

        local ESX = cfr and cfr.getObject and cfr:getObject() or nil
        if not ESX or type(ESX.TriggerServerCallback) ~= 'function' then
            return false
        end

        local result = false
        ESX.TriggerServerCallback('esx_billing:payBill', function(resp)
            if resp then
                TriggerEvent('esx_billing:paidBill', billId)
                result = true
            end
            coroutine.resume(co)
        end, billId)

        coroutine.yield()
        return result
    end,
})
