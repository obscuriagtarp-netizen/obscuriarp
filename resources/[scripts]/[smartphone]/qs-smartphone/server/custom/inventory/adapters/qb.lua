if Config.Inventory ~= 'qb-inventory' then
    return
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.supportsMetadata()
    return true
end

---@diagnostic disable-next-line: duplicate-set-field
function inventory.getPhoneItem(source)
    local player = sfr:getPlayerFromId(source)
    if not player then return nil end

    local items = player.PlayerData.items
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
    local player = sfr:getPlayerFromId(source)
    if not player then return end

    local items = player.PlayerData.items
    if items[slot] then
        items[slot].info = data
        player.Functions.SetInventory(items)
    end
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
    local player = sfr:getPlayerFromId(source)
    if not player then return {} end
    return player.PlayerData.items or {}
end

return inventory
