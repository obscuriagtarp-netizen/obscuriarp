ObVampiros = ObVampiros or {}

local harvestBusy = false
local activeHarvest = nil

local function farmConfig()
    return Config.PumaFarm or {}
end

local function actionConfig(mode)
    if mode == 'collect' then return farmConfig().collection or {} end
    return farmConfig().feeding or {}
end

local function notify(message, kind)
    exports.qbx_core:Notify(message, kind or 'inform')
end

local function isValidDeadPuma(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) or not IsEntityAPed(entity) then
        return false
    end
    if IsPedAPlayer(entity) or Entity(entity).state.obVampireFarmPuma ~= true then
        return false
    end
    local validModel = false
    for _, configuredModel in ipairs(farmConfig().models or {}) do
        local hash = type(configuredModel) == 'number' and configuredModel or joaat(configuredModel)
        if GetEntityModel(entity) == hash then
            validModel = true
            break
        end
    end
    return validModel and (IsEntityDead(entity) or IsPedDeadOrDying(entity, true) or GetEntityHealth(entity) <= 0)
end

local function carcassUnavailable(entity)
    if not isValidDeadPuma(entity) then return true end
    local state = Entity(entity).state
    return state.obVampireHarvested == true
        or (state.obVampireHarvester ~= nil and state.obVampireHarvester ~= false)
        or (state.obVampireEmbracer ~= nil and state.obVampireEmbracer ~= false)
end

local function canHarvest(entity)
    local playerPed = PlayerPedId()
    return farmConfig().enabled == true
        and ObVampiros.IsVampire()
        and not ObVampiros.IsPowerBlocked()
        and not harvestBusy
        and playerPed ~= 0
        and not IsEntityDead(playerPed)
        and not IsPedInAnyVehicle(playerPed, false)
        and not carcassUnavailable(entity)
end

local function requestControl(entity, timeoutMs)
    if not NetworkGetEntityIsNetworked(entity) then
        NetworkRegisterEntityAsNetworked(entity)
    end
    if not NetworkGetEntityIsNetworked(entity) then return false end
    if NetworkHasControlOfEntity(entity) then return true end

    local timeout = GetGameTimer() + math.max(250, tonumber(timeoutMs) or 1500)
    NetworkRequestControlOfEntity(entity)
    while DoesEntityExist(entity) and not NetworkHasControlOfEntity(entity)
        and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(entity)
        Wait(0)
    end
    return DoesEntityExist(entity) and NetworkHasControlOfEntity(entity)
end

