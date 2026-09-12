local SelectorConfig = Config.ClassSelector or {}

local NuiOpen = false
local ClassChosen = false
local CreationFlag = false
local SelectorLoopRunning = false
local StartSelectorLoop
local PtfxStatus = {}
local AudioReady = false
local AudioSession = 0
local CurrentAudioKey
local CurrentIntroKey
local PendingIntroAudio
local IntroAudioLocked = false
local NuiAudioLocked = false

local TeleportDelay = SelectorConfig.TeleportDelay or 2500

local NotifyTypeMap = {
    default = "inform",
    amarelo = "warning",
    vermelho = "error"
}

local function Notify(title, message, notifyType, duration)
    notifyType = NotifyTypeMap[notifyType] or notifyType or "inform"
    duration = duration or 5000

    if lib and lib.notify then
        lib.notify({
            title = title,
            description = message,
            type = notifyType,
            duration = duration
        })
        return
    end

    if GetResourceState("qbx_core") == "started" then
        local ok = pcall(function()
            exports.qbx_core:Notify(message, notifyType, duration)
        end)

        if ok then
            return
        end
    end

    TriggerEvent("QBCore:Notify", message, notifyType, duration)
end

local function SendPendingIntroAudio()
    if not AudioReady or not PendingIntroAudio then return end

    SendNUIMessage({
        action = "playAudio",
        audio = PendingIntroAudio
    })
    PendingIntroAudio = nil
end

local function StopSelectorAudio()
    PendingIntroAudio = nil
    CurrentAudioKey = nil
    CurrentIntroKey = nil
    IntroAudioLocked = false
    NuiAudioLocked = false
    SendNUIMessage({ action = "stopAudio" })
end

local function BeginIntroAudio()
    local audioConfig = SelectorConfig.Audio and SelectorConfig.Audio.Intro
    if not audioConfig or not audioConfig.File or audioConfig.File == "" then
        IntroAudioLocked = false
        NuiAudioLocked = false
        return
    end

    local key = ("intro:%s"):format(AudioSession)
    CurrentIntroKey = key
    CurrentAudioKey = key
    IntroAudioLocked = true
    NuiAudioLocked = true
    PendingIntroAudio = {
        key = key,
        src = audioConfig.File,
        volume = audioConfig.Volume or 1.0,
        label = "O chamado sem rosto"
    }
    SendPendingIntroAudio()

    CreateThread(function()
        Wait(math.max(10000, audioConfig.Timeout or 180000))
        if CurrentIntroKey ~= key then return end

        CurrentIntroKey = nil
        if CurrentAudioKey == key then
            CurrentAudioKey = nil
            NuiAudioLocked = false
        end
        IntroAudioLocked = false
        SendNUIMessage({ action = "stopAudio", key = key })
    end)
end

local function OpenSelectorNui()
    if NuiOpen or ClassChosen or IntroAudioLocked or NuiAudioLocked then return end

    NuiOpen = true
    FreezeEntityPosition(PlayerPedId(), true)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "open",
        classes = Config.Classes or {},
        session = AudioSession
    })
end

local function EnsurePtfxAsset(asset)
    if not asset or asset == "" then return false end
    if HasNamedPtfxAssetLoaded(asset) then
        PtfxStatus[asset] = true
        return true
    end
    RequestNamedPtfxAsset(asset)
    local deadline = GetGameTimer() + 1800
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < deadline do
        Wait(25)
    end

    local loaded = HasNamedPtfxAssetLoaded(asset)
    PtfxStatus[asset] = loaded and true or nil
    return loaded
end

local function ResolveFx(config)
    if EnsurePtfxAsset(config.FxAsset) then
        return config.FxAsset, config.FxName
    end
    if EnsurePtfxAsset(config.FallbackAsset) then
        return config.FallbackAsset, config.FallbackName
    end
    return nil, nil
end

local function SpawnMagicFx(asset, effect, coords, config)
    if not asset or not effect then return end

    local color = config.FxColor or { 1.0, 0.04, 0.02 }
    UseParticleFxAssetNextCall(asset)
    SetParticleFxNonLoopedColour(color[1] or 1.0, color[2] or 0.04, color[3] or 0.02)
    SetParticleFxNonLoopedAlpha(config.FxAlpha or 0.85)
    StartParticleFxNonLoopedAtCoord(
        effect,
        coords.x, coords.y, coords.z + (config.FxHeight or 0.0),
        0.0, 0.0, 0.0,
        config.FxScale or 1.0,
        false, false, false
    )
end

local function PlacePlayerAtSelectorStart()
    if not SelectorConfig.StartCoords then return end

    local ped = PlayerPedId()
    local coords = SelectorConfig.StartCoords
    local shouldFadeIn = not IsScreenFadedOut()

    if shouldFadeIn then
        DoScreenFadeOut(350)
        while not IsScreenFadedOut() do Wait(0) end
    end

    FreezeEntityPosition(ped, true)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, SelectorConfig.StartHeading or 0.0)

    local deadline = GetGameTimer() + 4000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        Wait(50)
    end

    SetEntityCollision(ped, true, true)
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)
end

