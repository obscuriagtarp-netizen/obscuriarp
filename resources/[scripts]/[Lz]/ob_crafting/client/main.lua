local isOpen = false
local currentContext = nil
local currentPayload = nil
local requestId = 0
local requests = {}
local targetZones = {}
local activeCraft = nil
local activeProp = nil
local activeScene = nil
local activeSceneObjects = {}
local activeStageProp = nil
local activeCamera = nil
local activeAnimation = nil
local stationProps = {}

local function modelCandidates(value)
    if type(value) == 'table' then return value end
    return value and { value } or {}
end

local function loadModel(value)
    for _, candidate in ipairs(modelCandidates(value)) do
        local model = type(candidate) == 'number' and candidate or joaat(candidate)
        if IsModelInCdimage(model) and IsModelValid(model) then
            RequestModel(model)
            local timeout = GetGameTimer() + 3500
            while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(25) end
            if HasModelLoaded(model) then return model end
        end
    end
end

local function relativeCoords(anchor, offset)
    offset = offset or vec3(0.0, 0.0, 0.0)
    local heading = math.rad(anchor.w or 0.0)
    local rightX, rightY = math.cos(heading), math.sin(heading)
    local forwardX, forwardY = -math.sin(heading), math.cos(heading)
    return vec3(
        anchor.x + rightX * offset.x + forwardX * offset.y,
        anchor.y + rightY * offset.x + forwardY * offset.y,
        anchor.z + offset.z
    )
end

local function deleteObject(entity)
    if entity and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        DetachEntity(entity, true, true)
        DeleteEntity(entity)
    end
end

local function offsetHeight(offset, amount)
    offset = offset or vec3(0.0, 0.0, 0.0)
    return vec3(offset.x, offset.y, offset.z + (tonumber(amount) or 0.0))
end

