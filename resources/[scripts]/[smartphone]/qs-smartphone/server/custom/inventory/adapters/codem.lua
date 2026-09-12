if Config.Inventory ~= 'codem-inventory' then
    return
end

local CodemInventory = exports['codem-inventory']

---@diagnostic disable-next-line: duplicate-set-field
function inventory.supportsMetadata()
    return true
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.getPhoneItem(source)
    local items = inventory.getItems(source)
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
    CodemInventory:SetItemMetadata(source, slot, data)
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
    local identifier = sfr:getIdentifier(source)
    return CodemInventory:GetInventory(identifier, source) or {}
end

return inventory
