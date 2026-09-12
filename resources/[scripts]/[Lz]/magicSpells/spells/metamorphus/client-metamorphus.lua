local Magic = MagicHelpers

local faunaCasting = false
local faunaCastId = 0
local transformed = false
local faunaOriginal = nil
local restoreTimerId = 0

local function EnsurePtfx(asset)
    if not asset or asset == "" then
        return false
    end

    if HasNamedPtfxAssetLoaded(asset) then
        return true
    end

    RequestNamedPtfxAsset(asset)
    local timeout = GetGameTimer() + 1800
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < timeout do
        Wait(0)
    end

    return HasNamedPtfxAssetLoaded(asset)
end

local function EnsureModel(model)
    if not IsModelInCdimage(model) or not IsModelValid(model) then
        return false
    end

    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(10)
    end

    return HasModelLoaded(model)
end

local function EnsureNetworked(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return 0
    end

    if not NetworkGetEntityIsNetworked(entity) then
        NetworkRegisterEntityAsNetworked(entity)
        Wait(0)
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId and netId ~= 0 then
        SetNetworkIdCanMigrate(netId, true)
    end

    return netId or 0
end

local function FaceTarget(caster, target)
    if not caster or not target or caster == target or not DoesEntityExist(target) then
        return
    end

    local from = GetEntityCoords(caster)
    local to = GetEntityCoords(target)
    SetEntityHeading(caster, GetHeadingFromVector_2d(to.x - from.x, to.y - from.y))
end

local function PlayFaunaSmokeOnEntity(entity, duration)
    if not entity or not DoesEntityExist(entity) then
        return
    end

    local time = tonumber(duration) or 1200
    if not EnsurePtfx("core") then
        return
    end

    CreateThread(function()
        local endAt = GetGameTimer() + time
        local nextPulse = 0

        while GetGameTimer() < endAt and DoesEntityExist(entity) do
            local now = GetGameTimer()
            if now >= nextPulse then
                nextPulse = now + 240

                UseParticleFxAssetNextCall("core")
                StartParticleFxNonLoopedOnEntity(
                    "exp_grd_grenade_smoke",
                    entity,
                    0.0, 0.0, 0.06,
                    0.0, 0.0, 0.0,
                    1.15,
                    false, false, false
                )

                UseParticleFxAssetNextCall("core")
                StartParticleFxNonLoopedOnEntity(
                    "exp_grd_grenade_smoke",
                    entity,
                    0.0, 0.0, 0.58,
                    0.0, 0.0, 0.0,
                    0.82,
                    false, false, false
                )
            end

            Wait(0)
        end
    end)
end

local function FadeOutForMetamorph()
    if IsScreenFadedOut() or IsScreenFadingOut() then
        return
    end

    DoScreenFadeOut(450)
    while not IsScreenFadedOut() do
        Wait(0)
    end
end

local function FadeInAfterMetamorph()
    if IsScreenFadedOut() or IsScreenFadingIn() then
        DoScreenFadeIn(700)
    end
end

local function PlayTransformAnim(entity, duration)
    if not entity or not DoesEntityExist(entity) then
        return
    end

    local cfg = Config.Spells.metamorphus_fauna or {}
    local anim = cfg.transformAnimation or {}
    if not anim.dict or not anim.anim then
        return
    end

    RequestAnimDict(anim.dict)
    local timeout = GetGameTimer() + (anim.loadTimeout or 1400)
    while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < timeout do
        Wait(10)
    end

    if not HasAnimDictLoaded(anim.dict) then
        return
    end

    TaskPlayAnim(
        entity,
        anim.dict,
        anim.anim,
        4.0, 4.0,
        duration or anim.duration or 1800,
        anim.flag or 49,
        0.0,
        false, false, false
    )
end

local function StartTransformTremble(entity, duration)
    if not entity or not DoesEntityExist(entity) then
        return
    end

    local cfg = Config.Spells.metamorphus_fauna or {}
    local tremble = cfg.transformTremble or {}
    if tremble.enabled == false then
        return
    end

    local time = tonumber(duration) or 1800
    local strength = tonumber(tremble.headingStrength) or 5.0
    local interval = tonumber(tremble.interval) or 90
    local baseHeading = GetEntityHeading(entity)
    local isLocal = entity == PlayerPedId()

    if isLocal and tremble.cameraShake ~= false then
        ShakeGameplayCam("DRUNK_SHAKE", tonumber(tremble.cameraIntensity) or 0.28)
    end

    CreateThread(function()
        local endAt = GetGameTimer() + time
        local side = 1

        while GetGameTimer() < endAt and DoesEntityExist(entity) do
            side = side * -1
            SetEntityHeading(entity, baseHeading + (strength * side))
            Wait(interval)
        end

        if DoesEntityExist(entity) then
            SetEntityHeading(entity, baseHeading)
        end

        if isLocal and IsGameplayCamShaking() then
            StopGameplayCamShaking(true)
        end
    end)
end

local function CaptureAppearanceExport(ped)
    if GetResourceState("illenium-appearance") == "started" then
        local ok, appearance = pcall(function()
            return exports["illenium-appearance"]:getPedAppearance(ped)
        end)
        if ok and appearance then
            return "illenium-appearance", appearance
        end
    end

    if GetResourceState("fivem-appearance") == "started" then
        local ok, appearance = pcall(function()
            return exports["fivem-appearance"]:getPedAppearance(ped)
        end)
        if ok and appearance then
            return "fivem-appearance", appearance
        end
    end

    return nil, nil
end

local function ApplyAppearanceExport(resourceName, appearance)
    if not resourceName or not appearance or GetResourceState(resourceName) ~= "started" then
        return false
    end

    local ok = false
    if resourceName == "illenium-appearance" then
        ok = pcall(function()
            exports["illenium-appearance"]:setPlayerAppearance(appearance)
        end)
    elseif resourceName == "fivem-appearance" then
        ok = pcall(function()
            exports["fivem-appearance"]:setPlayerAppearance(appearance)
        end)
    end

    return ok == true
end

local function SaveCurrentPlayerAppearance()
    local ped = PlayerPedId()
    local appearanceResource, appearance = CaptureAppearanceExport(ped)
    local data = {
        model = GetEntityModel(ped),
        health = GetEntityHealth(ped),
        maxHealth = GetEntityMaxHealth(ped),
        armor = GetPedArmour(ped),
        appearanceResource = appearanceResource,
        appearance = appearance,
        components = {},
        props = {}
    }

    for comp = 0, 12 do
        data.components[comp] = {
            drawable = GetPedDrawableVariation(ped, comp),
            texture = GetPedTextureVariation(ped, comp),
            palette = GetPedPaletteVariation(ped, comp)
        }
    end

    for prop = 0, 7 do
        data.props[prop] = {
            index = GetPedPropIndex(ped, prop),
            texture = GetPedPropTextureIndex(ped, prop)
        }
    end

    faunaOriginal = data
end

local function ApplyFallbackAppearance(data)
    local model = data.model
    if not EnsureModel(model) then
        return
    end

    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)

    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)

    for comp, item in pairs(data.components or {}) do
        SetPedComponentVariation(
            ped,
            comp,
            item.drawable or 0,
            item.texture or 0,
            item.palette or 0
        )
    end

    for prop, item in pairs(data.props or {}) do
        if item.index and item.index >= 0 then
            SetPedPropIndex(ped, prop, item.index, item.texture or 0, true)
        else
            ClearPedProp(ped, prop)
        end
    end

    if model == GetHashKey("mp_m_freemode_01") or model == GetHashKey("mp_f_freemode_01") then
        pcall(function()
            if exports["skinshop"] and exports["skinshop"].Apply then
                exports["skinshop"]:Apply(nil, ped)
            end
        end)

        pcall(function()
            if exports["barbershop"] and exports["barbershop"].Apply then
                exports["barbershop"]:Apply(nil, ped)
            end
        end)
    end
