local essence = {
    class = nil,
    key = nil,
    maxKey = nil,
    label = 'Essencia',
    value = 0,
    max = 0,
}

local refreshSequence = 0

local function publishEssence()
    TriggerEvent(
        'ob_essencias:client:updated',
        essence.value,
        essence.max,
        essence.key,
        essence.class,
        essence.label
    )
end

local function applyPayload(payload)
    if type(payload) ~= 'table' then
        return false
    end

    local nextClass = payload.class
    local nextKey = payload.key
    local nextMaxKey = payload.maxKey
    local nextLabel = payload.label or 'Essencia'
    local nextValue = tonumber(payload.value) or 0
    local nextMax = tonumber(payload.max) or 0
    local changed = essence.class ~= nextClass
        or essence.key ~= nextKey
        or essence.maxKey ~= nextMaxKey
        or essence.label ~= nextLabel
        or essence.value ~= nextValue
        or essence.max ~= nextMax

    essence.class = nextClass
    essence.key = nextKey
    essence.maxKey = nextMaxKey
    essence.label = nextLabel
    essence.value = nextValue
    essence.max = nextMax

    if changed then
        publishEssence()
    end
    return true
end

local function refresh(delay)
    refreshSequence = refreshSequence + 1
    local sequence = refreshSequence

    CreateThread(function()
        Wait(tonumber(delay) or 0)
        if sequence ~= refreshSequence or GetResourceState('qbx_core') ~= 'started' then
            return
        end

        local payload = lib.callback.await('ob_essencias:server:get', false)
        applyPayload(payload)
    end)
end

local function changeEssence(amount)
    amount = tonumber(amount)
    if not amount or amount == 0 then
        return false
    end

    local result = lib.callback.await('ob_essencias:server:change', false, amount)
    if type(result) ~= 'table' then
        return false
    end

    if result.key then
        applyPayload(result)
    end
    return result.success == true
end

local function setEssence(value)
    value = tonumber(value)
    if not value then
        return false
    end

    local result = lib.callback.await('ob_essencias:server:set', false, value)
    if type(result) ~= 'table' then
        return false
    end

    if result.key then
        applyPayload(result)
    end
    return result.success == true
end

exports('GetEssencia', function()
    return essence.value
end)

exports('GetMaxEssencia', function()
    return essence.max
end)

exports('GetEssenciaMetaKey', function()
    return essence.key
end)

exports('GetEssenciaLabel', function()
    return essence.label
end)

exports('GetEssenciaSnapshot', function()
    return {
        class = essence.class,
        key = essence.key,
        maxKey = essence.maxKey,
        label = essence.label,
        value = essence.value,
        max = essence.max,
    }
end)

exports('GetModifiedCost', function(amount)
    amount = math.max(0, math.floor(math.abs(tonumber(amount) or 0) + 0.5))
    if amount <= 1 or LocalPlayer.state.obArtifactCorrupted == true then return amount end

    local multiplier = math.max(0.01, tonumber(LocalPlayer.state.obEssenceCostMultiplier) or 1.0)
    if multiplier >= 1.0 then return amount end
    return math.max(1, math.ceil(amount * multiplier))
end)

exports('AddEssencia', function(amount)
    return changeEssence(math.abs(tonumber(amount) or 0))
end)

exports('RemoveEssencia', function(amount)
    return changeEssence(-math.abs(tonumber(amount) or 0))
end)

exports('SetEssencia', setEssence)
exports('RefreshEssencia', function()
    refresh(0)
end)

RegisterNetEvent('ob_essencias:client:update', function(payload)
    applyPayload(payload)
end)

RegisterNetEvent('qbx_core:client:onSetMetaData', function(key, _, newValue)
    if key == Config.ClassMetadataKey then
        refresh(50)
        return
    end

    if key == essence.key and newValue ~= nil then
        local value = tonumber(newValue)
        if value and value ~= essence.value then
            essence.value = value
            publishEssence()
        end
        return
    end

    if key == essence.maxKey and newValue ~= nil then
        refresh(0)
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refresh(350)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() or resourceName == 'qbx_core' or resourceName == 'ob_boxes' then
        refresh(700)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == 'ob_boxes' then
        refresh(50)
    end
end)

CreateThread(function()
    Wait(1200)
    refresh(0)
end)
