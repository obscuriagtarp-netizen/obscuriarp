local uiOpen = false
local uiMode = 'catalog'
local properties = {}
local targetZones = {}
local officeZone
local currentProperty
local playerIsAdmin = false
local textUiVisible = false
local textUiValue
local positionCapture = false
local debugPrint

local errorMessages = {
    database_initializing = 'O sistema de imóveis ainda está iniciando.',
    player_not_loaded = 'Seu personagem ainda não terminou de carregar.',
    forbidden = 'Você não possui permissão para esta ação.',
    property_not_found = 'Este imóvel não está disponível.',
    property_unavailable = 'Este imóvel já possui proprietário.',
    ownership_not_found = 'A propriedade informada não foi encontrada.',
    already_owned = 'Você já possui acesso a este imóvel.',
    no_access = 'Você não possui acesso a este imóvel.',
    too_far = 'Aproxime-se do ponto do imóvel.',
    insufficient_funds = 'Saldo insuficiente para esta compra.',
    not_for_sale = 'Este imóvel não está à venda.',
    purchases_disabled = 'As compras estão temporariamente indisponíveis.',
    house_limit = 'Você atingiu o limite de casas.',
    invalid_key = 'Use uma chave única com letras minúsculas, números, _ ou -.',
    invalid_label = 'Informe um nome válido para o imóvel.',
    invalid_model = 'Selecione um modelo de interior válido.',
    invalid_entrance = 'Capture uma entrada válida.',
    invalid_interior = 'Os pontos do interior estão incompletos.',
    duplicate_key = 'Já existe um imóvel com essa chave.',
    save_failed = 'Não foi possível salvar o imóvel. Consulte o console do servidor.',
    citizen_not_found = 'Citizen ID não encontrado.',
    invalid_expiry = 'Informe uma duração válida para a concessão.',
    already_owner = 'O proprietário já possui acesso total.',
    property_busy = 'Este imóvel está sendo atualizado. Tente novamente.',
    slow_down = 'Aguarde um instante antes de repetir a ação.',
    starter_cannot_archive = 'O apartamento inicial não pode ser arquivado.',
    stash_unavailable = 'O baú não está disponível nesta visita.',
    inventory_unavailable = 'O inventário não está disponível agora.',
    purchase_failed = 'A compra não foi concluída e o valor foi devolvido.',
    grant_failed = 'Não foi possível entregar o imóvel.',
    revoke_failed = 'Não foi possível remover o imóvel.',
    visitor_disabled = 'As visitas estão desativadas.',
    resident_offline = 'Esse morador não está na cidade.',
    owner_busy = 'Esse morador já está atendendo outra campainha.',
    bell_cooldown = 'Aguarde um pouco antes de tocar novamente.',
    invite_expired = 'A autorização de entrada expirou. Toque a campainha novamente.',
    preview_disabled = 'A visualização de interiores está desativada.',
    rental_not_found = 'Esta mensalidade não foi encontrada.',
    rental_active = 'Esta mansão já está com a mensalidade ativa.',
    rental_busy = 'Esta mensalidade já está sendo processada.',
    insufficient_runes = 'Você não possui Runas suficientes para renovar.',
    renewal_failed = 'Não foi possível renovar. Nenhuma Runa foi perdida.',
    vip_unavailable = 'O sistema VIP não está disponível agora.',
    internal_error = 'Ocorreu um erro interno. Tente novamente.'
}

local function notify(message, notifyType)
    lib.notify({
        title = 'Imóveis',
        description = message,
        type = notifyType or 'inform'
    })
end

local function explain(result, fallback)
    if result and result.ok then return true end
    local code = result and result.error
    notify(errorMessages[code] or fallback or 'Não foi possível concluir esta ação.', 'error')
    return false
end

local function request(action, data)
    return lib.callback.await('ob_housing:server:request', false, action, data or {}) or {
        ok = false,
        error = 'internal_error'
    }
end

local function currentCoords()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    return {
        x = coords.x + 0.0,
        y = coords.y + 0.0,
        z = coords.z + 0.0,
        h = GetEntityHeading(ped) + 0.0
    }
end

local function hideTextUi()
    if positionCapture then return end
    if not textUiVisible then return end
    lib.hideTextUI()
    textUiVisible = false
    textUiValue = nil
end

