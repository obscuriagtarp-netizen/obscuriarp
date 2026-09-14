local isMenuOpen = false
local serverRequestId = 0
local serverRequests = {}
local lastToggleAt = 0
local nativeMapOpen = false
local nativeMapWasActive = false
local suppressToggleUntil = 0
local externalNuiSuppressUntil = 0
local cachedPlayerInfo

local function trim(value)
    value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    return value ~= "" and value or nil
end

local function getImmediatePlayerInfo()
    local ok, playerData = pcall(function()
        return exports.qbx_core:GetPlayerData()
    end)
    if not ok or type(playerData) ~= "table" then return cachedPlayerInfo end

    local charinfo = type(playerData.charinfo) == "table" and playerData.charinfo or {}
    local firstname = trim(charinfo.firstname or charinfo.firstName)
    local lastname = trim(charinfo.lastname or charinfo.lastName)
    local characterName = firstname and lastname and (firstname .. " " .. lastname) or firstname or lastname
    local money = type(playerData.money) == "table" and playerData.money or {}
    local job = type(playerData.job) == "table" and playerData.job or {}
    local jobGrade = type(job.grade) == "table" and job.grade or {}
    local gang = type(playerData.gang) == "table" and playerData.gang or {}

    if not characterName or not trim(playerData.citizenid) then return cachedPlayerInfo end

    local info = {}
    for key, value in pairs(cachedPlayerInfo or {}) do info[key] = value end
    info.name = characterName
    info.passport = trim(playerData.citizenid)
    if charinfo.gender == 0 or tostring(charinfo.gender):lower() == "male" then
        info.gender = "Masculino"
    elseif charinfo.gender == 1 or tostring(charinfo.gender):lower() == "female" then
        info.gender = "Feminino"
    else
        info.gender = charinfo.gender
    end
    info.phone = trim(charinfo.phone or charinfo.phoneNumber)
    info.wallet = tonumber(money.cash) or 0
    info.bank = tonumber(money.bank) or 0
    info.job = trim(job.label or job.name)
    info.jobLevel = trim(jobGrade.name) or tonumber(jobGrade.level) or tonumber(jobGrade.grade)
    info.org = trim(gang.name) ~= "none" and trim(gang.label or gang.name) or "Nenhuma"
    return info
end

local function TrackExternalNuiFocus(now)
    if not isMenuOpen and IsNuiFocused() then
        externalNuiSuppressUntil = now + 550
        return true
    end

    return now < externalNuiSuppressUntil
end

local function CloseInventoryIfOpen()
    if GetResourceState("ox_inventory") ~= "started" then return false end
    if not LocalPlayer.state.invOpen then return false end

    suppressToggleUntil = GetGameTimer() + 500
    exports.ox_inventory:closeInventory()
    return true
end

local function OpenEscMenu()
    if isMenuOpen then return end

    isMenuOpen = true
    SetPauseMenuActive(false)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "open",
        playerInfo = getImmediatePlayerInfo()
    })
end

function CloseEscMenu()
    if not isMenuOpen then return end
    isMenuOpen = false

    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
end

function IsMagicPauseOpen()
    return isMenuOpen
end

local function ToggleEscMenu()
    local now = GetGameTimer()
    if CloseInventoryIfOpen() then return end
    if now < suppressToggleUntil then return end
    if TrackExternalNuiFocus(now) then return end

    if nativeMapOpen or IsPauseMenuActive() then
        nativeMapOpen = false
        nativeMapWasActive = false
        suppressToggleUntil = now + 650
        if IsPauseMenuActive() then
            SetPauseMenuActive(false)
        end
        return
    end

    if now - lastToggleAt < 250 then return end
    lastToggleAt = now

    if isMenuOpen then
        CloseEscMenu()
    else
        OpenEscMenu()
    end
end

RegisterCommand("toggleesc", function()
    ToggleEscMenu()
end, false)

RegisterKeyMapping("toggleesc", "Abrir/Fechar Menu ESC", "keyboard", "ESCAPE")

