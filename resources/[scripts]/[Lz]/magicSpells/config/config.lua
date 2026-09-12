Config = Config or {}

Config.Framework = "qbox"

Config.Debug = false

Config.MagicWandItem = "victoriawand"
Config.WandProp = "victoriawand"

Config.WandAttach = {
    bone = 57005,
    pos = vec3(0.27, 0.16, -0.02),
    rot = vec3(140.0, 90.0, 0.0)
}

Config.Database = {
    AutoCreate = true,
    SpellsTable = "magic_spells",
    PortusTable = "magic_portus_locations"
}

Config.Qbox = {
    UseOxInventory = true,
    LearnAllSpellsByDefault = false
}

Config.GrimoireAccess = {
    metadataKey = 'classe',
    allowedClasses = {
        bruxa = true,
    },
}

Config.Controls = {
    Cancel = 303,
    Back = 177,
    GrimoireNextKey = "RIGHT",
    GrimoirePrevKey = "LEFT",
    GrimoireNextLabel = "DIR",
    GrimoirePrevLabel = "ESQ"
}

Config.Crosshair = {
    Enabled = true,
    UpdateInterval = 120,
    MaxDistance = 55.0,
    CastChargeTime = 900
}

Config.TestCommand = {
    Enabled = true,
    Name = "grimorioteste"
}

Config.DefaultSpellAnimationFallback = {
    resource = "magicSpells",
    dict = "magic@dark_spell",
    anim = "base",
    flag = 48,
    duration = 2200,
    loadTimeout = 2500,
    blendIn = 4.0,
    blendOut = 2.0,
    playbackRate = 1.0
}

Config.EmergencySpellAnimationFallback = {
    dict = "anim@mp_player_intcelebrationfemale@jazz_hands",
    anim = "jazz_hands",
    flag = 0,
    duration = 2500,
    loadTimeout = 3000,
    blendIn = 4.0,
    blendOut = 2.0,
    playbackRate = 1.0
}

Config.Spells = Config.Spells or {}
Config.SpellOrder = Config.SpellOrder or {}

function Config.RegisterSpell(spellName, spellData)
    if not spellName or spellName == "" or type(spellData) ~= "table" then
        return
    end

    spellData.name = spellName
    spellData.order = spellData.order or (#Config.SpellOrder + 1)
    Config.Spells[spellName] = spellData

    local alreadyRegistered = false
    for _, registeredName in ipairs(Config.SpellOrder) do
        if registeredName == spellName then
            alreadyRegistered = true
            break
        end
    end

    if not alreadyRegistered then
        Config.SpellOrder[#Config.SpellOrder + 1] = spellName
    end

    table.sort(Config.SpellOrder, function(a, b)
        local spellA = Config.Spells[a] or {}
        local spellB = Config.Spells[b] or {}
        return (spellA.order or 9999) < (spellB.order or 9999)
    end)
end
