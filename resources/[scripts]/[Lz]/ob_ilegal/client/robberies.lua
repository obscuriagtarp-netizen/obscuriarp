local robberyStates = {}
local targetZones = {}
local activeToken

local stageIcons = {
    lock = 'fa-solid fa-key',
    vault = 'fa-solid fa-vault',
    loot = 'fa-solid fa-sack-dollar',
}

local function normalizeState(state)
    state = type(state) == 'table' and state or {}
    state.cooldownEndsAt = GetGameTimer() + (math.max(0, tonumber(state.cooldown) or 0) * 1000)
    return state
end

local function playWorkAnimation(ped)
    local dictionaries = {
        { 'amb@prop_human_atm@male@idle_a', 'idle_a' },
        { 'amb@prop_human_bum_bin@base', 'base' },
    }
    for index = 1, #dictionaries do
        local entry = dictionaries[index]
        if ObIlegalClient.EnsureAnim(entry[1]) then
            TaskPlayAnim(ped, entry[1], entry[2], 3.0, 2.0, -1, 49, 0.0, false, false, false)
            return
        end
    end
end

local function alignPed(stage)
    local coords = ObIlegalShared.NormalizeCoords(stage.coords)
    if not coords then return end
    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, coords.x, coords.y, coords.z, 650)
    Wait(650)
    if tonumber(stage.heading) then SetEntityHeading(ped, tonumber(stage.heading) + 0.0) end
    playWorkAnimation(ped)
end

local function runStageMinigame(stageType, classId, options)
    if stageType == 'lock' then return ObIlegalMinigames.PlayType('fechadura', options, classId) end
    if stageType == 'vault' then return ObIlegalMinigames.PlayType('cofre', options, classId) end
    if stageType == 'loot' then return ObIlegalMinigames.PlayLoot(classId, options) end
    return false
end

local function startStage(robberyId, stageIndex)
    local unavailable, reason = ObIlegalClient.IsUnavailable()
    if unavailable then
        ObIlegalClient.NotifyReason(reason)
        return false
    end

    local robbery = Config.Robberies and Config.Robberies[robberyId]
    local stage = robbery and robbery.stages and robbery.stages[stageIndex]
    if not stage then return false end

    local response = lib.callback.await('ob_ilegal:server:beginRobberyStage', false, robberyId, stageIndex)
    if not response or response.success ~= true then
        ObIlegalClient.NotifyReason(response and response.reason, 'Esta etapa ainda não pode ser iniciada.')
        return false
    end

    activeToken = response.token
    ObIlegalClient.SetBusy(true)
    alignPed(stage)
    local successful = runStageMinigame(response.stageType, response.class, response.minigame)
    ClearPedTasks(PlayerPedId())

    local result = lib.callback.await('ob_ilegal:server:finishRobberyStage', false, activeToken, successful == true)
    activeToken = nil
    ObIlegalClient.SetBusy(false)

    if not result or result.success ~= true then
        ObIlegalClient.NotifyReason(result and result.reason)
        return false
    end

    if result.final then
        ObIlegalClient.Notify('Tesouraria violada. Recolha o dinheiro antes que seja tarde.', 'success')
    else
        ObIlegalClient.Notify(('Etapa concluída. Próximo mecanismo: %d.'):format(result.nextStage), 'success')
    end
    return true
end

local function canUseStage(robberyId, stageIndex)
    local state = robberyStates[robberyId]
    if state and (state.busy or (state.cooldownEndsAt or 0) > GetGameTimer() or state.stageIndex ~= stageIndex) then
        return false
    end
    local unavailable = ObIlegalClient.IsUnavailable()
    return unavailable ~= true
end

local function registerTargets()
    for robberyId, robbery in pairs(Config.Robberies or {}) do
        if robbery.enabled == true then
            for stageIndex, stage in ipairs(robbery.stages or {}) do
                local coords = ObIlegalShared.NormalizeCoords(stage.coords)
                if coords then
                    local currentRobberyId = robberyId
                    local currentStageIndex = stageIndex
                    local zoneId = exports.ox_target:addSphereZone({
                        coords = vec3(coords.x, coords.y, coords.z),
                        radius = tonumber(stage.radius) or 0.9,
                        debug = false,
                        options = {
                            {
                                name = ('ob_ilegal:%s:%s'):format(robberyId, stage.id or stageIndex),
                                icon = stageIcons[stage.type] or 'fa-solid fa-mask',
                                label = stage.label or ('Executar etapa %d'):format(stageIndex),
                                distance = tonumber(stage.serverDistance) or 3.0,
                                canInteract = function()
                                    return canUseStage(currentRobberyId, currentStageIndex)
                                end,
                                onSelect = function()
                                    CreateThread(function() startStage(currentRobberyId, currentStageIndex) end)
                                end,
                            },
                        },
                    })
                    targetZones[#targetZones + 1] = zoneId
                end
            end
        end
    end
end

RegisterNetEvent('ob_ilegal:client:robberyState', function(robberyId, state)
    if type(robberyId) == 'string' and type(state) == 'table' then
        robberyStates[robberyId] = normalizeState(state)
    end
end)

exports('StartRobberyStage', function(robberyId, stageIndex)
    return startStage(robberyId, tonumber(stageIndex) or 1)
end)

CreateThread(function()
    local states = lib.callback.await('ob_ilegal:server:getRobberyStates', false)
    robberyStates = {}
    for robberyId, state in pairs(type(states) == 'table' and states or {}) do
        robberyStates[robberyId] = normalizeState(state)
    end
    registerTargets()
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if activeToken then TriggerServerEvent('ob_ilegal:server:cancelRobberyStage', activeToken) end
    for index = 1, #targetZones do exports.ox_target:removeZone(targetZones[index]) end
end)
