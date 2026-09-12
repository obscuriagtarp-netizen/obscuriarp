Config = {}

-----------------------------------------------------------------------
-- Framework & General Settings
-----------------------------------------------------------------------

-- Framework detection: 'auto', 'qbx', 'qb', 'esx', 'vrp', 'standalone'
Config.Framework = 'auto'

-- Enable ox_lib integration (lib.addCommand, lib.notify, etc.)
-- Set to false if ox_lib is not available on the target server
Config.UseOxLib = true

-- Language (system + HUD): 'pt-BR', 'en-US', 'es', 'fr', 'pt-PT', 'th'
-- Request new languages: contact math0001 on Discord
Config.Locale = 'pt-BR'

-- Notification system: 'auto', 'ox_lib', 'qb', 'esx', 'vrp', 'native'
-- 'auto' picks the best available (ox_lib > framework > native)
Config.Notifications = {
    type = 'auto',
    duration = 5000,
}

-----------------------------------------------------------------------
-- Command Names (customer can rename freely)
-----------------------------------------------------------------------

Config.Commands = {
    equip     = 'asas7',          -- Equip wings (accepts color param)
    remove    = 'remover7',       -- Remove equipped wings
    toggle    = 'asastg7',        -- Open/close wings
    fly       = 'asasvoar7',      -- Toggle flight mode
    color     = 'asascor7',       -- Change wing color
    cleanup   = 'asaslimpar7',    -- Admin: remove ALL wings in the world (global)
    cleanup2  = 'asaslimpar27',   -- Remove orphaned/bugged wings near you
    abrir     = 'abrir7',         -- Open wings (ground animation)
    fechar    = 'fechar7',        -- Close wings (ground animation)
    bater     = 'bater7',         -- Flap wings (ground animation)
}

-- HUD command
Config.HudCommand = 'hud7'

-----------------------------------------------------------------------
-- Keybinds (player can rebind in GTA V Settings > Key Bindings > FiveM)
-- Set key to false to disable that keybind
-- Key names: https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/
-----------------------------------------------------------------------

Config.Keybinds = {
    toggle = '',       -- Open/close wings
    fly    = false,     -- O voo e controlado exclusivamente pela ob_curandeiras
    hud    = false,     -- HUD controlada pela ob_curandeiras no F6
}

-----------------------------------------------------------------------
-- Callbacks (customer can override behavior without touching code)
-----------------------------------------------------------------------

Config.Callbacks = {}

-- Called BEFORE equipping wings. Return false to block.
-- Also controls whether the GET WING button appears enabled in the HUD.
-- @param source number - Player server ID
-- @param cor number - Wing color being equipped (nil when checking HUD state)
-- @return boolean|nil - false blocks, true/nil allows
Config.Callbacks.CanEquipWings = function(source, cor)
    return true
end

-- Called AFTER wings are equipped successfully
-- @param source number - Player server ID
-- @param cor number - Wing color equipped
Config.Callbacks.OnWingsEquipped = function(source, cor)
    -- Example: log to discord, give xp, etc.
end

-- Called AFTER wings are removed
-- @param source number - Player server ID
Config.Callbacks.OnWingsRemoved = function(source)
    -- Example: remove buffs, log, etc.
end

-- Called BEFORE opening the HUD. Return false to block.
-- @param source number - Player server ID
-- @return boolean - false blocks, true/nil allows
Config.Callbacks.CanOpenHUD = function(source)
    return true
end

-- Override permission check. Return nil to use default bridge logic.
-- @param source number - Player server ID
-- @param permission string - Permission key being checked
-- @return boolean|nil - true=allow, false=deny, nil=use default
Config.Callbacks.HasPermission = function(source, permission)
    return nil -- use default
end

-----------------------------------------------------------------------
-- Cooldowns (seconds) — 0 = no cooldown
-----------------------------------------------------------------------

Config.Cooldowns = {
}
