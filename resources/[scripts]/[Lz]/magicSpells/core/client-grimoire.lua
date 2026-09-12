MagicGrimoire = MagicGrimoire or {}

local knownSpells = {}
local spellCooldowns = {}
local grimoireIndex = 1
local grimoirePages = {}
local currentSpell = nil
local visualTestMode = false
local castRequestLocked = false
local lastCrosshairPayload = nil
local pendingSpellCharges = {}
local hudManuallyHidden = false
local holdCharge = {
    active = false,
    spell = nil,
    startedAt = 0
}

local function RefreshCrosshair()
    lastCrosshairPayload = nil
end

exports('RefreshCrosshair', RefreshCrosshair)
AddEventHandler('magic:client:refreshCrosshair', RefreshCrosshair)

local function Notify(title, message, notifyType, duration)
    if Main and Main.Notify then
        Main.Notify(title, message, notifyType, duration)
    end
end

local function HasLocalWand()
    return Main and Main.HasLocalWand and Main.HasLocalWand()
end

local function HasGrimoireAccess()
    return Main and Main.HasGrimoireAccess and Main.HasGrimoireAccess()
end

local function IsSpellMode()
    return Main and Main.IsSpellMode and Main.IsSpellMode()
end

local function CanUseGrimoire()
    return HasGrimoireAccess() and (visualTestMode or (IsSpellMode() and HasLocalWand()))
end

local function IsGrimoireSuppressed()
    return MagicHelpers
        and MagicHelpers.IsHudSuppressed
        and MagicHelpers.IsHudSuppressed()
        or false
end

local function CanCastGrimoireSpell()
    if not CanUseGrimoire() or IsGrimoireSuppressed() then
        return false
    end

    return not (Main and Main.IsMagicLocked and Main.IsMagicLocked())
end

function MagicGrimoire.IsVisible()
    return CanUseGrimoire() and not hudManuallyHidden and not IsGrimoireSuppressed()
end

exports('IsGrimoireVisible', function()
    return MagicGrimoire.IsVisible()
end)

local function GetCurrentSpellName()
    return grimoirePages[grimoireIndex] or currentSpell
end

local function GetCurrentSpellData()
    local spellName = GetCurrentSpellName()
    return spellName, spellName and Config.Spells[spellName] or nil
end

function MagicGrimoire.ConsumePendingCharge(spellName)
    local value = pendingSpellCharges[spellName]
    pendingSpellCharges[spellName] = nil
    return value
end

local function IsOnCooldown(spellName)
    local endsAt = spellCooldowns[spellName]
    return endsAt and GetGameTimer() < endsAt
end

local function GetCooldownRemaining(spellName)
    local endsAt = spellCooldowns[spellName]
    if not endsAt then
        return 0
    end

    return math.max(0, endsAt - GetGameTimer())
end

function MagicGrimoire.StartCooldown(spellName, ms)
    if not ms or ms <= 0 then
        return
    end

    spellCooldowns[spellName] = GetGameTimer() + ms
    MagicHud.StartCooldown(spellName, ms)
end

function StartCooldown(spellName, ms)
    MagicGrimoire.StartCooldown(spellName, ms)
end

local function BuildSpellHudList()
    local list
    list, grimoirePages = SpellsHud.BuildHudSpells(knownSpells)

    if grimoireIndex > #grimoirePages then
        grimoireIndex = 1
    end

    return list
end

function MagicGrimoire.SetActiveSpell(spellName, pageDirection)
    if not spellName or not knownSpells[spellName] then
        return
    end

    currentSpell = spellName

    for index, pageSpell in ipairs(grimoirePages) do
        if pageSpell == spellName then
            grimoireIndex = index
            break
        end
    end

    MagicHud.SetActiveSpell(spellName, grimoireIndex, pageDirection)
end

function MagicGrimoire.Refresh()
    if not CanUseGrimoire() then
        hudManuallyHidden = false
        MagicHud.Hide()
        return
    end

    if IsGrimoireSuppressed() then
        MagicHud.Hide()
        return
    end

    local spells = BuildSpellHudList()
    MagicHud.SetSpells(spells)
    MagicHud.SetNavigation()
    MagicHud.SetVisible(not hudManuallyHidden)

    if #grimoirePages > 0 then
        MagicGrimoire.SetActiveSpell(grimoirePages[grimoireIndex] or grimoirePages[1])
    end
