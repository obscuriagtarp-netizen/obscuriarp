Config = Config or {}

Config.ClassMetadataKey = 'classe'

Config.Classes = {
    bruxa = {
        key = 'mana',
        maxKey = 'mana_max',
        label = 'Mana',
        max = 100,
        initial = 100,
        regen = 1,
    },
    vampiro = {
        key = 'sangue',
        maxKey = 'sangue_max',
        label = 'Sangue',
        max = 100,
        initial = 100,
        regen = 1,
    },
    curandeira = {
        key = 'energia',
        maxKey = 'energia_max',
        label = 'Energia',
        max = 100,
        initial = 100,
        regen = 1,
    },
    humano = {
        key = 'energia',
        maxKey = 'energia_max',
        label = 'Energia',
        max = 100,
        initial = 100,
        regen = 1,
    },
}

Config.Regen = {
    enabled = false,
    interval = 10000,
}

Config.Client = {
    maxCostPerRequest = 100,
    allowRestore = false,
    allowSet = false,
}

Config.Commands = {
    AddEssence = 'addessencia',
    SetEssence = 'setessencia',
    AdminPermission = 'group.admin',
}

Config.Debug = false
Config.DebugCommand = 'setessencia'
