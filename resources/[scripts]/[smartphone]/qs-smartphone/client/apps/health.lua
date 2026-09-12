local HEALTH_CONFIG = Config.Health or {}
local OPEN_STATE_CHECK_INTERVAL_MS = 500
local STEP_SAMPLE_INTERVAL_MS = tonumber(HEALTH_CONFIG.stepSampleIntervalMs) or 250
local STEP_MIN_SPEED_MPS = tonumber(HEALTH_CONFIG.minStepSpeedMps) or 1.2
local STEP_MAX_SPEED_MPS = tonumber(HEALTH_CONFIG.maxStepSpeedMps) or 12.0
local STEP_MAX_SAMPLE_SECONDS = tonumber(HEALTH_CONFIG.maxStepSampleSeconds) or 1.5
local STEP_METERS_PER_STEP = tonumber(HEALTH_CONFIG.stepMetersPerStep)
if not STEP_METERS_PER_STEP or STEP_METERS_PER_STEP <= 0 then
    local legacyFactor = tonumber(HEALTH_CONFIG.stepFactor)
    if legacyFactor and legacyFactor > 0 then
        STEP_METERS_PER_STEP = 1.0 / legacyFactor
    else
        STEP_METERS_PER_STEP = 0.75
    end
end
local DEFAULT_NOTICE_SETTINGS = {
    { type = 'health',  value = 35, notice = true },
    { type = 'hungry',  value = 30, notice = true },
    { type = 'thirsty', value = 30, notice = true },
}

local HealthState = {
    stepsPending = 0,
    stepDistanceAccumulator = 0.0,
    lastStepSampleAtMs = nil,
    cachedNoticeSettings = nil,
    pendingNoticeSettings = nil,
    wasDeviceOpen = false,
}

---@param value unknown
---@param minValue number
---@param maxValue number
---@return number
local function clampInteger(value, minValue, maxValue)
    local parsed = math.floor(tonumber(value) or minValue)
    if parsed < minValue then return minValue end
    if parsed > maxValue then return maxValue end
    return parsed
end

---@return number
local function getHealthPercent()
    local ped = cache.ped
    if not ped or ped == 0 then
        return 100
    end

    local raw = GetEntityHealth(ped)
    local normalized = math.floor((raw - 100) + 0.5)
    return clampInteger(normalized, 0, 100)
end

---@param statusName string
---@return number?
local function getEsxStatusPercent(statusName)
    if Config.Framework ~= 'esx' then
        return nil
    end
    if GetResourceState('esx_status') ~= 'started' then
        return nil
    end

    local p = promise.new()
    TriggerEvent('esx_status:getStatus', statusName, function(status)
        if not status then
            p:resolve(nil)
            return
        end

        local value = nil
        if status.getPercent then
            value = status:getPercent()
        else
            value = status.percent or status.val or status.value
        end

        p:resolve(clampInteger(value, 0, 100))
    end)

    return Citizen.Await(p)
end

---@return number, number
local function getNeedsPercent()
    local hungry = nil
    local thirsty = nil

    local playerData = cfr and cfr.getPlayerData and cfr:getPlayerData() or nil
    local metadata = playerData and playerData.metadata or nil
    if type(metadata) == 'table' then
        hungry = metadata.hunger or metadata.hungry
        thirsty = metadata.thirst or metadata.thirsty
    end

    if hungry == nil then
        hungry = getEsxStatusPercent('hunger')
    end
    if thirsty == nil then
        thirsty = getEsxStatusPercent('thirst')
    end

    hungry = clampInteger(hungry or 100, 0, 100)
    thirsty = clampInteger(thirsty or 100, 0, 100)
    return hungry, thirsty
end

local function updatePendingSteps()
    local sampleAt = GetGameTimer()
    local ped = cache.ped
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        HealthState.lastStepSampleAtMs = sampleAt
        HealthState.stepDistanceAccumulator = 0.0
        return
    end

    local lastSampleAt = HealthState.lastStepSampleAtMs
    HealthState.lastStepSampleAtMs = sampleAt
    if not lastSampleAt then
        return
    end

    local elapsedMs = sampleAt - lastSampleAt
    if elapsedMs <= 0 then
        return
    end

    local elapsedSeconds = math.min((elapsedMs / 1000.0), STEP_MAX_SAMPLE_SECONDS)
    if elapsedSeconds <= 0 then
        return
    end

    if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then
        HealthState.stepDistanceAccumulator = 0.0
        return
    end

    if IsPedJumping(ped) or IsPedFalling(ped) or IsPedRagdoll(ped) or IsPedSwimming(ped) then
        return
    end

    local speed = GetEntitySpeed(ped)
    if speed < STEP_MIN_SPEED_MPS then
        return
    end

    -- Keep counting during long sprints; cap unrealistic spikes instead of stopping the counter.
    local effectiveSpeed = math.min(speed, STEP_MAX_SPEED_MPS)
    HealthState.stepDistanceAccumulator = HealthState.stepDistanceAccumulator + (effectiveSpeed * elapsedSeconds)
    local stepsDelta = math.floor(HealthState.stepDistanceAccumulator / STEP_METERS_PER_STEP)
    if stepsDelta <= 0 then
        return
    end

    HealthState.stepDistanceAccumulator = HealthState.stepDistanceAccumulator - (stepsDelta * STEP_METERS_PER_STEP)
    HealthState.stepsPending = HealthState.stepsPending + stepsDelta
