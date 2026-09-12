Config = {}
Config.Framework = {
    ["Framework"] = "auto", -- auto, esx, qbcore or qbox
    ["ResourceName"] = "auto", -- auto, es_extended or qb-core or your resource name. If you using qbx you should write qb-core
    ["SharedEvent"] = "" -- Event name for old cores.
}

Config.Language = "en" -- ar, cz, ro, it, fr, de, tr
Config.ShowDebug = false -- If you set this to `true`, the debug messages will be printed in the console. If you set it to `false`, no debug messages will be printed.
Config.ClockType = 24 --[[ 12 = 12 hour clock 9.30 PM || 24 = 24 hour clock 21.30 ]]
Config.ShowICTime = false -- If you set it to `true`, the in-game time will be displayed. If you set it to `false`, UTC (OOC) Time will be displayed.
Config.ShowMapOnFoot = false -- If `true` is set, the player can see the map when not in the vehicle. If `false`, the map will only be visible when in the vehicle.
Config.SendStatusAlert = false -- If this option is `true`, the player will be notified if the hunger or thirst value falls below 20. Tick `false` if you do not want to use this system
Config.StressSystem = true -- If you make `true`, stress will come next to the status bars. You will be able to see your stress values. You need to use a script for qb-stress esx for QBCore
Config.DisableRightCorner = false -- If you want to disable the top right corner, set it to `true`. This will hide all server and player information. If set to `false`, users can see and customize the top right corner.
Config.DisableMapAnimation = false -- If you set it to `true`, the minimap loading animation will be disabled. If you set it to `false`, the minimap loading animation will be enabled.
Config.DisableLocationInfo = false -- If you set it to `true`, the location and compass will not be displayed. If the nearby postal address is also not visible, the element there will be automatically hidden. If set to `false`, the Compass and Location will be displayed.
Config.MaxArmourValue = 100 -- If your maximum armor level is above 100, you should write it here. This way, the HUD bar will act accordingly. [[📛📛 ATTENTION: Does not modify or set player data. It is only an offset setting for visual appearance. 📛📛]]
Config.ShowCompassAlways = false -- If you set it to `true`, the compass will always be visible. If you set it to `false`, the compass will only be visible when in a vehicle or when the map is open.
Config.ShowMinimapToggleOption = false -- If you set it to `true`, the option to show or hide the minimap will be available in the settings menu. If you set it to `false`, the option to show or hide the minimap will not be available in the settings menu and the minimap will always be visible.

Config.BlackMoney = {
    ["display"] = false, -- if you set this to `true`, the black money will be displayed in the HUD. If you set it to `false`, the black money will not be displayed in the HUD.
    ["name"] = "YOUR_BLACKMONEY_ITEM_NAME", -- If `isItem` is `true`, write the item name of the black money here. If `isItem` is `false`, you can leave it default.
    ["isItem"] = false, -- If `blackmoney` is an item, set it to `true`. In ESX, this operation typically comes from the “Accounts” section, so set it to `false`. In frameworks like Qbox and QBCore, this is an item. Enter the item name in the field labeled “name” on the line above.
    ["account"] = "black_money", --[[
        ESX: The default is `black_money`, but if it's different, find the “black money” entry in the Accounts table in the `es_extended/shared/main.lua` file and add it here.
        Qbox, QBCore: This is usually an item. If it's not an item, you can leave it as `false` and the system will try to get the data from player data.
    ]]
}

Config.MusicSystem = {
    --[[
        📛 Currently this system is not synchronised with other players. 
        🟠 I tried to synchronise as efficiently as possible, but it did not work as I wanted. 

        🟢🟢🟢
        The new Speaker/Boombox/Carplay script, which works with Sync 3D Audio and 4 different realistic effects, works in conjunction with this HUD.
        You can purchase this script separately for Sync music processing.
        https://0resmon.tebex.io/package/fivem-speaker-boombox-carplay-script
    --]]

    ["disable"] = false, -- If you set `true`, people will not be able to use the music system from the car control menu. The system will switch off completely.
    ["distance"] = 10.0, -- If you are using the music system in the car control, it is the distance distance of the music played in the vehicle.  
}

