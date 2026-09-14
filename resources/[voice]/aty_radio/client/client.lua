pId = PlayerId()
UiOpen = false
Channel = nil
RadioProp = nil
Requests = {}
Members = {}
Answers = 0
ExamPed = nil
ExampBlip = nil

local function OpenRadioMenu()
    if UiOpen then return true end

    if not MumbleIsActive() then
        TriggerEvent("chat:addMessage", {
            color = {255, 0, 0},
            multiline = true,
            args = {"Radio", "Mumble is not active"}
        })

        return false
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openMenu",
    })
    UiOpen = true

    CreateRadioProp()

    RequestAnimDict("cellphone@")
    while not HasAnimDictLoaded("cellphone@") do
        Wait(100)
    end

    TaskPlayAnim(PlayerPedId(), "cellphone@", "cellphone_text_in", 8.0, 8.0, -1, 50, 0, false, false, false)
    return true
end

if Config.CommandSettings.Enable then
    RegisterCommand(Config.CommandSettings.Command, function()
        if Config.ItemSettings.RequireItem then
            if not TriggerCallback("hasItem", Config.ItemSettings.Item) then
                return Config.Notify("You do not have a radio", "Radio", "error")
            end
        end

        OpenRadioMenu()
    end)
end

exports('useRadio', function(data)
    exports.ox_inventory:useItem(data, function(usedItem)
        if usedItem then
            OpenRadioMenu()
        end
    end)
end)

RegisterNUICallback("closeMenu", function(_, cb)
    SetNuiFocus(0, 0)
    UiOpen = false
    cb({})
    
    RequestAnimDict("cellphone@")
    while not HasAnimDictLoaded("cellphone@") do
        Wait(100)
    end

    TaskPlayAnim(PlayerPedId(), "cellphone@", "cellphone_text_out", 8.0, 8.0, 1000, 50, 0, false, false, false)

    if RadioProp and Channel and Config.AttachPropOnUse then
        AttachEntityToEntity(RadioProp, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), 0xFCD9), 0.1, 0.06, -0.05, -36.0, 180.0, 180.0, true, true, false, true, 1, true)
    elseif RadioProp then
        DeleteEntity(RadioProp)
        RadioProp = nil
    end
end)

RegisterNUICallback("closeNoAnim", function(_, cb)
    SetNuiFocus(0, 0)
    UiOpen = false
    cb({})
end)

RegisterNUICallback("joinChannel", function(data, cb)
    local data = data.radio
    local forced = data.forced

    if not data then
        cb({status = "error", message = "No channel provided"})
        Config.Notify("No channel provided", "Radio", "error")
        return
    end

    if Channel == data then
        cb({status = "error", message = "You are already in this channel"})
        Config.Notify("You are already in this channel", "Radio", "error")
        return
    end

    if IsPlayerInAnyChannel() then
        TriggerCallback("radio:leaveChannel", Channel)
        LeaveChannel(Channel)
    end
    
    local resp = TriggerCallback("radio:joinChannel", {channel = data, forced = forced})
    Config.Notify(resp.message, "Error", resp.status)

    if resp.status == "success" then
        JoinChannel(tonumber(data))
        Channel = data
    end

    Requests = TriggerCallback("radio:getRequests", Channel)
    resp.requests = Requests

    cb(resp)
end)

RegisterNUICallback("leaveChannel", function(_, cb)
    if not Channel then
        cb({status = "error", message = "You are not in a channel"})
        Config.Notify("You are not in a channel", "Radio", "error")
        return
    end

    local resp = TriggerCallback("radio:leaveChannel", Channel)
    Config.Notify(resp.message, "Error", resp.status)

    if resp.status == "success" then
        Members = {}
        LeaveChannel(Channel)
        Channel = nil
    end

    cb(resp)
end)