local function approachCarcass(playerPed, carcass)
    local carcassCoords = GetEntityCoords(carcass)
    local playerCoords = GetEntityCoords(playerPed)
    local delta = playerCoords - carcassCoords
    local length = #(delta)
    if length < 0.05 then
        delta = GetEntityForwardVector(carcass) * -1.0
        length = math.max(0.05, #(delta))
    end
    local destination = carcassCoords + (delta / length) * 0.82
    TaskGoStraightToCoord(playerPed, destination.x, destination.y, destination.z, 1.0, 1300, 0.0, 0.12)

    local timeout = GetGameTimer() + 1350
    while GetGameTimer() < timeout and #(GetEntityCoords(playerPed) - destination) > 0.22 do
        if IsEntityDead(playerPed) or not DoesEntityExist(carcass) then return false end
        Wait(0)
    end
    ClearPedTasks(playerPed)
    TaskTurnPedToFaceEntity(playerPed, carcass, 650)
    Wait(500)
    return #(GetEntityCoords(playerPed) - carcassCoords) <= (tonumber(farmConfig().cancelDistance) or 3.6)
end

local function playPhase(playerPed, phase)
    if not phase or not phase.dictionary or not phase.clip
        or not ObVampiros.EnsureAnim(phase.dictionary, 4000) then return false end

    local duration = math.max(200, math.floor(tonumber(phase.duration) or 900))
    TaskPlayAnim(
        playerPed, phase.dictionary, phase.clip,
        3.0, -3.0, duration, tonumber(phase.flag) or 2,
        0.0, false, false, false
    )
    Wait(math.max(0, duration - 100))
    return true
end

local function runBloodEffect(carcass, session)
    local effect = farmConfig().effect or {}
    if effect.enabled ~= true or not effect.asset or not effect.name
        or not ObVampiros.EnsurePtfx(effect.asset) then return end

    CreateThread(function()
        local interval = math.max(500, math.floor(tonumber(effect.interval) or 1350))
        while activeHarvest == session and DoesEntityExist(carcass) do
            UseParticleFxAssetNextCall(effect.asset)
            StartParticleFxNonLoopedOnEntity(
                effect.name, carcass,
                0.0, 0.0, 0.16,
                0.0, 0.0, 0.0,
                tonumber(effect.scale) or 0.55,
                false, false, false
            )
            Wait(interval)
        end
    end)
end

local function rewardMessage(rewards)
    local parts = {}
    for _, reward in ipairs(rewards or {}) do
        parts[#parts + 1] = ('%dx %s'):format(tonumber(reward.amount) or 0, reward.label or reward.item)
    end
    return #parts > 0 and ('Coleta concluida: %s.'):format(table.concat(parts, ', '))
        or 'O sangue foi extraido.'
end

local function cancelHarvest(session)
    if session and session.token then
        TriggerServerEvent('ob_vampiros:server:cancelPumaHarvest', session.token)
    end
end

local function harvestPuma(carcass, mode)
    if harvestBusy or not canHarvest(carcass) then return end
    mode = mode == 'collect' and 'collect' or 'feed'
    harvestBusy = true

    if not requestControl(carcass, 1500) then
        harvestBusy = false
        return notify('Nao foi possivel acessar esta carcaca.', 'error')
    end
    local netId = NetworkGetNetworkIdFromEntity(carcass)
    if not netId or netId <= 0 then
        harvestBusy = false
        return notify('Esta carcaca nao pode ser identificada pela cidade.', 'error')
    end

    local callOk, response = pcall(function()
        return lib.callback.await('ob_vampiros:server:beginPumaHarvest', false, netId, mode)
    end)
    if not callOk or type(response) ~= 'table' or response.success ~= true then
        harvestBusy = false
        return notify(type(response) == 'table' and response.message or 'A coleta nao pode ser iniciada.', 'error')
    end

    local session = { token = response.token, netId = netId, carcass = carcass, mode = mode }
    activeHarvest = session
    local playerPed = PlayerPedId()
    local animation = farmConfig().animation or {}

    if not approachCarcass(playerPed, carcass) then
        cancelHarvest(session)
        activeHarvest = nil
        harvestBusy = false
        ClearPedTasks(playerPed)
        return notify('Voce se afastou da carcaca.', 'error')
    end

    playPhase(playerPed, animation.enter)
    runBloodEffect(carcass, session)
    CreateThread(function()
        local cancelDistance = math.max(1.5, tonumber(farmConfig().cancelDistance) or 3.6)
        while activeHarvest == session do
            Wait(200)
            local currentPed = PlayerPedId()
            if currentPed == 0 or IsEntityDead(currentPed) or IsPedInAnyVehicle(currentPed, false)
                or not isValidDeadPuma(carcass)
                or #(GetEntityCoords(currentPed) - GetEntityCoords(carcass)) > cancelDistance then
                session.interrupted = true
                if lib.progressActive() then lib.cancelProgress() end
                return
            end
        end
    end)
    local feed = animation.feed or {}
    local selectedAction = actionConfig(mode)
    local completed = lib.progressCircle({
        duration = math.max(2500, math.floor(tonumber(response.duration) or 8000)),
        label = selectedAction.progressLabel or (mode == 'collect'
            and 'Enchendo o frasco com sangue da puma'
            or 'Absorvendo a essencia do sangue'),
        position = 'bottom',
        useWhileDead = false,
        allowRagdoll = false,
        allowFalling = false,
        canCancel = true,
        disable = { move = true, sprint = true, car = true, combat = true, mouse = false },
        anim = feed.dictionary and feed.clip and {
            dict = feed.dictionary,
            clip = feed.clip,
            flag = tonumber(feed.flag) or 1,
        } or nil,
    })

    if completed and not session.interrupted and isValidDeadPuma(carcass) then
        local finishOk, result = pcall(function()
            return lib.callback.await('ob_vampiros:server:finishPumaHarvest', false, session.token, netId)
        end)
        if finishOk and type(result) == 'table' and result.success == true then
            if result.mode == 'feed' then
                notify(('Sua essencia de sangue aumentou em %d.'):format(tonumber(result.essenceGain) or 0), 'success')
            else
                notify(rewardMessage(result.rewards), 'success')
            end
        else
            notify(type(result) == 'table' and result.message or 'Nao foi possivel concluir a coleta.', 'error')
        end
    else
        cancelHarvest(session)
        notify('A coleta foi interrompida.', 'error')
    end

    activeHarvest = nil
    playPhase(playerPed, animation.exit)
    ClearPedTasks(playerPed)
    harvestBusy = false
end

CreateThread(function()
    if farmConfig().enabled ~= true then return end
    while GetResourceState('ox_target') ~= 'started' do Wait(500) end
    local collection = farmConfig().collection or {}
    local feeding = farmConfig().feeding or {}
    exports.ox_target:addModel(farmConfig().models or { 'a_c_mtlion' }, {
        {
            name = collection.targetName or 'ob_vampiros_coletar_puma',
            icon = collection.targetIcon or 'fa-solid fa-vial',
            label = collection.targetLabel or 'Recolher sangue da puma',
            distance = tonumber(farmConfig().interactionDistance) or 2.2,
            canInteract = function(entity)
                return canHarvest(entity)
            end,
            onSelect = function(data)
                harvestPuma(data.entity, 'collect')
            end,
        },
        {
            name = feeding.targetName or farmConfig().targetName or 'ob_vampiros_sugar_puma',
            icon = feeding.targetIcon or farmConfig().targetIcon or 'fa-solid fa-droplet',
            label = feeding.targetLabel or farmConfig().targetLabel or 'Sugar sangue da puma',
            distance = tonumber(farmConfig().interactionDistance) or 2.2,
            canInteract = function(entity)
                return canHarvest(entity)
            end,
            onSelect = function(data)
                harvestPuma(data.entity, 'feed')
            end,
        },
    })
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if GetResourceState('ox_target') == 'started' then
        local collection = farmConfig().collection or {}
        local feeding = farmConfig().feeding or {}
        exports.ox_target:removeModel(farmConfig().models or { 'a_c_mtlion' }, collection.targetName or 'ob_vampiros_coletar_puma')
        exports.ox_target:removeModel(farmConfig().models or { 'a_c_mtlion' }, feeding.targetName or farmConfig().targetName or 'ob_vampiros_sugar_puma')
    end
    if activeHarvest then cancelHarvest(activeHarvest) end
    ClearPedTasks(PlayerPedId())
    activeHarvest = nil
    harvestBusy = false
end)
