local providers = {}
local activeProviderId = nil
local hudVisible = true
local nuiReady = false
local demoVisible = false
local keybindMenuOpen = false
local runtimeStatus = {
    hidden = false,
    blocked = false,
    activeAbilityId = nil,
    reason = nil,
}
local runtimeSignature = ''
local keyControls = {}
local essence = {
    class = nil,
    key = nil,
    label = 'Essencia',
    value = 0,
    max = 0,
}
local overload = {
    success = false,
    class = nil,
    value = 0,
    max = 100,
    tier = 'stable',
    tierLabel = 'Estavel',
}

for _, option in ipairs(Config.KeyOptions or {}) do
    local key = string.upper(tostring(option.key or ''))
    local control = tonumber(option.control)
    if key ~= '' and control then
        keyControls[key] = control
    end
end

local function copyTable(source)
    local result = {}

    if type(source) ~= 'table' then
        return result
    end

    for key, value in pairs(source) do
        result[key] = value
    end

    return result
end

local function mergeTables(base, overrides)
    local result = copyTable(base)

    for key, value in pairs(overrides or {}) do
        result[key] = value
    end

    return result
end

local function normalizeKey(value)
    local key = string.upper(tostring(value or ''))
    return keyControls[key] and key or nil
end

local function keybindStorageKey(providerId)
    return ('obscuriaHud:keybinds:%s'):format(tostring(providerId or ''))
end

local function loadKeybinds(providerId)
    local encoded = GetResourceKvpString(keybindStorageKey(providerId))
    if not encoded or encoded == '' then
        return {}
    end

    local ok, decoded = pcall(json.decode, encoded)
    return ok and type(decoded) == 'table' and decoded or {}
end

local function isPlayerDead(ped, state)
    local stateDead = state and (
        state.isDead == true
        or state.dead == true
        or state.inLaststand == true
        or state.laststand == true
    )

    return ped == 0
        or stateDead == true
        or IsEntityDead(ped)
        or IsPedDeadOrDying(ped, true)
        or GetEntityHealth(ped) <= 0
end

local function isPlayerInVehicle(ped)
    if ped == 0 then
        return false
    end

    local currentVehicle = GetVehiclePedIsIn(ped, false)
    local enteringVehicle = GetVehiclePedIsTryingToEnter and GetVehiclePedIsTryingToEnter(ped) or 0

    return currentVehicle ~= 0
        or enteringVehicle ~= 0
        or IsPedInAnyVehicle(ped, true)
        or IsPedSittingInAnyVehicle(ped)
end

local function isPlayerAttachedToVehicle(ped)
    if ped == 0 or not DoesEntityExist(ped) or not IsEntityAttached(ped) then
        return false
    end

    local attachedTo = GetEntityAttachedTo(ped)
    return attachedTo ~= 0
        and DoesEntityExist(attachedTo)
        and IsEntityAVehicle(attachedTo)
end

CreateThread(function()
    local published = nil

    while true do
        local attached = isPlayerAttachedToVehicle(PlayerPedId())
        if attached ~= published and LocalPlayer and LocalPlayer.state then
            published = attached
            LocalPlayer.state:set('obInVehicleAttachment', attached, true)
        end
        Wait(attached and 100 or 250)
    end
end)

local function isMapOpen()
    local pauseState = GetPauseMenuState and GetPauseMenuState() or 0
    local bigMapActive = IsBigmapActive and IsBigmapActive() or false

    return IsPauseMenuActive() or pauseState ~= 0 or bigMapActive
end

local function getRuntimeStatus()
    local ped = PlayerPedId()
    local state = LocalPlayer and LocalPlayer.state or nil
    local inVehicle = isPlayerInVehicle(ped)
    local inventoryOpen = state and state.invOpen == true
    local pauseOpen = isMapOpen()
    local dead = isPlayerDead(ped, state)
    local attachedToVehicle = isPlayerAttachedToVehicle(ped)
        or (state and state.obInVehicleAttachment == true)
    local activeAbilityId = nil

    if state then
        if state.obFamiliar == true then
            activeAbilityId = 'familiar'
        elseif state.obBatForm == true then
            activeAbilityId = 'forma_morcego'
        elseif state.obHealerFlight == true then
            activeAbilityId = 'voo'
        end
    end

    local externallyBlocked = state and (
        state.magicFauna == true
        or state.obscuriaPowerBlocked == true
        or state.obHypnotized == true
        or state.obInVehicleAttachment == true
    )
    local blocked = dead or attachedToVehicle or activeAbilityId ~= nil or externallyBlocked == true
    local reason = nil

    if dead then
        reason = 'dead'
    elseif attachedToVehicle then
        reason = 'vehicle_attachment'
    elseif activeAbilityId then
        reason = 'transformation'
    elseif externallyBlocked then
        reason = 'transformation'
    end

    return {
        hidden = inventoryOpen or pauseOpen or inVehicle or attachedToVehicle,
        blocked = blocked,
        activeAbilityId = activeAbilityId,
        reason = reason,
    }
