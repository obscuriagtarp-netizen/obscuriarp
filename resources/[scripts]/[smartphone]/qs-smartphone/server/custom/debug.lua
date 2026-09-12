if not Config.Debug then
    return
end

RegisterCommand('phonecall', function(source, _args)
    local phoneApp = Apps and Apps.Phone
    local result = phoneApp.debugIncomingQuasarStoreCall(source)

    if type(result) == 'table' and result.success == true then
        Notification(source, 'Test incoming call from Quasar Store (555-0100).', 'success')
        return
    end

    local errorMessage = type(result) == 'table' and result.message or type(result) == 'table' and result.error or 'Failed to start test call.'
    Notification(source, tostring(errorMessage), 'error')
end, false)

RegisterCommand('phonenotify', function(source, args)
    local targetArg = args[1]
    local targetSource = tonumber(targetArg)
    local targetPhone = nil
    if (not targetSource or targetSource < 1) and type(targetArg) == 'string' and targetArg ~= '' then
        targetPhone = targetArg
        targetSource = PhoneManager.getSourceByPhone(targetPhone)
    end

    if (not targetSource or targetSource < 1) and not targetPhone then
        if source > 0 then
            Notification(source, 'Usage: /phonenotify <targetId|phoneNumber> [appId] [message]', 'error')
        else
            print('[phone] Usage: /phonenotify <targetId|phoneNumber> [appId] [message]')
        end
        return
    end

    local appId = type(args[2]) == 'string' and args[2] ~= '' and args[2] or 'messages'
    local textStartIndex = args[2] and 3 or 2
    local message = table.concat(args, ' ', textStartIndex)
    if message == nil or message == '' then
        message = 'Debug notification from server.'
    end

    local phone = targetSource and PhoneManager and PhoneManager.getBySource and PhoneManager.getBySource(targetSource) or nil
    if targetSource and (not phone or type(phone.getIdentifier) ~= 'function') and type(SyncCurrentPhoneFromInventory) == 'function' then
        phone = SyncCurrentPhoneFromInventory(targetSource, { closeClientOnMissing = false })
    end
    if targetSource and not phone and PhoneManager and type(PhoneManager.getBySource) == 'function' then
        phone = PhoneManager.getBySource(targetSource)
    end

    local scopeId = phone and type(phone.getIdentifier) == 'function' and phone:getIdentifier() or nil
    if (type(scopeId) ~= 'string' or scopeId == '') and targetSource and sfr and type(sfr.getIdentifier) == 'function' then
        scopeId = sfr:getIdentifier(targetSource)
    end
    if type(scopeId) ~= 'string' or scopeId == '' then
        if source > 0 then
            Notification(source, ('Unable to resolve target scope for %s.'):format(targetArg or '?'), 'error')
        else
            print(('[phone] Unable to resolve target scope for %s.'):format(targetArg or '?'))
        end
        return
    end

    local senderLabel = source > 0 and ('Player %s'):format(source) or 'Server Console'
    local ok, err, payload = NotificationsManager.push(scopeId, {
        appId = appId,
        title = 'Server Debug',
        subtitle = senderLabel,
        text = message,
        closeTimeout = 5000,
        metadata = {
            debug = true,
            sender = senderLabel,
            target = targetSource or targetPhone,
        }
    })

    if not ok then
        local errorMessage = err or 'Failed to push notification.'
        if source > 0 then
            Notification(source, errorMessage, 'error')
        else
            print(('[phone] %s'):format(errorMessage))
        end
        return
    end

    if type(payload) == 'table' and payload.suppressed == true then
        if source > 0 then
            Notification(source, ('Notification suppressed (app disabled): %s'):format(appId), 'info')
        else
            print(('[phone] Notification suppressed (app disabled): %s'):format(appId))
        end
        return
    end

    if source > 0 then
        Notification(source, ('Notification sent to %s via app %s'):format(targetSource or targetPhone or targetArg, appId), 'success')
    else
        print(('[phone] Notification sent to %s via app %s'):format(targetSource or targetPhone or targetArg, appId))
    end
end, false)
