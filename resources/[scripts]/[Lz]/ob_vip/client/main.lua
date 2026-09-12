local EMPTY_STATE = {
    active = false,
    memberships = {},
    benefits = {
        salaryTotal = 0,
        vehicleDiscount = 0,
        fuelDiscount = 0,
        medicalDiscount = 0,
        inventoryWeight = 0,
        vipInventoryWeight = 0,
        backpackWeight = 0,
        backpack = nil,
        availableBackpacks = {},
        keepBackpackOnDeath = false,
        nameChanges = 0,
        discordRoleIds = {},
    },
}

local function vipState()
    return LocalPlayer.state.obVip or EMPTY_STATE
end

local function copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end

    local result = {}
    seen[value] = result
    for key, item in pairs(value) do result[copy(key, seen)] = copy(item, seen) end
    return result
end

exports('IsVip', function()
    return vipState().active == true
end)

exports('HasVip', function(vip)
    local expected = vip and tostring(vip):lower()
    if not expected then return vipState().active == true end

    for _, membership in ipairs(vipState().memberships or {}) do
        if membership.vip == expected then return true end
    end

    return false
end)

exports('GetVips', function()
    return copy(vipState().memberships or {})
end)

exports('GetHighestVip', function()
    return copy(vipState().highest)
end)

exports('GetBenefits', function()
    return copy(vipState().benefits or EMPTY_STATE.benefits)
end)

exports('GetSalaryTotal', function()
    return tonumber(vipState().benefits and vipState().benefits.salaryTotal) or 0
end)

exports('GetSalaryEntries', function()
    return copy(vipState().benefits and vipState().benefits.salaryEntries or {})
end)

exports('GetVehicleDiscount', function()
    return tonumber(vipState().benefits and vipState().benefits.vehicleDiscount) or 0
end)

exports('GetInventoryBonus', function()
    return tonumber(vipState().benefits and vipState().benefits.inventoryWeight) or 0
end)

exports('GetVipInventoryBonus', function()
    return tonumber(vipState().benefits and vipState().benefits.vipInventoryWeight) or 0
end)

exports('GetBackpackBonus', function()
    return tonumber(vipState().benefits and vipState().benefits.backpackWeight) or 0
end)

exports('GetFuelDiscount', function()
    return tonumber(vipState().benefits and vipState().benefits.fuelDiscount) or 0
end)

exports('GetMedicalDiscount', function()
    return tonumber(vipState().benefits and vipState().benefits.medicalDiscount) or 0
end)

RegisterNetEvent('ob_vip:client:useNameChange', function()
    local input = lib.inputDialog('Troca de Nome', {
        { type = 'input', label = 'Nome', required = true, min = 2, max = 24 },
        { type = 'input', label = 'Sobrenome', required = true, min = 2, max = 24 },
    })
    if not input then return end

    local result = lib.callback.await('ob_vip:server:changeName', false, {
        firstName = input[1],
        lastName = input[2],
    }) or {}
    lib.notify({
        type = result.ok and 'success' or 'error',
        description = result.message or 'Nao foi possivel trocar o nome.',
    })
end)

exports('GetDiscordRoleIds', function()
    return copy(vipState().benefits and vipState().benefits.discordRoleIds or {})
end)

exports('RequestRefresh', function()
    TriggerServerEvent('ob_vip:server:requestRefresh')
end)

RegisterNetEvent('ob_vip:client:updated', function(payload)
    TriggerEvent('ob_vip:client:onUpdated', payload or vipState())
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('ob_vip:server:requestRefresh')
end)