end

local function statusSignature(status)
    return table.concat({
        status.hidden and '1' or '0',
        status.blocked and '1' or '0',
        tostring(status.activeAbilityId or ''),
        tostring(status.reason or ''),
    }, ':')
end

local function applySavedKeybinds(provider)
    local saved = loadKeybinds(provider.id)

    for slot = 1, 4 do
        local ability = provider.abilities[slot]
        if ability then
            local savedKey = normalizeKey(saved[ability.id])
            ability.key = savedKey or ability.key
        end
    end
end

local function serializeEssence()
    return {
        class = essence.class,
        key = essence.key,
        label = essence.label,
        value = essence.value,
        max = essence.max,
    }
end

local function sendEssence()
    if not nuiReady then
        return
    end

    SendNUIMessage({
        action = 'essence',
        essence = serializeEssence(),
    })
end

local function serializeOverload()
    return {
        success = overload.success == true,
        class = overload.class,
        value = tonumber(overload.value) or 0,
        max = tonumber(overload.max) or 100,
        tier = overload.tier or 'stable',
        tierLabel = overload.tierLabel or 'Estavel',
    }
end

local function sendOverload()
    if not nuiReady then return end
    SendNUIMessage({
        action = 'overload',
        overload = serializeOverload(),
    })
end

local function refreshOverload(delay)
    CreateThread(function()
        Wait(math.max(0, tonumber(delay) or 0))
        if GetResourceState('ob_manalimit') ~= 'started' then return end

        local ok, payload = pcall(function()
            return exports.ob_manalimit:GetSnapshot()
        end)
        if ok and type(payload) == 'table' then
            overload = payload
            sendOverload()
        end
    end)
end

local function refreshEssence(delay)
    CreateThread(function()
        Wait(math.max(0, tonumber(delay) or 0))

        if GetResourceState('ob_essencias') ~= 'started' then
            return
        end

        local snapshotOk, snapshot = pcall(function()
            return exports.ob_essencias:GetEssenciaSnapshot()
        end)

        if snapshotOk and type(snapshot) == 'table' then
            essence.value = tonumber(snapshot.value) or 0
            essence.max = tonumber(snapshot.max) or 0
            essence.key = snapshot.key
            essence.class = snapshot.class
            essence.label = tostring(snapshot.label or 'Essencia')
            sendEssence()
            return
        end

        local valueOk, value = pcall(function()
            return exports.ob_essencias:GetEssencia()
        end)
        local maxOk, maxValue = pcall(function()
            return exports.ob_essencias:GetMaxEssencia()
        end)
        local keyOk, key = pcall(function()
            return exports.ob_essencias:GetEssenciaMetaKey()
        end)
        local labelOk, label = pcall(function()
            return exports.ob_essencias:GetEssenciaLabel()
        end)

        if valueOk and maxOk then
            essence.value = tonumber(value) or 0
            essence.max = tonumber(maxValue) or 0
            essence.key = keyOk and key or nil
            essence.label = labelOk and tostring(label or 'Essencia') or 'Essencia'
            sendEssence()
        end
    end)
end

