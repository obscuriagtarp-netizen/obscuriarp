local function normalize(value)
    return tostring(value or ''):lower()
end

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

local function getEquippedItems(source)
    local ok, equipped = pcall(function()
        return exports.ox_inventory:GetEquippedItems(source)
    end)

    return ok and type(equipped) == 'table' and equipped or {}
end

local function findProtectionItem(source)
    local equipped = getEquippedItems(source)

    for index = 1, #(Config.Protection.items or {}) do
        local item = Config.Protection.items[index]
        local itemName = type(item) == 'table' and item.name or item
        local equipmentType = type(item) == 'table' and item.equipment or nil

        if itemName and itemName ~= '' then
            for equippedType, slotData in pairs(equipped) do
                if type(slotData) == 'table' and slotData.name == itemName
                    and (not equipmentType or equipmentType == equippedType) then
                    return {
                        name = itemName,
                        label = type(item) == 'table' and (item.label or itemName) or itemName,
                        equipment = equippedType,
                        slot = slotData.slot,
                        blocksWeakness = type(item) == 'table' and item.blocksWeakness == true,
                    }
                end
            end

            if Config.Protection.requireEquipped ~= true then
                local ok, count = pcall(function()
                    return exports.ox_inventory:Search(source, 'count', itemName)
                end)
                if ok and (tonumber(count) or 0) >= 1 then
                    return {
                        name = itemName,
                        label = type(item) == 'table' and (item.label or itemName) or itemName,
                        blocksWeakness = type(item) == 'table' and item.blocksWeakness == true,
                    }
                end
            end
        end
    end

    return nil
end

local function buildStatus(source)
    source = tonumber(source)
    if not source then
        return {
            vampire = false,
            protected = false,
        }
    end

    local player = getPlayer(source)
    if not player or not player.PlayerData then
        return {
            vampire = false,
            protected = false,
        }
    end

    local metadata = player.PlayerData.metadata or {}
    local vampire = normalize(metadata[Config.ClassMetadataKey]) == normalize(Config.VampireClass)
    local protection = vampire and findProtectionItem(source) or nil

    local statePlayer = Player(source)
    if statePlayer and statePlayer.state then
        statePlayer.state:set('obSunVampire', vampire, true)
        statePlayer.state:set('obSunProtected', protection ~= nil, true)
        statePlayer.state:set('obSunProtectionItem', protection and protection.name or nil, true)
        statePlayer.state:set(
            'obSunProtectionBlocksWeakness',
            protection and protection.blocksWeakness == true or false,
            true
        )
    end

    return {
        vampire = vampire,
        protected = protection ~= nil,
        protection = protection,
    }
end

lib.callback.register('ob_sol_vampiros:server:getStatus', function(source)
    return buildStatus(source)
end)

exports('GetSunStatus', function(source)
    return buildStatus(source)
end)

exports('IsSunProtected', function(source)
    local status = buildStatus(source)
    return status.protected, status.protection
end)

exports('IsSunWeakened', function(source)
    source = tonumber(source)
    if not source then return false end
    local player = Player(source)
    return player and player.state and player.state.obSunWeakened == true or false
end)

AddEventHandler('ox_inventory:server:equipmentChanged', function(owner)
    local source = tonumber(owner)
    if source and GetPlayerName(source) then
        buildStatus(source)
    end
end)