end

local function SetFaunaBlocked(enabled)
    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set("magicFauna", enabled and true or false, true)
        LocalPlayer.state:set("invBusy", enabled and true or false, true)
        LocalPlayer.state:set("inv_busy", enabled and true or false, true)
        LocalPlayer.state:set("Buttons", enabled and true or false, true)
    end

    if enabled then
        if Main and Main.ForceCloseGrimoire then
            Main.ForceCloseGrimoire(true)
        else
            TriggerServerEvent("magic:server:setWandState", false)
            if MagicHud then
                MagicHud.Hide()
            end
        end

        SetNuiFocus(false, false)
    end
end

local function StartFaunaControlBlock()
    CreateThread(function()
        while transformed do
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 45, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 157, true)
            DisableControlAction(0, 158, true)
            DisableControlAction(0, 159, true)
            DisableControlAction(0, 160, true)
            DisableControlAction(0, 161, true)
            DisableControlAction(0, 162, true)
            DisableControlAction(0, 163, true)
            DisableControlAction(0, 164, true)
            DisableControlAction(0, 165, true)
            DisableControlAction(0, 166, true)
            DisableControlAction(0, 167, true)
            DisableControlAction(0, 168, true)
            DisableControlAction(0, 169, true)
            DisableControlAction(0, 170, true)
            DisableControlAction(0, 289, true)
            Wait(0)
        end
    end)