RegisterNUICallback("closeMenu", function(_, cb)
    CloseEscMenu()
    cb("ok")
end)

RegisterNUICallback("openSection", function(_, cb)
    cb({ ok = true })
end)

RegisterNUICallback("close", function(_, cb)
    CloseEscMenu()
    cb({ ok = true })
end)

local function requestServer(eventName, payload, cb)
    serverRequestId = serverRequestId + 1
    local token = serverRequestId
    serverRequests[token] = cb
    TriggerServerEvent(eventName, token, payload or {})
    SetTimeout(15000, function()
        local pending = serverRequests[token]
        if not pending then return end
        serverRequests[token] = nil
        pending({ ok = false, message = "O servidor demorou para responder. Tente novamente." })
    end)
end

local function OpenNativeMap()
    if CloseInventoryIfOpen() then return end
    if TrackExternalNuiFocus(GetGameTimer()) then return end

    nativeMapOpen = true
    nativeMapWasActive = false
    suppressToggleUntil = GetGameTimer() + 800
    CloseEscMenu()
    Wait(100)
    ActivateFrontendMenu("FE_MENU_VERSION_MP_PAUSE", 0, -1)
end

local function currentCoords()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    return { x = coords.x, y = coords.y, z = coords.z, h = GetEntityHeading(ped) }
end

RegisterNetEvent("MagicPause:client:serverResponse", function(token, payload)
    local cb = serverRequests[token]
    if not cb then return end
    serverRequests[token] = nil
    cb(payload or {})
end)

RegisterNetEvent("MagicPause:client:refreshFactions", function()
    if not isMenuOpen then return end
    SendNUIMessage({ action = "refreshFactions" })
end)

RegisterNetEvent("MagicPause:client:useAppearanceVoucher", function()
    TriggerServerEvent("MagicPause:server:useAppearanceVoucher")
end)

RegisterNetEvent("MagicPause:client:openAppearanceVoucher", function()
    CloseEscMenu()
    Wait(250)

    local appearanceConfig = {
        ped = true,
        headBlend = true,
        faceFeatures = true,
        headOverlays = true,
        components = true,
        componentConfig = {
            masks = true,
            upperBody = true,
            lowerBody = true,
            bags = true,
            shoes = true,
            scarfAndChains = true,
            bodyArmor = true,
            shirts = true,
            decals = true,
            jackets = true
        },
        props = true,
        propConfig = {
            hats = true,
            glasses = true,
            ear = true,
            watches = true,
            bracelets = true
        },
        tattoos = true,
        enableExit = true,
        hasTracker = false,
        automaticFade = true,
        uiEyebrow = "Obscuria",
        uiTitle = "Refazer Personagem",
        uiDescription = "Ajuste toda a aparencia antes de confirmar."
    }

    exports["illenium-appearance"]:startPlayerCustomization(function(appearance)
        if not appearance then return end
        TriggerServerEvent("illenium-appearance:server:saveAppearance", appearance)
    end, appearanceConfig)
end)

RegisterNUICallback("getPlayerInfo", function(_, cb)
    requestServer("MagicPause:server:getPlayerInfo", {}, function(payload)
        if type(payload) == "table" and payload.name and payload.passport then
            cachedPlayerInfo = payload
            if isMenuOpen then
                SendNUIMessage({ action = "updatePlayerInfo", playerInfo = payload })
            end
        end
        cb(payload)
    end)
end)

local function refreshPlayerInfoCache()
    requestServer("MagicPause:server:getPlayerInfo", {}, function(payload)
        if type(payload) ~= "table" or not payload.name or not payload.passport then return end
        cachedPlayerInfo = payload
        if isMenuOpen then
            SendNUIMessage({ action = "updatePlayerInfo", playerInfo = payload })
        end
    end)
end

RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
    cachedPlayerInfo = nil
    SetTimeout(750, refreshPlayerInfoCache)
end)

RegisterNetEvent("QBCore:Client:OnPlayerUnload", function()
    cachedPlayerInfo = nil
    SendNUIMessage({ action = "clearPlayerInfo" })
end)