local function normalizeAbility(data, fallbackSlot)
    if type(data) ~= 'table' then
        return nil
    end

    local slot = math.floor(tonumber(data.slot) or tonumber(fallbackSlot) or 0)
    if slot < 1 or slot > 4 then
        return nil
    end

    local id = tostring(data.id or data.name or ('slot_%s'):format(slot))
    local maxCharges = tonumber(data.maxCharges)
    local charges = tonumber(data.charges)

    if maxCharges and not charges then
        charges = maxCharges
    end

    local defaultKey = normalizeKey(data.key) or normalizeKey(Config.Keybinds[slot]) or tostring(slot)

    return {
        id = id,
        slot = slot,
        input = math.floor(tonumber(data.input) or slot),
        label = tostring(data.label or id),
        description = tostring(data.description or ''),
        icon = data.icon,
        key = defaultKey,
        defaultKey = defaultKey,
        enabled = data.enabled ~= false,
        selected = data.selected == true,
        charges = charges,
        maxCharges = maxCharges,
        cooldownMs = math.max(0, tonumber(data.cooldownMs or data.cooldown) or 0),
        cooldownEnd = tonumber(data.cooldownEnd) or 0,
        cooldownDuration = math.max(0, tonumber(data.cooldownDuration) or 0),
        autoCooldown = data.autoCooldown == true,
        consumeCharge = data.consumeCharge == true,
        clientEvent = data.clientEvent,
        serverEvent = data.serverEvent,
        payload = data.payload,
    }
end

local function findAbility(provider, abilityId)
    if not provider then
        return nil
    end

    local wantedId = tostring(abilityId or '')
    for slot = 1, 4 do
        local ability = provider.abilities[slot]
        if ability and ability.id == wantedId then
            return ability
        end
    end

    return nil
end

local function serializeProvider(provider)
    if not provider then
        return nil
    end

    local now = GetGameTimer()
    local abilities = {}

    for slot = 1, 4 do
        local ability = provider.abilities[slot]
        if ability then
            abilities[#abilities + 1] = {
                id = ability.id,
                slot = ability.slot,
                label = ability.label,
                description = ability.description,
                icon = ability.icon,
                key = ability.key,
                defaultKey = ability.defaultKey,
                enabled = ability.enabled,
                selected = ability.selected,
                charges = ability.charges,
                maxCharges = ability.maxCharges,
                cooldownRemaining = math.max(0, (ability.cooldownEnd or 0) - now),
                cooldownDuration = math.max(0, ability.cooldownDuration or 0),
            }
        end
    end

    local baseTheme = Config.Themes[provider.archetype] or Config.Themes.default or {}

    return {
        id = provider.id,
        label = provider.label,
        archetype = provider.archetype,
        theme = mergeTables(baseTheme, provider.theme),
        abilities = abilities,
    }
end

local function syncHud()
    if not nuiReady then
        return
    end

    local provider = activeProviderId and providers[activeProviderId] or nil
    local position = mergeTables(Config.Position, provider and provider.position or nil)
    local scale = tonumber(position.scale) or 1.0
    position.scale = scale * math.max(0.1, tonumber(Config.HudScaleMultiplier) or 1.0)
    runtimeStatus = getRuntimeStatus()
    runtimeSignature = statusSignature(runtimeStatus)

    SendNUIMessage({
        action = 'hydrate',
        visible = hudVisible
            and provider ~= nil
            and provider.visible ~= false
            and runtimeStatus.hidden ~= true,
        provider = serializeProvider(provider),
        essence = serializeEssence(),
        overload = serializeOverload(),
        position = position,
        status = runtimeStatus,
    })
end

local function registerProvider(providerId, data)
    providerId = tostring(providerId or '')
    if providerId == '' or type(data) ~= 'table' then
        return false
    end

    local provider = providers[providerId] or {
        id = providerId,
        abilities = {},
    }

    provider.label = tostring(data.label or provider.label or providerId)
    provider.archetype = tostring(data.archetype or provider.archetype or 'default')
    provider.theme = data.theme or provider.theme
    provider.position = data.position or provider.position
    provider.visible = data.visible ~= false

    if type(data.abilities) == 'table' then
        provider.abilities = {}
        for key, abilityData in pairs(data.abilities) do
            local ability = normalizeAbility(abilityData, key)
            if ability then
                provider.abilities[ability.slot] = ability
            end
        end
    end

    applySavedKeybinds(provider)

    providers[providerId] = provider
    activeProviderId = activeProviderId or providerId
    syncHud()

    return true
end

local function setAbilities(providerId, abilities)
    local provider = providers[tostring(providerId or '')]
    if not provider or type(abilities) ~= 'table' then
        return false
    end

    provider.abilities = {}
    for key, abilityData in pairs(abilities) do
        local ability = normalizeAbility(abilityData, key)
        if ability then
            provider.abilities[ability.slot] = ability
        end
    end

    applySavedKeybinds(provider)

    syncHud()
    return true