end

local function RestorePlayerAppearance()
    if not transformed then
        return
    end

    local data = faunaOriginal
    transformed = false
    restoreTimerId = restoreTimerId + 1
    faunaOriginal = nil

    if not data then
        SetFaunaBlocked(false)
        return
    end

    local oldPed = PlayerPedId()
    local currentHealth = GetEntityHealth(oldPed)
    local coords = GetEntityCoords(oldPed)
    local heading = GetEntityHeading(oldPed)

    if IsEntityDead(oldPed) then
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
        currentHealth = math.max(101, math.floor((data.health or 200) * 0.45))
    end

    local restoredByExport = ApplyAppearanceExport(data.appearanceResource, data.appearance)
    if not restoredByExport then
        ApplyFallbackAppearance(data)
    end

    Wait(0)

    local ped = PlayerPedId()
    local maxHealth = math.max(tonumber(data.maxHealth) or 200, 100)
    local health = math.min(maxHealth, math.max(101, tonumber(currentHealth) or data.health or maxHealth))

    SetEntityMaxHealth(ped, maxHealth)
    SetEntityHealth(ped, health)
    SetPedArmour(ped, tonumber(data.armor) or 0)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetPedDiesWhenInjured(ped, true)

    SetFaunaBlocked(false)
    Magic.Notify("Metamorphus", "Voce retorna a sua forma original.", "inform", 4500)
end

local function StartMetamorphFxOnNet(targetNet, duration)
    targetNet = tonumber(targetNet) or 0
    if targetNet <= 0 then
        return
    end

    local ped = NetToPed(targetNet)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return
    end

    PlayFaunaSmokeOnEntity(ped, duration or 1500)
end

RegisterNetEvent("magic:client:metamorphusFx", function(targetNet, duration)
    StartMetamorphFxOnNet(targetNet, duration or 20000)
end)

local function TransformLocalPlayerToChicken(duration)
    if transformed then
        return
    end

    if LocalPlayer and LocalPlayer.state and LocalPlayer.state.magicInvulneris then
        Magic.Notify("Invulneris", "O domo arcano bloqueia Metamorphus.", "inform", 3500)
        return
    end

    SaveCurrentPlayerAppearance()
    SetFaunaBlocked(true)

    local cfg = Config.Spells.metamorphus_fauna or {}
    local transformDelay = tonumber(cfg.transformDelay) or 1900
    local smokeTime = tonumber(cfg.transformSmokeTime) or (transformDelay + 450)
    local beforePed = PlayerPedId()

    FreezeEntityPosition(beforePed, true)
    PlayTransformAnim(beforePed, transformDelay)
    StartTransformTremble(beforePed, transformDelay)
    PlayFaunaSmokeOnEntity(beforePed, smokeTime)
    Wait(transformDelay)
    FadeOutForMetamorph()

    local chickenHash = GetHashKey("a_c_hen")
    if not EnsureModel(chickenHash) then
        FreezeEntityPosition(beforePed, false)
        SetFaunaBlocked(false)
        FadeInAfterMetamorph()
        Magic.Notify("Metamorphus", "Modelo de galinha nao carregou.", "error", 3500)
        return
    end

    local original = faunaOriginal or {}
    local maxHealth = math.max(tonumber(original.maxHealth) or 200, 100)
    local health = math.min(maxHealth, math.max(1, tonumber(original.health) or maxHealth))

    SetPlayerModel(PlayerId(), chickenHash)
    SetModelAsNoLongerNeeded(chickenHash)

    local chickenPed = PlayerPedId()
    SetEntityMaxHealth(chickenPed, maxHealth)
    SetEntityHealth(chickenPed, health)
    SetPedArmour(chickenPed, tonumber(original.armor) or 0)
    SetEntityVisible(chickenPed, true, false)
    FreezeEntityPosition(chickenPed, false)
    SetPedDiesWhenInjured(chickenPed, false)

    transformed = true
    PlayFaunaSmokeOnEntity(chickenPed, 900)
    FadeInAfterMetamorph()
    StartFaunaControlBlock()

    restoreTimerId = restoreTimerId + 1
    local thisTimer = restoreTimerId
    SetTimeout(duration or 20000, function()
        if transformed and thisTimer == restoreTimerId then
            RestorePlayerAppearance()
        end
    end)
