local beltKeybind = nil

local function ToggleSeatbelt()
    if Player.vehicle.vehicle <= 0 then return end
    if Player.vehicle.ignoreBelt then return end
    local ped = PlayerPedId()
    Player.vehicle.belt = not Player.vehicle.belt

    TriggerEvent("InteractSound_CL:PlayOnOne", Player.vehicle.belt and "carbuckle" or "carunbuckle", 0.25)
    Config.Notification(Lang('belt'), Lang(('belt_%s'):format(Player.vehicle.belt and 'plug' or 'unplug')), (Player.vehicle.belt and "success" or "error"), 5000)
    SetPedConfigFlag(ped, 32, not Player.vehicle.belt)
    LocalPlayer.state:set("belt", Player.vehicle.belt, true)

    if Player.vehicle.belt then
        lib.disableControls:Add(75)
    else
        lib.disableControls:Remove(75)
        SetFlyThroughWindscreenParams(22.0, 40.0, 17.0, 7.0)
    end
end

if not Config.Commands.belt.disabled then
    if Config.Commands.belt.keymapping.usable then
        beltKeybind = lib.addKeybind({
            name = 'Belt',
            description = Config.Commands.belt.keymapping.description,
            defaultKey = Config.Commands.belt.keymapping.key,
            onPressed = function(self)
                ToggleSeatbelt()
            end,
        })
    else
        RegisterCommand(Config.Commands.belt.keymapping.command, function()
            if not Config.Commands.belt.disabled then
                ToggleSeatbelt()
            end
        end, false)
    end
end

function resetBelt()
    Player.vehicle.belt = false
    lib.disableControls:Remove(75)
    SetPedConfigFlag(PlayerPedId(), 32, true)
    LocalPlayer.state:set("belt", false, true)
    SetFlyThroughWindscreenParams(22.0, 40.0, 17.0, 7.0)
end

CreateThread(function()
    if Config.Commands.belt.disabled then
        return SetPedConfigFlag(cache.ped, 32, false)
    end

    LocalPlayer.state:set("belt", Player.vehicle.belt, false)
    SetFlyThroughWindscreenParams(22.0, 40.0, 17.0, 7.0)
end)

exports("seatbelt", function()
    return Player.vehicle.belt
end)