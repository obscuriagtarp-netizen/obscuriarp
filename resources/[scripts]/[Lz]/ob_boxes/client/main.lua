local artifactStatus = {
    active = false,
    class = nil,
    item = nil,
    maxHealthBonus = 0,
    corrupted = false,
    staminaRechargeMultiplier = 1.0,
    underwaterTimeMultiplier = 1.0,
}

local wisdomExpiresAt = 0
local wisdomThreadRunning = false
local wisdomSpeedMultiplier = 1.25
local dizzinessExpiresAt = 0
local dizzinessToken = 0
local refreshSequence = 0

local function notify(description, notificationType)
    lib.notify({
        title = 'Obscuria',
        description = description,
        type = notificationType or 'inform',
    })
end

local function applyHumanHealthBonus(status)
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then return end

    local active = status.active == true
        and status.class == 'humano'
        and (tonumber(status.maxHealthBonus) or 0) > 0
    local baseHealth = math.max(100, tonumber(Config.HumanBaseMaxHealth) or 200)
    local targetMax = baseHealth + (active and math.floor(tonumber(status.maxHealthBonus) or 0) or 0)

    SetEntityMaxHealth(ped, targetMax)
    if GetEntityHealth(ped) > targetMax then SetEntityHealth(ped, targetMax) end
end

local function applyMovementEffects(status)
    local ped = PlayerPedId()
    local underwaterMultiplier = math.max(1.0, tonumber(status.underwaterTimeMultiplier) or 1.0)
    local baseUnderwater = math.max(1.0, tonumber(Config.Effects.baseUnderwaterSeconds) or 10.0)

    if ped ~= 0 and DoesEntityExist(ped) then
        SetPedMaxTimeUnderwater(ped, baseUnderwater * underwaterMultiplier)
    end
end

local function applyCorruption(active)
    active = active == true
    if artifactStatus.corrupted == active then return end

    if active then
        AnimpostfxPlay('Rampage', 0, true)
        ShakeGameplayCam('DRUNK_SHAKE', 0.18)
    else
        AnimpostfxStop('Rampage')
        if GetGameTimer() >= dizzinessExpiresAt then StopGameplayCamShaking(true) end
    end
end

local function applyArtifactStatus(status)
    if type(status) ~= 'table' then return end

    applyCorruption(status.corrupted)
    artifactStatus = status
    applyHumanHealthBonus(status)
    applyMovementEffects(status)
end

local function refreshEffects(delay)
    refreshSequence = refreshSequence + 1
    local sequence = refreshSequence

    CreateThread(function()
        Wait(tonumber(delay) or 0)
        if sequence ~= refreshSequence then return end

        local status = lib.callback.await('ob_boxes:server:getEffects', false)
        applyArtifactStatus(status)

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
            SetRunSprintMultiplierForPlayer(player, wisdomSpeedMultiplier)
            SetPedMoveRateOverride(PlayerPedId(), wisdomSpeedMultiplier)
        end

        SetRunSprintMultiplierForPlayer(player, 1.0)
        SetPedMoveRateOverride(PlayerPedId(), 1.0)
        wisdomThreadRunning = false
    end)
end

local function startDizziness(durationMs)
    durationMs = math.max(1000, math.floor(tonumber(durationMs) or 60000))
    dizzinessExpiresAt = math.max(GetGameTimer(), dizzinessExpiresAt) + durationMs
    dizzinessToken = dizzinessToken + 1
    local token = dizzinessToken

    CreateThread(function()
        local animSet = 'move_m@drunk@verydrunk'
        lib.requestAnimSet(animSet)
        SetPedMovementClipset(PlayerPedId(), animSet, 1.0)
        SetPedMotionBlur(PlayerPedId(), true)
        AnimpostfxPlay('DrugsTrevorClownsFight', 0, true)
        ShakeGameplayCam('DRUNK_SHAKE', 0.55)

        while token == dizzinessToken and GetGameTimer() < dizzinessExpiresAt do
            Wait(500)
        end
        if token ~= dizzinessToken then return end

        local ped = PlayerPedId()
        ResetPedMovementClipset(ped, 1.0)
        SetPedMotionBlur(ped, false)
        AnimpostfxStop('DrugsTrevorClownsFight')
        if artifactStatus.corrupted then
            ShakeGameplayCam('DRUNK_SHAKE', 0.18)
        else
            StopGameplayCamShaking(true)
        end
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
    applyArtifactStatus(status)

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

    wisdomSpeedMultiplier = math.max(1.0, math.min(1.49, tonumber(speedMultiplier) or 1.25))
    durationMs = math.max(1000, math.floor(tonumber(durationMs) or 600000))
    wisdomExpiresAt = math.max(GetGameTimer(), wisdomExpiresAt) + durationMs
    startWisdomThread()
end)

