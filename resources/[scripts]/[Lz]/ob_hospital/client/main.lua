local isOpen = false
local currentMode
local requestId = 0
local requests = {}
local targetZones = {}
local attendantPed
local autoAvailable = false
local displayVisible = false
local nextDisplayRefresh = 0
local queueAudioEnabled = false

local function requestServer(action, data, callback)
    requestId = requestId + 1
    requests[requestId] = callback
    TriggerServerEvent('ob_hospital:server:request', requestId, action, data or {})
end

RegisterNetEvent('ob_hospital:client:response', function(token, payload)
    local callback = requests[tonumber(token)]
    if not callback then return end
    requests[tonumber(token)] = nil
    callback(payload or {})
end)

local function isDoctor()
    local job = QBX and QBX.PlayerData and QBX.PlayerData.job or {}
    return (job.name == Config.Job.name or job.type == Config.Job.type) and job.onduty ~= false
end

local function closeInterface()
    if not isOpen then return end
    isOpen = false
    currentMode = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openInterface(mode, extra)
    if isOpen then closeInterface() end
    requestServer('bootstrap', { mode = mode }, function(payload)
        if not payload.ok then
            local messages = {
                not_authorized = 'Acesso restrito à equipe médica.',
                doctors_online = 'O atendimento presencial está disponível no momento.',
                terminal_too_far = 'Aproxime-se da maquininha do hospital.'
            }
            exports.qbx_core:Notify(messages[payload.error] or 'Não foi possível abrir o sistema hospitalar.', 'error')
            return
        end
        currentMode = mode
        isOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open', mode = mode, payload = payload, extra = extra or {} })
    end)
end

exports('OpenPanel', function(mode)
    openInterface(mode or 'panel')
end)

RegisterNetEvent('ob_hospital:client:openPanel', function(mode)
    openInterface(mode or 'panel')
end)

RegisterNUICallback('close', function(_, cb)
    closeInterface()
    cb({ ok = true })
end)

RegisterNUICallback('request', function(body, cb)
    body = type(body) == 'table' and body or {}
    requestServer(tostring(body.action or ''), type(body.data) == 'table' and body.data or {}, cb)
end)

RegisterNUICallback('waypoint', function(body, cb)
    local coords = type(body) == 'table' and body.coords or {}
    if coords.x and coords.y then
        SetNewWaypoint(coords.x + 0.0, coords.y + 0.0)
        exports.qbx_core:Notify('Rota marcada no GPS.', 'success')
    end
    cb({ ok = true })
end)

local function deleteAttendant()
    if attendantPed and DoesEntityExist(attendantPed) then
        exports.ox_target:removeLocalEntity(attendantPed)
        DeleteEntity(attendantPed)
    end
    attendantPed = nil
end

local function spawnAttendant()
    if attendantPed or not Config.AutoAttendant.enabled then return end
    local model = joaat(Config.AutoAttendant.model)
    lib.requestModel(model, 10000)
    local coords = Config.AutoAttendant.coords
    attendantPed = CreatePed(0, model, coords.x, coords.y, coords.z, coords.w, false, false)
    SetEntityInvincible(attendantPed, true)
    FreezeEntityPosition(attendantPed, true)
    SetBlockingOfNonTemporaryEvents(attendantPed, true)
    TaskStartScenarioInPlace(attendantPed, Config.AutoAttendant.scenario, 0, true)
    exports.ox_target:addLocalEntity(attendantPed, {
        {
            name = 'ob_hospital_auto_treatment',
            icon = 'fa-solid fa-bed-pulse',
            label = 'Receber atendimento automático',
            distance = Config.InteractionDistance + 0.5,
            onSelect = function()
                requestServer('selfTreatment', {}, function(payload)
                    if payload.ok then
                        exports.qbx_core:Notify('Atendimento iniciado. Você será encaminhado ao leito.', 'success')
                    else
                        local messages = { doctors_online = 'Há médicos disponíveis.', no_bed = 'Não há leitos disponíveis.' }
                        exports.qbx_core:Notify(messages[payload.error] or 'Atendimento indisponível.', 'error')
                    end
                end)
            end
        },
        {
            name = 'ob_hospital_public_shop',
            icon = 'fa-solid fa-kit-medical',
            label = 'Comprar suprimentos',
            distance = Config.InteractionDistance + 0.5,
            onSelect = function() openInterface('shop') end
        }
    })
    SetModelAsNoLongerNeeded(model)
