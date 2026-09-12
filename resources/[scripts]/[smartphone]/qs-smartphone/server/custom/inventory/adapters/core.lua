if Config.Inventory ~= 'core_inventory' then
    return
end

local CoreInventory = exports['core_inventory']

---@diagnostic disable-next-line: duplicate-set-field
function inventory.supportsMetadata()
    return true
end

local function getInventoryId(source)
    local identifier = sfr:getIdentifier(source)
    return 'content-' .. identifier:gsub(':', '')
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.getPhoneItem(source)
    local inventoryId = getInventoryId(source)
    local items = CoreInventory:getInventory(inventoryId)
    if not items then return nil end

    for _, item in pairs(items) do
        if item.name == Config.Phone.itemName then
            return {
                slot = item.id,
                name = item.name,
                metadata = item.metadata
            }
        end
    end

    return nil
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.setMetadata(source, slot, data)
    local inventoryId = getInventoryId(source)
    CoreInventory:updateMetadata(inventoryId, slot, data)
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.registerUsable(itemName, callback)
    sfr:registerUsableItem(itemName, function(source, item, itemData)
        local actualItem = type(item) == 'table' and item or itemData
        actualItem.info = actualItem.metadata

        callback(source, {
            slot = actualItem.id,
            name = actualItem.name,
            metadata = actualItem.metadata
        })
    end)
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.getItems(source)
    local inventoryId = getInventoryId(source)
    return CoreInventory:getInventory(inventoryId) or {}
end

return inventory