RegisterNetEvent('ob_boxes:client:applyDizziness', function(durationMs)
    startDizziness(durationMs)
end)

RegisterNetEvent('ob_boxes:client:applyHealthRegen', function(amount)
    local deathState = tonumber(LocalPlayer.state['qbx_medical:deathState']) or 1
    if deathState ~= 1 or LocalPlayer.state.isDead == true then return end

    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then return end
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount > 0 then
        SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + amount))
    end
end)

RegisterNetEvent('ob_boxes:client:applyFullRestore', function()
    CreateThread(function()
        Wait(150)
        local ped = PlayerPedId()
        if ped == 0 or not DoesEntityExist(ped) then return end

        applyHumanHealthBonus(artifactStatus)
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        ClearPedBloodDamage(ped)
        ClearPedLastDamageBone(ped)

        if GetResourceState('qbx_medical') == 'started' then
            pcall(function()
                exports.qbx_medical:RemoveBleed(4)
            end)
        end
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshEffects(700)
end)

RegisterNetEvent('qbx_core:client:onSetMetaData', function(key)
    if key == Config.ClassMetadataKey then refreshEffects(100) end
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
        applyHumanHealthBonus(artifactStatus)
        applyMovementEffects(artifactStatus)
    end
end)

CreateThread(function()
    while true do
        Wait(250)

        local multiplier = math.max(1.0, tonumber(artifactStatus.staminaRechargeMultiplier) or 1.0)
        if multiplier > 1.0 then
            local ped = PlayerPedId()
            if ped ~= 0
                and DoesEntityExist(ped)
                and not IsEntityDead(ped)
                and not IsPedRunning(ped)
                and not IsPedSprinting(ped)
                and not IsPedJumping(ped)
                and not IsPedClimbing(ped)
            then
                local extraRecharge = math.min(0.02, 0.004 * ((multiplier - 1.0) / 0.10))
                RestorePlayerStamina(PlayerId(), extraRecharge)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    local player = PlayerId()
    local ped = PlayerPedId()
    SetRunSprintMultiplierForPlayer(player, 1.0)
    SetPedMoveRateOverride(ped, 1.0)
    SetPedMaxTimeUnderwater(ped, math.max(1.0, tonumber(Config.Effects.baseUnderwaterSeconds) or 10.0))
    SetPedMotionBlur(ped, false)
    ResetPedMovementClipset(ped, 1.0)
    AnimpostfxStop('Rampage')
    AnimpostfxStop('DrugsTrevorClownsFight')
    StopGameplayCamShaking(true)

    if artifactStatus.active and artifactStatus.class == 'humano' then
        local baseHealth = math.max(100, tonumber(Config.HumanBaseMaxHealth) or 200)
        SetEntityMaxHealth(ped, baseHealth)
        if GetEntityHealth(ped) > baseHealth then SetEntityHealth(ped, baseHealth) end
    end
end)

exports('GetNecklaceEffect', function()
    return artifactStatus
end)

exports('GetArtifactEffects', function()
    return artifactStatus
end)

exports('GetHealerPowerMultiplier', function(abilityId)
    if tostring(abilityId or ''):lower() == 'voo' or artifactStatus.corrupted then return 1.0 end
    return math.max(1.0, tonumber(artifactStatus.healerPowerMultiplier) or 1.0)
end)

exports('IsWisdomActive', function()
    return GetGameTimer() < wisdomExpiresAt, math.max(0, wisdomExpiresAt - GetGameTimer())
end)