end

local function updateAbility(providerId, abilityId, patch)
    local provider = providers[tostring(providerId or '')]
    local ability = findAbility(provider, abilityId)
    if not ability or type(patch) ~= 'table' then
        return false
    end

    for key, value in pairs(patch) do
        if key ~= 'id' and key ~= 'slot' then
            ability[key] = value
        end
    end

    syncHud()
    return true
end

local function setActiveProvider(providerId)
    providerId = tostring(providerId or '')
    if not providers[providerId] then
        return false
    end

    activeProviderId = providerId
    syncHud()
    return true
end

local function setVisible(visible)
    hudVisible = visible == true
    syncHud()
end

local function setProviderVisible(providerId, visible)
    local provider = providers[tostring(providerId or '')]
    if not provider then
        return false
    end

    provider.visible = visible == true
    syncHud()
    return true
end

local function setProviderPosition(providerId, position)
    local provider = providers[tostring(providerId or '')]
    if not provider or type(position) ~= 'table' then
        return false
    end

    provider.position = copyTable(position)
    syncHud()
    return true
end

local function startCooldown(providerId, abilityId, durationMs)
    local provider = providers[tostring(providerId or '')]
    local ability = findAbility(provider, abilityId)
    if not ability then
        return false
    end

    durationMs = math.max(0, tonumber(durationMs) or ability.cooldownMs or 0)
    ability.cooldownEnd = GetGameTimer() + durationMs
    ability.cooldownDuration = durationMs

    if nuiReady and activeProviderId == provider.id then
        SendNUIMessage({
            action = 'cooldown',
            abilityId = ability.id,
            duration = durationMs,
        })
    end

    return true
end

local function setCharges(providerId, abilityId, charges, maxCharges)
    local provider = providers[tostring(providerId or '')]
    local ability = findAbility(provider, abilityId)
    if not ability then
        return false
    end

    ability.charges = math.max(0, tonumber(charges) or 0)
    ability.maxCharges = math.max(0, tonumber(maxCharges) or ability.maxCharges or ability.charges)
    syncHud()
    return true
end

local function setSelected(providerId, abilityId)
    local provider = providers[tostring(providerId or '')]
    if not provider then
        return false
    end

    local wantedId = tostring(abilityId or '')
    local found = false

    for slot = 1, 4 do
        local ability = provider.abilities[slot]
        if ability then
            ability.selected = ability.id == wantedId
            found = found or ability.selected
        end
    end

    syncHud()
    return found
end

local function pulseAbility(providerId, abilityId, variant)
    local provider = providers[tostring(providerId or '')]
    local ability = findAbility(provider, abilityId)
    if not ability then
        return false
    end

    if nuiReady and activeProviderId == provider.id then
        SendNUIMessage({
            action = 'pulse',
            abilityId = ability.id,
            variant = variant == 'error' and 'error' or 'default',
        })
    end

    return true
end

local function activateSlot(slot)
    local provider = activeProviderId and providers[activeProviderId] or nil
    local ability = provider and provider.abilities[tonumber(slot)] or nil

    local status = getRuntimeStatus()

    if not hudVisible or status.hidden or not provider or provider.visible == false or not ability then
        return false, 'unavailable'
    end

    local function reject(reason)
        pulseAbility(provider.id, ability.id, 'error')
        return false, reason
    end

    if status.blocked and status.activeAbilityId ~= ability.id then
        return reject(status.reason or 'blocked')
    end

    if ability.enabled == false then
        return reject('unavailable')
    end

    local now = GetGameTimer()
    if (ability.cooldownEnd or 0) > now then
        return reject('cooldown')
    end

    if ability.maxCharges and (ability.charges or 0) <= 0 then
        return reject('charges')
    end

    setSelected(provider.id, ability.id)

    if ability.consumeCharge and ability.maxCharges then
        ability.charges = math.max(0, (ability.charges or 0) - 1)
    end

    if ability.autoCooldown and ability.cooldownMs > 0 then
        startCooldown(provider.id, ability.id, ability.cooldownMs)
    end

    local context = {
        providerId = provider.id,
        archetype = provider.archetype,
        abilityId = ability.id,
        slot = ability.slot,
        payload = ability.payload,
    }

    pulseAbility(provider.id, ability.id, 'default')
    TriggerEvent('obscuriaHud:abilityActivated', context)

    if ability.clientEvent then
        TriggerEvent(ability.clientEvent, context)
    end

    if ability.serverEvent then
        TriggerServerEvent(ability.serverEvent, context)
    end

    syncHud()
    return true
