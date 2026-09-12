MagicHud = MagicHud or {}

local externalCrosshairs = {}
local grimoireVisible = false
local grimoireVisibilityInitialized = false

function MagicHud.SetVisible(visible)
    visible = visible == true
    if grimoireVisibilityInitialized and grimoireVisible == visible then
        return
    end

    grimoireVisibilityInitialized = true
    SendNUIMessage({
        action = "setVisible",
        visible = visible
    })

    grimoireVisible = visible
    TriggerEvent('magic:client:grimoireVisibilityChanged', grimoireVisible)
end

exports('IsGrimoireHudVisible', function()
    return grimoireVisible
end)

function MagicHud.SetCrosshair(payload)
    payload = payload or {}
    payload.action = "setCrosshair"
    SendNUIMessage(payload)
end

function MagicHud.HideCrosshair()
    MagicHud.SetCrosshair({ visible = false })
end

function MagicHud.SetExternalCrosshair(owner, payload)
    owner = tostring(owner or '')
    if owner == '' then
        return false
    end

    payload = type(payload) == 'table' and payload or {}
    if payload.visible == false then
        externalCrosshairs[owner] = nil
        return true
    end

    externalCrosshairs[owner] = {
        payload = {
            visible = true,
            target = payload.target == true,
            label = tostring(payload.label or ''),
            kind = payload.kind,
        },
        priority = tonumber(payload.priority) or 0,
        updatedAt = GetGameTimer(),
        expiresAt = GetGameTimer() + math.max(150, tonumber(payload.ttl) or 500),
    }

    MagicHud.SetCrosshair(externalCrosshairs[owner].payload)
    return true
end

function MagicHud.HideExternalCrosshair(owner)
    owner = tostring(owner or '')
    if owner == '' then
        return false
    end

    externalCrosshairs[owner] = nil
    TriggerEvent('magic:client:refreshCrosshair')
    return true
end

function MagicHud.GetExternalCrosshairPayload()
    local now = GetGameTimer()
    local selected = nil

    for owner, entry in pairs(externalCrosshairs) do
        if entry.expiresAt <= now then
            externalCrosshairs[owner] = nil
        elseif not selected
            or entry.priority > selected.priority
            or (entry.priority == selected.priority and entry.updatedAt > selected.updatedAt) then
            selected = entry
        end
    end

    return selected and selected.payload or nil
end

function MagicHud.HasExternalCrosshair()
    return next(externalCrosshairs) ~= nil
end

exports('SetExternalCrosshair', function(owner, payload)
    return MagicHud.SetExternalCrosshair(owner, payload)
end)

exports('HideExternalCrosshair', function(owner)
    return MagicHud.HideExternalCrosshair(owner)
end)

exports('SetCrosshairCharge', function(active, duration, label)
    MagicHud.SetCastCharge(active == true, tonumber(duration) or 0, label)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    externalCrosshairs[resourceName] = nil
end)

function MagicHud.SetCancelTipVisible(visible)
    SendNUIMessage({
        action = "setCancelTip",
        visible = visible and true or false
    })
end

function MagicHud.SetSpells(spells)
    SendNUIMessage({
        action = "setSpells",
        spells = spells or {}
    })
end

function MagicHud.SetNavigation()
    SendNUIMessage({
        action = "setNavigation",
        prev = (Config.Controls and Config.Controls.GrimoirePrevLabel) or "ESQ",
        next = (Config.Controls and Config.Controls.GrimoireNextLabel) or "DIR"
    })
end

function MagicHud.SetActiveSpell(spellName, index, direction)
    SendNUIMessage({
        action = "setActiveSpell",
        spell = spellName,
        index = index,
        direction = tonumber(direction) or 0
    })
end

function MagicHud.StartCooldown(spellName, duration)
    SendNUIMessage({
        action = "startCooldown",
        spell = spellName,
        duration = duration or 0
    })
end

function MagicHud.PulseSpellError(spellName)
    SendNUIMessage({
        action = "pulseSpellError",
        spell = spellName
    })
end

function MagicHud.SetCastCharge(active, duration, spellName)
    SendNUIMessage({
        action = "setCastCharge",
        active = active and true or false,
        duration = duration or 0,
        spell = spellName
    })
end

function MagicHud.SetSpellCharge(active, value, spellName)
    SendNUIMessage({
        action = "setSpellCharge",
        active = active and true or false,
        value = value or 0,
        spell = spellName
    })
end

function MagicHud.SetHints(lines)
    SendNUIMessage({
        action = "setHints",
        lines = lines or {}
    })
end

function MagicHud.Hide()
    MagicHud.SetVisible(false)
    MagicHud.HideCrosshair()
    MagicHud.SetSpellCharge(false)
    MagicHud.SetCancelTipVisible(false)
end
