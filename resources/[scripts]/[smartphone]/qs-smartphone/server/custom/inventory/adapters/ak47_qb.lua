if Config.Inventory ~= 'ak47_qb_inventory' then
    return
end

local ak47_qb_inventory = exports['ak47_qb_inventory']

---@diagnostic disable-next-line: duplicate-set-field
function inventory.supportsMetadata()
    return true
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.getPhoneItem(source)
    local identifier = sfr:getIdentifier(source)
    local items = ak47_qb_inventory:GetInventoryItems(identifier)
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
    local identifier = sfr:getIdentifier(source)
    ak47_qb_inventory:SetItemInfo(identifier, slot, data)
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
    local identifier = sfr:getIdentifier(source)
    return ak47_qb_inventory:GetInventoryItems(identifier) or {}
end
