local uiOpen = false
local uiReady = false
local uiAcknowledged = false
local uiSyncGeneration = 0
local busy = false
local busyLabel
local lastOpenPayload
local bootstrapActive = false
local characterPreload
local characterPreloadGeneration = 0
local selectionCam
local currentScene
local previewGeneration = 0
local awaitingClassSelection = false
local focusResetGeneration = 0
local focusResetting = false

local characterConfig = Config.Character or {}
characterConfig.dateMin = characterConfig.dateMin or '1900-01-01'
characterConfig.dateMax = characterConfig.dateMax or '2008-12-31'
characterConfig.defaultNationality = characterConfig.defaultNationality or 'Brasileira'
characterConfig.nationalities = characterConfig.nationalities or { characterConfig.defaultNationality }
characterConfig.minNameLength = characterConfig.minNameLength or 2
characterConfig.maxNameLength = characterConfig.maxNameLength or 24

local function debugPrint(message)
    if Config.Debug then print(('[ob_multichar] %s'):format(message)) end
end

local function sendUi(action, data)
    if action == 'open' then
        bootstrapActive = false
        lastOpenPayload = data
        uiAcknowledged = false
    elseif action == 'bootstrap' then
        bootstrapActive = true
    end
    SendNUIMessage({ action = action, data = data })
end

local function syncUiUntilAcknowledged()
    if not uiOpen or not lastOpenPayload then return end

    uiSyncGeneration = uiSyncGeneration + 1
    local generation = uiSyncGeneration

    CreateThread(function()
        for _ = 1, 20 do
            if generation ~= uiSyncGeneration or not uiOpen or uiAcknowledged then return end
            SendNUIMessage({ action = 'open', data = lastOpenPayload })
            SendNUIMessage({ action = 'visible', data = { visible = true } })
            Wait(350)
        end
    end)
end

local function claimUiFocus(recenter)
    if not uiOpen then return end

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    if recenter then SetCursorLocation(0.5, 0.5) end
end

local function resetUiFocus()
    if not uiOpen then return end

    focusResetGeneration = focusResetGeneration + 1
    local generation = focusResetGeneration
    focusResetting = true

    CreateThread(function()
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        Wait(50)

        if generation ~= focusResetGeneration then return end
        if not uiOpen then
            focusResetting = false
            return
        end

        focusResetting = false
        claimUiFocus(true)

        local retryDelays = { 100, 250, 500, 1000, 1500 }
        for i = 1, #retryDelays do
            Wait(retryDelays[i])
            if generation ~= focusResetGeneration or not uiOpen then return end
            claimUiFocus(false)
        end
    end)
end

local function setUiVisible(value)
    local wasOpen = uiOpen
    uiOpen = value == true
    if not uiOpen then
        focusResetGeneration = focusResetGeneration + 1
        focusResetting = false
        uiSyncGeneration = uiSyncGeneration + 1
        uiAcknowledged = false
    end
    if uiOpen then
        claimUiFocus(not wasOpen)
    else
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
    sendUi('visible', { visible = uiOpen })
    if uiOpen then syncUiUntilAcknowledged() end
end

CreateThread(function()
    while true do
        if uiOpen then
            if not focusResetting then claimUiFocus(false) end
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 245, true)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

local function getLoadedPlayerData()
    local ok, data = pcall(function() return exports.qbx_core:GetPlayerData() end)
    return ok and data or nil
end

local function setBusy(value, label)
    busy = value == true
    busyLabel = busy and label or nil
    sendUi('busy', { active = busy, label = label })
end

local function showBootstrap(label)
    label = label or 'Preparando seus registros...'
    uiSyncGeneration = uiSyncGeneration + 1
    uiAcknowledged = false
    lastOpenPayload = nil
    pcall(function() SetNuiZIndex(1000) end)
    setBusy(true, label)
    sendUi('bootstrap', { label = label })
    setUiVisible(true)
    DisplayHud(false)
    DisplayRadar(false)
end

local function destroySelectionCam()
    if selectionCam and DoesCamExist(selectionCam) then
        SetCamActive(selectionCam, false)
        DestroyCam(selectionCam, true)
    end

    selectionCam = nil
    RenderScriptCams(false, false, 250, true, true)
    ClearFocus()
end

local function cleanupSelection()
    previewGeneration = previewGeneration + 1
    bootstrapActive = false
    busy = false
    busyLabel = nil
    setUiVisible(false)
    destroySelectionCam()
    DisplayHud(true)
    DisplayRadar(true)

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    if NetworkIsInTutorialSession() then NetworkEndTutorialSession() end
end

