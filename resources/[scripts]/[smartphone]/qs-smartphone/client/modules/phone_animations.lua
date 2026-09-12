PhoneAnimations = {}

local currentState = 'closed'
local currentAnim = nil
local transitionToken = 0
local attachedPhoneProp = nil
local runtimeSuspended = false
local watchdogStarted = false
local lastWatchdogReplayAt = 0
local WATCHDOG_INTERVAL_MS = 250
local DEFAULT_CONFIG = {
    enabled = true,
    disableInPeek = true,
    blockInVehicle = false,
    loadTimeoutMs = 1500,
    defaultBlendIn = 3.0,
    defaultBlendOut = 2.0,
    defaultFlag = 49,
    defaultPlaybackRate = 1.0,
    prop = {
        enabled = true,
        model = 'custom_phone_prop',
        bone = 28422,
        offset = { x = 0.0, y = 0.0, z = 0.0 },
        rotation = { x = 0.0, y = 0.0, z = 0.0 },
    },
}
local DEFAULT_STATES = {
    opening = {
        dict = 'cellphone@',
        clip = 'cellphone_text_in',
        durationMs = 340,
        blendIn = 3.2,
        blendOut = 2.0,
        nextState = 'holding',
    },
    holding = {
        dict = 'cellphone@',
        clip = 'cellphone_text_read_base',
        durationMs = -1,
        blendIn = 2.8,
        blendOut = 2.0,
    },
    calling = {
        dict = 'cellphone@',
        clip = 'cellphone_call_out',
        durationMs = 620,
        blendIn = 3.0,
        blendOut = 2.0,
        nextState = 'speaking',
    },
    speaking = {
        dict = 'cellphone@',
        clip = 'cellphone_call_listen_base',
        durationMs = -1,
        blendIn = 2.8,
        blendOut = 2.0,
    },
    peek = {
        dict = 'cellphone@',
        clip = 'cellphone_text_read_base',
        durationMs = -1,
        blendIn = 2.0,
        blendOut = 2.0,
    },
}

---@return table
local function getConfig()
    return DEFAULT_CONFIG
end

---@param ped number
---@param cfg table
---@return boolean
local function isPedEligible(ped, cfg)
    if not DoesEntityExist(ped) then
        return false
    end
    if IsEntityDead(ped) or IsPedFatallyInjured(ped) then
        return false
    end
    if IsPedRagdoll(ped) then
        return false
    end
    if cfg.blockInVehicle ~= false and IsPedInAnyVehicle(ped, false) then
        return false
    end
    return true
end

---@param dict string
---@param timeoutMs number
---@return boolean
local function ensureAnimDict(dict, timeoutMs)
    if type(dict) ~= 'string' or dict == '' then
        return false
    end
    if HasAnimDictLoaded(dict) then
        return true
    end

    RequestAnimDict(dict)
    local startedAt = GetGameTimer()
    while not HasAnimDictLoaded(dict) do
        if (GetGameTimer() - startedAt) >= timeoutMs then
            return false
        end
        Wait(0)
    end
    return true
end

---@param modelHash number
---@param timeoutMs number
---@return boolean
local function ensureModel(modelHash, timeoutMs)
    if modelHash == 0 or not IsModelValid(modelHash) then
        return false
    end
    if HasModelLoaded(modelHash) then
        return true
    end

    RequestModel(modelHash)
    local startedAt = GetGameTimer()
    while not HasModelLoaded(modelHash) do
        if (GetGameTimer() - startedAt) >= timeoutMs then
            return false
        end
        Wait(0)
    end
    return true
end

local function detachAndDeletePhoneProp()
    if not attachedPhoneProp or not DoesEntityExist(attachedPhoneProp) then
        attachedPhoneProp = nil
        return
    end
    DetachEntity(attachedPhoneProp, true, true)
    DeleteEntity(attachedPhoneProp)
    attachedPhoneProp = nil
end

---@param entity number
---@param timeoutMs number
---@return boolean
local function ensureEntityNetworked(entity, timeoutMs)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false
    end

    NetworkRegisterEntityAsNetworked(entity)

    local startedAt = GetGameTimer()
    while not NetworkGetEntityIsNetworked(entity) do
        if (GetGameTimer() - startedAt) >= timeoutMs then
            return false
        end
        NetworkRegisterEntityAsNetworked(entity)
        Wait(0)
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if not netId or netId == 0 then
        return false
    end

    SetNetworkIdExistsOnAllMachines(netId, true)
    SetNetworkIdCanMigrate(netId, false)
    return true
end

