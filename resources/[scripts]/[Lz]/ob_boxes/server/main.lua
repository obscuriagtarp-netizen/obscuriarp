local opening = {}

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

local function equippedNecklace(source)
    if GetResourceState('ox_inventory') ~= 'started' then return nil end

    local ok, equipped = pcall(function()
        return exports.ox_inventory:GetEquippedItems(source)
    end)
    if not ok or type(equipped) ~= 'table' then return nil end

    local slotData = equipped.necklace
    if type(slotData) ~= 'table' or tonumber(slotData.slot) ~= tonumber(Config.NecklaceSlot) then return nil end
    if not isDurabilityValid(slotData.metadata) then return nil end

    local definition = Config.Necklaces[slotData.name]
    if not definition or normalize(definition.class) ~= getClass(source) then return nil end

    return slotData, definition
end

local function buildEffects(source)
    source = tonumber(source)
    local classId = source and getClass(source) or ''
    local slotData, definition
    if source then
        slotData, definition = equippedNecklace(source)
    end
    local status = {
        active = definition ~= nil,
        class = classId ~= '' and classId or nil,
        item = slotData and slotData.name or nil,
        label = definition and definition.label or nil,
        essenceBonus = definition and math.max(0, math.floor(tonumber(definition.essenceBonus) or 0)) or 0,
        maxHealthBonus = definition and math.max(0, math.floor(tonumber(definition.maxHealthBonus) or 0)) or 0,
    }

    if source then
        local player = Player(source)
        if player and player.state then
            player.state:set('obClassNecklace', status.item, true)
            player.state:set('obEssenceBonus', status.essenceBonus, true)
            player.state:set('obMaxHealthBonus', status.maxHealthBonus, true)
        end
    end

    return status
end

local function refreshEffects(source)
    source = tonumber(source)
    if not source or not GetPlayerName(source) then return end
    TriggerClientEvent('ob_boxes:client:updateEffects', source, buildEffects(source))
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
        if getClass(source) ~= normalize(potion.class) then
            notify(source, Config.Messages.wrongClass, 'error')
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

    if event ~= 'usedItem' then return end

    if potion.essence then
        if GetResourceState('ob_essencias') ~= 'started' then
            notify(source, Config.Messages.potionFailed, 'error')
            return
        end

        local ok, success = pcall(function()
            return exports.ob_essencias:AddEssencia(source, potion.essence)
        end)
        if not ok or success ~= true then
            notify(source, Config.Messages.potionFailed, 'error')
            return
        end

        notify(source, ('%s restaurou %d de essência.'):format(potion.label, potion.essence), 'success')
        return
    end

    TriggerClientEvent(
        'ob_boxes:client:applyWisdom',
        source,
        potion.health,
        potion.speedMultiplier,
        potion.durationMs
    )
    notify(source, ('%s ativo por %d minutos.'):format(potion.label, math.floor(potion.durationMs / 60000)), 'success')
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
    return buildEffects(source)
end)

RegisterNetEvent('ob_boxes:server:requestEffects', function()
    refreshEffects(source)
end)

AddEventHandler('ox_inventory:server:equipmentChanged', function(owner)
    local source = tonumber(owner)
    if source and GetPlayerName(source) then
        refreshEffects(source)
    end
end)

AddEventHandler('classeSelector:server:classChanged', function(source)
    refreshEffects(source)
end)

AddEventHandler('qbx_core:server:onSetMetaData', function(key, _, _, source)
    if key == Config.ClassMetadataKey then
        refreshEffects(source)
    end
end)

AddEventHandler('playerDropped', function()
    opening[source] = nil
end)

exports('GetActiveNecklace', function(source)
    return buildEffects(source)
end)

exports('GetEssenceBonus', function(source, classId)
    classId = normalize(classId)
    if classId == '' or classId ~= getClass(source) then return 0 end

    local _, definition = equippedNecklace(source)
    return definition and math.max(0, math.floor(tonumber(definition.essenceBonus) or 0)) or 0
end)

exports('HasNecklaceEffect', function(source, effect)
    local status = buildEffects(source)
    return status.active == true and (tonumber(status[effect]) or 0) > 0, status
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