local function requestModel(model)
    local ok = pcall(function() lib.requestModel(model, Config.LoadingModelTimeout) end)
    return ok and HasModelLoaded(model)
end

local function setDefaultPed(gender)
    local model = gender == 1 and joaat('mp_f_freemode_01') or joaat('mp_m_freemode_01')
    if not requestModel(model) then return false end

    SetPlayerModel(cache.playerId, model)
    SetModelAsNoLongerNeeded(model)
    Wait(0)
    SetPedDefaultComponentVariation(PlayerPedId())
    return true
end

local function placePreviewPed()
    if not currentScene then return end

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, currentScene.ped.x, currentScene.ped.y, currentScene.ped.z, false, false, false)
    SetEntityHeading(ped, currentScene.ped.w)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    SetEntityInvincible(ped, true)
    ClearPedTasksImmediately(ped)
end

local function previewPed(citizenId, gender)
    previewGeneration = previewGeneration + 1
    local generation = previewGeneration

    if not citizenId then
        setDefaultPed(gender)
        if generation == previewGeneration then placePreviewPed() end
        return
    end

    local clothing, model = lib.callback.await('qbx_core:server:getPreviewPedData', false, citizenId)
    if generation ~= previewGeneration then return end

    if model and clothing and requestModel(model) then
        SetPlayerModel(cache.playerId, model)
        SetModelAsNoLongerNeeded(model)
        Wait(0)

        local appearance = type(clothing) == 'string' and json.decode(clothing) or clothing
        if appearance then
            pcall(function()
                exports['illenium-appearance']:setPedAppearance(PlayerPedId(), appearance)
            end)
        end
    else
        setDefaultPed(gender)
    end

    if generation == previewGeneration then placePreviewPed() end
end

local function createSelectionCam()
    destroySelectionCam()
    if not currentScene then return end

    local camera = currentScene.camera
    selectionCam = CreateCamWithParams(
        'DEFAULT_SCRIPTED_CAMERA',
        camera.x, camera.y, camera.z,
        -5.0, 0.0, camera.w,
        currentScene.fov or 38.0,
        false,
        0
    )
    SetCamActive(selectionCam, true)
    PointCamAtCoord(selectionCam, currentScene.ped.x, currentScene.ped.y, currentScene.ped.z + 0.62)
    RenderScriptCams(true, false, 500, true, true)
    SetFocusPosAndVel(currentScene.ped.x, currentScene.ped.y, currentScene.ped.z, 0.0, 0.0, 0.0)
end

local function streamSelectionScene()
    if not currentScene then return end

    local coords = currentScene.ped
    local ped = PlayerPedId()
    local deadline = GetGameTimer() + 6000

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    NewLoadSceneStartSphere(coords.x, coords.y, coords.z, 35.0, 0)

    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        Wait(50)
    end

    if IsNewLoadSceneActive() then NewLoadSceneStop() end
end

local function ensureScreenVisible(duration)
    if IsScreenFadedOut() or IsScreenFadingOut() then
        DoScreenFadeIn(duration or 350)
    end
end