end

function MagicGrimoire.ResetCurrentSpell()
    currentSpell = nil
end

function MagicGrimoire.TurnPage(direction)
    if not CanCastGrimoireSpell() or #grimoirePages <= 0 then
        return
    end

    if holdCharge.active then
        MagicHud.SetSpellCharge(false, 0, holdCharge.spell)
        holdCharge.active = false
        holdCharge.spell = nil
        holdCharge.startedAt = 0
    end

    grimoireIndex = grimoireIndex + direction
    if grimoireIndex < 1 then
        grimoireIndex = #grimoirePages
    elseif grimoireIndex > #grimoirePages then
        grimoireIndex = 1
    end

    MagicGrimoire.SetActiveSpell(grimoirePages[grimoireIndex], direction)
end

function MagicGrimoire.SetVisualTestMode(state)
    visualTestMode = state and true or false

    if visualTestMode then
        hudManuallyHidden = false
        knownSpells = {}
        for spellName in pairs(Config.Spells or {}) do
            knownSpells[spellName] = true
        end

        currentSpell = nil
        grimoireIndex = 1
        Notify("Grimorio", "Preview visual do grimorio ativado.", "inform", 2500)
        MagicGrimoire.Refresh()
        return
    end

    MagicHud.Hide()
    hudManuallyHidden = false
    TriggerServerEvent("magic:server:syncSpells")
    Notify("Grimorio", "Preview visual do grimorio fechado.", "inform", 2500)
end

function MagicGrimoire.ToggleHudHidden()
    if not CanUseGrimoire() then
        MagicHud.SetVisible(false)
        return
    end

    hudManuallyHidden = not hudManuallyHidden
    MagicHud.SetVisible(not hudManuallyHidden)

    if hudManuallyHidden then
        Notify("Grimorio", "HUD oculta. As magias continuam funcionando.", "inform", 2500)
    else
        MagicGrimoire.Refresh()
        Notify("Grimorio", "HUD visivel novamente.", "inform", 2500)
    end
end

function MagicGrimoire.ToggleVisualTestMode()
    MagicGrimoire.SetVisualTestMode(not visualTestMode)
end

local function CastCurrentGrimoireSpell(castMode, chargeValue)
    if not CanCastGrimoireSpell() or castRequestLocked then
        return
    end

    local spellName, spellData = GetCurrentSpellData()
    if not spellName or not spellData then
        return
    end

    if castMode == "self" and spellData.selfCast ~= true then
        return
    end

    if not knownSpells[spellName] then
        Notify("Grimorio", "Voce ainda nao aprendeu essa magia.", "error", 4000)
        return
    end

    if IsOnCooldown(spellName) then
        local ms = GetCooldownRemaining(spellName)
        Notify("Grimorio", ("Essa magia ainda esta em recarga (%.1fs)."):format(ms / 1000), "error", 3000)
        return
    end

    castRequestLocked = true
    MagicGrimoire.SetActiveSpell(spellName)

    if type(chargeValue) == "number" then
        pendingSpellCharges[spellName] = chargeValue
    end

    TriggerServerEvent("magic:server:requestCast", spellName, castMode or "target")

    CreateThread(function()
        Wait(1200)
        castRequestLocked = false
    end)
end

local function StopHoldCharge()
    if holdCharge.active then
        MagicHud.SetSpellCharge(false, 0, holdCharge.spell)
    end

    holdCharge.active = false
    holdCharge.spell = nil
    holdCharge.startedAt = 0
end

local function GetHoldChargeValue(spellData)
    if not holdCharge.active then
        return 0.0
    end

    local duration = tonumber(spellData and spellData.holdChargeMs) or 1200
    if duration <= 0 then
        return 1.0
    end

    return math.min((GetGameTimer() - holdCharge.startedAt) / duration, 1.0)
end

local function StartHoldCharge(spellName)
    holdCharge.active = true
    holdCharge.spell = spellName
    holdCharge.startedAt = GetGameTimer()
    MagicHud.SetSpellCharge(true, 0.0, spellName)
end

local function UpdateHoldCharge(spellData)
    if not holdCharge.active then
        return
    end

    MagicHud.SetSpellCharge(true, GetHoldChargeValue(spellData), holdCharge.spell)