---@param ped number
---@param cfg table
local function ensurePhonePropAttached(ped, cfg)
    local propCfg = cfg.prop
    if type(propCfg) ~= 'table' or propCfg.enabled == false then
        detachAndDeletePhoneProp()
        return
    end

    local modelName = type(propCfg.model) == 'string' and propCfg.model or 'ks_qsphone_01'
    local modelHash = joaat(modelName)
    if not ensureModel(modelHash, cfg.loadTimeoutMs or 1500) then
        return
    end

    local networkTimeoutMs = cfg.loadTimeoutMs or 1500
    if attachedPhoneProp and DoesEntityExist(attachedPhoneProp) then
        if IsEntityAttachedToEntity(attachedPhoneProp, ped) and ensureEntityNetworked(attachedPhoneProp, networkTimeoutMs) then
            if PhonePropSkin and PhonePropSkin.onPropReady then
                PhonePropSkin.onPropReady()
            end
            return
        end
        detachAndDeletePhoneProp()
    end

    local pedCoords = GetEntityCoords(ped)
    local obj = CreateObjectNoOffset(modelHash, pedCoords.x, pedCoords.y, pedCoords.z, true, true, false)
    if not obj or obj == 0 or not DoesEntityExist(obj) then
        return
    end

    SetEntityAsMissionEntity(obj, true, true)
    if not ensureEntityNetworked(obj, networkTimeoutMs) then
        DeleteEntity(obj)
        return
    end

    local boneId = type(propCfg.bone) == 'number' and propCfg.bone or 57005
    local boneIndex = GetPedBoneIndex(ped, boneId)
    local offset = type(propCfg.offset) == 'table' and propCfg.offset or {}
    local rotation = type(propCfg.rotation) == 'table' and propCfg.rotation or {}
    local offX = tonumber(offset.x) or 0.13
    local offY = tonumber(offset.y) or 0.03
    local offZ = tonumber(offset.z) or -0.02
    local rotX = tonumber(rotation.x) or -80.0
    local rotY = tonumber(rotation.y) or 150.0
    local rotZ = tonumber(rotation.z) or 15.0

    AttachEntityToEntity(
        obj,
        ped,
        boneIndex,
        offX,
        offY,
        offZ,
        rotX,
        rotY,
        rotZ,
        true,
        true,
        false,
        true,
        2,
        true
    )

    SetModelAsNoLongerNeeded(modelHash)
    attachedPhoneProp = obj

    if PhonePropSkin and PhonePropSkin.onPropReady then
        PhonePropSkin.onPropReady()
    end
end

---@param blendOut number
local function stopCurrent(blendOut)
    local ped = cache.ped
    if not ped then
        currentAnim = nil
        return
    end
    if currentAnim and currentAnim.dict and currentAnim.clip then
        StopAnimTask(ped, currentAnim.dict, currentAnim.clip, blendOut or 1.5)
    end
    ClearPedSecondaryTask(ped)
    detachAndDeletePhoneProp()
    currentAnim = nil
end

---@param stateName string
---@param stateCfg table
---@param cfg table
local function playState(stateName, stateCfg, cfg)
    local ped = cache.ped
    if not ped or not isPedEligible(ped, cfg) then
        stopCurrent(cfg.defaultBlendOut or 2.0)
        currentState = 'closed'
        return
    end

    if not ensureAnimDict(stateCfg.dict, cfg.loadTimeoutMs or 1500) then
        return
    end
    ensurePhonePropAttached(ped, cfg)

    if currentAnim and currentAnim.dict and currentAnim.clip then
        StopAnimTask(ped, currentAnim.dict, currentAnim.clip, stateCfg.blendOut or cfg.defaultBlendOut or 2.0)
    end

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    TaskPlayAnimAdvanced(
        ped,
        stateCfg.dict,
        stateCfg.clip,
        coords.x,
        coords.y,
        coords.z,
        0.0,
        0.0,
        heading,
        stateCfg.blendIn or cfg.defaultBlendIn or 3.0,
        stateCfg.blendOut or cfg.defaultBlendOut or 2.0,
        stateCfg.durationMs or -1,
        stateCfg.flag or cfg.defaultFlag or 49,
        stateCfg.playbackRate or cfg.defaultPlaybackRate or 1.0,
        false,
        false
    )

    currentAnim = {
        dict = stateCfg.dict,
        clip = stateCfg.clip,
    }
    currentState = stateName

    if type(stateCfg.nextState) == 'string' and stateCfg.nextState ~= '' and type(stateCfg.durationMs) == 'number' and stateCfg.durationMs > 0 then
        local myToken = transitionToken
        PhoneProfiler.thread('phoneAnimations.stateTransition', function()
            Wait(math.floor(stateCfg.durationMs))
            if transitionToken ~= myToken then
                return
            end
            if currentState ~= stateName then
                return
            end
            PhoneAnimations.setState(stateCfg.nextState)
        end, { label = '@qs-smartphone/client/modules/phone_animations.lua:271', module = 'phone_animations', feature = 'state_transition' })
    end