Config.DutySystem = {
    --[[
        ❇️❇️
        If your server has a ‘Duty’ system for jobs, you can use this feature to display the ‘Duty’ status in HUD.
        You can add the jobs that have a duty system in the ‘jobs’ section below.
        When a player goes on or off duty, the HUD will automatically update and show the current duty status.
    --]]

    ["enabled"] = true, -- If you want the duty value to appear in the HUD, set it to `true`. If you don't want the duty value to appear in the HUD, set it to `false`.
    ["jobs"] = {
        --[[
            ❓🤔
            If you want the duty value to appear in certain jobs, you should add them here.
            Examples:
                ["bcso"] = true,
                ["police"] = true,
                ["sheriff"] = true,
                ["ambulance"] = true,
                ["parkranger"] = true,
                ["mechanic"] = true,
        ]]
        ["police"] = true,
        ["ambulance"] = true,
        ["mechanic"] = true,
        ["sheriff"] = true,
        ["bcso"] = true,
    },
}

Config.PostalMap = {
    --[[
        ⚠️ If you have a postal map, the following enabled must be true. Otherwise problems may occur.
    --]]

    ["enabled"] = false, -- If you are using PostalMap on your server, you should set this to `true`. Otherwise, the map may disappear, visibility problems or mask problems may occur.
    ["zoom_level"] = 1100, -- Postal (custom) map zoom level. Recommended value: 1100 
    ["showNearPostal"] = true, -- If you do `true`, the code of the postal you are close to will appear just opposite your location information. (It may increase resmon, albeit very little)
}

Config.Commands = {
    --[[ 
        ⁉️ VERY IMPORTANT: 
        ⚠️ When the keymapping system is activated, it will create a command in users with the current key. 
        ⚠️ When you change the Key or Command, this process will change for people entering the server for the first time. 
        ⚠️ Key and Command will not change for players already on the server. 
        ⚠️ Changing this setting does not change the key assignment in the game, it only changes the default. In the game, the key assignment is changed in settings / fivem / keybinds.
    --]]

    ["cinematic"] = { -- For those who want to activate cinematic mode by command
        ["disabled"] = false, -- If you set this variable to `true`, the cinematic mode code will be completely disabled.
        ["command"] = "cinematic",
    },
    ["belt"] = { -- You can use these button settings to fasten your seat belt in the vehicle.
        ["disabled"] = false, -- If you set this variable to `true`, the belt system will be completely disabled.
        ["notification"] = true, -- If you set it to `true`, you will receive a notification for the seatbelt connection. If it is `false`, you will not see a notification, only hear a sound.
        ["keymapping"] = {
            ["key"] = "B",
            ["usable"] = true,
            ["command"] = "belt",
            ["description"] = "Toggle seatbelt",
        },
    },
    ["settings"] = { -- You can make the necessary command or key links to open Hud's settings menu here.
        ["disabled"] = false, -- If you set this variable to `true`, the settings menu will be completely disabled.
        ["keymapping"] = {
            ["key"] = "G",
            ["usable"] = false,
            ["command"] = "hud",
            ["description"] = "Open HUD settings",
        },
    },
    ["editor"] = { -- If you change the key, enter the equivalent of the key you changed here in this way or it will not work!
        ["disabled"] = false, -- If you set this variable to `true`, editor mode will be completely disabled.
        ["closeKey"] = "PageUp", -- https://www.toptal.com/developers/keycode => Keys such as F1-2-3-3-4-5-6-7-8-9 should be written in upper case and other keys should be written in lower case!
        ["keymapping"] = {
            ["key"] = "PageUp",
            ["usable"] = true,
            ["command"] = "editormode",
            ["description"] = "Open Editor mode",
        },
    },
    ["carcontrol"] = {
        ["key"] = "Q", -- Q ( RADIO KEYBIND )
        ["command"] = "carcontrol", -- Command to open car control menu
        ["disabled"] = false, -- If you set this variable to `true`, car control menu will be completely disabled.
        ["openevent"] = "wais:hudv6:client:openCarControl", -- Event to open car control menu
        ["disableKey"] = false, -- If you set this variable to `true`, the keymapping system will be disabled and only command or event will be used to open car control menu.
        ["description"] = "Open Car Control Menu", -- Description of the command
        ["mouseControl"] = false, -- Allows you to control both the mouse and keyboard simultaneously. If you set it to `true`, you can control car control without splitting the game. If set to `false`, the game will split because your keyboard will only focus on car control.
        ["tabs"] = {
            --[[
                If you set it to `false`, the tab will be enabled.
                If you set it to `true`, the tab will be disabled. 
            ]]

            ["music"] = Config.MusicSystem.disable, -- Music tab allows you to control the music system in your vehicle. If you set it to `true`, the music tab will be completely disabled.
            ["nearby"] = false, -- Nearby tabs show nearby banks, gas stations, and other important locations.
            ["carmenu"] = false, -- Car menu tab allows you to control your vehicle's doors, hood, trunk, and other features. If you set it to `true`, the car menu tab will be completely disabled.
        }
    },
    ["postal"] = {
        ["disabled"] = false, -- If you set this variable to `true`, postal code will be completely disabled.
        ["command"] = "postal", -- Command to mark postal
        ["help"] = {
            ["command"] = "Marks the postal code you entered on the map.",
            ["postalid"] = "The postal code you want to mark on the map.",
        }
    },
    ["seat"] = {
        ["disabled"] = false, -- If you set this variable to `true`, seat changing command will be completely disabled.
        ["command"] = "seat", -- Command to change seat
        ["help"] = {
            ["command"] = "You can change the seats inside the vehicle.",
            ["seatid"] = "The seat number you wish to move to (1 for driver, 2 for front passenger, 3+ for rear seats).",
        }
    }
}