end

local function ReleaseHoldCharge(spellData)
    if not holdCharge.active then
        return
    end

    local spellName = holdCharge.spell
    local value = GetHoldChargeValue(spellData)
    StopHoldCharge()

    if spellName == GetCurrentSpellName() then
        CastCurrentGrimoireSpell("target", value)
    end
end

local function BuildCrosshairPayload()
    if IsGrimoireSuppressed() then
        return { visible = false }
    end

    local external = MagicHud.GetExternalCrosshairPayload and MagicHud.GetExternalCrosshairPayload()
    if external then
        return external
    end

    if not MagicGrimoire.IsVisible()
        or not Config.Crosshair
        or Config.Crosshair.Enabled == false then
        return { visible = false }
    end

    local payload = {
        visible = true,
        target = false,
        label = currentSpell and ((Config.Spells[currentSpell] and Config.Spells[currentSpell].shortLabel) or currentSpell) or ""
    }

    if MagicHelpers and MagicHelpers.RaycastFromCamera then
        local result = MagicHelpers.RaycastFromCamera((Config.Crosshair and Config.Crosshair.MaxDistance) or 55.0, -1)
        if result and result.hit and result.entity and DoesEntityExist(result.entity) then
            payload.target = true
            if IsEntityAPed(result.entity) then
                payload.kind = "ped"
            elseif IsEntityAVehicle(result.entity) then
                payload.kind = "vehicle"
            else
                payload.kind = "world"
            end
        end
    end

    return payload
end

CreateThread(function()
    MagicHud.Hide()
    TriggerServerEvent("magic:server:syncSpells")
end)

RegisterNetEvent("magic:client:setKnownSpells", function(spellNames)
    knownSpells = {}
    for _, name in ipairs(spellNames or {}) do
        knownSpells[name] = true
    end

    MagicGrimoire.Refresh()
end)

if Config.TestCommand and Config.TestCommand.Enabled ~= false then
    RegisterCommand(Config.TestCommand.Name or "grimorioteste", function()
        MagicGrimoire.ToggleVisualTestMode()
    end, false)
end

RegisterCommand("magic_grimoire_next", function()
    MagicGrimoire.TurnPage(1)
end, false)

RegisterCommand("magic_grimoire_prev", function()
    MagicGrimoire.TurnPage(-1)
end, false)

RegisterCommand("removerhud", function()
    MagicGrimoire.ToggleHudHidden()
end, false)

RegisterKeyMapping("magic_grimoire_next", "Proxima pagina do grimorio", "keyboard", (Config.Controls and Config.Controls.GrimoireNextKey) or "RIGHT")
RegisterKeyMapping("magic_grimoire_prev", "Pagina anterior do grimorio", "keyboard", (Config.Controls and Config.Controls.GrimoirePrevKey) or "LEFT")

RegisterNetEvent("magic:client:castSpell", function(spell, castMode)
    if not CanCastGrimoireSpell() then
        castRequestLocked = false
        return
    end

    local data = Config.Spells[spell]
    if not data then
        print("[magicSpells] Spell nao encontrada: " .. tostring(spell))
        castRequestLocked = false
        return
    end

    currentSpell = spell
    MagicGrimoire.SetActiveSpell(spell)
    MagicHud.SetCancelTipVisible(false)

    if data.cancelTipDelay and data.cancelTipDelay > 0 then
        CreateThread(function()
            local thisSpell = spell
            Wait(data.cancelTipDelay)

            if IsSpellMode() and currentSpell == thisSpell then
                MagicHud.SetCancelTipVisible(true)
            end
        end)
    end

    local chargeTime = tonumber(data.chargeTime or (Config.Crosshair and Config.Crosshair.CastChargeTime) or 0) or 0
    if chargeTime > 0 then
        MagicHud.SetCastCharge(true, chargeTime, spell)

        local ped = PlayerPedId()
        if spell == "ignis_conflagratio" and data.animation and data.animation.dict and data.animation.anim then
            MagicHelpers.PlaySpellAnim(data)
        end

        Wait(chargeTime)
        ClearPedSecondaryTask(ped)

        if not CanCastGrimoireSpell() then
            MagicHud.SetCastCharge(false)
            castRequestLocked = false
            return
        end
    end

    TriggerEvent("magic:spells:" .. spell, castMode or "target")
    castRequestLocked = false
end)

