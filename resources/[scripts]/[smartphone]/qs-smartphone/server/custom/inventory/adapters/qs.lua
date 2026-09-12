if Config.Inventory ~= 'qs-inventory' then
    return
end

local QSInventory = exports['qs-inventory']

---@diagnostic disable-next-line: duplicate-set-field
function inventory.supportsMetadata()
    return true
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.getPhoneItem(source)
    local items = QSInventory:GetInventory(source)
    if not items then return nil end

    for _, item in pairs(items) do
        if item.name == Config.Phone.itemName then
            local metadata = item.info or item.metadata
            return {
                slot = item.slot,
                name = item.name,
                metadata = metadata
            }
        end
    end

    return nil
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.setMetadata(source, slot, data)
    QSInventory:SetItemMetadata(source, slot, data)
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.registerUsable(itemName, callback)
    sfr:registerUsableItem(itemName, function(source, item)
        local metadata = item.info or item.metadata
        callback(source, {
            slot = item.slot,
            name = item.name,
            metadata = metadata
        })
    end)
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.getItems(source)
    return QSInventory:GetInventory(source) or {}
end

return inventory