end

local function TransformPedToChicken(targetPed, duration)
    if not targetPed or not DoesEntityExist(targetPed) then
        return false
    end

    local targetNet = EnsureNetworked(targetPed)
    if targetNet ~= 0 and _G.MagicProtectedEntities and _G.MagicProtectedEntities[targetNet] then
        Magic.Notify("Invulneris", "O domo arcano bloqueia Metamorphus.", "inform", 3500)
        return false
    end

    local cfg = Config.Spells.metamorphus_fauna or {}
    local time = duration or 20000
    local transformDelay = tonumber(cfg.transformDelay) or 1900
    local smokeTime = tonumber(cfg.transformSmokeTime) or (transformDelay + 450)
    local model = GetHashKey("a_c_hen")

    if not EnsureModel(model) then
        return false
    end

    SetEntityAsMissionEntity(targetPed, true, true)
    FreezeEntityPosition(targetPed, true)
    PlayTransformAnim(targetPed, transformDelay)
    StartTransformTremble(targetPed, transformDelay)
    PlayFaunaSmokeOnEntity(targetPed, smokeTime)
    Wait(transformDelay)

    local coords = GetEntityCoords(targetPed)
    local heading = GetEntityHeading(targetPed)

    local chicken = CreatePed(28, model, coords.x, coords.y, coords.z, heading, true, false)
    SetModelAsNoLongerNeeded(model)

    if not DoesEntityExist(chicken) then
        FreezeEntityPosition(targetPed, false)
        return false
    end

    local maxHealth = math.max(GetEntityMaxHealth(targetPed), 100)
    local health = math.min(maxHealth, math.max(1, GetEntityHealth(targetPed)))
    SetEntityMaxHealth(chicken, maxHealth)
    SetEntityHealth(chicken, health)
    SetPedDiesWhenInjured(chicken, false)
    PlayFaunaSmokeOnEntity(chicken, 900)

    SetEntityVisible(targetPed, false, false)
    SetEntityCollision(targetPed, false, false)
    FreezeEntityPosition(targetPed, true)
    SetEntityInvincible(targetPed, true)

    TaskWanderStandard(chicken, 10.0, 10)

    SetTimeout(time, function()
        local finalHealth = health
        if DoesEntityExist(chicken) then
            finalHealth = math.max(1, GetEntityHealth(chicken))
            DeleteEntity(chicken)
        end

        if DoesEntityExist(targetPed) then
            SetEntityVisible(targetPed, true, false)
            SetEntityCollision(targetPed, true, true)
            FreezeEntityPosition(targetPed, false)
            SetEntityInvincible(targetPed, false)
            SetEntityHealth(targetPed, math.min(GetEntityMaxHealth(targetPed), finalHealth))
        end
    end)

    return true
end

RegisterNetEvent("magic:client:metamorphPlayer", function(duration)
    TransformLocalPlayerToChicken(duration or 20000)
end)

local function GetFaunaTarget(dist)
    local target = nil
    if Magic.GetPedTargetInFront then
        target = Magic.GetPedTargetInFront(dist or 12.0)
    end

    if not target or not DoesEntityExist(target) or not IsPedAPlayer(target)
        or IsPedDeadOrDying(target, true) then
        return nil
    end

    return target
