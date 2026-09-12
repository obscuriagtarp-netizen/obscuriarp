local success, result = pcall(lib.load, ('custom.%s.server'):format(Config.Framework))

if not success then
    error(result, 0)
end

_G.sfr = result --[[@as ServerFramework]]
print('^2[INFO]^7 Successfully loaded the framework.', Config.Framework)

_G.inventory = {}

_G.Billing = {
    _pending = {},
    register = function(name, adapter)
        if type(name) ~= 'string' or name == '' or type(adapter) ~= 'table' then
            return
        end
        Billing._pending[name] = adapter
    end,
}

---@param src number
---@param msg string
---@param type 'info' | 'error' | 'success'
function Notification(src, msg, type)
    TriggerClientEvent('phone:notification', src, msg, type)
end

---@param scopeId string
---@param payload PhonePushPayload
---@return boolean, string?, table?
function PhonePushNotification(scopeId, payload)
    if type(scopeId) ~= 'string' or scopeId == '' then
        return false, 'INVALID_SCOPE_ID'
    end

    if type(NotificationsManager) ~= 'table' or type(NotificationsManager.push) ~= 'function' then
        return false, 'NOTIFICATIONS_MANAGER_UNAVAILABLE'
    end

    return NotificationsManager.push(scopeId, payload)
end
