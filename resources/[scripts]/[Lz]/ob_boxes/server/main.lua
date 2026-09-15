local opening = {}
local corruptionState = {}

local function normalize(value)
    return tostring(value or ''):lower()
end

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

local function getClass(source)
    local player = getPlayer(source)
    local metadata = player and player.PlayerData and player.PlayerData.metadata or {}
    return normalize(metadata[Config.ClassMetadataKey])
end

local function notify(source, description, notificationType)
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Obscuria',
        description = description,
        type = notificationType or 'inform',
    })
end

local function isDurabilityValid(metadata)
    local durability = type(metadata) == 'table' and tonumber(metadata.durability) or nil
    if not durability then return true end
    if durability > 100 then return durability > os.time() end
    return durability > 0
end

local function getEquippedItems(source)
    if GetResourceState('ox_inventory') ~= 'started' then return {} end

    local ok, equipped = pcall(function()
        return exports.ox_inventory:GetEquippedItems(source)
    end)
    return ok and type(equipped) == 'table' and equipped or {}
end

local function applyArtifactDefinition(status, definition)
    status.essenceRegen = status.essenceRegen + math.max(0, tonumber(definition.essenceRegen) or 0)
    status.healthRegen = status.healthRegen + math.max(0, tonumber(definition.healthRegen) or 0)
    status.essenceCostMultiplier = math.min(
        status.essenceCostMultiplier,
        math.max(0.01, tonumber(definition.essenceCostMultiplier) or 1.0)
    )
    status.potionMultiplier = math.max(
        status.potionMultiplier,
        math.max(1.0, tonumber(definition.potionMultiplier) or 1.0)
    )
    status.healerPowerMultiplier = math.max(
        status.healerPowerMultiplier,
        math.max(1.0, tonumber(definition.healerPowerMultiplier) or 1.0)
    )
    status.staminaRechargeMultiplier = math.max(
        status.staminaRechargeMultiplier,
        math.max(1.0, tonumber(definition.staminaRechargeMultiplier) or 1.0)
    )
    status.underwaterTimeMultiplier = math.max(
        status.underwaterTimeMultiplier,
        math.max(1.0, tonumber(definition.underwaterTimeMultiplier) or 1.0)
    )
    status.solarProtection = status.solarProtection or definition.solarProtection == true
end

local function publishEffects(source, status)
    local player = Player(source)
    if not player or not player.state then return end

    player.state:set('obClassNecklace', status.item, true)
    player.state:set('obEssenceBonus', status.essenceBonus, true)
    player.state:set('obMaxHealthBonus', status.maxHealthBonus, true)
    player.state:set('obArtifactCorrupted', status.corrupted, true)
    player.state:set('obEssenceCostMultiplier', status.essenceCostMultiplier, true)
    player.state:set('obPotionMultiplier', status.potionMultiplier, true)
    player.state:set('obHealerPowerMultiplier', status.healerPowerMultiplier, true)
    player.state:set('obEssenceRegen', status.essenceRegen, true)
    player.state:set('obHealthRegen', status.healthRegen, true)
    player.state:set('obStaminaRechargeMultiplier', status.staminaRechargeMultiplier, true)
    player.state:set('obUnderwaterTimeMultiplier', status.underwaterTimeMultiplier, true)

    if status.corrupted and corruptionState[source] ~= true then
        notify(source, Config.Messages.wrongArtifact, 'error')
    end
    corruptionState[source] = status.corrupted
end

