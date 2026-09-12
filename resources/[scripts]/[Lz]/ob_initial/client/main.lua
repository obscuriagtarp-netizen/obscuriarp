local uiOpen = false
local activeMode = nil
local guidePed = nil
local targetRegistered = false
local tutorialRequestPending = false
local tutorialCheckedThisSession = false
local tutorialRequestGeneration = 0
local tutorialCompletedThisSession = false
local preCharacterCallback = nil
local nuiReady = false

local function claimUiFocus(recenter)
    if not uiOpen then return end

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    if recenter then SetCursorLocation(0.5, 0.5) end
end

local function debugLog(message, ...)
    if Config.Debug then
        print(('[ob_initial] ' .. message):format(...))
    end
end

local function emitPreCharacterResult(completed, shown)
    local result = {
        completed = completed == true,
        shown = shown == true,
    }

    TriggerEvent('ob_initial:client:preCharacterFinished', result)

    local callback = preCharacterCallback
    preCharacterCallback = nil
    if type(callback) == 'function' then
        pcall(callback, result)
    end
end

local function closeUi(completed)
    local wasOpen = uiOpen
    local closingPreCharacter = activeMode == 'precharacter'
    uiOpen = false
    activeMode = nil
    if wasOpen then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        pcall(function() SetNuiZIndex(0) end)
    end
    SendNUIMessage({ action = 'close' })

    if closingPreCharacter then
        if completed == true then tutorialCompletedThisSession = true end
        emitPreCharacterResult(completed == true, true)
    end
end

local function canOpenGuide()
    local ped = PlayerPedId()
    return DoesEntityExist(ped)
        and not IsEntityDead(ped)
        and not IsPedInAnyVehicle(ped, false)
        and not IsPauseMenuActive()
end

local function openFlow(mode, slides, startIndex, totalPages)
    if uiOpen or type(slides) ~= 'table' or #slides == 0 then return false end
    if mode == 'guide' and not canOpenGuide() then return false end

    uiOpen = true
    activeMode = mode
    pcall(function() SetNuiZIndex(1100) end)
    claimUiFocus(true)
    SendNUIMessage({
        action = 'open',
        mode = mode,
        slides = slides,
        startIndex = tonumber(startIndex) or 1,
        totalPages = tonumber(totalPages) or #slides,
    })
    return true
end

CreateThread(function()
    while true do
        if uiOpen then
            claimUiFocus(false)
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            Wait(0)
        else
            Wait(250)
        end
    end
end)

local function openTutorial(startIndex, mode)
    local tutorial = Config.Tutorial or {}
    if tutorial.enabled == false then return false end
    return openFlow(mode == 'precharacter' and 'precharacter' or 'tutorial', tutorial.slides or {}, startIndex, tutorial.totalPages)
end