RegisterNUICallback("acceptRequest", function(identifier, cb)
    if not identifier then
        cb({status = "error", message = "No identifier provided"})
        Config.Notify("No identifier provided", "Radio", "error")
        return
    end

    if not Channel then
        cb({status = "error", message = "You are not in a channel"})
        Config.Notify("You are not in a channel", "Radio", "error")
        return
    end

    local resp = TriggerCallback("radio:acceptRequest", {
        channel = Channel,
        identifier = identifier
    })

    Config.Notify(resp.message, "Error", resp.status)

    cb(resp)
end)

RegisterNUICallback("declineRequest", function(identifier, cb)
    if not identifier then
        cb({status = "error", message = "No identifier provided"})
        Config.Notify("No identifier provided", "Radio", "error")
        return
    end

    if not Channel then
        cb({status = "error", message = "You are not in a channel"})
        Config.Notify("You are not in a channel", "Radio", "error")
        return
    end

    local resp = TriggerCallback("radio:declineRequest", {
        channel = Channel,
        identifier = identifier
    })

    Config.Notify(resp.message, "Error", resp.status)

    cb(resp)
end)

RegisterNUICallback("cracked", function(codes, cb)
    Hacking = false

    local channels = TriggerCallback("radio:getRandomChannels")

    if next(channels) == nil then
        Config.Notify("No channels found", "Radio", "error")
    end

    SetNuiFocus(1, 1)

    cb({
        status = "success",
        channels = channels
    })
end)

RegisterNUICallback("answerQuestion", function(isTrue, cb) 
    if isTrue then
        Answers = Answers + 1
    end

    cb('ok')
end)

RegisterNUICallback("finishExam", function(_, cb) 
    if Answers == Config.ExamSettings.QuestionsToPass then
        TriggerCallback("radio:finishExam")
    else
        Config.Notify("You have not answered all the questions correctly", "Radio", "error")
    end

    UiOpen = false
    SetNuiFocus(0, 0)

    cb('ok')
end)

RegisterNetEvent("radio:refreshMembers", function(members)
    SendNUIMessage({
        action = "refreshMembers",
        members = members
    })

    Members = members
end)

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        if RadioProp then
            DeleteEntity(RadioProp)
        end

        if ExamPed then
            DeleteEntity(ExamPed)
        end

        if ExampBlip then
            RemoveBlip(ExampBlip)
        end
    end
end)