end

local function addTargets()
    targetZones[#targetZones + 1] = exports.ox_target:addSphereZone({
        coords = Config.Points.triage,
        radius = Config.Queue.checkInDistance,
        debug = Config.Debug,
        options = {
            {
                name = 'ob_hospital_queue_checkin',
                icon = 'fa-solid fa-ticket',
                label = 'Retirar senha de atendimento',
                distance = Config.Queue.checkInDistance,
                onSelect = function()
                    requestServer('joinQueue', {}, function(payload)
                        if not payload.ok then
                            local messages = {
                                too_far = 'Aproxime-se da recepção para retirar uma senha.',
                                patient_unavailable = 'Pacientes inconscientes são encaminhados à central de emergência.'
                            }
                            exports.qbx_core:Notify(messages[payload.error] or 'Não foi possível retirar sua senha.', 'error')
                            return
                        end
                        local code = payload.ticket and payload.ticket.ticket_code or 'indisponível'
                        local message = payload.existing and ('Sua senha ativa é %s.'):format(code)
                            or ('Senha %s retirada. Aguarde a avaliação da triagem.'):format(code)
                        exports.qbx_core:Notify(message, payload.existing and 'inform' or 'success')
                    end)
                end
            }
        }
    })

    targetZones[#targetZones + 1] = exports.ox_target:addSphereZone({
        coords = Config.Points.panel,
        radius = Config.InteractionDistance,
        debug = Config.Debug,
        options = {
            {
                name = 'ob_hospital_panel',
                icon = 'fa-solid fa-notes-medical',
                label = 'Abrir painel médico',
                distance = Config.InteractionDistance + 0.5,
                canInteract = isDoctor,
                onSelect = function() openInterface('panel') end
            }
        }
    })

    targetZones[#targetZones + 1] = exports.ox_target:addSphereZone({
        coords = Config.Points.billing,
        radius = Config.Billing.terminalDistance,
        debug = Config.Debug,
        options = {
            {
                name = 'ob_hospital_billing_terminal',
                icon = 'fa-solid fa-credit-card',
                label = 'Usar maquininha do hospital',
                distance = Config.Billing.terminalDistance,
                onSelect = function() openInterface('billing') end
            }
        }
    })

    targetZones[#targetZones + 1] = exports.ox_target:addSphereZone({
        coords = Config.Points.stash,
        radius = Config.InteractionDistance,
        debug = Config.Debug,
        options = {
            {
                name = 'ob_hospital_stash',
                icon = 'fa-solid fa-box-open',
                label = Config.Stash.label,
                distance = Config.InteractionDistance + 0.5,
                canInteract = isDoctor,
                onSelect = function() exports.ox_inventory:openInventory('stash', Config.Stash.name) end
            }
        }
    })

    targetZones[#targetZones + 1] = exports.ox_target:addSphereZone({
        coords = Config.Points.armory,
        radius = Config.InteractionDistance,
        debug = Config.Debug,
        options = {
            {
                name = 'ob_hospital_armory',
                icon = 'fa-solid fa-suitcase-medical',
                label = Config.Armory.label,
                distance = Config.InteractionDistance + 0.5,
                canInteract = isDoctor,
                onSelect = function() exports.ox_inventory:openInventory('shop', { type = Config.Armory.name }) end
            }
        }
    })
end

-- RegisterCommand('hospitalpagamento', function()
--     openInterface('billing')
-- end, false)

RegisterNetEvent('ob_hospital:client:dispatchUpdate', function(call, isNew)
    if isNew and isDoctor() then
        exports.qbx_core:Notify(('Novo chamado %s: %s'):format(call.public_code or 'MED', call.reason or 'Atendimento solicitado.'), 'inform', 7000)
        if Config.Dispatch.playNativeSound then PlaySoundFrontend(-1, 'CONFIRM_BEEP', 'HUD_MINI_GAME_SOUNDSET', true) end
    end
    if isOpen and currentMode == 'panel' then
        SendNUIMessage({ action = 'dispatchUpdate', call = call, isNew = isNew == true })
    end
    nextDisplayRefresh = 0
end)

