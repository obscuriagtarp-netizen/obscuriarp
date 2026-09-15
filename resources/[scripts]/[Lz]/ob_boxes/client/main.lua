local necklaceStatus = {
    active = false,
    class = nil,
    item = nil,
    maxHealthBonus = 0,
}

local wisdomExpiresAt = 0
local wisdomThreadRunning = false
local refreshSequence = 0

local function notify(description, notificationType)
    lib.notify({
        title = 'Obscuria',
        description = description,
        type = notificationType or 'inform',
    })
end

local function applyNecklaceStatus(status)
    if type(status) ~= 'table' then return end

    local wasHumanActive = necklaceStatus.active
        and necklaceStatus.class == 'humano'
        and (tonumber(necklaceStatus.maxHealthBonus) or 0) > 0

    necklaceStatus = status

    local isHumanActive = status.active == true
        and status.class == 'humano'
        and (tonumber(status.maxHealthBonus) or 0) > 0

    if not wasHumanActive and not isHumanActive then return end

    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then return end

    local baseHealth = math.max(100, tonumber(Config.HumanBaseMaxHealth) or 200)
    local targetMax = baseHealth + (isHumanActive and math.floor(tonumber(status.maxHealthBonus) or 0) or 0)
    SetEntityMaxHealth(ped, targetMax)

    if GetEntityHealth(ped) > targetMax then
        SetEntityHealth(ped, targetMax)
    end
end

local function refreshEffects(delay)
    refreshSequence = refreshSequence + 1
    local sequence = refreshSequence

    CreateThread(function()
        Wait(tonumber(delay) or 0)
        if sequence ~= refreshSequence then return end

        local status = lib.callback.await('ob_boxes:server:getEffects', false)
        applyNecklaceStatus(status)

        if GetResourceState('ob_essencias') == 'started' then
            pcall(function()
                exports.ob_essencias:RefreshEssencia()
            end)
        end
    end)
end

local function startWisdomThread()
    if wisdomThreadRunning then return end
    wisdomThreadRunning = true

    CreateThread(function()
        local player = PlayerId()

        while GetGameTimer() < wisdomExpiresAt do
            Wait(0)
            local multiplier = tonumber(Config.Potions.elixir_sabedoria.speedMultiplier) or 1.25
            SetRunSprintMultiplierForPlayer(player, multiplier)
            SetPedMoveRateOverride(PlayerPedId(), multiplier)
        end

        SetRunSprintMultiplierForPlayer(player, 1.0)
        SetPedMoveRateOverride(PlayerPedId(), 1.0)
        wisdomThreadRunning = false
    end)
end

RegisterNetEvent('ob_boxes:client:openBox', function(boxName, slot)
    local box = Config.Boxes[tostring(boxName or '')]
    if not box then
        notify(Config.Messages.invalidBox, 'error')
        return
    end

    local contextId = ('ob_boxes_%s_%s'):format(boxName, tonumber(slot) or 0)
    local options = {}

    for index, option in ipairs(box.options or {}) do
        local optionIndex = index
        local optionData = option
        options[#options + 1] = {
            title = optionData.label or optionData.item,
            description = optionData.description,
            icon = 'gift',
            image = optionData.image,
            onSelect = function()
                local confirmation = lib.alertDialog({
                    header = optionData.label or optionData.item,
                    content = 'Confirmar esta escolha? A caixa será consumida.',
                    centered = true,
                    cancel = true,
                    labels = {
                        confirm = 'Escolher',
                        cancel = 'Voltar',
                    },
                })

                if confirmation ~= 'confirm' then
                    lib.showContext(contextId)
                    return
                end

                local result = lib.callback.await('ob_boxes:server:redeem', false, boxName, slot, optionIndex)
                if type(result) == 'table' then
                    notify(result.message or Config.Messages.redeemFailed, result.success and 'success' or 'error')
                end
            end,
        }
    end

    lib.registerContext({
        id = contextId,
        title = box.label or 'Abrir caixa',
        description = box.description,
        options = options,
    })
    lib.showContext(contextId)
end)

RegisterNetEvent('ob_boxes:client:updateEffects', function(status)
    applyNecklaceStatus(status)

    if GetResourceState('ob_essencias') == 'started' then
        pcall(function()
            exports.ob_essencias:RefreshEssencia()
        end)
    end
end)

RegisterNetEvent('ob_boxes:client:applyWisdom', function(health, speedMultiplier, durationMs)
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then return end

    health = math.max(0, math.floor(tonumber(health) or 0))
    if health > 0 then
        SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + health))
    end

    Config.Potions.elixir_sabedoria.speedMultiplier = math.max(1.0, math.min(1.49, tonumber(speedMultiplier) or 1.25))
    durationMs = math.max(1000, math.floor(tonumber(durationMs) or 600000))
    wisdomExpiresAt = math.max(GetGameTimer(), wisdomExpiresAt) + durationMs
    startWisdomThread()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshEffects(700)
end)

RegisterNetEvent('qbx_core:client:onSetMetaData', function(key)
    if key == Config.ClassMetadataKey then
        refreshEffects(100)
    end
end)

AddEventHandler('ox_inventory:equipmentChanged', function()
    refreshEffects(100)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() or resourceName == 'ox_inventory' or resourceName == 'ob_essencias' then
        refreshEffects(800)
    end
end)

CreateThread(function()
    while true do
        Wait(60000)
        refreshEffects(0)
    end
end)

CreateThread(function()
    while true do
        Wait(2000)

        if necklaceStatus.active
            and necklaceStatus.class == 'humano'
            and (tonumber(necklaceStatus.maxHealthBonus) or 0) > 0 then
            local ped = PlayerPedId()
            local targetMax = math.max(100, tonumber(Config.HumanBaseMaxHealth) or 200)
                + math.floor(tonumber(necklaceStatus.maxHealthBonus) or 0)

            if GetEntityMaxHealth(ped) ~= targetMax then
                SetEntityMaxHealth(ped, targetMax)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    SetPedMoveRateOverride(PlayerPedId(), 1.0)

    if necklaceStatus.active and necklaceStatus.class == 'humano' then
        local ped = PlayerPedId()
        local baseHealth = math.max(100, tonumber(Config.HumanBaseMaxHealth) or 200)
        SetEntityMaxHealth(ped, baseHealth)
        if GetEntityHealth(ped) > baseHealth then SetEntityHealth(ped, baseHealth) end
    end
end)

exports('GetNecklaceEffect', function()
    return necklaceStatus
end)

exports('IsWisdomActive', function()
    return GetGameTimer() < wisdomExpiresAt, math.max(0, wisdomExpiresAt - GetGameTimer())
end)