local function spawnSceneObject(definition, anchor, collection, heightOffset)
    if type(definition) ~= 'table' then return end
    local model = loadModel(definition.models or definition.model)
    if not model then return end
    local position = relativeCoords(anchor, offsetHeight(definition.offset, heightOffset))
    local entity = CreateObjectNoOffset(model, position.x, position.y, position.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if not DoesEntityExist(entity) then return end

    local rotation = definition.rotation or vec3(0.0, 0.0, 0.0)
    SetEntityRotation(entity, rotation.x, rotation.y, (anchor.w or 0.0) + rotation.z, 2, true)
    SetEntityCollision(entity, definition.collision == true, definition.collision == true)
    SetEntityInvincible(entity, true)
    FreezeEntityPosition(entity, true)
    if definition.ground == true then PlaceObjectOnGroundProperly(entity) end
    if collection then collection[#collection + 1] = entity end
    return entity
end

local function destroyCamera()
    if activeCamera and DoesCamExist(activeCamera) then
        SetCamActive(activeCamera, false)
        RenderScriptCams(false, true, 550, true, true)
        DestroyCam(activeCamera, false)
    end
    activeCamera = nil
end

local function destroyActiveScene()
    destroyCamera()
    deleteObject(activeStageProp)
    activeStageProp = nil
    for _, entity in ipairs(activeSceneObjects) do deleteObject(entity) end
    activeSceneObjects = {}
    activeScene = nil
end

local function sceneAnchorFromPlayer(distance)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local origin = vec4(coords.x, coords.y, coords.z, heading)
    local position = relativeCoords(origin, vec3(0.0, distance or 1.05, 0.0))
    return vec4(position.x, position.y, position.z, heading)
end

local function sceneContext(payload)
    local kind = payload and payload.station and tostring(payload.station.kind or '') or ''
    local definition = Config.ImmersiveScenes and Config.ImmersiveScenes[kind]
    if not definition or definition.enabled ~= true then return end

    local station
    if currentContext and currentContext.provider == 'config' then
        station = Config.Stations and Config.Stations[tostring(currentContext.stationId)]
    end
    local coords = station and station.coords
    local anchor = coords and vec4(coords.x, coords.y, coords.z, coords.w or 0.0) or sceneAnchorFromPlayer(1.05)
    return definition, anchor, station, kind
end

local function createRecipeVisual(payload, definition, anchor)
    local visual = payload and payload.recipe and payload.recipe.visual
    if type(visual) ~= 'table' then return end
    local result = definition.result or {}
    local offset = offsetHeight(visual.offset or result.offset or vec3(0.0, 0.0, 0.9), definition.propHeightOffset)
    local rotation = visual.rotation or result.rotation or vec3(0.0, 0.0, 0.0)
    local position = relativeCoords(anchor, offset)
    local entity

    if visual.type == 'weapon' and visual.weapon then
        entity = CreateWeaponObject(joaat(visual.weapon), 0, position.x, position.y, position.z, true, tonumber(visual.scale) or 1.0, 0)
    else
        local model = loadModel(visual.models or visual.model)
        if model then
            entity = CreateObjectNoOffset(model, position.x, position.y, position.z, false, false, false)
            SetModelAsNoLongerNeeded(model)
        end
    end

    if not entity or not DoesEntityExist(entity) then return end
    SetEntityRotation(entity, rotation.x, rotation.y, (anchor.w or 0.0) + rotation.z, 2, true)
    SetEntityCollision(entity, false, false)
    SetEntityInvincible(entity, true)
    FreezeEntityPosition(entity, true)
    activeSceneObjects[#activeSceneObjects + 1] = entity
    return entity
end

local function beginImmersiveScene(payload)
    destroyActiveScene()
    local definition, anchor, station, kind = sceneContext(payload)
    if not definition then return end
    activeScene = { definition = definition, anchor = anchor, kind = kind }

    local sceneOptions = station and station.scene or nil
    local hasPersistentBench = station and stationProps[tostring(currentContext.stationId)]
    if not hasPersistentBench and (not station or (sceneOptions and sceneOptions.spawnBench == true)) then
        spawnSceneObject((sceneOptions and sceneOptions.bench) or definition.bench, anchor, activeSceneObjects)
    end
    for _, prop in ipairs(definition.decorations or {}) do
        spawnSceneObject(prop, anchor, activeSceneObjects, definition.propHeightOffset)
    end
    createRecipeVisual(payload, definition, anchor)

    local ped = PlayerPedId()
    if definition.alignPlayer == true then
        local playerPosition = relativeCoords(anchor, definition.playerOffset)
        SetEntityCoordsNoOffset(ped, playerPosition.x, playerPosition.y, playerPosition.z, false, false, false)
        SetEntityHeading(ped, (anchor.w or 0.0) + (definition.playerHeadingOffset or 0.0))
    end

    local camera = definition.camera
    if camera then
        local cameraPosition = relativeCoords(anchor, camera.offset)
        local focus = relativeCoords(anchor, camera.focus)
        activeCamera = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', cameraPosition.x, cameraPosition.y, cameraPosition.z, 0.0, 0.0, 0.0, camera.fov or 43.0, true, 2)
        PointCamAtCoord(activeCamera, focus.x, focus.y, focus.z)
        SetCamActive(activeCamera, true)
        RenderScriptCams(true, true, 650, true, true)
    end
end

local function updateSceneStep(stepKey)
    deleteObject(activeStageProp)
    activeStageProp = nil
    if not activeScene or not stepKey then return end
    local definition = activeScene.definition.stepProps and activeScene.definition.stepProps[tostring(stepKey)]
    if definition then
        activeStageProp = spawnSceneObject(definition, activeScene.anchor, nil, activeScene.definition.propHeightOffset)
    end
end

local function requestServer(action, data, callback)
    requestId = requestId + 1
    requests[requestId] = callback
    TriggerServerEvent('ob_crafting:server:request', requestId, action, data or {})
end

RegisterNetEvent('ob_crafting:client:response', function(token, payload)
    local callback = requests[tonumber(token)]
    if not callback then return end
    requests[tonumber(token)] = nil
    callback(payload or {})
end)

local function destroyProp()
    deleteObject(activeProp)
    activeProp = nil
end

local function stopAnimation()
    local ped = PlayerPedId()
    if activeAnimation and activeAnimation.dict and activeAnimation.clip then
        StopAnimTask(ped, activeAnimation.dict, activeAnimation.clip, 1.0)
        RemoveAnimDict(activeAnimation.dict)
    end
    activeAnimation = nil
    ClearPedSecondaryTask(ped)
    ClearPedTasksImmediately(ped)
    TaskClearLookAt(ped)
    FreezeEntityPosition(ped, false)
    destroyProp()
end

local function loadAnimation(animation, skipProp)
    if type(animation) ~= 'table' then return end
    local ped = PlayerPedId()
    if animation.dict and animation.clip then
        RequestAnimDict(animation.dict)
        local timeout = GetGameTimer() + 3500
        while not HasAnimDictLoaded(animation.dict) and GetGameTimer() < timeout do Wait(25) end
        if HasAnimDictLoaded(animation.dict) then
            TaskPlayAnim(ped, animation.dict, animation.clip, 3.0, 3.0, -1, 1, 0.0, false, false, false)
            activeAnimation = { dict = animation.dict, clip = animation.clip }
        elseif animation.fallbackScenario then
            TaskStartScenarioInPlace(ped, animation.fallbackScenario, 0, true)
        end
    elseif animation.scenario then
        TaskStartScenarioInPlace(ped, animation.scenario, 0, true)
    end

    local prop = not skipProp and animation.prop or nil
    if not prop or (not prop.model and not prop.models) then return end
    local model = loadModel(prop.models or prop.model)
    if not model then return end
    local coords = GetEntityCoords(ped)
    activeProp = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, false, false, false)
    if DoesEntityExist(activeProp) then
        local pos, rot = prop.pos or vec3(0.0, 0.0, 0.0), prop.rot or vec3(0.0, 0.0, 0.0)
        SetEntityCollision(activeProp, false, false)
        AttachEntityToEntity(activeProp, ped, GetPedBoneIndex(ped, prop.bone or 57005), pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
    end
    SetModelAsNoLongerNeeded(model)
end

local function stageCoords(payload, step)
    local stages = payload and payload.station and payload.station.stages
    local key = step and tostring(step.stage or '') or ''
    local stage = type(stages) == 'table' and stages[key]
    if type(stage) ~= 'table' then return end
    if not tonumber(stage.x) or not tonumber(stage.y) or not tonumber(stage.z) then return end
    return stage
end

local function moveToStage(stage)
    if not stage then return true end
    local ped = PlayerPedId()
    local destination = vec3(stage.x + 0.0, stage.y + 0.0, stage.z + 0.0)
    local arrivalDistance = math.max(0.35, tonumber(Config.StageArrivalDistance) or 0.8)
    local timeout = GetGameTimer() + math.max(3000, tonumber(Config.StageMoveTimeout) or 15000)

    stopAnimation()
    if #(GetEntityCoords(ped) - destination) > arrivalDistance then
        TaskFollowNavMeshToCoord(ped, destination.x, destination.y, destination.z, 1.0, timeout - GetGameTimer(), arrivalDistance * 0.65, false, tonumber(stage.w) or 0.0)
        while activeCraft and not IsEntityDead(ped) and #(GetEntityCoords(ped) - destination) > arrivalDistance and GetGameTimer() < timeout do
            Wait(100)
        end
    end

    ClearPedTasksImmediately(ped)
    if not activeCraft or IsEntityDead(ped) or #(GetEntityCoords(ped) - destination) > arrivalDistance + 0.45 then return false end
    if stage.w ~= nil then SetEntityHeading(ped, tonumber(stage.w) or GetEntityHeading(ped)) end
    return true
end

local function refreshInterface()
    if not isOpen or not currentContext or currentContext.preview then return end
    requestServer('bootstrap', { context = currentContext }, function(payload)
        if not isOpen then return end
        if payload.ok then
            currentPayload = payload
            SendNUIMessage({ action = 'refresh', payload = payload })
        else
            SendNUIMessage({ action = 'feedback', payload = payload })
        end
    end)
end

local function finishCraft(result)
    stopAnimation()
    destroyActiveScene()
    activeCraft = nil
    if not isOpen then return end
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'craftComplete', payload = result or { ok = false, error = 'server_error' } })
    if result and result.ok then SetTimeout(500, refreshInterface) end
end

local function runCraft(payload, preview)
    local ped = PlayerPedId()
    activeCraft = { token = payload.token, preview = preview == true }
    stopAnimation()
    if payload.heading then SetEntityHeading(ped, payload.heading + 0.0) end
    beginImmersiveScene(payload)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'craftStarted', payload = payload })

    CreateThread(function()
        local duration = math.max(1, math.floor(tonumber(payload.duration) or 4)) * 1000
        local steps = payload.recipe and payload.recipe.steps or {}
        local stepCount = math.max(1, #steps)
        local stepDuration = duration / stepCount
        local function playStep(index)
            local step = steps[index]
            local kind = payload.station and tostring(payload.station.kind or '') or ''
            local kindAnimation = step and Config.KindAnimations and Config.KindAnimations[kind] and Config.KindAnimations[kind][tostring(step.key or '')]
            local animation = step and Config.Animations[tostring(kindAnimation or step.animation or '')] or payload.animation
            stopAnimation()
            if not moveToStage(stageCoords(payload, step)) then return false end
            FreezeEntityPosition(ped, true)
            updateSceneStep(step and step.key)
            local onlyAnimation = kind == 'kitchen' and payload.station and type(payload.station.stages) == 'table'
            loadAnimation(animation or Config.Animations.utility, onlyAnimation)
            return true
        end

        for index = 1, stepCount do
            if not activeCraft or not playStep(index) then
                local token = activeCraft and activeCraft.token
                activeCraft = nil
                if token and not preview then requestServer('cancel', { token = token }, function() end) end
                finishCraft({ ok = false, error = 'interrupted' })
                return
            end
            local stepEndsAt = GetGameTimer() + stepDuration
            while activeCraft and GetGameTimer() < stepEndsAt do
                if IsEntityDead(ped) then
                    local token = activeCraft.token
                    activeCraft = nil
                    if not preview then requestServer('cancel', { token = token }, function() end) end
                    finishCraft({ ok = false, error = 'interrupted' })
                    return
                end
                Wait(150)
            end
        end
        if not activeCraft then return end
        if preview then
            local outputAmount = payload.recipe and payload.recipe.output and payload.recipe.output.amount or 1
            finishCraft({ ok = true, label = payload.recipe and payload.recipe.output and payload.recipe.output.label or 'Producao concluida', amount = outputAmount * math.max(1, tonumber(payload.quantity) or 1) })
            return
        end
        requestServer('complete', { token = payload.token }, finishCraft)
    end)
end

local function openPayload(payload, context)
    if not payload or not payload.ok then return false end
    currentContext = context
    currentPayload = payload
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', payload = payload })
    return true
end

local function closeInterface()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if activeCraft then
        local token = activeCraft.token
        activeCraft = nil
        if not currentContext or not currentContext.preview then requestServer('cancel', { token = token }, function() end) end
        stopAnimation()
        destroyActiveScene()
    end
    currentContext = nil
    currentPayload = nil
end

local function canOpen()
    local ped = PlayerPedId()
    return not IsEntityDead(ped) and not IsPedInAnyVehicle(ped, false) and not IsPauseMenuActive()
end

local function openStation(stationId)
    if not canOpen() then return end
    local context = { provider = 'config', stationId = tostring(stationId) }
    requestServer('bootstrap', { context = context }, function(payload)
        if payload.ok then openPayload(payload, context) end
    end)
end

local function openRestaurantStation(stationType, restaurantId, pointId)
    if not canOpen() then return end
    local context = { provider = 'restaurant', stationType = tostring(stationType), restaurantId = tostring(restaurantId), pointId = tonumber(pointId) }
    requestServer('bootstrap', { context = context }, function(payload)
        if payload.ok then openPayload(payload, context) end
    end)
end

exports('OpenStation', openStation)
exports('OpenRestaurantStation', openRestaurantStation)

RegisterNetEvent('ob_crafting:client:open', openStation)
RegisterNetEvent('ob_crafting:client:openRestaurant', openRestaurantStation)

RegisterNUICallback('close', function(_, cb)
    closeInterface()
    cb({ ok = true })
end)

RegisterNUICallback('beginCraft', function(data, cb)
    if not isOpen or activeCraft then cb({ ok = false, error = 'already_crafting' }) return end
    if currentContext and currentContext.preview then
        local recipe
        for _, candidate in ipairs(currentPayload.recipes or {}) do if tostring(candidate.id) == tostring(data.recipeId) then recipe = candidate break end end
        if not recipe then cb({ ok = false, error = 'recipe_not_found' }) return end
        local quantity = math.max(1, math.min(math.floor(tonumber(Config.MaxCraftQuantity) or 20), math.floor(tonumber(data.quantity) or 1)))
        local increase = math.max(0, tonumber(Config.QuantityTimeIncreasePercent) or 0.12)
        local duration = math.ceil((tonumber(recipe.duration) or 4) * (1 + (quantity - 1) * increase))
        duration = math.min(math.floor(tonumber(Config.MaximumDuration) or 120), duration)
        local payload = { ok = true, token = 'preview', duration = duration, quantity = quantity, recipe = recipe, station = currentPayload.station, animation = Config.Animations[currentPayload.station.animation] or Config.Animations.utility }
        cb(payload)
        runCraft(payload, true)
        return
    end
    requestServer('begin', {
        context = currentContext,
        recipeId = data.recipeId,
        quantity = data.quantity
    }, function(payload)
        cb(payload)
        if payload.ok then runCraft(payload, false) end
    end)
end)

RegisterCommand(Config.PreviewCommand, function(_, args)
    if isOpen then closeInterface() return end
    requestServer('preview', { kind = tostring(args[1] or 'kitchen'):lower() }, function(payload)
        if payload.ok then openPayload(payload, { preview = true }) end
    end)
end, false)

local function destroyStationProps()
    for stationId, entity in pairs(stationProps) do
        deleteObject(entity)
        stationProps[stationId] = nil
    end
end

local function spawnStationBench(stationId, station)
    local sceneOptions = station.scene
    if type(sceneOptions) ~= 'table' or sceneOptions.spawnBench ~= true then return end
    local definition = Config.ImmersiveScenes and Config.ImmersiveScenes[tostring(station.kind or '')]
    if not definition or not station.coords then return end
    local coords = station.coords
    local anchor = vec4(coords.x, coords.y, coords.z, coords.w or 0.0)
    local entity = spawnSceneObject(sceneOptions.bench or definition.bench, anchor)
    if entity then stationProps[tostring(stationId)] = entity end
end

local function removeTargets()
    for _, zoneId in ipairs(targetZones) do pcall(function() exports.ox_target:removeZone(zoneId) end) end
    targetZones = {}
end

local function registerTargets()
    removeTargets()
    destroyStationProps()
    for stationId, station in pairs(Config.Stations or {}) do
        if station.enabled == true and station.coords then
            spawnStationBench(stationId, station)
            local capturedId = stationId
            local zoneId = exports.ox_target:addSphereZone({
                coords = vec3(station.coords.x, station.coords.y, station.coords.z),
                radius = Config.InteractionDistance,
                debug = Config.Debug,
                options = {
                    {
                        name = 'ob_crafting_' .. stationId,
                        label = station.label or 'Usar bancada',
                        icon = 'fa-solid fa-screwdriver-wrench',
                        distance = Config.InteractionDistance + 0.5,
                        canInteract = canOpen,
                        onSelect = function() openStation(capturedId) end
                    }
                }
            })
            targetZones[#targetZones + 1] = zoneId
        end
    end
end

CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(500) end
    Wait(500)
    registerTargets()
end)

CreateThread(function()
    while true do
        local sleep = 750
        if not isOpen and not activeCraft then
            local playerCoords = GetEntityCoords(PlayerPedId())
            for stationId, station in pairs(Config.Stations or {}) do
                if station.enabled == true and station.coords then
                    local coords = vec3(station.coords.x, station.coords.y, station.coords.z)
                    local distance = #(playerCoords - coords)
                    if distance <= 10.0 then
                        sleep = 0
                        if GetResourceState('ob_markers') == 'started' then
                            pcall(function()
                                exports.ob_markers:Draw('bancada', coords, {
                                    distance = distance,
                                    drawDistance = 10.0,
                                    height = 1.0,
                                    size = 0.92,
                                })
                            end)
                        end

                        if distance <= (tonumber(Config.InteractionDistance) or 2.0) and IsControlJustReleased(0, 38) then
                            openStation(stationId)
                            Wait(350)
                            break
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        if activeCraft then
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 75, true)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        if isOpen and not activeCraft then
            local ped = PlayerPedId()
            if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) or IsPauseMenuActive() then closeInterface() end
            Wait(250)
        else
            Wait(1000)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    removeTargets()
    destroyStationProps()
    SetNuiFocus(false, false)
    stopAnimation()
    destroyActiveScene()
end)