local function showTextUi(value)
    if textUiVisible and textUiValue == value then return end
    if textUiVisible then lib.hideTextUI() end
    lib.showTextUI(value, {
        position = 'right-center',
        icon = 'house'
    })
    textUiVisible = true
    textUiValue = value
end

local function closeUi()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openUi(mode)
    mode = mode == 'admin' and 'admin' or mode == 'mine' and 'mine' or 'catalog'
    local payload = request('bootstrap', { mode = mode })
    if not explain(payload, 'Não foi possível abrir o painel.') then return end
    playerIsAdmin = payload.isAdmin == true
    uiMode = payload.mode or mode
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', payload = payload })
end

local function activateInterior(interior)
    if type(interior) ~= 'table' or interior.provider ~= 'bob74_ipl' then return end
    local resource = Config.Resources.ipl
    if GetResourceState(resource) ~= 'started' then return end
    local exportName = tostring(interior.exportName or '')
    if exportName == '' then return end

    local ok, message = pcall(function()
        local object = exports[resource][exportName]()
        if object and type(object.LoadDefault) == 'function' then object.LoadDefault() end
    end)
    if not ok then debugPrint(('Falha ao ativar %s: %s'):format(exportName, message)) end
end

debugPrint = function(message)
    if Config.Debug then print(('^5[ob_housing]^7 %s'):format(tostring(message))) end
end

local function teleport(destination)
    if not destination then return false end
    local ped = PlayerPedId()
    DoScreenFadeOut(350)
    local timeout = GetGameTimer() + 1500
    while not IsScreenFadedOut() and GetGameTimer() < timeout do Wait(0) end
    FreezeEntityPosition(ped, true)
    RequestCollisionAtCoord(destination.x, destination.y, destination.z)
    SetEntityCoordsNoOffset(ped, destination.x, destination.y, destination.z, false, false, false)
    SetEntityHeading(ped, destination.h or 0.0)

    timeout = GetGameTimer() + 2500
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        RequestCollisionAtCoord(destination.x, destination.y, destination.z)
        Wait(50)
    end
    FreezeEntityPosition(ped, false)
    Wait(120)
    DoScreenFadeIn(350)
    return true
end

local function beginInteriorSession(response)
    closeUi()
    activateInterior(response.interior)
    currentProperty = {
        property = response.property,
        interior = response.interior,
        preview = response.preview == true,
        accessRole = response.accessRole
    }
    teleport(response.interior.entry)
    if response.preview and response.timeoutSeconds then
        notify(('Visualização liberada por até %d minutos. Use E na saída para voltar.'):format(math.floor(response.timeoutSeconds / 60)), 'inform')
    end
end

local function enterProperty(propertyId, preview, inviteToken)
    local response = request(preview and 'preview' or 'enter', {
        propertyId = propertyId,
        inviteToken = inviteToken
    })
    if not explain(response, preview and 'Não foi possível visualizar o interior.' or 'Não foi possível entrar.') then return end
    beginInteriorSession(response)
end

local function previewPreset(presetKey)
    local response = request('previewPreset', { presetKey = presetKey })
    if not explain(response, 'Não foi possível visualizar este modelo.') then return end
    beginInteriorSession(response)
end

local function ringBell(propertyId, ownershipId)
    local response = request('ringBell', {
        propertyId = propertyId,
        ownershipId = ownershipId
    })
    if not explain(response, 'Não foi possível tocar a campainha.') then return end
    notify('Campainha tocada. Aguarde a resposta do morador.', 'inform')
end