local function buildEffects(source, publish)
    source = tonumber(source)
    local classId = source and getClass(source) or ''
    local status = {
        active = false,
        class = classId ~= '' and classId or nil,
        item = nil,
        label = nil,
        essenceBonus = 0,
        maxHealthBonus = 0,
        artifacts = {},
        corrupted = false,
        essenceRegen = 0,
        healthRegen = 0,
        essenceCostMultiplier = 1.0,
        potionMultiplier = 1.0,
        healerPowerMultiplier = 1.0,
        staminaRechargeMultiplier = 1.0,
        underwaterTimeMultiplier = 1.0,
        solarProtection = false,
    }
    if not source then return status end

    local equipped = getEquippedItems(source)
    local validArtifacts = {}

    for equipmentType, slotData in pairs(equipped) do
        if type(slotData) == 'table' and isDurabilityValid(slotData.metadata) then
            local expectedSlot = Config.EquipmentSlots[equipmentType]
            local definition = Config.Artifacts[slotData.name]

            if definition
                and definition.slot == equipmentType
                and tonumber(slotData.slot) == tonumber(expectedSlot) then
                local classMatches = classId ~= '' and normalize(definition.class) == classId
                status.artifacts[equipmentType] = {
                    item = slotData.name,
                    label = definition.label,
                    class = definition.class,
                    validClass = classMatches,
                }

                if classMatches then
                    validArtifacts[#validArtifacts + 1] = definition
                elseif classId ~= '' then
                    status.corrupted = true
                end
            end

            if equipmentType == 'necklace' and tonumber(slotData.slot) == tonumber(Config.EquipmentSlots.necklace) then
                local necklace = Config.Necklaces[slotData.name]
                if necklace then
                    if normalize(necklace.class) == classId then
                        status.active = true
                        status.item = slotData.name
                        status.label = necklace.label
                        status.essenceBonus = math.max(0, math.floor(tonumber(necklace.essenceBonus) or 0))
                        status.maxHealthBonus = math.max(0, math.floor(tonumber(necklace.maxHealthBonus) or 0))
                    elseif classId ~= '' then
                        status.corrupted = true
                    end
                end
            end
        end
    end

    if not status.corrupted then
        for index = 1, #validArtifacts do
            applyArtifactDefinition(status, validArtifacts[index])
        end
    end

    if publish == true then publishEffects(source, status) end
    return status
end

local function refreshEffects(source)
    source = tonumber(source)
    if not source or not GetPlayerName(source) then return end
    local status = buildEffects(source, true)
    TriggerClientEvent('ob_boxes:client:updateEffects', source, status)
end

local function getPotionMultiplier(source)
    local status = buildEffects(source, false)
    return status.corrupted and 1.0 or math.max(1.0, tonumber(status.potionMultiplier) or 1.0)
end

local function setMetadata(player, key, value)
    if not player or not player.Functions then return false end
    if player.Functions.SetMetaData then
        player.Functions.SetMetaData(key, value)
        return true
    end
    if player.Functions.SetMetadata then
        player.Functions.SetMetadata(key, value)
        return true
    end
    return false
end

local function applyFullRestore(source, potion)
    local player = getPlayer(source)
    if not player then return false end

    setMetadata(player, 'hunger', 100)
    setMetadata(player, 'thirst', 100)
    setMetadata(player, 'stress', 0)

    local state = Player(source).state
    state:set('obBleeding', false, true)
    state:set('obBleedingSeverity', 0, true)
    state:set('obFear', false, true)
    state:set('obAnxiety', false, true)
    state:set('obExhausted', false, true)

    if GetResourceState('ob_curandeiras') == 'started' then
        pcall(function()
            exports.ob_curandeiras:SetBleeding(source, false, 0)
        end)
    end

    if GetResourceState('qbx_medical') == 'started' then
        pcall(function()
            exports.qbx_medical:Heal(source)
        end)
    end

    TriggerClientEvent('ob_boxes:client:applyFullRestore', source)
    notify(source, ('%s: %s'):format(potion.label, Config.Messages.fullRestore), 'success')
    return true
end

exports('useBox', function(event, item, inventory, slot)
    if event ~= 'usingItem' then return end

    local source = inventory and tonumber(inventory.id)
    local boxName = item and item.name
    if not source or not getPlayer(source) or not Config.Boxes[boxName] then return false end

    TriggerClientEvent('ob_boxes:client:openBox', source, boxName, slot)
    return false
end)

exports('usePotion', function(event, item, inventory)
    local source = inventory and tonumber(inventory.id)
    local potion = item and Config.Potions[item.name]
    if not source or not potion then return false end

    if event == 'usingItem' then
        local player = getPlayer(source)
        local metadata = player and player.PlayerData and player.PlayerData.metadata or {}
        if metadata.isdead == true or metadata.inlaststand == true then
            notify(source, Config.Messages.incapacitated, 'error')
            return false
        end

        if getClass(source) ~= normalize(potion.class) then
            notify(source, Config.Messages.wrongClass, 'error')
            TriggerClientEvent('ob_boxes:client:applyDizziness', source, Config.Effects.wrongPotionDurationMs)
            return false
        end

        if potion.essence then
            if GetResourceState('ob_essencias') ~= 'started' then
                notify(source, Config.Messages.potionFailed, 'error')
                return false
            end

            local ok, snapshot = pcall(function()
                return exports.ob_essencias:GetEssenciaSnapshot(source)
            end)
            if not ok or type(snapshot) ~= 'table' or snapshot.success ~= true then
                notify(source, Config.Messages.potionFailed, 'error')
                return false
            end

            if snapshot.value >= snapshot.max then
                notify(source, Config.Messages.alreadyFull, 'error')
                return false
            end
        end

        return true
    end

    if event ~= 'usedItem' or getClass(source) ~= normalize(potion.class) then return end

    local potionMultiplier = getPotionMultiplier(source)
    if potion.fullRestore == true then
        applyFullRestore(source, potion)
        return
    end

    if potion.essence then
        if GetResourceState('ob_essencias') ~= 'started' then
            notify(source, Config.Messages.potionFailed, 'error')
            return
        end

        local amount = math.max(1, math.floor((tonumber(potion.essence) or 0) * potionMultiplier + 0.5))
        local ok, success = pcall(function()
            return exports.ob_essencias:AddEssencia(source, amount)
        end)
        if not ok or success ~= true then
            notify(source, Config.Messages.potionFailed, 'error')
            return
        end

        notify(source, ('%s restaurou %d de essência.'):format(potion.label, amount), 'success')
        return
    end

    local health = math.max(0, math.floor((tonumber(potion.health) or 0) * potionMultiplier + 0.5))
    local durationMs = math.max(1000, math.floor((tonumber(potion.durationMs) or 600000) * potionMultiplier))
    TriggerClientEvent('ob_boxes:client:applyWisdom', source, health, potion.speedMultiplier, durationMs)
    notify(source, ('%s ativo por %d minutos.'):format(potion.label, math.floor(durationMs / 60000)), 'success')
end)

lib.callback.register('ob_boxes:server:redeem', function(source, boxName, slot, choiceIndex)
    source = tonumber(source)
    boxName = tostring(boxName or '')
    slot = tonumber(slot)
    choiceIndex = tonumber(choiceIndex)

    local box = Config.Boxes[boxName]
    local option = box and choiceIndex and box.options and box.options[choiceIndex]
    if not source or not box or not option then
        return { success = false, message = Config.Messages.invalidChoice }
    end

    if opening[source] then
        return { success = false, message = 'Aguarde a abertura atual terminar.' }
    end
    opening[source] = true

    local function finish(result)
        opening[source] = nil
        return result
    end

    local slotData = exports.ox_inventory:GetSlot(source, slot)
    if type(slotData) ~= 'table' or slotData.name ~= boxName or (tonumber(slotData.count) or 0) < 1 then
        return finish({ success = false, message = Config.Messages.boxMoved })
    end

    local amount = math.max(1, math.floor(tonumber(option.amount) or 1))
    if not exports.ox_inventory:CanSwapItem(source, boxName, 1, option.item, amount) then
        return finish({ success = false, message = Config.Messages.inventoryFull })
    end

    local boxMetadata = slotData.metadata
    local removed = exports.ox_inventory:RemoveItem(source, boxName, 1, nil, slot)
    if not removed then
        return finish({ success = false, message = Config.Messages.redeemFailed })
    end

    local added = exports.ox_inventory:AddItem(source, option.item, amount, option.metadata)
    if not added then
        local refunded = exports.ox_inventory:AddItem(source, boxName, 1, boxMetadata, slot)
        if not refunded then
            print(('[ob_boxes] ATENCAO: falha ao devolver %s ao jogador %d.'):format(boxName, source))
        end
        return finish({ success = false, message = Config.Messages.redeemFailed })
    end

    refreshEffects(source)
    return finish({
        success = true,
        message = ('Você escolheu %dx %s.'):format(amount, option.label or option.item),
    })
end)

lib.callback.register('ob_boxes:server:getEffects', function(source)
    return buildEffects(source, true)
end)

RegisterNetEvent('ob_boxes:server:requestEffects', function()
    refreshEffects(source)
end)

AddEventHandler('ox_inventory:server:equipmentChanged', function(owner)
    local source = tonumber(owner)
    if source and GetPlayerName(source) then refreshEffects(source) end
end)

AddEventHandler('classeSelector:server:classChanged', function(source)
    refreshEffects(source)
end)

AddEventHandler('qbx_core:server:onSetMetaData', function(key, _, _, source)
    if key == Config.ClassMetadataKey then refreshEffects(source) end
end)

AddEventHandler('playerDropped', function()
    opening[source] = nil
    corruptionState[source] = nil
end)

CreateThread(function()
    local interval = math.max(1000, tonumber(Config.Effects.regenIntervalMs) or 60000)
    while true do
        Wait(interval)

        for _, playerId in ipairs(GetPlayers()) do
            local source = tonumber(playerId)
            if source then
                local status = buildEffects(source, true)
                if not status.corrupted then
                    if status.essenceRegen > 0 and GetResourceState('ob_essencias') == 'started' then
                        pcall(function()
                            exports.ob_essencias:AddEssencia(source, status.essenceRegen)
                        end)
                    end
                    if status.healthRegen > 0 then
                        TriggerClientEvent('ob_boxes:client:applyHealthRegen', source, status.healthRegen)
                    end
                end
            end
        end
    end
end)

exports('GetActiveNecklace', function(source)
    return buildEffects(source, false)
end)

exports('GetEssenceBonus', function(source, classId)
    classId = normalize(classId)
    local status = buildEffects(source, false)
    if classId == '' or classId ~= status.class then return 0 end
    return status.essenceBonus
end)

exports('HasNecklaceEffect', function(source, effect)
    local status = buildEffects(source, false)
    return status.active == true and (tonumber(status[effect]) or 0) > 0, status
end)

exports('GetArtifactEffects', function(source)
    return buildEffects(source, false)
end)

exports('ModifyEssenceCost', function(source, amount)
    amount = math.max(0, math.floor(math.abs(tonumber(amount) or 0) + 0.5))
    if amount <= 1 then return amount, false end

    local status = buildEffects(source, false)
    if status.corrupted or status.essenceCostMultiplier >= 1.0 then return amount, false end

    return math.max(1, math.ceil(amount * status.essenceCostMultiplier)), true
end)

exports('GetPotionMultiplier', function(source)
    return getPotionMultiplier(source)
end)

exports('GetHealerPowerMultiplier', function(source, abilityId)
    if normalize(abilityId) == 'voo' then return 1.0 end
    local status = buildEffects(source, false)
    if status.corrupted then return 1.0 end
    return math.max(1.0, tonumber(status.healerPowerMultiplier) or 1.0)
end)

exports('GiveBox', function(source, boxName, amount)
    source = tonumber(source)
    boxName = tostring(boxName or '')
    amount = math.max(1, math.min(100, math.floor(tonumber(amount) or 1)))

    if not source or not Config.Boxes[boxName] then
        return false, 'invalid_box'
    end

    return exports.ox_inventory:AddItem(source, boxName, amount)
end)
