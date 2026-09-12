ObIlegalMinigames = ObIlegalMinigames or {}

local activeGame
local gameSequence = 0

local function closeNui()
    SendNUIMessage({ action = 'closeAtmMinigame' })
    SetNuiFocus(false, false)
end

local function resolveGame(success)
    local current = activeGame
    if not current then return end
    activeGame = nil
    closeNui()
    current.promise:resolve(success == true)
end

RegisterNUICallback('atmMinigameResult', function(data, callback)
    callback({ success = true })
    resolveGame(type(data) == 'table' and data.success == true)
end)

local function playNui(mode, options)
    if activeGame then return false end
    options = type(options) == 'table' and options or {}

    gameSequence = gameSequence + 1
    local gameId = gameSequence
    local seconds = tonumber(options.timeLimit) or 24
    local timeLimit = math.max(10000, math.floor(seconds * 1000))
    local deferred = promise.new()
    activeGame = {
        id = gameId,
        promise = deferred,
    }

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = 'openAtmMinigame',
        mode = mode,
        timeLimit = timeLimit,
        options = options,
    })

    CreateThread(function()
        local expiresAt = GetGameTimer() + timeLimit + 2000
        while activeGame and activeGame.id == gameId and GetGameTimer() < expiresAt do
            local ped = PlayerPedId()
            if ped == 0 or IsPedDeadOrDying(ped, true) or IsPedInAnyVehicle(ped, false) then
                resolveGame(false)
                return
            end
            Wait(250)
        end
        if activeGame and activeGame.id == gameId then resolveGame(false) end
    end)

    return Citizen.Await(deferred) == true
end

function ObIlegalMinigames.Play(classId, seconds, options)
    if classId ~= 'bruxa' and classId ~= 'vampiro' and classId ~= 'curandeira' then
        return false
    end
    options = type(options) == 'table' and options or {}
    local payload = {}
    for key, value in pairs(options) do payload[key] = value end
    payload.timeLimit = math.max(18, tonumber(payload.timeLimit) or ((tonumber(seconds) or 8) * 3))
    payload.context = payload.context or 'atm'
    return playNui(classId, payload)
end

function ObIlegalMinigames.PlayType(minigameType, options, classId)
    local aliases = {
        lock = 'fechadura',
        fechadura = 'fechadura',
        vault = 'cofre',
        cofre = 'cofre',
    }
    local mode = aliases[tostring(minigameType or ''):lower()]
    if not mode then return false end

    local defaults = mode == 'fechadura' and Config.Minigames.lock or Config.Minigames.vault
    local requestedOptions = type(options) == 'table' and options or {}
    classId = tostring(classId or requestedOptions.classId or ObIlegalClient.GetClass() or 'humano'):lower()
    if classId ~= 'bruxa' and classId ~= 'vampiro' and classId ~= 'curandeira' then classId = 'humano' end

    local merged = {}
    for key, value in pairs(defaults or {}) do
        if type(value) ~= 'table' then merged[key] = value end
    end
    for key, value in pairs((defaults and defaults[classId]) or {}) do merged[key] = value end
    for key, value in pairs(requestedOptions) do
        if type(value) ~= 'table' then merged[key] = value end
    end
    for key, value in pairs(requestedOptions[classId] or {}) do merged[key] = value end
    merged.classId = classId
    return playNui(mode, merged)
end

function ObIlegalMinigames.PlayLoot(classId, options)
    options = type(options) == 'table' and options or {}
    if classId == 'bruxa' or classId == 'vampiro' or classId == 'curandeira' then
        local seconds = math.max(6, (tonumber(options.timeLimit) or 30) / 3)
        local payload = {}
        for key, value in pairs(options) do payload[key] = value end
        payload.context = 'loot'
        return ObIlegalMinigames.Play(classId, seconds, payload)
    end
    return ObIlegalMinigames.PlayType('cofre', options)
end

exports('StartLockMinigame', function(options)
    return ObIlegalMinigames.PlayType('fechadura', options, options and options.classId)
end)

exports('StartVaultMinigame', function(options)
    return ObIlegalMinigames.PlayType('cofre', options, options and options.classId)
end)

exports('StartLootMinigame', function(classId, options)
    return ObIlegalMinigames.PlayLoot(classId or ObIlegalClient.GetClass(), options)
end)

exports('StartMinigame', function(minigameType, options)
    if minigameType == 'loot' then
        return ObIlegalMinigames.PlayLoot(ObIlegalClient.GetClass(), options)
    end
    return ObIlegalMinigames.PlayType(minigameType, options)
end)

function ObIlegalMinigames.Cancel()
    resolveGame(false)
end

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    activeGame = nil
    closeNui()
end)