local function openEntrance(property)
    local response = request('entranceOptions', { propertyId = property.id })
    if not explain(response, 'Não foi possível consultar essa entrada.') then return end

    local options = {}
    if response.access then
        options[#options + 1] = {
            title = property.starter and 'Entrar no meu apartamento' or 'Entrar no meu imóvel',
            description = 'Acessar sua propriedade',
            icon = property.type == 'apartment' and 'building' or 'house',
            onSelect = function() enterProperty(property.id, false) end
        }
    end

    if response.expiredRental then
        local rental = response.expiredRental
        options[#options + 1] = {
            title = ('Renovar por %d Runas'):format(tonumber(rental.renewalRunes) or 0),
            description = ('Liberar a mansão por mais %d dias'):format(tonumber(rental.durationDays) or 30),
            icon = 'gem',
            onSelect = function()
                local answer = lib.alertDialog({
                    header = 'Renovar mansão',
                    content = ('Pagar %d Runas para liberar este imóvel por mais %d dias?'):format(
                        tonumber(rental.renewalRunes) or 0,
                        tonumber(rental.durationDays) or 30
                    ),
                    centered = true,
                    cancel = true,
                    labels = { confirm = 'Renovar', cancel = 'Cancelar' }
                })
                if answer ~= 'confirm' then return end
                local result = request('renewProperty', { ownershipId = rental.ownershipId })
                if explain(result, 'Não foi possível renovar a mansão.') then
                    notify(('Mansão liberada por mais %d dias.'):format(tonumber(rental.durationDays) or 30), 'success')
                end
            end
        }
    end

    for _, owner in ipairs(response.owners or {}) do
        local selected = owner
        options[#options + 1] = {
            title = ('Visitar %s'):format(selected.name),
            description = selected.online and 'Tocar a campainha' or 'Morador indisponível',
            icon = 'bell',
            disabled = not selected.online,
            onSelect = function() ringBell(property.id, selected.ownershipId) end
        }
    end

    if #options == 0 then
        notify('Não há moradores disponíveis para receber visitas.', 'warning')
        return
    end

    lib.registerContext({
        id = 'ob_housing_entrance',
        title = property.label,
        options = options
    })
    lib.showContext('ob_housing_entrance')
end

local function exitProperty()
    if not currentProperty then return end
    local response = request('exit')
    if not explain(response, 'Não foi possível sair do imóvel.') then return end
    local entrance = response.entrance or currentProperty.property.entrance
    currentProperty = nil
    hideTextUi()
    teleport(entrance)
end

local function openStash()
    local response = request('openStash')
    if not explain(response, 'Não foi possível abrir o baú.') then return end
    exports.ox_inventory:openInventory('stash', response.stashId)
end

local function openWardrobe()
    if GetResourceState(Config.Resources.appearance) ~= 'started' then
        notify('O guarda-roupa não está disponível agora.', 'error')
        return
    end
    TriggerEvent('illenium-appearance:client:openOutfitMenu')
end

local function removeTargets()
    if GetResourceState(Config.Resources.target) ~= 'started' then
        targetZones = {}
        officeZone = nil
        return
    end
    for _, zoneId in ipairs(targetZones) do
        pcall(function() exports.ox_target:removeZone(zoneId) end)
    end
    targetZones = {}
    if officeZone then
        pcall(function() exports.ox_target:removeZone(officeZone) end)
        officeZone = nil
    end
end

local function registerTargets()
    removeTargets()
    if Config.Interaction.useTargetWhenAvailable == false then return false end
    if GetResourceState(Config.Resources.target) ~= 'started' then return false end

    if Config.CatalogOffice.enabled then
        local options = {
            {
                name = 'ob_housing_catalog',
                label = 'Ver catálogo de imóveis',
                icon = 'fa-solid fa-house',
                distance = Config.Interaction.targetDistance,
                onSelect = function() openUi('catalog') end
            },
            {
                name = 'ob_housing_mine',
                label = 'Meus imóveis',
                icon = 'fa-solid fa-key',
                distance = Config.Interaction.targetDistance,
                onSelect = function() openUi('mine') end
            }
        }
        if playerIsAdmin then
            options[#options + 1] = {
                name = 'ob_housing_admin',
                label = 'Administrar imóveis',
                icon = 'fa-solid fa-building-shield',
                distance = Config.Interaction.targetDistance,
                onSelect = function() openUi('admin') end
            }
        end
        officeZone = exports.ox_target:addSphereZone({
            coords = Config.CatalogOffice.coords,
            radius = Config.CatalogOffice.radius,
            debug = Config.Debug,
            options = options
        })
    end

    for _, property in ipairs(properties) do
        local entry = property.entrance
        if entry and not property.starter then
            local captured = property
            targetZones[#targetZones + 1] = exports.ox_target:addSphereZone({
                coords = vec3(entry.x, entry.y, entry.z),
                radius = 1.15,
                debug = Config.Debug,
                options = {
                    {
                        name = ('ob_housing_enter_%s'):format(property.id),
                        label = ('Entrar em %s'):format(property.label),
                        icon = property.type == 'apartment' and 'fa-solid fa-building' or 'fa-solid fa-house',
                        distance = Config.Interaction.targetDistance,
                        onSelect = function() openEntrance(captured) end
                    }
                }
            })
        end
    end
    return true