CreateThread(function()
    Wait(1500)
    refreshPlayerInfoCache()
end)

RegisterNUICallback("getRankings", function(_, cb)
    requestServer("MagicPause:server:getRankings", {}, cb)
end)

RegisterNUICallback("getFactions", function(_, cb)
    requestServer("MagicPause:server:getFactions", {}, cb)
end)

RegisterNUICallback("getVipStore", function(_, cb)
    requestServer("MagicPause:server:getVipStore", {}, cb)
end)

RegisterNUICallback("getVipDashboard", function(_, cb)
    requestServer("MagicPause:server:getVipDashboard", {}, cb)
end)

RegisterNUICallback("saveVipCoupon", function(data, cb)
    requestServer("MagicPause:server:saveVipCoupon", data or {}, cb)
end)

RegisterNUICallback("setVipCouponEnabled", function(data, cb)
    requestServer("MagicPause:server:setVipCouponEnabled", data or {}, cb)
end)

RegisterNUICallback("buyVipProductRunes", function(data, cb)
    requestServer("MagicPause:server:buyVipProductRunes", data or {}, cb)
end)

RegisterNUICallback("redeemVipVehicle", function(data, cb)
    requestServer("MagicPause:server:redeemVipVehicle", data or {}, cb)
end)

RegisterNUICallback("createVipPixOrder", function(data, cb)
    requestServer("MagicPause:server:createVipPixOrder", data or {}, cb)
end)

RegisterNUICallback("validateRuneCoupon", function(data, cb)
    requestServer("MagicPause:server:validateRuneCoupon", data or {}, cb)
end)

RegisterNUICallback("createRuneDepositOrder", function(data, cb)
    requestServer("MagicPause:server:createRuneDepositOrder", data or {}, cb)
end)

RegisterNUICallback("checkVipPixOrder", function(data, cb)
    requestServer("MagicPause:server:checkVipPixOrder", data or {}, cb)
end)

RegisterNUICallback("getTickets", function(data, cb)
    requestServer("MagicPause:server:getTickets", data or {}, cb)
end)

RegisterNUICallback("createTicket", function(data, cb)
    requestServer("MagicPause:server:createTicket", data or {}, cb)
end)

RegisterNUICallback("replyTicket", function(data, cb)
    requestServer("MagicPause:server:replyTicket", data or {}, cb)
end)

RegisterNUICallback("setTicketStatus", function(data, cb)
    requestServer("MagicPause:server:setTicketStatus", data or {}, cb)
end)

RegisterNUICallback("claimTicket", function(data, cb)
    requestServer("MagicPause:server:claimTicket", data or {}, cb)
end)

RegisterNUICallback("transcriptTicket", function(data, cb)
    requestServer("MagicPause:server:transcriptTicket", data or {}, cb)
end)

RegisterNUICallback("getBattlePass", function(_, cb)
    requestServer("MagicPause:server:getBattlePass", {}, cb)
end)

RegisterNUICallback("getEstablishments", function(_, cb)
    requestServer("MagicPause:server:getEstablishments", {}, cb)
end)

RegisterNUICallback("setRestaurantAvailability", function(data, cb)
    requestServer("MagicPause:server:setRestaurantAvailability", data or {}, cb)
end)

RegisterNUICallback("setEstablishmentWaypoint", function(data, cb)
    local coords = type(data) == "table" and type(data.coords) == "table" and data.coords or nil
    local x, y = coords and tonumber(coords.x), coords and tonumber(coords.y)
    if not x or not y then
        cb({ ok = false, error = "location_unavailable" })
        return
    end

    SetNewWaypoint(x + 0.0, y + 0.0)
    cb({ ok = true })
end)

RegisterNUICallback("callEstablishment", function(data, cb)
    requestServer("MagicPause:server:callEstablishment", data or {}, cb)
end)

RegisterNUICallback("getRestaurantManagement", function(data, cb)
    requestServer("MagicPause:server:getRestaurantManagement", data or {}, cb)
end)