local function GetAppearanceDestination()
    local coords = SelectorConfig.DestinationCoords
    if not coords then return nil end

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        w = SelectorConfig.DestinationHeading or 0.0,
    }
end

RegisterNetEvent("classeSelector:notify", function(title, message, notifyType, duration)
    Notify(title or "Classe", message or "", notifyType, duration)
end)

RegisterNetEvent("classeSelector:startSelector", function(creation)
    CreationFlag = creation and true or false
    ClassChosen = false
    NuiOpen = false
    AudioSession = AudioSession + 1
    StopSelectorAudio()
    if StartSelectorLoop then
        StartSelectorLoop()
    end

    CreateThread(function()
        Wait(TeleportDelay)

        PlacePlayerAtSelectorStart()

        local ped = PlayerPedId()
        SetEntityInvincible(ped, true)
        DisplayRadar(false)

        if IsScreenFadedOut() then
            DoScreenFadeIn(500)
        end

        Notify("Destino", "Siga os vestígios. Algo aguarda por você.", "default", 10000)
        Wait(450)
        BeginIntroAudio()
    end)
end)

RegisterNetEvent("classeSelector:beginCreation", function()
    CreationFlag = true
    ClassChosen = false
    TriggerServerEvent("classeSelector:enterCreationFlow")
end)

RegisterNetEvent("classeSelector:client:useRaceChangeVoucher", function()
    if NuiOpen or CreationFlag then
        Notify("Troca de raca", "Finalize a selecao atual antes de usar outro selo.", "error", 5000)
        return
    end

    TriggerServerEvent("classeSelector:useRaceChangeVoucher")
end)

RegisterNetEvent("classeSelector:creationFlowFailed", function()
    CreationFlag = false
    ClassChosen = false
    NuiOpen = false
    StopSelectorAudio()
    SetNuiFocus(false, false)
    FreezeEntityPosition(PlayerPedId(), false)
    TriggerEvent("classeSelector:creationFailed")
end)

RegisterNetEvent("classeSelector:alreadyHasClass", function(classId)
    ClassChosen = true
    StopSelectorAudio()
    SetNuiFocus(false, false)
    NuiOpen = false
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityInvincible(PlayerPedId(), false)
    DisplayRadar(true)
    Notify("Classe", "Sua classe já foi definida: "..(classId or "?")..".", "default", 10000)

    if CreationFlag then
        CreationFlag = false
        TriggerEvent("classeSelector:creationFinished", classId, GetAppearanceDestination())
    end
end)

RegisterNetEvent("classeSelector:classChosenSuccess", function(classId)
    ClassChosen = true
    StopSelectorAudio()
    SetNuiFocus(false, false)
    NuiOpen = false
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityInvincible(PlayerPedId(), false)
    DisplayRadar(true)

    Notify("Classe", "Classe selecionada: "..(classId or "?")..".", "default", 10000)

    if CreationFlag then
        CreationFlag = false
        TriggerEvent("classeSelector:creationFinished", classId, GetAppearanceDestination())
        return
    end

    CreateThread(function()
        Wait(2000)

        DoScreenFadeOut(800)
        while not IsScreenFadedOut() do
            Wait(0)
        end

        local ped = PlayerPedId()
        if SelectorConfig.DestinationCoords then
            SetEntityCoords(
                ped,
                SelectorConfig.DestinationCoords.x,
                SelectorConfig.DestinationCoords.y,
                SelectorConfig.DestinationCoords.z,
                false, false, false, true
            )
            SetEntityHeading(ped, SelectorConfig.DestinationHeading or 0.0)
        end

        Wait(800)
        DoScreenFadeIn(1200)
    end)
end)

