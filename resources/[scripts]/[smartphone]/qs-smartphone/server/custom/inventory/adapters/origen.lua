if Config.Inventory ~= 'origen_inventory' then
    return
end

local OrigenInventory = exports['origen_inventory']

---@diagnostic disable-next-line: duplicate-set-field
function inventory.supportsMetadata()
    return true
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.getPhoneItem(source)
    local userData = OrigenInventory:getInventory(source)
    if not userData or not userData.inventory then return nil end

    local items = userData.inventory
    for slot, item in pairs(items) do
        if item.name == Config.Phone.itemName then
            return {
                slot = slot,
                name = item.name,
                metadata = item.metadata
            }
        end
    end

    return nil
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.setMetadata(source, slot, data)
    OrigenInventory:setMetadata(source, slot, data)
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.registerUsable(itemName, callback)
    -- actually can be use sfr:registerUsableItem but it's not working. maybe because of my framework. but i don't know so we are directly using the export.
    exports.origen_inventory:CreateUseableItem(itemName, function(source, item)
        callback(source, {
            slot = item.slot,
            name = item.name,
            metadata = item.metadata
        })
    end)
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.getItems(source)
    local userData = OrigenInventory:getInventory(source)
    if not userData then return {} end
    return userData.inventory or {}
end

return inventory