RegisterNUICallback("restaurantManagementAction", function(data, cb)
    data = type(data) == "table" and data or {}
    data.data = type(data.data) == "table" and data.data or {}

    if data.action == "savePoint" and type(data.data.point) == "table" then
        data.data.point.coords = currentCoords()
    end

    requestServer("MagicPause:server:restaurantManagementAction", data, cb)
end)

RegisterNUICallback("saveBattlePassSeason", function(data, cb)
    requestServer("MagicPause:server:saveBattlePassSeason", data or {}, cb)
end)

RegisterNUICallback("setBattlePassSlotCount", function(data, cb)
    requestServer("MagicPause:server:setBattlePassSlotCount", data or {}, cb)
end)

RegisterNUICallback("saveBattlePassSlot", function(data, cb)
    requestServer("MagicPause:server:saveBattlePassSlot", data or {}, cb)
end)

RegisterNUICallback("buyBattlePassPremium", function(data, cb)
    requestServer("MagicPause:server:buyBattlePassPremium", data or {}, cb)
end)

RegisterNUICallback("claimBattlePassReward", function(data, cb)
    requestServer("MagicPause:server:claimBattlePassReward", data or {}, cb)
end)

RegisterNUICallback("setFactionLeader", function(data, cb)
    requestServer("MagicPause:server:setFactionLeader", data or {}, cb)
end)

RegisterNUICallback("placeIncluded", function(data, cb)
    data = data or {}
    data.coords = currentCoords()
    requestServer("MagicPause:server:placeIncludedFeature", data, cb)
end)

RegisterNUICallback("buyUpgrade", function(data, cb)
    data = data or {}
    data.coords = currentCoords()
    requestServer("MagicPause:server:buyFactionUpgrade", data, cb)
end)

RegisterNUICallback("renewUpgrade", function(data, cb)
    requestServer("MagicPause:server:renewFactionUpgrade", data or {}, cb)
end)

RegisterNUICallback("setFeatureLocation", function(data, cb)
    data = data or {}
    data.coords = currentCoords()
    requestServer("MagicPause:server:setFeatureLocation", data, cb)
end)

RegisterNUICallback("renameFeature", function(data, cb)
    requestServer("MagicPause:server:renameFactionFeature", data or {}, cb)
end)

RegisterNUICallback("repositionFeature", function(data, cb)
    data = data or {}
    data.coords = currentCoords()
    requestServer("MagicPause:server:repositionFactionFeature", data, cb)
end)

RegisterNUICallback("setGarageSpawn", function(data, cb)
    data = data or {}
    data.coords = currentCoords()
    requestServer("MagicPause:server:setGarageSpawn", data, cb)
end)

RegisterNUICallback("resetAllPositions", function(data, cb)
    requestServer("MagicPause:server:resetAllFactionPositions", data or {}, cb)
end)

RegisterNUICallback("addMember", function(data, cb)
    requestServer("MagicPause:server:addFactionMember", data or {}, cb)
end)

RegisterNUICallback("removeMember", function(data, cb)
    requestServer("MagicPause:server:removeFactionMember", data or {}, cb)
end)

RegisterNUICallback("openMap", function(_, cb)
    OpenNativeMap()
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if Config.OpenWithESC == false then
            Wait(500)
        else
            Wait(0)

            TrackExternalNuiFocus(GetGameTimer())

            if nativeMapOpen then
                if IsPauseMenuActive() then
                    nativeMapWasActive = true
                elseif nativeMapWasActive then
                    nativeMapOpen = false
                    nativeMapWasActive = false
                    suppressToggleUntil = GetGameTimer() + 650
                end
                goto continue
            end

            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)
            DisableControlAction(0, 199, true)

            if IsPauseMenuActive() then
                SetPauseMenuActive(false)
            end

            if IsDisabledControlJustPressed(0, 200) then
                ToggleEscMenu()
            elseif IsDisabledControlJustPressed(0, 199) then
                OpenNativeMap()
            end

            ::continue::
        end
    end
end)
