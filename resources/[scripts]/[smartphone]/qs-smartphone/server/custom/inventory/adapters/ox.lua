if Config.Inventory ~= 'ox_inventory' then
    return
end

local ox_inventory = exports['ox_inventory']

---@diagnostic disable-next-line: duplicate-set-field
function inventory.supportsMetadata()
    return true
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.getPhoneItem(source)
    local items = ox_inventory:GetInventoryItems(source)
    if not items then return nil end

    for _, item in pairs(items) do
        if item.name == Config.Phone.itemName then
            return {
                slot = item.slot,
                name = item.name,
                metadata = item.metadata
            }
        end
    end

    return nil
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.setMetadata(source, slot, data)
    ox_inventory:SetMetadata(source, slot, data)
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.registerUsable(itemName, callback)
    RegisterNetEvent('phone:usePhoneItem', function(itemData)
        local src = source
        callback(src, {
            slot = itemData.slot,
            name = itemData.name,
            metadata = itemData.metadata
        })
    end)

    if Core.isQbFramework() then
        sfr:registerUsableItem(itemName, function(source, item)
            local phoneItem = inventory.getPhoneItem(source)
            if phoneItem then
                callback(source, {
                    slot = phoneItem.slot,
                    name = phoneItem.name,
                    metadata = phoneItem.metadata
                })
            else
                callback(source, {
                    slot = item and item.slot or nil,
                    name = itemName,
                    metadata = item and (item.metadata or item.info) or nil
                })
            end
        end)
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.getItems(source)
    return ox_inventory:GetInventoryItems(source) or {}
end

return inventory
