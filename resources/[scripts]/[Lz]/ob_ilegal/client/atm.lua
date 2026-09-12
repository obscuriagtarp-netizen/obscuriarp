ObIlegalAtm = ObIlegalAtm or {}

local targetName = 'ob_ilegal:atm'
local atmStates = {}
local activeAttempt

local routePresentation = {
    humano = {
        label = 'Conectando o dispositivo ao terminal',
        dict = 'anim@heists@ornate_bank@hack',
        clip = 'hack_loop',
        fallbackDict = 'amb@prop_human_atm@male@idle_a',
        fallbackClip = 'idle_a',
    },
    bruxa = {
        label = 'Corrompendo as runas do mecanismo',
        dict = 'kiml@magic@export@nib@wizardsv_wand_attack_b1',
        clip = 'nib@wizardsv_wand_attack_b1',
        fallbackDict = 'anim@mp_snowball',
        fallbackClip = 'pickup_snowball',
    },
    vampiro = {
        label = 'Rompendo o compartimento interno',
        dict = 'missheistfbi3b_ig7',
        clip = 'lift_fibagent_loop',
        fallbackDict = 'melee@large_wpn@streamed_core',
        fallbackClip = 'plyr_aimed',
    },
    curandeira = {
        label = 'Conduzindo raízes pelo mecanismo',
        dict = 'kiml@magic@export@nib@wizardsv_wand_attack_b3',
        clip = 'nib@wizardsv_wand_attack_b3',
        fallbackDict = 'anim@mp_snowball',
        fallbackClip = 'pickup_snowball',
    },
}

local function setAtmState(key, status, remaining)
    if status == 'available' then
        atmStates[key] = nil
        return
    end
    atmStates[key] = GetGameTimer() + (math.max(1, tonumber(remaining) or 1) * 1000)
end

local function isAtmLocked(entity)
    local coords = GetEntityCoords(entity)
    local key = ObIlegalShared.AtmKey(GetEntityModel(entity), coords)
    local expiresAt = key and atmStates[key]
    if expiresAt and expiresAt <= GetGameTimer() then
        atmStates[key] = nil
        expiresAt = nil
    end
    return expiresAt ~= nil
end

local function turnToAtm(entity)
    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, entity, 650)
    Wait(450)
end

local function playRouteAnimation(presentation, duration)
    local ped = PlayerPedId()
    local dict, clip = presentation.dict, presentation.clip
    if not ObIlegalClient.EnsureAnim(dict) then
        dict, clip = presentation.fallbackDict, presentation.fallbackClip
        if not ObIlegalClient.EnsureAnim(dict) then return end
    end
    TaskPlayAnim(ped, dict, clip, 3.5, -3.5, duration, 1, 0.0, false, false, false)
end

local function playSearchAnimation()
    local ped = PlayerPedId()
    local dict = IsPedMale(ped)
        and 'amb@prop_human_atm@male@idle_a'
        or 'amb@prop_human_atm@female@idle_a'
    local clip = 'idle_a'
    if not ObIlegalClient.EnsureAnim(dict) then
        dict, clip = 'amb@prop_human_bum_bin@base', 'base'
        if not ObIlegalClient.EnsureAnim(dict) then return false end
    end
    TaskPlayAnim(ped, dict, clip, 2.5, -2.5, -1, 1, 0.0, false, false, false)
    return true
end

local function runProgress(classId, seconds)
    local presentation = routePresentation[classId] or routePresentation.humano
    local duration = math.max(1000, math.floor((tonumber(seconds) or 5) * 1000))
    playRouteAnimation(presentation, duration)

    local completed = lib.progressCircle({
        duration = duration,
        position = 'bottom',
        label = presentation.label,
        useWhileDead = false,
        allowRagdoll = false,
        allowCuffed = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
            sprint = true,
        },
    })
    ClearPedTasks(PlayerPedId())
    return completed == true
end

local function runHumanHack(seconds)
    if not runProgress('humano', seconds) then return false end
    playSearchAnimation()

    if GetResourceState('glitch-minigames') == 'started' then
        local ok, result = pcall(function()
            return exports['glitch-minigames']:StartCodeCrackGame(45000, 4, 6)
        end)
        if ok then
            ClearPedTasks(PlayerPedId())
            return result == true
        end
    end

    local result = lib.skillCheck({
        { areaSize = 34, speedMultiplier = 0.85 },
        { areaSize = 28, speedMultiplier = 1.05 },
        { areaSize = 22, speedMultiplier = 1.18 },
    }, { 'w', 'a', 's', 'd' }) == true
    ClearPedTasks(PlayerPedId())
    return result
end

ObIlegalAtm.PlayHumanHack = runHumanHack

local function moveAwayFromAtm(entity, distance)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local atmCoords = GetEntityCoords(entity)
    local x, y = pedCoords.x - atmCoords.x, pedCoords.y - atmCoords.y
    local length = math.sqrt((x * x) + (y * y))
    if length < 0.05 then
        local forward = GetEntityForwardVector(entity)
        x, y, length = -forward.x, -forward.y, 1.0
    end

    local target = vector3(
        atmCoords.x + ((x / length) * distance),
        atmCoords.y + ((y / length) * distance),
        pedCoords.z
    )
    TaskGoStraightToCoord(ped, target.x, target.y, target.z, 1.25, 2200, 0.0, 0.2)

    local expiresAt = GetGameTimer() + 2200
    while GetGameTimer() < expiresAt and #(GetEntityCoords(ped) - target) > 0.32 do
        DisableControlAction(0, 21, true)
        DisableControlAction(0, 22, true)
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        Wait(0)
    end
    ClearPedTasks(ped)
    local current = GetEntityCoords(ped)
    if #(current - target) < 1.0 then
        SetEntityCoordsNoOffset(ped, target.x, target.y, target.z, false, false, false)
    end
    SetEntityHeading(ped, GetHeadingFromVector_2d(atmCoords.x - target.x, atmCoords.y - target.y))
    TaskTurnPedToFaceEntity(ped, entity, 600)
    Wait(420)
    return true
