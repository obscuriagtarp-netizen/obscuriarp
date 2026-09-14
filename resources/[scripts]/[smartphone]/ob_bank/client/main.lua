local PHONE_RESOURCE = 'qs-smartphone'
local RESOURCE = GetCurrentResourceName()
local APP_ID = Config.App.id
local UI_ROOT = ('https://cfx-nui-%s/ui/build/'):format(RESOURCE)
local callbacks = {}
local sequence = 0

local function requestToken()
    sequence = sequence + 1
    return ('%s:%s:%s'):format(GetGameTimer(), sequence, math.random(100000, 999999))
end

RegisterNUICallback('ob-bank:api', function(data, cb)
    local action = type(data) == 'table' and data.action or nil
    if type(action) ~= 'string' or action == '' then
        cb({ ok = false, error = 'Acao invalida.' })
        return
    end

    local token = requestToken()
    callbacks[token] = cb
    TriggerServerEvent('ob_bank:server:request', token, action, data.payload)

    SetTimeout(15000, function()
        local pending = callbacks[token]
        if not pending then return end
        callbacks[token] = nil
        pending({ ok = false, error = 'O banco demorou para responder. Tente novamente.' })
    end)
end)

RegisterNetEvent('ob_bank:client:response', function(token, response)
    local cb = callbacks[tostring(token or '')]
    if not cb then return end
    callbacks[tostring(token)] = nil
    cb(type(response) == 'table' and response or { ok = false, error = 'Resposta bancaria invalida.' })
end)

local function registerApp()
    if GetResourceState(PHONE_RESOURCE) ~= 'started' then return end

    local cacheBust = ('?v=%s-%s'):format(GetGameTimer(), math.random(100000, 999999))
    pcall(function() exports[PHONE_RESOURCE]:removeCustomApp(APP_ID) end)

    local added, reason = exports[PHONE_RESOURCE]:addCustomApp({
        id = APP_ID,
        label = Config.App.label,
        icon = UI_ROOT .. 'icon.png' .. cacheBust,
        category = Config.App.category,
        creator = Config.App.creator,
        description = Config.App.description,
        age = Config.App.age,
        appStoreOnly = Config.App.appStoreOnly,
        sizeMb = Config.App.sizeMb,
        version = Config.App.version,
        iframe = {
            url = UI_ROOT .. 'index.html' .. cacheBust,
        },
        custom = {
            enabled = true,
            sourceResource = RESOURCE,
            bridge = {
                enabled = true,
                allowedOrigins = { ('https://cfx-nui-%s'):format(RESOURCE) },
            },
        },
    })

    if not added then
        print(('^1[%s]^7 Nao foi possivel registrar o aplicativo: %s'):format(RESOURCE, tostring(reason or 'motivo desconhecido')))
        return
    end

    print(('^2[%s]^7 Aplicativo registrado no qs-smartphone.'):format(RESOURCE))
end

CreateThread(function()
    while GetResourceState(PHONE_RESOURCE) ~= 'started' do Wait(500) end
    registerApp()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == PHONE_RESOURCE then SetTimeout(500, registerApp) end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= RESOURCE then return end
    for token, cb in pairs(callbacks) do
        callbacks[token] = nil
        cb({ ok = false, error = 'O aplicativo bancario foi reiniciado.' })
    end
    if GetResourceState(PHONE_RESOURCE) == 'started' then
        pcall(function() exports[PHONE_RESOURCE]:removeCustomApp(APP_ID) end)
    end
end)