end

local function activateInput(input)
    local provider = activeProviderId and providers[activeProviderId] or nil
    local wantedInput = math.floor(tonumber(input) or 0)

    if provider then
        for slot = 1, 4 do
            local ability = provider.abilities[slot]
            if ability and ability.input == wantedInput then
                return activateSlot(slot)
            end
        end
    end

    return false, 'unavailable'
end

local function activateKey(key)
    local provider = activeProviderId and providers[activeProviderId] or nil
    local wantedKey = normalizeKey(key)

    if provider and wantedKey then
        for slot = 1, 4 do
            local ability = provider.abilities[slot]
            if ability and ability.key == wantedKey then
                return activateSlot(slot)
            end
        end
    end

    return false, 'unavailable'
end

local function closeKeybindMenu()
    if not keybindMenuOpen then
        return
    end

    keybindMenuOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'keybindsClose' })
end

local function openKeybindMenu()
    local provider = activeProviderId and providers[activeProviderId] or nil
    local status = getRuntimeStatus()

    if not provider or provider.visible == false or status.hidden then
        return false
    end

    keybindMenuOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = 'keybindsOpen',
        provider = serializeProvider(provider),
        allowedKeys = Config.KeyOptions or {},
    })
    return true
end

local function saveKeybinds(bindings)
    local provider = activeProviderId and providers[activeProviderId] or nil
    if not provider or type(bindings) ~= 'table' then
        return false, 'unavailable'
    end

    local normalized = {}
    local used = {}

    for slot = 1, 4 do
        local ability = provider.abilities[slot]
        if ability then
            local key = normalizeKey(bindings[ability.id])
            if not key or used[key] then
                return false, 'invalid_key'
            end

            used[key] = true
            normalized[ability.id] = key
        end
    end

    for slot = 1, 4 do
        local ability = provider.abilities[slot]
        if ability then
            ability.key = normalized[ability.id]
        end
    end

    SetResourceKvp(keybindStorageKey(provider.id), json.encode(normalized))
    syncHud()
    return true
end

local function clearProvider(providerId)
    providerId = tostring(providerId or '')
    if not providers[providerId] then
        return false
    end

    providers[providerId] = nil
    if activeProviderId == providerId then
        activeProviderId = next(providers)
    end

    syncHud()
    return true
end

exports('RegisterProvider', registerProvider)
exports('SetAbilities', setAbilities)
exports('UpdateAbility', updateAbility)
exports('SetActiveProvider', setActiveProvider)
exports('SetVisible', setVisible)
exports('SetProviderVisible', setProviderVisible)
exports('SetProviderPosition', setProviderPosition)
exports('StartCooldown', startCooldown)
exports('SetCharges', setCharges)
exports('SetSelected', setSelected)
exports('PulseAbility', pulseAbility)
exports('ActivateSlot', activateSlot)
exports('ActivateInput', activateInput)
exports('ActivateKey', activateKey)
exports('OpenKeybindMenu', openKeybindMenu)
exports('ClearProvider', clearProvider)
exports('GetActiveProvider', function()
    return activeProviderId
end)

RegisterNetEvent('obscuriaHud:client:registerProvider', registerProvider)
RegisterNetEvent('obscuriaHud:client:setAbilities', setAbilities)
RegisterNetEvent('obscuriaHud:client:updateAbility', updateAbility)
RegisterNetEvent('obscuriaHud:client:setActiveProvider', setActiveProvider)
RegisterNetEvent('obscuriaHud:client:setVisible', setVisible)
RegisterNetEvent('obscuriaHud:client:setProviderPosition', setProviderPosition)
RegisterNetEvent('obscuriaHud:client:startCooldown', startCooldown)
RegisterNetEvent('obscuriaHud:client:setCharges', setCharges)
RegisterNetEvent('obscuriaHud:client:setSelected', setSelected)
RegisterNetEvent('obscuriaHud:client:clearProvider', clearProvider)
RegisterNetEvent('obscuriaHud:client:activateInput', activateInput)
RegisterNetEvent('obscuriaHud:client:openKeybindMenu', openKeybindMenu)