Config.MoneySettings = {
    ["name"] = "money",
    ["isItem"] = false, -- If your money is in the form of items, make it `true`. If you are using ox_inventory, make it `false`.
    ["isOldType"] = false, -- If you have an old ESX Version or Chezza Inventory etc. If you are using esx with an old infrastructure, make `true`. If you do not know what you are doing, please leave it as `false`
    
    -- [[ 🟢 Inventory detections, to work automatically compatible with some inventories. 🟢 ]]
    ["qs_inventory"] = GetResourceState("qs-inventory"):find("start") and true or false,
    ["ox_inventory"] = GetResourceState("ox_inventory"):find("start") and true or false,
}

Config.RefreshTimes = {
    --[[
        ⚠️ If you lower the refresh values here, hud will use more resmon. ⚠️
    --]]

    ["carhud"] = {  -- How often to refresh carhud
        ["balanced"] = 200,
        ["performance"] = 100,
    },
    ["status"] = { -- How often to refresh status
        ["balanced"] = 250,
        ["performance"] = 100,
    },
    ["compass"] = { -- How often to refresh compass
        ["balanced"] = 750,
        ["performance"] = 500,
    },
    ["players"] = 10 * 1000, -- How often to refresh player counts
    ["statusControl"] = 1 * 60 * 1000, -- Control time of the system that checks the user hunger thirst value and sends notifications.
    ["sysControllers"] = {
        ["screenRes"] = 2 * 1000, -- The duration of the control structure that detects the screen resolution and rebuilds things accordingly
        ["beltAlarm"] = 7.5 * 1000, -- Control time for belt fastening tone and warning
    }
}

