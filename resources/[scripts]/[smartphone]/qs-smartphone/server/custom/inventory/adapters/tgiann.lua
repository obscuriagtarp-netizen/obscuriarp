if Config.Inventory ~= 'tgiann-inventory' then
    return
end

local TgiannInventory = exports['tgiann-inventory']

---@diagnostic disable-next-line: duplicate-set-field
function inventory.supportsMetadata()
    return true
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.getPhoneItem(source)
    local items = TgiannInventory:GetPlayerItems(source)
    if not items then return nil end

    for _, item in pairs(items) do
        if item.name == Config.Phone.itemName then
            return {
                slot = item.slot,
                name = item.name,
                metadata = item.info
            }
        end
    end

    return nil
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.setMetadata(source, slot, data)
    local item = TgiannInventory:GetItemBySlot(source, slot)
    if not item then return end
    TgiannInventory:UpdateItemMetadata(source, item.name, slot, data)
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.registerUsable(itemName, callback)
    sfr:registerUsableItem(itemName, function(source, item)
        callback(source, {
            slot = item.slot,
            name = item.name,
            metadata = item.info
        })
    end)
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.getItems(source)
    return TgiannInventory:GetPlayerItems(source) or {}
end

return inventory
