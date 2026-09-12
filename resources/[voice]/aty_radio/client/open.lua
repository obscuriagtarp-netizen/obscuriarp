AddEventHandler('gameEventTriggered', function (name, args)
    if name == "CEventNetworkEntityDamage" then
        local victim = args[1]
        local ped = PlayerPedId()

        if victim == ped then
            if GetEntityHealth(ped) <= 0 then
                if Config.DisableOnDeath then
                    if IsPlayerInAnyChannel() then
                        SendNUIMessage({
                            action = "leaveChannel"
                        })
                    end
                end
            end
        end
    end
end)

function IsPlayerInAnyChannel()
    if GetResourceState("pma-voice") == "started" then
        local plyState = Player(pId).state
        local radioChannel = plyState.radioChannel
        return proximity ~= 0
    elseif GetResourceState("mumble-voip") == "started" then
        return exports["mumble-voip"]:GetPlayerRadioChannel() ~= 0
    elseif GetResourceState("salty-chat") == "started" then
        return exports.saltychat:GetRadioChannel(true) ~= 0
    end
end

function JoinChannel(channel)
    if GetResourceState("pma-voice") == "started" then
        exports["pma-voice"]:setRadioChannel(channel) 
        exports["pma-voice"]:setVoiceProperty("radioEnabled", true)
    elseif GetResourceState("mumble-voip") == "started" then
        exports["mumble-voip"]:SetRadioChannel(channel)
        exports["mumble-voip"]:SetMumbleProperty("radioEnabled", true)
    elseif GetResourceState("salty-chat") == "started" then
        exports.saltychat:SetRadioChannel(data, true)
    end
end

function LeaveChannel(channel)
    if GetResourceState("pma-voice") == "started" then
        exports["pma-voice"]:setRadioChannel(0) 
        exports["pma-voice"]:setVoiceProperty("radioEnabled", false)
    elseif GetResourceState("mumble-voip") == "started" then
        exports["mumble-voip"]:SetRadioChannel(0)
        exports["mumble-voip"]:SetMumbleProperty("radioEnabled", false)
    elseif GetResourceState("salty-chat") == "started" then
        exports.saltychat:SetRadioChannel('', true)
    end
end

function SetRadioVolume(vol)
    if GetResourceState("pma-voice") == "started" then
        exports["pma-voice"]:setRadioVolume(vol)
    elseif GetResourceState("mumble-voip") == "started" then
        -- mumble-voip doesn't have a volume setting
    elseif GetResourceState("salty-chat") == "started" then
        exports.saltychat:SetRadioVolume(vol)
    end
end

exports("IsPlayerInAnyChannel", IsPlayerInAnyChannel)
exports("JoinChannel", JoinChannel)
exports("LeaveChannel", LeaveChannel)
exports("SetRadioVolume", SetRadioVolume)