end

local function requestImpact(token)
    local ok, response = pcall(function()
        return lib.callback.await('ob_ilegal:server:impactAtm', false, token)
    end)
    return ok and type(response) == 'table' and response.success == true
end

local function performImpact(classId, entity, token)
    local presentation = routePresentation[classId] or routePresentation.humano
    local ped = PlayerPedId()

    if classId == 'bruxa' then
        if not moveAwayFromAtm(entity, 2.65) then return false end
        playRouteAnimation(presentation, 1800)
        Wait(380)
        if not requestImpact(token) then return false end
        Wait(1150)
    elseif classId == 'vampiro' then
        if not moveAwayFromAtm(entity, 1.0) then return false end
        playRouteAnimation(presentation, 1850)
        Wait(520)
        if not requestImpact(token) then return false end
        Wait(1050)
    elseif classId == 'curandeira' then
        moveAwayFromAtm(entity, 1.55)
        playRouteAnimation(presentation, 2100)
        Wait(650)
        if not requestImpact(token) then return false end
        Wait(1250)
    else
        if not moveAwayFromAtm(entity, 0.92) then return false end
        playRouteAnimation(presentation, 1200)
        Wait(420)
        if not requestImpact(token) then return false end
        Wait(850)
    end

    ClearPedTasks(ped)
    return true
end

local function performRoute(classId, seconds, entity, token)
    if classId == 'humano' then
        if not moveAwayFromAtm(entity, 0.92) then return false end
        if not runHumanHack(seconds) then return false end
        return performImpact(classId, entity, token)
    end

    if not moveAwayFromAtm(entity, 0.92) then return false end
    playSearchAnimation()
    local minigameSuccess = ObIlegalMinigames.Play(classId, seconds)
    ClearPedTasks(PlayerPedId())
    if not minigameSuccess then return false end
    return performImpact(classId, entity, token)
end

local function finishAttempt(token, successful)
    local ok, result = pcall(function()
        return lib.callback.await('ob_ilegal:server:finishAtm', false, token, successful == true)
    end)

    activeAttempt = nil
    ObIlegalClient.SetBusy(false)
    ClearPedTasks(PlayerPedId())

    if not ok or type(result) ~= 'table' then
        ObIlegalClient.Notify('A conexão com o caixa foi perdida.', 'error')
        return
    end
    if not result.success then
        ObIlegalClient.NotifyReason(result.reason)
        return
    end

    ObIlegalClient.Notify(
        ('Caixa rompido. %d montes de dinheiro cairam no chao.'):format(tonumber(result.dropCount) or 0),
        'success'
    )
end

local function startAtm(entity)
    if activeAttempt or not entity or entity == 0 or not DoesEntityExist(entity) then return end

    local unavailable, reason = ObIlegalClient.IsUnavailable()
    if unavailable then
        ObIlegalClient.NotifyReason(reason)
        return
    end

    local coords = GetEntityCoords(entity)
    local payload = {
        model = GetEntityModel(entity),
        coords = { x = coords.x, y = coords.y, z = coords.z },
    }

    local ok, response = pcall(function()
        return lib.callback.await('ob_ilegal:server:beginAtm', false, payload)
    end)
    if not ok or type(response) ~= 'table' or response.success ~= true then
        if type(response) == 'table' and response.key and response.remaining then
            setAtmState(response.key, 'cooldown', response.remaining)
        end
        ObIlegalClient.NotifyReason(type(response) == 'table' and response.reason or nil)
        return
    end

    activeAttempt = response.token
    setAtmState(response.key, 'busy', response.timeout)
    ObIlegalClient.SetBusy(true)
    turnToAtm(entity)

    CreateThread(function()
        local routeOk, successful = pcall(
            performRoute,
            response.class,
            response.duration,
            entity,
            response.token
        )
        finishAttempt(response.token, routeOk and successful == true)
    end)
end

RegisterNetEvent('ob_ilegal:client:atmState', function(key, status, remaining)
    if not key then return end
    setAtmState(key, status, remaining)
end)

CreateThread(function()
    local states = lib.callback.await('ob_ilegal:server:getAtmStates', false)
    if type(states) == 'table' then
        for key, state in pairs(states) do
            setAtmState(key, state.status, state.remaining)
        end
    end

    exports.ox_target:addModel(Config.Atm.models, {
        {
            name = targetName,
            icon = 'fa-solid fa-sack-dollar',
            label = 'Violar caixa eletrônico',
            distance = Config.Atm.interactionDistance,
            canInteract = function(entity)
                local unavailable = ObIlegalClient.IsUnavailable()
                return not unavailable and not isAtmLocked(entity)
            end,
            onSelect = function(data)
                startAtm(data.entity)
            end,
        },
    })
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    exports.ox_target:removeModel(Config.Atm.models, targetName)
    if activeAttempt then
        ObIlegalMinigames.Cancel()
        TriggerServerEvent('ob_ilegal:server:cancelAtm', activeAttempt)
    end
    activeAttempt = nil
    ObIlegalClient.SetBusy(false)
end)