end

local function flushStepsToServer()
    if HealthState.stepsPending <= 0 then
        return true
    end

    local payload = { delta = HealthState.stepsPending }
    local response = lib.callback.await('phone:health:steps:sync', false, payload)
    if response and response.success == true then
        HealthState.stepsPending = 0
        return true
    end
    return false
end

local function flushNoticeSettingsToServer()
    if type(HealthState.pendingNoticeSettings) ~= 'table' then
        return true
    end

    local response = lib.callback.await('phone:health:notice:set', false, {
        items = HealthState.pendingNoticeSettings,
    })
    if response and response.success == true then
        HealthState.pendingNoticeSettings = nil
        return true
    end
    return false
end

local function flushHealthOnPhoneClose()
    flushStepsToServer()
    flushNoticeSettingsToServer()
end

local function cloneNoticeSettings(source)
    local out = {}
    local target = type(source) == 'table' and source or DEFAULT_NOTICE_SETTINGS
    for index = 1, #target do
        local item = target[index]
        if type(item) == 'table' then
            out[#out + 1] = {
                type = item.type,
                value = clampInteger(item.value, 5, 100),
                notice = item.notice == true,
            }
        end
    end
    if #out == 0 then
        for index = 1, #DEFAULT_NOTICE_SETTINGS do
            local item = DEFAULT_NOTICE_SETTINGS[index]
            out[#out + 1] = {
                type = item.type,
                value = item.value,
                notice = item.notice,
            }
        end
    end
    return out
end

local function buildLocalInsights(metrics)
    return {
        {
            id = 'daily-steps',
            label = i18n.t('apps.health.backend.insights.steps_label'),
            value = tostring(metrics.steps),
            description = i18n.t('apps.health.backend.insights.steps_description'),
        },
        {
            id = 'vitality',
            label = i18n.t('apps.health.backend.insights.vitality_label'),
            value = ('%s%%'):format(metrics.health),
            description = i18n.t('apps.health.backend.insights.vitality_description'),
        },
        {
            id = 'needs',
            label = i18n.t('apps.health.backend.insights.needs_label'),
            value = ('%s%% / %s%%'):format(metrics.hungry, metrics.thirsty),
            description = i18n.t('apps.health.backend.insights.needs_description', {
                hunger = metrics.hungry >= 60 and i18n.t('apps.health.backend.insights.stable') or i18n.t('apps.health.backend.insights.low'),
                thirst = metrics.thirsty >= 60 and i18n.t('apps.health.backend.insights.stable') or i18n.t('apps.health.backend.insights.low'),
            }),
        },
    }
end

PhoneProfiler.thread('health.stepSampler', function()
    while true do
        Wait(STEP_SAMPLE_INTERVAL_MS)
        updatePendingSteps()
    end
end, { label = '@qs-smartphone/client/apps/health.lua:245', module = 'health', feature = 'step_sampler' })

PhoneProfiler.thread('health.openStateWatcher', function()
    while true do
        Wait(OPEN_STATE_CHECK_INTERVAL_MS)
        local isOpen = Device and Device.isOpen and Device.isOpen() or false
        if HealthState.wasDeviceOpen and not isOpen then
            flushHealthOnPhoneClose()
        end
        HealthState.wasDeviceOpen = isOpen == true
    end
end, { label = '@qs-smartphone/client/apps/health.lua:252', module = 'health', feature = 'open_state_watcher' })

RegisterNUICallback('health:bootstrap', function(_, cb)
    updatePendingSteps()

    local health = getHealthPercent()
    local hungry, thirsty = getNeedsPercent()
    local metrics = {
        health = health,
        hungry = hungry,
        thirsty = thirsty,
        steps = HealthState.stepsPending,
    }
    local noticeSettings = cloneNoticeSettings(HealthState.pendingNoticeSettings or HealthState.cachedNoticeSettings)
    HealthState.cachedNoticeSettings = noticeSettings

    cb({
        success = true,
        data = {
            metrics = metrics,
            noticeSettings = noticeSettings,
            insights = buildLocalInsights(metrics),
        }
    })
end)

RegisterNUICallback('health:notice:get', function(_, cb)
    if type(HealthState.pendingNoticeSettings) == 'table' then
        cb({ success = true, data = cloneNoticeSettings(HealthState.pendingNoticeSettings) })
        return
    end
    if type(HealthState.cachedNoticeSettings) == 'table' then
        cb({ success = true, data = cloneNoticeSettings(HealthState.cachedNoticeSettings) })
        return
    end
    HealthState.cachedNoticeSettings = cloneNoticeSettings(nil)
    cb({ success = true, data = cloneNoticeSettings(HealthState.cachedNoticeSettings) })
end)

RegisterNUICallback('health:notice:set', function(data, cb)
    local payload = type(data) == 'table' and data or {}
    if type(payload.items) == 'table' then
        local normalized = cloneNoticeSettings(payload.items)
        HealthState.cachedNoticeSettings = normalized
        HealthState.pendingNoticeSettings = normalized
        cb({ success = true, data = { updated = true } })
        return
    end
    cb({ success = false, error = 'INVALID_NOTICE_PAYLOAD' })
end)