end

---@param requestedState string
---@param cfg table
local function forceReplayState(requestedState, cfg)
    local stateCfg = DEFAULT_STATES[requestedState]
    if type(stateCfg) ~= 'table' then
        return
    end
    if type(stateCfg.dict) ~= 'string' or stateCfg.dict == '' then
        return
    end
    if type(stateCfg.clip) ~= 'string' or stateCfg.clip == '' then
        return
    end
    playState(requestedState, stateCfg, cfg)
end

local function startWatchdog()
    if watchdogStarted then
        return
    end
    if not Device.isOpen() then
        return
    end
    watchdogStarted = true

    PhoneProfiler.thread('phoneAnimations.watchdog', function()
        while Device.isOpen() do
            Wait(WATCHDOG_INTERVAL_MS)

            local cfg = getConfig()
            if cfg.enabled ~= true or runtimeSuspended then
                goto continue
            end

            if currentState == 'closed' then
                goto continue
            end
            if currentState == 'peek' and cfg.disableInPeek == true then
                goto continue
            end

            local ped = cache.ped
            if not ped or not isPedEligible(ped, cfg) then
                goto continue
            end
            if not currentAnim or not currentAnim.dict or not currentAnim.clip then
                goto continue
            end

            if IsEntityPlayingAnim(ped, currentAnim.dict, currentAnim.clip, 3) then
                goto continue
            end

            local now = GetGameTimer()
            if (now - lastWatchdogReplayAt) < WATCHDOG_INTERVAL_MS then
                goto continue
            end

            lastWatchdogReplayAt = now
            forceReplayState(currentState, cfg)

            ::continue::
        end
        watchdogStarted = false
    end, { label = '@qs-smartphone/client/modules/phone_animations.lua:309', module = 'phone_animations', feature = 'watchdog' })
end

---@param stateName string
function PhoneAnimations.setState(stateName)
    local cfg = getConfig()
    transitionToken = transitionToken + 1

    if cfg.enabled ~= true then
        stopCurrent(cfg.defaultBlendOut or 2.0)
        currentState = 'closed'
        return
    end
    if runtimeSuspended then
        currentState = type(stateName) == 'string' and stateName or currentState
        return
    end

    local requested = type(stateName) == 'string' and stateName or 'closed'
    if requested == 'closed' then
        stopCurrent(cfg.defaultBlendOut or 2.0)
        currentState = 'closed'
        return
    end
    startWatchdog()

    if requested == 'peek' and cfg.disableInPeek == true then
        stopCurrent(cfg.defaultBlendOut or 2.0)
        currentState = 'peek'
        return
    end

    if requested == currentState then
        return
    end

    local stateCfg = DEFAULT_STATES[requested]
    if type(stateCfg) ~= 'table' then
        return
    end
    if type(stateCfg.dict) ~= 'string' or stateCfg.dict == '' then
        return
    end
    if type(stateCfg.clip) ~= 'string' or stateCfg.clip == '' then
        return
    end

    playState(requested, stateCfg, cfg)
end

---@param reason string|nil
function PhoneAnimations.stop(reason)
    local cfg = getConfig()
    transitionToken = transitionToken + 1
    stopCurrent(cfg.defaultBlendOut or 2.0)
    currentState = 'closed'
    Debug('[phone-anim] stop', reason or 'unspecified')
end

function PhoneAnimations.getState()
    return currentState
end

---@return number|nil
function PhoneAnimations.getPropEntity()
    if attachedPhoneProp and DoesEntityExist(attachedPhoneProp) then
        return attachedPhoneProp
    end
    return nil
end

---@return number
function PhoneAnimations.getPropModelHash()
    local modelName = DEFAULT_CONFIG.prop and DEFAULT_CONFIG.prop.model
    if type(modelName) == 'string' and modelName ~= '' then
        return joaat(modelName)
    end
    return joaat('custom_phone_prop')
end

---@param suspended boolean
---@param reason string|nil
function PhoneAnimations.setRuntimeSuspended(suspended, reason)
    local cfg = getConfig()
    runtimeSuspended = suspended == true

    if runtimeSuspended then
        stopCurrent(cfg.defaultBlendOut or 2.0)
    else
        startWatchdog()
        if currentState ~= 'closed' then
            forceReplayState(currentState, cfg)
        end
    end

    Debug('[phone-anim] runtime-suspend', runtimeSuspended, reason or 'unspecified')
end
