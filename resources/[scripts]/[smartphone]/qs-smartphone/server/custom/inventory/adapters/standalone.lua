if Config.Inventory ~= 'standalone' then
    return
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.supportsMetadata()
    return false
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.getPhoneItem(source)
    return {
        slot = 1,
        name = Config.Phone.itemName,
        metadata = nil
    }
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.setMetadata(source, slot, data)
    Debug('Standalone', 'setMetadata called but metadata not supported')
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.registerUsable(itemName, callback)
    if Config.Framework == 'esx' then
        sfr:registerUsableItem(itemName, function(source)
            callback(source, { slot = 1, name = itemName, metadata = nil })
        end)
    elseif Config.Framework == 'qb' then
        sfr:registerUsableItem(itemName, function(source)
            callback(source, { slot = 1, name = itemName, metadata = nil })
        end)
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.getItems(source)
    return {}
end

return inventory