RegisterNetEvent("magic:client:castDenied", function(spell, reason, essenceCost)
    castRequestLocked = false
    pendingSpellCharges[spell] = nil
    MagicHud.SetCastCharge(false)

    if reason == "overload" then
        MagicHud.PulseSpellError(spell)
    elseif reason == "essence" then
        MagicHud.PulseSpellError(spell)
        Notify(
            "Grimorio",
            ("Essencia insuficiente. %s requer %d."):format(
                (Config.Spells[spell] and Config.Spells[spell].label) or spell or "Essa magia",
                math.max(0, tonumber(essenceCost) or 0)
            ),
            "error",
            3200
        )
    elseif reason == "cooldown" then
        MagicHud.PulseSpellError(spell)
        Notify(
            "Grimorio",
            ("Essa magia ainda esta em recarga (%.1fs)."):format(math.max(0, tonumber(essenceCost) or 0) / 1000),
            "error",
            3000
        )
    elseif reason == "busy" then
        MagicHud.PulseSpellError(spell)
        Notify("Grimorio", "Essa magia ja esta sendo conjurada.", "error", 2500)
    end
end)

CreateThread(function()
    while true do
        if CanCastGrimoireSpell() then
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 142, true)

            local externalCrosshairActive = MagicHud.HasExternalCrosshair
                and MagicHud.HasExternalCrosshair()

            if externalCrosshairActive then
                if holdCharge.active then
                    StopHoldCharge()
                end
            else
                local spellName, spellData = GetCurrentSpellData()
                local holdToCharge = spellData and spellData.holdToCharge == true

                if holdToCharge then
                    if IsDisabledControlJustPressed(0, 24) and not castRequestLocked then
                        if IsOnCooldown(spellName) then
                            local ms = GetCooldownRemaining(spellName)
                            Notify("Grimorio", ("Essa magia ainda esta em recarga (%.1fs)."):format(ms / 1000), "error", 2500)
                        else
                            StartHoldCharge(spellName)
                        end
                    elseif holdCharge.active and IsDisabledControlPressed(0, 24) then
                        UpdateHoldCharge(spellData)
                    elseif holdCharge.active and IsDisabledControlJustReleased(0, 24) then
                        ReleaseHoldCharge(spellData)
                    end
                else
                    if holdCharge.active then
                        StopHoldCharge()
                    end

                    if IsDisabledControlJustPressed(0, 24) then
                        CastCurrentGrimoireSpell("target")
                    elseif IsDisabledControlJustPressed(0, 25) then
                        CastCurrentGrimoireSpell("self")
                    end
                end
            end

            Wait(0)
        else
            if holdCharge.active then
                StopHoldCharge()
            end

            Wait(1000)
        end
    end
end)

CreateThread(function()
    local wasSuppressed = IsGrimoireSuppressed()

    while true do
        local suppressed = IsGrimoireSuppressed()
        if suppressed ~= wasSuppressed then
            wasSuppressed = suppressed

            if suppressed then
                StopHoldCharge()
                castRequestLocked = false
                MagicHud.SetCastCharge(false)
                MagicHud.HideCrosshair()
            end

            MagicGrimoire.Refresh()
        end

        Wait(IsSpellMode() and 120 or 500)
    end
end)

CreateThread(function()
    while true do
        local hasExternalCrosshair = MagicHud.HasExternalCrosshair
            and MagicHud.HasExternalCrosshair()
        local grimoireVisible = MagicGrimoire.IsVisible()

        if not grimoireVisible
            and not castRequestLocked
            and not holdCharge.active
            and not hasExternalCrosshair then
            if lastCrosshairPayload ~= 'hidden' then
                lastCrosshairPayload = 'hidden'
                MagicHud.HideCrosshair()
            end

            Wait(1000)
        else
            local payload = BuildCrosshairPayload()
            local encoded = json.encode(payload)

            if encoded ~= lastCrosshairPayload then
                lastCrosshairPayload = encoded
                MagicHud.SetCrosshair(payload)
            end

            local interval = payload.visible
                and ((Config.Crosshair and Config.Crosshair.UpdateInterval) or 120)
                or 250
            Wait(interval)
        end
    end
end)