function CreateRadioProp()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local forward = GetEntityForwardVector(playerPed)
    local pos = coords + forward * 0.5

    if RadioProp then
        AttachEntityToEntity(RadioProp, playerPed, GetPedBoneIndex(playerPed, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        return    
    end

    RequestModel(Config.RadioProp)
    while not HasModelLoaded(Config.RadioProp) do
        Wait(100)
    end

    RadioProp = CreateObject(GetHashKey(Config.RadioProp), pos.x, pos.y, pos.z, true, true, true)
    SetEntityAsMissionEntity(RadioProp, true, true)
    SetModelAsNoLongerNeeded(Config.RadioProp)

    AttachEntityToEntity(RadioProp, playerPed, GetPedBoneIndex(playerPed, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
end





RegisterNetEvent("aty_radio:client:switchChannel", function(newChannel)
    if not newChannel or type(newChannel) ~= "number" then return end

    -- usa joinChannel direto
    if IsPlayerInAnyChannel() then
        TriggerCallback("radio:leaveChannel", Channel)
        LeaveChannel(Channel)
    end

    local resp = TriggerCallback("radio:joinChannel", { channel = newChannel })

    if resp.status == "success" then
        Channel = tostring(newChannel)
        JoinChannel(newChannel)
        Config.Notify("Frequência alterada para: " .. newChannel, "Rádio", "success")
    else
        Config.Notify(resp.message, "Rádio", "error")
    end
end)


RegisterCommand("radio_increase", function()
    if Channel then
        local nextChannel = tonumber(Channel) + 1
        TriggerEvent("aty_radio:client:switchChannel", nextChannel)
    end
end)

RegisterCommand("radio_decrease", function()
    if Channel then
        local nextChannel = tonumber(Channel) - 1
        if nextChannel > 0 then
            TriggerEvent("aty_radio:client:switchChannel", nextChannel)
        end
    end
end)


RegisterKeyMapping("radio_increase", "[Rádio] Aumentar Frequência", "keyboard", "PAGEUP")
RegisterKeyMapping("radio_decrease", "[Rádio] Diminuir Frequência", "keyboard", "PAGEDOWN")






function GetClosestHackPoint()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local closest = nil
    local dist = nil

    for _, point in ipairs(Config.HackingSettings.HackingCoordinates) do
        local pointDist = #(coords - vector3(point.coords.x, point.coords.y, point.coords.z))   

        if not dist or pointDist < dist then
            dist = pointDist
            closest = point
        end
    end

    return closest, dist
end

function StartHackingAnimation(loc, data)
    local ped = PlayerPedId()
    TaskLookAtCoord(ped, loc.x, loc.y, loc.z, 1000, 0, 0)
    TaskGoStraightToCoord(ped, loc.x, loc.y, loc.z, 1.0, 1500, loc.w, 0)

    while (GetEntityHeading(ped) - loc.w > 5.0 or GetEntityHeading(ped) - loc.w < 355.0) and #(GetEntityCoords(ped) - vector3(loc.x, loc.y, loc.z)) > 0.1 do
        Wait(0)
    end

    TaskClearLookAt(ped)

    local animDict = "anim@heists@ornate_bank@hack"

    RequestAnimDict(animDict)
    RequestModel("hei_prop_hst_laptop")
    RequestModel("hei_p_m_bag_var22_arm_s")
    RequestModel("hei_prop_heist_card_hack_02")
    while not HasAnimDictLoaded(animDict)
        or not HasModelLoaded("hei_prop_hst_laptop")
        or not HasModelLoaded("hei_p_m_bag_var22_arm_s")
        or not HasModelLoaded("hei_prop_heist_card_hack_02") do
        Citizen.Wait(100)
    end

    SetEntityHeading(ped, loc.w)
    local loc = GetOffsetFromEntityInWorldCoords(ped, 0.18, 1.5, 0.0)
    
    local targetPosition, targetRotation = (vec3(GetEntityCoords(ped))), vec3(GetEntityRotation(ped))
    
    local animPos = GetAnimInitialOffsetPosition(animDict, "hack_enter", loc.x, loc.y, loc.z + 0.85, targetRotation.x, targetRotation.y, targetRotation.z, 0, 1)
    local animPos2 = GetAnimInitialOffsetPosition(animDict, "hack_loop", loc.x, loc.y, loc.z + 0.85, targetRotation.x, targetRotation.y, targetRotation.z, 0, 1)
    local animPos3 = GetAnimInitialOffsetPosition(animDict, "hack_exit", loc.x, loc.y, loc.z + 0.85, targetRotation.x, targetRotation.y, targetRotation.z, 0, 1)

    FreezeEntityPosition(ped, true)
    local netScene = NetworkCreateSynchronisedScene(animPos, targetRotation, 2, false, false, 1065353216, 0, 1.3)
    local bag = CreateObject(GetHashKey("hei_p_m_bag_var22_arm_s"), targetPosition, 1, 1, 0)
    local laptop = CreateObject(GetHashKey("hei_prop_hst_laptop"), targetPosition, 1, 1, 0)
    local card = CreateObject(GetHashKey("hei_prop_heist_card_hack_02"), targetPosition, 1, 1, 0)

    NetworkAddPedToSynchronisedScene(ped, netScene, animDict, "hack_enter", 1.5, -4.0, 1, 16, 1148846080, 0)
    NetworkAddEntityToSynchronisedScene(bag, netScene, animDict, "hack_enter_bag", 4.0, -8.0, 1)
    NetworkAddEntityToSynchronisedScene(laptop, netScene, animDict, "hack_enter_laptop", 4.0, -8.0, 1)
    NetworkAddEntityToSynchronisedScene(card, netScene, animDict, "hack_enter_card", 4.0, -8.0, 1)

    local netScene2 = NetworkCreateSynchronisedScene(animPos2, targetRotation, 2, false, true, 1065353216, 0, 1.3)
    NetworkAddPedToSynchronisedScene(ped, netScene2, animDict, "hack_loop", 1.5, -4.0, 1, 16, 1148846080, 0)
    NetworkAddEntityToSynchronisedScene(bag, netScene2, animDict, "hack_loop_bag", 4.0, -8.0, 1)
    NetworkAddEntityToSynchronisedScene(laptop, netScene2, animDict, "hack_loop_laptop", 4.0, -8.0, 1)
    NetworkAddEntityToSynchronisedScene(card, netScene2, animDict, "hack_loop_card", 4.0, -8.0, 1)

    local netScene3 = NetworkCreateSynchronisedScene(animPos3, targetRotation, 2, false, false, 1065353216, 0, 1.3)
    NetworkAddPedToSynchronisedScene(ped, netScene3, animDict, "hack_exit", 1.5, -4.0, 1, 16, 1148846080, 0)
    NetworkAddEntityToSynchronisedScene(bag, netScene3, animDict, "hack_exit_bag", 4.0, -8.0, 1)
    NetworkAddEntityToSynchronisedScene(laptop, netScene3, animDict, "hack_exit_laptop", 4.0, -8.0, 1)
    NetworkAddEntityToSynchronisedScene(card, netScene3, animDict, "hack_exit_card", 4.0, -8.0, 1)

    Citizen.Wait(200)
    NetworkStartSynchronisedScene(netScene)
    Citizen.Wait(6300)
    NetworkStartSynchronisedScene(netScene2)
    Citizen.Wait(2000)

    Hacking = true

    SendNUIMessage({
        action = "startCracking",
        hackTime = data.hackTime
    })

    while Hacking do Wait(100) end

    Citizen.Wait(1500)
    NetworkStartSynchronisedScene(netScene3)
    Citizen.Wait(4600)
    NetworkStopSynchronisedScene(netScene3)
    DeleteObject(bag)
    DeleteObject(laptop)
    DeleteObject(card)
    FreezeEntityPosition(ped, false)
end

CreateThread(function()
    while not NetworkIsPlayerActive(pId) do
        Wait(100)
    end

    if Config.ExamSettings.Npc.Enable then
        LoadObject(GetHashKey(Config.ExamSettings.Npc.Ped))
        ExamPed = CreatePed(4, GetHashKey(Config.ExamSettings.Npc.Ped), Config.ExamSettings.Npc.Coords.x, Config.ExamSettings.Npc.Coords.y, Config.ExamSettings.Npc.Coords.z - 1.0, Config.ExamSettings.Npc.Coords.w, false, false)
        SetEntityAsMissionEntity(ExamPed, true, true)
        SetBlockingOfNonTemporaryEvents(ExamPed, true)
        SetEntityInvincible(ExamPed, true)
        FreezeEntityPosition(ExamPed, true)
    end

    if Config.ExamSettings.Blip.Enable then
        local blip = AddBlipForCoord(Config.ExamSettings.Blip.Coords.x, Config.ExamSettings.Blip.Coords.y, Config.ExamSettings.Blip.Coords.z)
        SetBlipSprite(blip, Config.ExamSettings.Blip.Sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, Config.ExamSettings.Blip.Color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.ExamSettings.Blip.Label)
        EndTextCommandSetBlipName(blip)

        ExampBlip = blip
    end

    local ped = ExamPed
    local sleep = 250

    local myPrompt = vPrompt:Create({
        key = "E",
        label = "Start Radio Licence Exam",
        coords = vector3(Config.ExamSettings.Npc.Coords.x, Config.ExamSettings.Npc.Coords.y, Config.ExamSettings.Npc.Coords.z),
        drawDistance = 4.0,        
        interactDistance = 2.0,      
        font = 0,                   
        scale = 0.25,                -- the font scale
        margin = 0,             -- The left / right margin for the label text  (percentage of screen)
        padding = 0.003,            -- the padding for the background box (percentage of screen)
        buttonSize = 0.012,         -- The size of the button (percentage of screen)
        textOffset = 0.0025,          -- y-offset for the text for custom fonts (GTAV native fonts are handled by the instance)
        offset = vector3(0, 0, 1),   -- The offset to apply to the prompt position
        backgroundColor = { r = 0, g = 0, b = 0, a = 100 },     -- background box color
        labelColor = { r = 255, g = 255, b = 255, a = 255 },    -- the label color
        buttonColor = { r = 255, g = 255, b = 255, a = 255 },   -- the button's background color
        keyColor = { r = 0, g = 0, b = 0, a = 255 },            -- the button's text color
    })

    myPrompt:On("interact", function()
        if TriggerCallback("hasMoney", Config.ExamSettings.ExamPrice) then
            UiOpen = true
            SetNuiFocus(true, true)
            SendNUIMessage({
                action = "startExam",
                questions = Config.ExamSettings.ExamQuestions
            })
        else
            Config.Notify("You do not have enough money", "Exam", "error")
        end
    end)
end)

CreateThread(function()
    while true do
        Wait(1000)

        if next(Members) then
            for src, name in pairs(Members) do
                local playerPed = NetToPed(Members[src].networkId)
                local playerId = NetworkGetEntityOwner(playerPed)
                local isTalking = NetworkIsPlayerTalking(playerId) or MumbleIsPlayerTalking(playerId)

                Members[src].isTalking = isTalking
            end

            SendNUIMessage({
                action = "refreshMembers",
                members = Members
            })
        end
    end
end)

CreateThread(function()
    local sleep = 250

    local myPrompt = vPrompt:Create({
        key = "E",
        label = "Hack The Radio Tower",
        coords = vector3(0.0, 0.0, 0.0),
        drawDistance = 7.0,        
        interactDistance = 2.0,      
        font = 0,                   
        scale = 0.25,                -- the font scale
        margin = 0,             -- The left / right margin for the label text  (percentage of screen)
        padding = 0.003,            -- the padding for the background box (percentage of screen)
        buttonSize = 0.012,         -- The size of the button (percentage of screen)
        textOffset = 0.0025,          -- y-offset for the text for custom fonts (GTAV native fonts are handled by the instance)
        offset = vector3(0, 0, 1),   -- The offset to apply to the prompt position
        backgroundColor = { r = 0, g = 0, b = 0, a = 100 },     -- background box color
        labelColor = { r = 255, g = 255, b = 255, a = 255 },    -- the label color
        buttonColor = { r = 255, g = 255, b = 255, a = 255 },   -- the button's background color
        keyColor = { r = 0, g = 0, b = 0, a = 255 },            -- the button's text color
    })

    myPrompt:On("interact", function()
        if TriggerCallback("hasItem", Config.HackingSettings.UsbItem) and TriggerCallback("hasItem", Config.HackingSettings.LabtopItem) then
            StartHackingAnimation(Config.HackingSettings.HackingCoordinates[1].coords, Config.HackingSettings.HackingCoordinates[1])
        else
            Config.Notify("You do not have the required items", "Hacking", "error")
        end
    end)

    while true do
        if not UiOpen then
            local closestPoint, dist = GetClosestHackPoint()
        
            if closestPoint and dist <= 7.5 then
                myPrompt:SetCoords(vector3(closestPoint.coords.x, closestPoint.coords.y, closestPoint.coords.z))
            end
        end

        Wait(sleep)
    end 
end)

RegisterNetEvent("aty_radio:client:openRadio", OpenRadioMenu)
RegisterNetEvent("mm_radio:client:use", OpenRadioMenu)