local function openGuide()
    local guide = Config.Guide or {}
    if guide.enabled == false then return false end
    return openFlow('guide', guide.slides or {}, 1, #(guide.slides or {}))
end

RegisterNetEvent('ob_initial:client:openTutorial', function(startIndex)
    openTutorial(startIndex)
end)

RegisterNetEvent('ob_initial:client:openGuide', function()
    openGuide()
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    if uiOpen then claimUiFocus(true) else closeUi() end
    cb({ ok = true })
end)

RegisterNUICallback('claimFocus', function(_, cb)
    claimUiFocus(false)
    cb({ ok = uiOpen })
end)

RegisterNUICallback('close', function(_, cb)
    closeUi()
    cb({ ok = true })
end)

RegisterNUICallback('complete', function(_, cb)
    local completed = true
    if activeMode == 'tutorial' or activeMode == 'precharacter' then
        local ok, result = pcall(function()
            return lib.callback.await('ob_initial:server:completeTutorial', false)
        end)
        completed = ok and result == true
    end

    closeUi(completed)
    cb({ ok = completed })
end)

RegisterNUICallback('choice', function(data, cb)
    local mode = activeMode
    local choiceId = type(data) == 'table' and tostring(data.id or '') or ''
    local slideId = type(data) == 'table' and tostring(data.slideId or '') or ''

    TriggerEvent('ob_initial:client:onChoice', mode, slideId, choiceId)
    cb({ ok = true })
end)

RegisterNUICallback('starterVehicle', function(_, cb)
    if activeMode ~= 'guide' then
        cb({ ok = false, message = 'Esta ação só está disponível durante a conversa com Edward.' })
        return
    end

    local result = lib.callback.await('ob_initial:server:claimStarterVehicle', false)
    cb(type(result) == 'table' and result or {
        ok = false,
        message = 'Não foi possível registrar o veículo agora.',
    })
end)

RegisterNUICallback('openTutorial', function(_, cb)
    closeUi()
    SetTimeout(100, function()
        openTutorial(1)
    end)
    cb({ ok = true })
end)

local function tutorialEnvironmentReady()
    local ped = PlayerPedId()
    if not NetworkIsPlayerActive(PlayerId()) or not DoesEntityExist(ped) then return false end
    if IsEntityDead(ped) or IsPauseMenuActive() or not IsScreenFadedIn() then return false end
    if type(IsNuiFocused) == 'function' and IsNuiFocused() then return false end

    return QBX
        and QBX.PlayerData
        and QBX.PlayerData.citizenid ~= nil
end

local function requestPreCharacterTutorial(callback)
    local tutorial = Config.Tutorial or {}
    if type(callback) == 'function' then preCharacterCallback = callback end

    if tutorial.enabled == false then
        emitPreCharacterResult(true, false)
        return
    end

    if tutorialCompletedThisSession then
        emitPreCharacterResult(true, false)
        return
    end

    if tutorialRequestPending then
        tutorialRequestGeneration = tutorialRequestGeneration + 1
        tutorialRequestPending = false
    end

    if uiOpen then
        if activeMode ~= 'precharacter' then emitPreCharacterResult(false, false) end
        return
    end

    tutorialRequestPending = true
    tutorialRequestGeneration = tutorialRequestGeneration + 1
    local generation = tutorialRequestGeneration

    CreateThread(function()
        Wait(tonumber(tutorial.preCharacterDelay) or 250)
        if generation ~= tutorialRequestGeneration then return end

        local readyDeadline = GetGameTimer() + 10000
        while not nuiReady and GetGameTimer() < readyDeadline do Wait(50) end
        if generation ~= tutorialRequestGeneration then return end
        if not nuiReady then
            tutorialRequestPending = false
            debugLog('A NUI não ficou pronta para o tutorial pré-personagem.')
            emitPreCharacterResult(false, false)
            return
        end

        local ok, shouldOpen = pcall(function()
            return lib.callback.await('ob_initial:server:shouldOpen', false)
        end)

        if generation ~= tutorialRequestGeneration then return end
        tutorialRequestPending = false

        if not ok then
            debugLog('Falha ao consultar o tutorial pré-personagem: %s', tostring(shouldOpen))
            emitPreCharacterResult(false, false)
            return
        end

        tutorialCheckedThisSession = true
        if not shouldOpen then
            tutorialCompletedThisSession = true
            emitPreCharacterResult(true, false)
            return
        end

        if not openTutorial(1, 'precharacter') then
            emitPreCharacterResult(false, false)
        end
    end)
end

AddEventHandler('ob_initial:client:openBeforeCharacter', function(callback)
    requestPreCharacterTutorial(callback)
end)

local function requestInitialTutorial()
    local tutorial = Config.Tutorial or {}
    if tutorial.enabled == false or tutorialRequestPending or tutorialCheckedThisSession then return end

    tutorialRequestPending = true
    tutorialRequestGeneration = tutorialRequestGeneration + 1
    local generation = tutorialRequestGeneration

    Wait(tonumber(tutorial.openDelay) or 1800)

    local readySince
    local deadline = GetGameTimer() + 45000
    while generation == tutorialRequestGeneration and GetGameTimer() < deadline do
        if tutorialEnvironmentReady() then
            readySince = readySince or GetGameTimer()
            if GetGameTimer() - readySince >= 2000 then break end
        else
            readySince = nil
        end
        Wait(250)
    end

    if generation ~= tutorialRequestGeneration then return end
    tutorialRequestPending = false
    if not readySince or GetGameTimer() - readySince < 2000 then
        debugLog('Tutorial aguardará o próximo carregamento: jogador ainda não estabilizou.')
        return
    end

    local ok, shouldOpen = pcall(function()
        return lib.callback.await('ob_initial:server:shouldOpen', false)
    end)
    if not ok then
        debugLog('Falha ao consultar o tutorial inicial: %s', tostring(shouldOpen))
        return
    end

    tutorialCheckedThisSession = true
    if shouldOpen and not uiOpen then openTutorial(1) end
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    if (Config.Tutorial or {}).autoOpenAfterCharacter == true then
        CreateThread(requestInitialTutorial)
    end
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    tutorialRequestGeneration = tutorialRequestGeneration + 1
    tutorialRequestPending = false
    tutorialCheckedThisSession = false
    tutorialCompletedThisSession = false
    preCharacterCallback = nil
    closeUi()
end)

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end

    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(20) end
    return HasModelLoaded(hash) and hash or nil
end