end

local function refreshClientState()
    if not LocalPlayer.state.isLoggedIn then return end
    local payload = request('bootstrap', { mode = 'catalog' })
    if payload.ok then
        playerIsAdmin = payload.isAdmin == true
        if type(payload.entrances) == 'table' then properties = payload.entrances end
        registerTargets()
    end
end

RegisterNetEvent('ob_housing:client:syncProperties', function(payload)
    properties = type(payload) == 'table' and payload or {}
    if LocalPlayer.state.isLoggedIn then refreshClientState() end
end)

RegisterNetEvent('ob_housing:client:open', function(mode)
    openUi(mode)
end)

RegisterNetEvent('ob_housing:client:forceExit', function(entrance, reason)
    currentProperty = nil
    closeUi()
    hideTextUi()
    if entrance then teleport(entrance) end
    if reason == 'preview_expired' then
        notify('O tempo de visualização terminou.', 'warning')
    else
        notify('Seu acesso a este imóvel foi encerrado.', 'warning')
    end
end)

RegisterNetEvent('ob_housing:client:bellRequest', function(data)
    data = type(data) == 'table' and data or {}
    CreateThread(function()
        local answer = lib.alertDialog({
            header = 'Campainha',
            content = ('%s quer visitar %s.'):format(data.visitorName or 'Uma pessoa', data.propertyLabel or 'seu imóvel'),
            centered = true,
            cancel = true,
            labels = {
                confirm = 'Permitir entrada',
                cancel = 'Recusar'
            }
        })
        TriggerServerEvent('ob_housing:server:answerBell', data.requestId, answer == 'confirm')
    end)
end)

RegisterNetEvent('ob_housing:client:bellAccepted', function(data)
    data = type(data) == 'table' and data or {}
    notify(('%s autorizou sua entrada.'):format(data.ownerName or 'O morador'), 'success')
    enterProperty(data.propertyId, false, data.token)
end)

RegisterNetEvent('ob_housing:client:bellResult', function(status)
    if status == 'denied' then
        notify('O morador recusou a visita.', 'error')
    else
        notify('A solicitação de visita expirou.', 'warning')
    end
end)

RegisterNUICallback('close', function(_, cb)
    closeUi()
    cb({ ok = true })
end)

RegisterNUICallback('request', function(body, cb)
    body = type(body) == 'table' and body or {}
    local action = tostring(body.action or '')
    local data = type(body.data) == 'table' and body.data or {}
    if action == 'enter' then
        enterProperty(data.propertyId, false)
        cb({ ok = true })
        return
    end
    if action == 'preview' then
        enterProperty(data.propertyId, true)
        cb({ ok = true })
        return
    end
    if action == 'previewPreset' then
        previewPreset(data.presetKey)
        cb({ ok = true })
        return
    end
    if action == 'waypoint' then
        local entry = data.entrance
        if entry and entry.x and entry.y then
            SetNewWaypoint(entry.x + 0.0, entry.y + 0.0)
            notify('Rota marcada no GPS.', 'success')
            cb({ ok = true })
        else
            cb({ ok = false, error = 'invalid_entrance' })
        end
        return
    end
    cb(request(action, data))
end)

RegisterNUICallback('capturePoint', function(_, cb)
    if not playerIsAdmin or not uiOpen or positionCapture then
        cb({ ok = false, error = 'forbidden' })
        return
    end

    positionCapture = true
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'capture', active = true })
    showTextUi('[E] Confirmar posição  |  [BACKSPACE] Cancelar')

    local captured
    while positionCapture do
        Wait(0)
        if IsControlJustReleased(0, 38) then
            captured = currentCoords()
            positionCapture = false
        elseif IsControlJustReleased(0, 177) then
            positionCapture = false
        end
    end

    hideTextUi()
    SendNUIMessage({ action = 'capture', active = false })
    if uiOpen then SetNuiFocus(true, true) end
    cb(captured and { ok = true, coords = captured } or { ok = false, error = 'cancelled' })
end)

RegisterCommand('casas', function()
    if uiOpen or positionCapture then return end
    openUi(playerIsAdmin and 'admin' or 'mine')
end, false)