AddEventHandler('ob_essencias:client:updated', function(value, maxValue, key, classId, label)
    essence.value = tonumber(value) or 0
    essence.max = tonumber(maxValue) or 0
    essence.key = key
    essence.class = classId
    essence.label = tostring(label or essence.label or 'Essencia')
    sendEssence()
end)

AddEventHandler('ob_manalimit:client:updated', function(payload)
    if type(payload) ~= 'table' then return end
    overload = payload
    sendOverload()
end)

RegisterNUICallback('ready', function(_, callback)
    nuiReady = true
    syncHud()
    refreshEssence(0)
    refreshOverload(0)
    callback({ ok = true })
end)

RegisterNUICallback('activate', function(data, callback)
    local success, reason = activateSlot(tonumber(data and data.slot))
    callback({ ok = success == true, reason = reason })
end)

RegisterNUICallback('saveKeybinds', function(data, callback)
    local success, reason = saveKeybinds(data and data.bindings)
    if success then
        closeKeybindMenu()
    end
    callback({ ok = success == true, reason = reason })
end)

RegisterNUICallback('closeKeybinds', function(_, callback)
    closeKeybindMenu()
    callback({ ok = true })
end)

if Config.KeybindMenuCommand and Config.KeybindMenuCommand ~= '' then
    RegisterCommand(Config.KeybindMenuCommand, function()
        openKeybindMenu()
    end, false)
end

CreateThread(function()
    while true do
        local provider = activeProviderId and providers[activeProviderId] or nil
        local status = runtimeStatus
        local canReadKeys = hudVisible
            and provider ~= nil
            and provider.visible ~= false
            and status.hidden ~= true
            and not keybindMenuOpen
            and not IsNuiFocused()

        if canReadKeys then
            Wait(0)

            for slot = 1, 4 do
                local ability = provider.abilities[slot]
                local control = ability and keyControls[ability.key] or nil

                if control and (IsControlJustPressed(0, control) or IsDisabledControlJustPressed(0, control)) then
                    activateSlot(slot)
                    break
                end
            end
        else
            Wait(180)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(300)

        local current = getRuntimeStatus()
        local signature = statusSignature(current)
        if signature ~= runtimeSignature then
            runtimeStatus = current
            runtimeSignature = signature

            if keybindMenuOpen and current.hidden then
                closeKeybindMenu()
            end

            syncHud()
        end
    end
end)

if Config.TestCommand and Config.TestCommand ~= '' then
    RegisterCommand(Config.TestCommand, function()
        demoVisible = not demoVisible

        if demoVisible then
            registerProvider('obscuria_demo', {
                label = 'Bruxa',
                archetype = 'witch',
                abilities = {
                    { id = 'ignis', slot = 1, label = 'Ignis', icon = 'icons/demo-ignis.png', charges = 3, maxCharges = 3 },
                    { id = 'vitae', slot = 2, label = 'Vitae', icon = 'icons/demo-vitae.png', charges = 2, maxCharges = 3 },
                    { id = 'petrificus', slot = 3, label = 'Glacies', icon = 'icons/demo-petrificus.png', charges = 1, maxCharges = 3 },
                    { id = 'invulneris', slot = 4, label = 'Invulneris', icon = 'icons/demo-invulneris.png', charges = 3, maxCharges = 3 },
                },
            })
            setActiveProvider('obscuria_demo')
            setVisible(true)
        else
            setVisible(false)
        end
    end, false)
end

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        syncHud()
        refreshEssence(300)
        refreshOverload(350)
    elseif resourceName == 'ob_essencias' then
        refreshEssence(500)
    elseif resourceName == 'ob_manalimit' then
        refreshOverload(500)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if LocalPlayer and LocalPlayer.state then
            LocalPlayer.state:set('obInVehicleAttachment', false, true)
        end
        closeKeybindMenu()
        SendNUIMessage({ action = 'hydrate', visible = false })
    elseif resourceName == 'ob_essencias' then
        essence.value = 0
        essence.max = 0
        essence.key = nil
        sendEssence()
    elseif resourceName == 'ob_manalimit' then
        overload = {
            success = false,
            class = nil,
            value = 0,
            max = 100,
            tier = 'stable',
            tierLabel = 'Estavel',
        }
        sendOverload()
    end
end)