RegisterNetEvent('ob_hospital:client:queueUpdate', function(queue)
    if isOpen and currentMode == 'panel' then
        SendNUIMessage({ action = 'queueUpdate', queue = queue or {} })
    end
end)

RegisterNetEvent('ob_hospital:client:billingChanged', function()
    if not isOpen or currentMode ~= 'billing' then return end
    requestServer('billing', {}, function(payload)
        if payload.ok then SendNUIMessage({ action = 'billingUpdate', payload = payload }) end
    end)
end)

RegisterNetEvent('ob_hospital:client:subscriptionUpdate', function(citizenid, plan)
    if panelOpen then
        SendNUIMessage({ action = 'subscriptionUpdate', citizenid = citizenid, plan = plan or {} })
    end
end)

RegisterNetEvent('ob_hospital:client:queueDisplayUpdate', function(queue, displayLimit)
    nextDisplayRefresh = 0
    if displayVisible and not isOpen then
        SendNUIMessage({ action = 'display', visible = true, payload = { queue = queue or {}, displayLimit = displayLimit } })
    end
end)

RegisterCommand('hospitalpainel', function()
    openInterface('panel')
end, false)

RegisterNetEvent('ob_hospital:client:queueAnnouncement', function(announcement)
    if not Config.QueueVoice.enabled or IsPauseMenuActive() then return end
    if #(GetEntityCoords(PlayerPedId()) - Config.Points.display) > Config.DisplayRenderDistance then return end
    queueAudioEnabled = true
    SendNUIMessage({ action = 'queueAudio', enabled = true })
    SendNUIMessage({ action = 'queueAnnouncement', announcement = announcement, voice = Config.QueueVoice })
end)

RegisterCommand('192', function(_, args)
    local reason = table.concat(args or {}, ' ')
    TriggerServerEvent('ob_hospital:server:createCall', reason ~= '' and reason or Config.Dispatch.defaultReason, 'normal')
end, false)

RegisterKeyMapping('hospitalpainel', 'Abrir painel médico', 'keyboard', 'F9')

CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(500) end
    addTargets()
    while true do
        requestServer('availability', {}, function(payload)
            autoAvailable = payload.ok and payload.autoAttendant == true
            if autoAvailable then spawnAttendant() else deleteAttendant() end
        end)
        Wait(10000)
    end
end)

CreateThread(function()
    while true do
        local wait = 1000
        local coords = GetEntityCoords(PlayerPedId())
        local distance = #(coords - Config.Points.display)
        local nearDisplay = distance <= Config.DisplayRenderDistance and not IsPauseMenuActive()
        local audioEnabled = nearDisplay and Config.QueueVoice.enabled
        if queueAudioEnabled ~= audioEnabled then
            queueAudioEnabled = audioEnabled
            SendNUIMessage({ action = 'queueAudio', enabled = audioEnabled })
        end
        if nearDisplay then
            wait = 250
            displayVisible = true
            if GetGameTimer() >= nextDisplayRefresh then
                nextDisplayRefresh = GetGameTimer() + Config.DisplayRefreshMs
                requestServer('bootstrap', { mode = 'display' }, function(payload)
                    if displayVisible and payload.ok then
                        SendNUIMessage({ action = 'display', visible = true, payload = payload })
                    end
                end)
            end
        elseif displayVisible then
            displayVisible = false
            nextDisplayRefresh = 0
            SendNUIMessage({ action = 'display', visible = false })
        end
        Wait(wait)
    end
end)

CreateThread(function()
    while true do
        if isOpen then
            if IsPauseMenuActive() or IsEntityDead(PlayerPedId()) then closeInterface() end
            Wait(250)
        else
            Wait(1000)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeInterface()
    SendNUIMessage({ action = 'queueAudio', enabled = false })
    deleteAttendant()
    for _, zoneId in ipairs(targetZones) do pcall(function() exports.ox_target:removeZone(zoneId) end) end
end)