local function registerGuideTarget()
    if not guidePed or not DoesEntityExist(guidePed) then return end
    if GetResourceState('ox_target') ~= 'started' then return end

    local guide = Config.Guide or {}
    exports.ox_target:addLocalEntity(guidePed, {
        {
            name = 'ob_initial_guide',
            icon = guide.targetIcon or 'fa-solid fa-book-open',
            label = guide.targetLabel or 'Conversar com o guia',
            distance = tonumber(guide.interactionDistance) or 2.2,
            canInteract = function()
                return not uiOpen and canOpenGuide()
            end,
            onSelect = openGuide,
        },
    })
    targetRegistered = true
end

local function deleteGuide()
    if targetRegistered and guidePed and GetResourceState('ox_target') == 'started' then
        pcall(function()
            exports.ox_target:removeLocalEntity(guidePed, 'ob_initial_guide')
        end)
    end
    targetRegistered = false

    if guidePed and DoesEntityExist(guidePed) then DeleteEntity(guidePed) end
    guidePed = nil
end

local function createGuide()
    local guide = Config.Guide or {}
    if guide.enabled == false or not guide.coords then return end
    if guidePed and DoesEntityExist(guidePed) then return end
    guidePed = nil

    local hash = loadModel(guide.model or 'ig_bankman')
    if not hash then
        debugLog('Modelo do guia não pôde ser carregado: %s', tostring(guide.model))
        return
    end

    local coords = guide.coords
    guidePed = CreatePed(0, hash, coords.x, coords.y, coords.z - 1.0, coords.w, false, false)
    SetEntityAsMissionEntity(guidePed, true, true)
    SetEntityInvincible(guidePed, true)
    SetEntityCanBeDamaged(guidePed, false)
    FreezeEntityPosition(guidePed, true)
    SetBlockingOfNonTemporaryEvents(guidePed, true)
    SetPedCanRagdoll(guidePed, false)
    SetPedCanBeTargetted(guidePed, false)
    SetPedFleeAttributes(guidePed, 0, false)
    SetPedCombatAttributes(guidePed, 17, true)

    if guide.scenario and guide.scenario ~= '' then
        TaskStartScenarioInPlace(guidePed, guide.scenario, 0, true)
        SetPedKeepTask(guidePed, true)
    end

    SetModelAsNoLongerNeeded(hash)
    registerGuideTarget()
end

CreateThread(function()
    Wait(0)
    closeUi()

    if (Config.Tutorial or {}).autoOpenAfterCharacter == true
        and QBX and QBX.PlayerData and QBX.PlayerData.citizenid then
        CreateThread(requestInitialTutorial)
    end
end)

CreateThread(function()
    while true do
        local wait = 1500
        local guide = Config.Guide or {}
        local playerPed = PlayerPedId()

        if guide.enabled ~= false and guide.coords and NetworkIsPlayerActive(PlayerId()) and DoesEntityExist(playerPed) then
            local playerCoords = GetEntityCoords(playerPed)
            local configuredCoords = vec3(guide.coords.x, guide.coords.y, guide.coords.z)
            local distance = #(playerCoords - configuredCoords)
            local spawnDistance = tonumber(guide.spawnDistance) or 80.0
            local despawnDistance = math.max(spawnDistance + 20.0, tonumber(guide.despawnDistance) or 120.0)

            if not guidePed or not DoesEntityExist(guidePed) then
                guidePed = nil
                targetRegistered = false
                if distance <= spawnDistance then createGuide() end
            elseif distance >= despawnDistance and not uiOpen then
                deleteGuide()
            else
                if targetRegistered and GetResourceState('ox_target') ~= 'started' then
                    targetRegistered = false
                end
                if not targetRegistered and GetResourceState('ox_target') == 'started' then
                    registerGuideTarget()
                end

                if not targetRegistered and distance < 12.0 then
                    wait = 0
                    local interactionDistance = tonumber(guide.interactionDistance) or 2.2
                    if distance <= interactionDistance and not uiOpen and canOpenGuide() then
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName(('Pressione ~INPUT_CONTEXT~ para %s.'):format(
                            guide.targetLabel or 'conversar com o guia'
                        ))
                        EndTextCommandDisplayHelp(0, false, false, -1)

                        if IsControlJustReleased(0, 38) then openGuide() end
                    end
                end
            end
        end
        Wait(wait)
    end
end)

local commands = Config.Commands or {}
if commands.enabled ~= false then
    RegisterCommand(commands.tutorial or 'tutorial', function()
        openTutorial(1)
    end, false)

    RegisterCommand(commands.guide or 'guia', function()
        openGuide()
    end, false)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    closeUi()
    deleteGuide()
end)

exports('OpenTutorial', openTutorial)
exports('OpenBeforeCharacter', requestPreCharacterTutorial)
exports('OpenGuide', openGuide)
exports('IsOpen', function()
    return uiOpen, activeMode
end)