Config.BlacklistedVehicles = {
    --[[
        ⚠️ There is a special hiding and blocking feature for some tools. It works with Class or Specific Model. ⚠️
        🟢 ["belt"] = true, -- If you set this to `true`, the seat belt system will not work in this vehicle or class.
        🟢 ["music"] = true, -- If you set this to `true`, the music system will not work in this vehicle or class.
        🟢 ["carhud"] = true, -- If you set this to `true`, the carhud will not be visible in this vehicle or class.
    --]]

    ["class"] = {
        [8] = {
            ["belt"] = true,
            ["music"] = true,
        },
        [13] = {
            ["belt"] = true,
            ["music"] = true,
            ["carhud"] = true,
        },
        [14] = {
            ["belt"] = true,
        },
        [15] = {
            ["belt"] = true,
        },
        [16] = {
            ["belt"] = true,
        },
    },
    ["models"] = {
        [`t20`] = {
            ["carhud"] = false,
        },
    }
}

Config.VoiceSettings = {
    ["totalRange"] = 3,
    ["defaultRange"] = 2,
}

Config.Notification = function(title, text, type, time)
    title = title or "Hud"
    time = time or 5000

    if Config.Framework.Framework == "qbcore" then
        TriggerEvent('QBCore:Notify', text, type, time)
    elseif Config.Framework.Framework == "esx" then
        lib.notify({
            title = title,
            type = type,
            duration = time,
            description = text,
            iconAnimation = "beatFade",
            position = "center-right"
        })
    elseif GetResourceState("okokNotify"):find("start") then
        exports['okokNotify']:Alert(title, text, time, type, true)
    elseif Config.Framework.Framework == "qbox" then
        lib.notify({
            title = title,
            type = type,
            duration = time,
            description = text,
            iconAnimation = "beatFade",
            position = "center-right"
        })
    end
end

Config.Debug = function(...)
    if not Config.ShowDebug then return end
    print(...)
end

Config.GetVehicleFuel = function(vehicle)
    return GetVehicleFuelLevel(vehicle) or 0.0
end

Config.MapFactor = {
    ["1280x720"] = {
        ["square"] = {
            ["x"] = 1.65,
            ["y"] = 530,
        },
        ["circle"] = {
            ["x"] = 1.65,
            ["y"] = 550,
        }
    },
    ["1366x768"] = {
        ["square"] = {
            ["x"] = 1.65,
            ["y"] = 605,
        },
        ["circle"] = {
            ["x"] = 1.65,
            ["y"] = 625,
        }
    },
    ["1920x1080"] = {
        ["square"] = {
            ["x"] = 1.65,
            ["y"] = 1200,
        },
        ["circle"] = {
            ["x"] = 1.65,
            ["y"] = 1235,
        }
    },
    ["2560x1440"] = {
        ["square"] = {
            ["x"] = 1.65,
            ["y"] = 2125,
        },
        ["circle"] = {
            ["x"] = 1.65,
            ["y"] = 2185,
        }
    },
    ["5120x1440"] = {
        ["square"] = {
            ["x"] = 2,
            ["y"] = 2093,
        },
        ["circle"] = {
            ["x"] = 1.95,
            ["y"] = 2178,
        }
    },
    ["7680x2160"] = {
        ["square"] = {
            ["x"] = 2,
            ["y"] = 4705,
        },
        ["circle"] = {
            ["x"] = 1.95,
            ["y"] = 4835,
        }
    },

    getFactor = function(resolution, maptype)
        if Config.MapFactor[resolution] ~= nil then
            return Config.MapFactor[resolution][maptype].x, Config.MapFactor[resolution][maptype].y
        end

        Config.Debug(("MapFactor: Resolution not found, can't use the positionable feature. %s"):format(resolution))
        return nil
    end
}

Config.CanOpenSettingsMenu = function()
    --[[
        -- Can the player open the settings menu?
        -- The person attempting to open the Settings menu will be monitored from here.
        -- return `true` allows the player to open the settings menu. return `false` prevents the player from opening the settings menu.

        📛📛📛
        If you want something like this, you must write custom code yourself or have your developer write the code.
        At this point, customizations like this are entirely your responsibility. We do not assist with Discord integration.
    ]]

    return true
end