end

local function CastFauna(targetPed, castMode)
    if faunaCasting then
        return
    end

    local cfg = Config.Spells.metamorphus_fauna or {}
    local ped = PlayerPedId()
    local castTime = tonumber(cfg.castTime) or 3000
    local duration = tonumber(cfg.duration) or 20000

    if castMode == "self" then
        castTime = tonumber(cfg.selfCastTime) or 0
    end

    if not targetPed or not DoesEntityExist(targetPed)
        or (castMode ~= "self" and not IsPedAPlayer(targetPed)) then
        Magic.Notify("Metamorphus", "Nenhum alvo valido na mira.", "error", 3500)
        return
    end

    local targetNet = EnsureNetworked(targetPed)
    if targetNet ~= 0 and _G.MagicProtectedEntities and _G.MagicProtectedEntities[targetNet] then
        Magic.Notify("Invulneris", "O domo arcano bloqueia Metamorphus.", "inform", 3500)
        return
    end

    faunaCasting = true
    faunaCastId = faunaCastId + 1
    local thisCastId = faunaCastId

    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set("Buttons", true, true)
    end

    FaceTarget(ped, targetPed)
    if castTime > 0 then
        Magic.PlaySpellAnim(cfg)
        TriggerEvent("Progress", "Entoando Metamorphus Fauna", castTime)
    end

    CreateThread(function()
        while faunaCasting and thisCastId == faunaCastId do
            if IsControlJustPressed(0, 303) or IsControlJustPressed(0, 177) then
                faunaCasting = false
                faunaCastId = faunaCastId + 1

                if LocalPlayer and LocalPlayer.state then
                    LocalPlayer.state:set("Buttons", false, true)
                end

                ClearPedTasks(ped)
                Magic.Notify("Metamorphus", "Metamorphus Fauna foi cancelada.", "inform", 3500)
                return
            end

            Wait(0)
        end
    end)

    SetTimeout(castTime, function()
        if not faunaCasting or thisCastId ~= faunaCastId then
            return
        end

        faunaCasting = false
        if LocalPlayer and LocalPlayer.state then
            LocalPlayer.state:set("Buttons", false, true)
        end
        ClearPedTasks(ped)

        if not targetPed or not DoesEntityExist(targetPed)
            or (castMode ~= "self" and not IsPedAPlayer(targetPed)) then
            Magic.Notify("Metamorphus", "O alvo desapareceu.", "error", 3500)
            return
        end

        local isPlayer = IsPedAPlayer(targetPed)
        local success = false

        if isPlayer then
            local ply = NetworkGetPlayerIndexFromPed(targetPed)
            local targetSrc = ply and GetPlayerServerId(ply) or nil
            local mySrc = GetPlayerServerId(PlayerId())

            if targetSrc and targetSrc ~= mySrc then
                TriggerServerEvent("magic:server:metamorphPlayer", targetSrc, duration)
                success = true
            else
                TransformLocalPlayerToChicken(duration)
                success = true
            end
        end

        if success then
            if targetNet ~= 0 then
                TriggerServerEvent("magic:server:metamorphusFxBroadcast", targetNet, math.min(duration, 3000))
            end

            Magic.ApplyDamageToPlayer(10)
            Magic.FinishSpellCooldown("metamorphus_fauna")
        else
            Magic.Notify("Metamorphus", "Nao foi possivel transformar esse alvo.", "error", 3500)
        end
    end)
end

RegisterNetEvent("magic:spells:metamorphus_fauna", function(castMode)
    if faunaCasting then
        return
    end

    local cfg = Config.Spells.metamorphus_fauna or {}

    if castMode == "self" then
        CastFauna(PlayerPedId(), "self")
        return
    end

    local target = GetFaunaTarget(cfg.distance or 12.0)
    if not target or target == PlayerPedId() then
        Magic.Notify("Metamorphus", "Mire em uma pessoa viva para transformar.", "error", 3500)
        return
    end

    CastFauna(target, "target")
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if transformed then
        RestorePlayerAppearance()
    end
end)
