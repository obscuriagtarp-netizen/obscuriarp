Apps.ICar = {}

---@param a string
---@param b string
---@return boolean
local function platesMatch(a, b)
    return Core.trim(a):gsub('%s+', ''):upper() == Core.trim(b):gsub('%s+', ''):upper()
end

Core.callback('icar:list', function(source, identifier, _scopeId, _data)
    local result = getGarageData(identifier)
    if result == false then
        return Core.ok({
            vehicles = {},
            valetEnabled = Config.Valet == true,
            valetPrice = math.floor(tonumber(Config.ValetPrice) or 0),
        })
    end
    return Core.ok({
        vehicles = result,
        valetEnabled = Config.Valet == true,
        valetPrice = math.floor(tonumber(Config.ValetPrice) or 0),
    })
end)

Core.callback('icar:take', function(source, identifier, _scopeId, data)
    if not Config.Valet then
        return Core.fail('VALET_DISABLED', i18n.t('apps.icar.backend.valet_disabled'))
    end
    local payload = type(data) == 'table' and data or {}
    local plate = Core.trim(type(payload.plate) == 'string' and payload.plate or '')
    if plate == '' then
        return Core.fail('INVALID_PLATE', i18n.t('apps.icar.backend.invalid_plate'))
    end
    local rows = getGarageData(identifier, plate)
    if not rows or not rows[1] then
        return Core.fail('NOT_FOUND', i18n.t('apps.icar.backend.vehicle_not_found'))
    end
    local row = rows[1]
    TriggerClientEvent('phone:icar:takeVehicle', source, row.vehicle, row.inGarage)
    return Core.ok(true)
end)

Core.callback('icar:valetPay', function(source, _identifier, _scopeId, _data)
    if not Config.Valet then
        return Core.fail('VALET_DISABLED', i18n.t('apps.icar.backend.valet_disabled'))
    end
    local price = math.floor(tonumber(Config.ValetPrice) or 0)
    if price < 0 then
        price = 0
    end
    local account = Config.IcarValetPaymentAccount
    if price == 0 then
        return Core.ok({ paid = 0 })
    end
    local balance = sfr:getAccountMoney(source, account)
    if balance < price then
        return Core.fail('NO_MONEY', i18n.t('apps.icar.backend.no_money'))
    end
    if not sfr:removeAccountMoney(source, account, price) then
        return Core.fail('PAYMENT_FAILED', i18n.t('apps.icar.backend.payment_failed'))
    end
    return Core.ok({ paid = price })
end)

Core.callback('icar:isVehicleExist', function(source, _identifier, _scopeId, data)
    local payload = type(data) == 'table' and data or {}
    local plate = Core.trim(type(payload.plate) == 'string' and payload.plate or '')
    if plate == '' then
        return Core.ok(false)
    end
    if type(GetAllVehicles) ~= 'function' then
        return Core.ok(false)
    end
    local vehicles = GetAllVehicles()
    if type(vehicles) ~= 'table' then
        return Core.ok(false)
    end
    for _, veh in pairs(vehicles) do
        if DoesEntityExist(veh) then
            local text = GetVehicleNumberPlateText(veh)
            if type(text) == 'string' and platesMatch(text, plate) then
                local c = GetEntityCoords(veh)
                return Core.ok(c)
            end
        end
    end
    return Core.ok(false)
end)