StartSelectorLoop = function()
    if SelectorLoopRunning then return end

    SelectorLoopRunning = true
    CreateThread(function()
        local markerConfig = SelectorConfig.Marker or {}
        local trailConfig = SelectorConfig.Trail or {}
        local markerAsset, markerEffect = ResolveFx(markerConfig)
        local trailAsset, trailEffect = ResolveFx(trailConfig)
        local nextMarkerFx = 0
        local nextTrailFx = 0

        while not ClassChosen do
            local sleep = 1000

            if NuiOpen then
                sleep = 500
            elseif SelectorConfig.MarkerCoords then
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                local dist = #(coords - SelectorConfig.MarkerCoords)
                local maxView = SelectorConfig.ViewDistance or 15.0
                local now = GetGameTimer()

                if dist <= maxView then
                    sleep = 0

                    if now >= nextMarkerFx then
                        nextMarkerFx = now + (markerConfig.FxInterval or 260)
                        SpawnMagicFx(markerAsset, markerEffect, SelectorConfig.MarkerCoords, markerConfig)
                    end

                    local light = markerConfig.LightColor or { 255, 30, 18 }
                    local pulse = (markerConfig.LightIntensity or 1.2)
                        + ((math.sin(now / 350.0) + 1.0) * 0.12)
                    DrawLightWithRange(
                        SelectorConfig.MarkerCoords.x,
                        SelectorConfig.MarkerCoords.y,
                        SelectorConfig.MarkerCoords.z + (markerConfig.FxHeight or 0.12),
                        light[1] or 255, light[2] or 30, light[3] or 18,
                        markerConfig.LightRange or 5.5,
                        pulse
                    )

                    if dist <= (SelectorConfig.MarkerRadius or 2.0) then
                        local prompt = markerConfig.Prompt or "~r~E~s~  SELAR O DESTINO"
                        if IntroAudioLocked or NuiAudioLocked then
                            prompt = markerConfig.LockedPrompt or "~p~ESCUTE O CHAMADO..."
                        end

                        DrawTxt3D(
                            SelectorConfig.MarkerCoords.x,
                            SelectorConfig.MarkerCoords.y,
                            SelectorConfig.MarkerCoords.z + (markerConfig.PromptHeight or 1.55),
                            prompt
                        )

                        if not IntroAudioLocked and not NuiAudioLocked and IsControlJustPressed(0, 38) then
                            OpenSelectorNui()
                        end
                    end
                else
                    sleep = 750
                end

                if trailConfig.Enabled ~= false
                    and type(trailConfig.Points) == "table"
                    and now >= nextTrailFx then
                    nextTrailFx = now + (trailConfig.FxInterval or 720)
                    local renderDistance = trailConfig.RenderDistance or 48.0

                    for _, point in ipairs(trailConfig.Points) do
                        if #(coords - point) <= renderDistance then
                            SpawnMagicFx(trailAsset, trailEffect, point, trailConfig)
                        end
                    end
                end
            end

            Wait(sleep)
        end
        SelectorLoopRunning = false
    end)
end

RegisterNUICallback("close", function(_, cb)
    StopSelectorAudio()

    if CreationFlag and not ClassChosen then
        TriggerServerEvent("classeSelector:chooseClass", "humano", true)
        cb("ok")
        return
    end

    NuiOpen = false
    SetNuiFocus(false, false)
    FreezeEntityPosition(PlayerPedId(), false)
    cb("ok")
end)

RegisterNUICallback("chooseClass", function(data, cb)
    if NuiAudioLocked then
        cb("audio_locked")
        return
    end

    local classId = data.classId or data.id or data.class or data.value

    if not classId then
        for key, value in pairs(data or {}) do
            print("[classeSelector] chooseClass data", key, value)
        end

        Notify("Classe", "Nenhuma classe selecionada para vincular.", "amarelo", 5000)
        cb("ok")
        return
    end

    TriggerServerEvent("classeSelector:chooseClass", classId, CreationFlag)
    cb("ok")
end)

RegisterNUICallback("audioReady", function(_, cb)
    AudioReady = true
    SendPendingIntroAudio()
    cb("ok")
end)

RegisterNUICallback("audioStarted", function(data, cb)
    local key = data and data.key
    if key then
        CurrentAudioKey = key
        NuiAudioLocked = true
        if key == CurrentIntroKey then
            IntroAudioLocked = true
        end
    end
    cb("ok")
end)

RegisterNUICallback("audioFinished", function(data, cb)
    local key = data and data.key

    if key and key == CurrentIntroKey then
        CurrentIntroKey = nil
        IntroAudioLocked = false
    end

    if not key or key == CurrentAudioKey then
        CurrentAudioKey = nil
        NuiAudioLocked = false
    end

    cb("ok")
end)

function DrawTxt3D(x, y, z, text)
    local onScreen, screenX, screenY = World3dToScreen2d(x, y, z)

    if onScreen then
        SetTextScale(0.0, 0.31)
        SetTextFont(0)
        SetTextProportional(1)
        SetTextColour(242, 235, 232, 245)
        SetTextCentre(1)
        SetTextDropshadow(1, 0, 0, 0, 210)
        SetTextOutline()
        SetTextEntry("STRING")
        AddTextComponentString(text)
        DrawText(screenX, screenY)
    end
end

RegisterCommand("classe", function()
    TriggerServerEvent("classeSelector:enterFlow")
end)

if SelectorConfig.EnableTestCommand then
    RegisterCommand("classeteste", function()
        TriggerEvent("classeSelector:startSelector", false)
    end)
end

AddEventHandler("onClientResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    SetNuiFocus(false, false)
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityInvincible(PlayerPedId(), false)
    DisplayRadar(true)
    StopSelectorAudio()
end)