local function prepareScene()
    local locations = Config.Scene.locations
    currentScene = locations[math.random(1, #locations)]

    DoScreenFadeOut(150)
    while not IsScreenFadedOut() do Wait(0) end

    placePreviewPed()
    DisplayRadar(false)
    NetworkStartSoloTutorialSession()
    createSelectionCam()

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeIn(250)

    CreateThread(streamSelectionScene)
end

local function formatCharacter(character, slot, classMap)
    if not character then return { slot = slot, empty = true } end

    local charinfo = character.charinfo or {}
    local metadata = character.metadata or {}
    local job = character.job or {}
    local grade = job.grade or {}
    local gang = character.gang or {}
    local money = character.money or {}
    local classId = metadata.classe or metadata.class or classMap[character.citizenid] or 'indefinida'
    local classInfo = Config.Classes[classId] or Config.Classes.indefinida

    return {
        slot = slot,
        empty = false,
        citizenid = character.citizenid,
        firstname = charinfo.firstname or 'Sem',
        lastname = charinfo.lastname or 'nome',
        gender = tonumber(charinfo.gender) or 0,
        birthdate = charinfo.birthdate or 'Não informado',
        nationality = charinfo.nationality or 'Não informada',
        phone = charinfo.phone or 'Não informado',
        account = charinfo.account or 'Não informada',
        bank = tonumber(money.bank) or 0,
        cash = tonumber(money.cash) or 0,
        job = job.label or job.name or 'Desempregado',
        grade = grade.name or grade.label or 'Sem cargo',
        gang = gang.label or gang.name or 'Nenhum',
        class = {
            id = classId,
            label = classInfo.label,
            icon = classInfo.icon,
            accent = classInfo.accent,
        },
    }
end

local function fetchCharacters()
    local characters, amount = lib.callback.await('qbx_core:server:getCharacters')
    characters = type(characters) == 'table' and characters or {}
    amount = math.max(1, tonumber(amount) or #characters, #characters)

    local missingClassIds = {}
    local charactersBySlot = {}
    for i = 1, #characters do
        local character = characters[i]
        if character and character.citizenid then
            local slot = tonumber(character.charinfo and character.charinfo.cid) or i
            charactersBySlot[slot] = character
            local metadata = character.metadata or {}
            if not metadata.classe and not metadata.class then
                missingClassIds[#missingClassIds + 1] = character.citizenid
            end
            amount = math.max(amount, slot)
        end
    end

    local classMap = {}
    if #missingClassIds > 0 then
        classMap = lib.callback.await('ob_multichar:server:getClassMap', false, missingClassIds) or {}
    end

    local result = {}
    for slot = 1, amount do
        result[slot] = formatCharacter(charactersBySlot[slot], slot, classMap)
    end

    return result, amount
end

local function startCharacterPreload()
    characterPreloadGeneration = characterPreloadGeneration + 1
    local preload = {
        generation = characterPreloadGeneration,
        done = false,
    }
    characterPreload = preload

    CreateThread(function()
        local ok, characters, amount = pcall(fetchCharacters)
        if characterPreload ~= preload or preload.generation ~= characterPreloadGeneration then return end

        preload.ok = ok
        preload.characters = characters
        preload.amount = amount
        preload.done = true
    end)
end

local function awaitCharacterPreload()
    local preload = characterPreload
    if not preload then return fetchCharacters() end

    while characterPreload == preload and not preload.done do Wait(20) end
    if characterPreload ~= preload then return fetchCharacters() end

    characterPreload = nil
    if not preload.ok then error(preload.characters) end
    return preload.characters, preload.amount
end

local function openCharacterSelection()
    showBootstrap('Lendo registros...')

    local ok, characters, amount = pcall(awaitCharacterPreload)
    if not ok then
        debugPrint(('Falha ao carregar personagens: %s'):format(characters))
        sendUi('open', {
            characters = { { slot = 1, empty = true } },
            amount = 1,
            selectedSlot = 1,
            deleteEnabled = false,
            dateMin = characterConfig.dateMin,
            dateMax = characterConfig.dateMax,
            defaultNationality = characterConfig.defaultNationality,
            nationalities = characterConfig.nationalities,
        })
        setBusy(false)
        setUiVisible(true)
        ensureScreenVisible()
        sendUi('error', { message = 'Falha ao consultar o Qbox. Reinicie o resource e tente novamente.' })
        return
    end

    local selectedSlot
    local selectedCharacter
    for i = 1, #characters do
        if not characters[i].empty then
            selectedSlot = i
            selectedCharacter = characters[i]
            break
        end
    end

    if not selectedSlot then
        selectedSlot = 1
    end

    sendUi('open', {
        characters = characters,
        amount = amount,
        selectedSlot = selectedSlot,
        deleteEnabled = Config.EnableDelete,
        dateMin = characterConfig.dateMin,
        dateMax = characterConfig.dateMax,
        defaultNationality = characterConfig.defaultNationality,
        nationalities = characterConfig.nationalities,
    })
    setBusy(false)
    setUiVisible(true)
    ensureScreenVisible()

    CreateThread(function()
        if selectedCharacter then
            previewPed(selectedCharacter.citizenid, selectedCharacter.gender)
        else
            previewPed(nil, 0)
        end
    end)
end

local function runInitialTutorial(nextStep)
    local tutorial = Config.InitialTutorial
    if not tutorial.enabled or GetResourceState(tutorial.resource) ~= 'started' then
        nextStep()
        return
    end

    local called = false
    local tutorialOwnsScreen = false
    local function continueFlow()
        if called then return end
        called = true
        nextStep()
    end

    focusResetGeneration = focusResetGeneration + 1
    focusResetting = false
    uiSyncGeneration = uiSyncGeneration + 1
    uiAcknowledged = false
    uiOpen = false
    sendUi('visible', { visible = false })
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    pcall(function() SetNuiZIndex(0) end)

    local ok = pcall(function()
        exports[tutorial.resource]:OpenBeforeCharacter(function()
            continueFlow()
        end)
    end)

    if not ok then
        debugPrint('ob_initial indisponível; seguindo para a seleção.')
        continueFlow()
        return
    end

    CreateThread(function()
        local unopenedDeadline = GetGameTimer() + 15000

        while not called do
            if GetResourceState(tutorial.resource) ~= 'started' then
                debugPrint('ob_initial foi interrompido; seguindo para a seleção.')
                continueFlow()
                return
            end

            local stateOk, isOpen, mode = pcall(function()
                return exports[tutorial.resource]:IsOpen()
            end)

            if stateOk and isOpen and mode == 'precharacter' then
                if not tutorialOwnsScreen then
                    tutorialOwnsScreen = true
                    uiSyncGeneration = uiSyncGeneration + 1
                    uiAcknowledged = false
                    sendUi('visible', { visible = false })
                end
                Wait(100)
            elseif GetGameTimer() >= unopenedDeadline then
                debugPrint('ob_initial não abriu em 15 segundos; usando o fallback.')
                continueFlow()
                return
            else
                Wait(250)
            end
        end
    end)
end

local function beginFlow(showInitial)
    if uiOpen or busy then return end

    showBootstrap('Preparando seus registros...')
    startCharacterPreload()

    local sceneReady, sceneError = pcall(prepareScene)
    if not sceneReady then
        debugPrint(('Falha ao preparar a cena: %s'):format(sceneError))
        ensureScreenVisible(0)
    end
    if showInitial then runInitialTutorial(openCharacterSelection) else openCharacterSelection() end
end

local function capName(value)
    value = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
    return value:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

local function validName(value)
    local length = #value
    return length >= characterConfig.minNameLength
        and length <= characterConfig.maxNameLength
        and value:match("^[%aÀ-ÿ' %-]+$") ~= nil
end

local function spawnNewCharacter(destination)
    local spawn = destination
        and vec4(destination.x, destination.y, destination.z, destination.w or 0.0)
        or (Config.Appearance and Config.Appearance.coords)
        or Config.Spawn.default
    local ped = PlayerPedId()

    DoScreenFadeOut(350)
    Wait(500)
    if NetworkIsInTutorialSession() then NetworkEndTutorialSession() end

    FreezeEntityPosition(ped, true)
    RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
    SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)
    SetEntityHeading(ped, spawn.w)

    local collisionDeadline = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collisionDeadline do
        RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
        Wait(50)
    end

    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    DisplayHud(true)
    DisplayRadar(true)

    Wait(350)
    DoScreenFadeIn(300)

    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
    TriggerEvent('qb-weathersync:client:EnableSync')
    TriggerEvent('qb-clothes:client:CreateFirstCharacter')
end

local function fallbackSpawn()
    local spawn = Config.Spawn.default
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)
    SetEntityHeading(ped, spawn.w)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    DisplayHud(true)
    DisplayRadar(true)
    if NetworkIsInTutorialSession() then NetworkEndTutorialSession() end
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    TriggerEvent('qb-weathersync:client:EnableSync')
    DoScreenFadeIn(400)
end

local function loadCharacter(citizenId)
    if busy then return end
    busy = true
    setBusy(true, 'Abrindo seu destino...')
    DoScreenFadeOut(250)
    setUiVisible(false)

    lib.callback.await('qbx_core:server:loadCharacter', false, citizenId)
    destroySelectionCam()
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityInvincible(PlayerPedId(), false)
    DisplayHud(true)
    DisplayRadar(true)
    if NetworkIsInTutorialSession() then NetworkEndTutorialSession() end

    if Config.Spawn.useQbxSpawn and GetResourceState('qbx_spawn'):find('start') then
        TriggerEvent('qb-spawn:client:setupSpawns')
    else
        fallbackSpawn()
    end

    busy = false
end

local function IsLeapYear(year)
    return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

local function IsValidBirthdate(value)
    local year, month, day = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    year, month, day = tonumber(year), tonumber(month), tonumber(day)

    if not year or not month or not day or month < 1 or month > 12 then
        return false
    end

    local days = { 31, IsLeapYear(year) and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if day < 1 or day > days[month] then
        return false
    end

    return value >= characterConfig.dateMin and value <= characterConfig.dateMax
end

local function createCharacter(data)
    if busy then return end

    local firstname = capName(data.firstname)
    local lastname = capName(data.lastname)
    local nationality = capName(data.nationality)
    local birthdate = tostring(data.birthdate or '')
    local gender = tonumber(data.gender)
    local slot = tonumber(data.slot)

    if not validName(firstname) or not validName(lastname) then
        sendUi('formError', { message = 'Informe nome e sobrenome válidos.' })
        return
    end

    if not validName(nationality) or not IsValidBirthdate(birthdate) or not slot or (gender ~= 0 and gender ~= 1) then
        sendUi('formError', { message = 'Use uma data válida no formato DD/MM/AAAA e revise os demais dados.' })
        return
    end

    busy = true
    setBusy(true, 'Criando personagem...')
    DoScreenFadeOut(250)
    setUiVisible(false)

    local newData = lib.callback.await('qbx_core:server:createCharacter', false, {
        firstname = firstname,
        lastname = lastname,
        nationality = nationality,
        gender = gender,
        birthdate = birthdate,
        cid = slot,
    })

    if not newData then
        busy = false
        setBusy(false)
        DoScreenFadeIn(350)
        openCharacterSelection()
        sendUi('formError', { message = 'Não foi possível criar o personagem.' })
        return
    end

    destroySelectionCam()

    if GetResourceState('classeSelector') == 'started' then
        awaitingClassSelection = true
        setBusy(true, 'Escolha sua classe...')
        TriggerEvent('classeSelector:beginCreation')
        return
    end

    spawnNewCharacter()
    busy = false
end

RegisterNetEvent('classeSelector:creationFinished', function(_, destination)
    if not awaitingClassSelection then return end

    awaitingClassSelection = false
    setBusy(true, 'Preparando seu destino...')
    spawnNewCharacter(destination)
    busy = false
end)

RegisterNetEvent('classeSelector:creationFailed', function()
    if not awaitingClassSelection then return end

    setBusy(true, 'Sincronizando sua classe...')

    SetTimeout(2500, function()
        if not awaitingClassSelection then return end

        if GetResourceState('classeSelector') == 'started' then
            TriggerEvent('classeSelector:beginCreation')
            return
        end

        awaitingClassSelection = false
        spawnNewCharacter()
        busy = false
    end)
end)

local function deleteCharacter(citizenId)
    if busy or not Config.EnableDelete then return end

    busy = true
    setBusy(true, 'Apagando registro...')
    local success = lib.callback.await('qbx_core:server:deleteCharacter', false, citizenId)
    busy = false

    if not success then
        setBusy(false)
        sendUi('error', { message = 'Não foi possível excluir este personagem.' })
        return
    end

    openCharacterSelection()
end

RegisterNUICallback('ready', function(_, cb)
    uiReady = true

    if uiOpen then claimUiFocus(true) end

    if bootstrapActive then
        sendUi('bootstrap', { label = busyLabel or 'Preparando seus registros...' })
    end

    if lastOpenPayload then
        sendUi('open', lastOpenPayload)
    end

    sendUi('visible', { visible = uiOpen })
    sendUi('busy', { active = busy, label = busyLabel })
    cb({ ok = true })
end)

RegisterNUICallback('claimFocus', function(_, cb)
    claimUiFocus(false)
    cb({ ok = true })
end)

RegisterNUICallback('uiAck', function(_, cb)
    uiAcknowledged = true
    resetUiFocus()
    cb({ ok = true })
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    if uiOpen and not busy then
        CreateThread(function() previewPed(data.citizenid, tonumber(data.gender)) end)
    end
    cb({ ok = true })
end)

RegisterNUICallback('previewNew', function(data, cb)
    if uiOpen and not busy then
        CreateThread(function() previewPed(nil, tonumber(data.gender) or 0) end)
    end
    cb({ ok = true })
end)

RegisterNUICallback('playCharacter', function(data, cb)
    cb({ ok = true })
    if uiOpen and type(data.citizenid) == 'string' then
        CreateThread(function() loadCharacter(data.citizenid) end)
    end
end)

RegisterNUICallback('createCharacter', function(data, cb)
    cb({ ok = true })
    if uiOpen then CreateThread(function() createCharacter(data) end) end
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    cb({ ok = true })
    if uiOpen and type(data.citizenid) == 'string' then
        CreateThread(function() deleteCharacter(data.citizenid) end)
    end
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    if GetInvokingResource() then return end
    CreateThread(function() beginFlow(false) end)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        uiReady = false
        uiAcknowledged = false
        uiSyncGeneration = uiSyncGeneration + 1
        lastOpenPayload = nil
        cleanupSelection()
    end
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(100) end
    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)

    local playerData = getLoadedPlayerData()
    if playerData and playerData.citizenid then
        debugPrint('Resource iniciado com jogador carregado; seleção não será reaberta.')
        return
    end

    beginFlow(true)
end)

CreateThread(function()
    while true do
        if uiOpen or busy or awaitingClassSelection or NetworkIsInTutorialSession() then
            HideHudAndRadarThisFrame()
            if uiOpen or awaitingClassSelection or NetworkIsInTutorialSession() then
                SetEntityInvincible(PlayerPedId(), true)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)