CreateThread(function()
    if Config.CatalogOffice.enabled and Config.CatalogOffice.blip.enabled then
        local blip = AddBlipForCoord(Config.CatalogOffice.coords.x, Config.CatalogOffice.coords.y, Config.CatalogOffice.coords.z)
        SetBlipSprite(blip, Config.CatalogOffice.blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.CatalogOffice.blip.scale)
        SetBlipColour(blip, Config.CatalogOffice.blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.CatalogOffice.blip.label)
        EndTextCommandSetBlipName(blip)
    end

    while true do
        local sleep = 900
        local action
        local label
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        if currentProperty then
            local interior = currentProperty.interior
            local nearestDistance = 999.0
            local canUseHomeUtilities = not currentProperty.preview
                and (currentProperty.accessRole == 'owner' or currentProperty.accessRole == 'resident')
            local candidates = {
                { coords = interior.exit, action = exitProperty, label = '[E] Sair do imóvel' },
                { coords = canUseHomeUtilities and interior.stash or nil, action = openStash, label = '[E] Abrir baú' },
                { coords = canUseHomeUtilities and interior.wardrobe or nil, action = openWardrobe, label = '[E] Abrir guarda-roupa' }
            }
            for _, candidate in ipairs(candidates) do
                if candidate.coords then
                    local distance = #(coords - vec3(candidate.coords.x, candidate.coords.y, candidate.coords.z))
                    if distance < nearestDistance then
                        nearestDistance = distance
                        if distance <= Config.Interaction.distance then
                            action = candidate.action
                            label = candidate.label
                        end
                    end
                end
            end
            if nearestDistance < Config.Interaction.markerDistance then sleep = 0 end
        elseif not uiOpen then
            local useWorldMarkers = Config.Interaction.useTargetWhenAvailable == false
                or GetResourceState(Config.Resources.target) ~= 'started'
            if useWorldMarkers and Config.CatalogOffice.enabled then
                local distance = #(coords - Config.CatalogOffice.coords)
                if distance < Config.Interaction.markerDistance then
                    sleep = 0
                    DrawMarker(1, Config.CatalogOffice.coords.x, Config.CatalogOffice.coords.y, Config.CatalogOffice.coords.z - 1.0,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.8, 0.8, 0.18, 151, 91, 190, 150, false, false, 2, false)
                    if distance <= Config.Interaction.distance then
                        action = function() openUi(playerIsAdmin and 'admin' or 'catalog') end
                        label = playerIsAdmin and '[E] Abrir painel de imóveis' or '[E] Abrir catálogo de imóveis'
                    end
                end
            end
            if not action then
                for _, property in ipairs(properties) do
                    local entry = property.entrance
                    if entry and (property.starter or useWorldMarkers) then
                        local distance = #(coords - vec3(entry.x, entry.y, entry.z))
                        if distance < Config.Interaction.markerDistance then
                            sleep = 0
                            DrawMarker(1, entry.x, entry.y, entry.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                0.65, 0.65, 0.14, 69, 165, 134, 145, false, false, 2, false)
                            if distance <= Config.Interaction.distance then
                                local captured = property
                                action = function() openEntrance(captured) end
                                label = property.starter
                                    and '[E] Acessar apartamentos'
                                    or ('[E] Acessar %s'):format(property.label)
                                break
                            end
                        end
                    end
                end
            end
        end

        if action and not uiOpen then
            showTextUi(label)
            if IsControlJustReleased(0, 38) then action() end
        else
            hideTextUi()
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(1000)
    refreshClientState()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    closeUi()
    hideTextUi()
    currentProperty = nil
    removeTargets()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        uiOpen = false
        positionCapture = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
        Wait(750)
        refreshClientState()
    elseif resourceName == Config.Resources.target then
        Wait(750)
        refreshClientState()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    positionCapture = false
    closeUi()
    hideTextUi()
    removeTargets()
    if currentProperty and currentProperty.property and currentProperty.property.entrance then
        local entry = currentProperty.property.entrance
        SetEntityCoordsNoOffset(PlayerPedId(), entry.x, entry.y, entry.z, false, false, false)
    end
end)

exports('OpenCatalog', function() openUi('catalog') end)
exports('OpenMyProperties', function() openUi('mine') end)
exports('IsInsideProperty', function() return currentProperty ~= nil end)
exports('GetCurrentProperty', function() return currentProperty end)
