Config = Config or {}

Config.Debug = false
Config.TableName = 'magic_spells'
Config.AutoCreateTable = true

Config.ClassAccess = {
    enabled = true,
    metadataKey = 'classe',
    allowed = {
        bruxa = true,
    },
}

Config.Learning = {
    requireItem = true,
    consumeItemOnSuccess = true,
    minimumTraceTime = 800,
    inputTimeout = 2000,
    sessionTimeout = 120000,
}

Config.LearningCommand = {
    enabled = true,
    name = 'aprenderruna',
    restricted = false,
}

Config.Spells = {
    { id = 'blink', label = 'Blink', letter = 'F', rune = 'f_blink', item = 'livro_blink', image = 'assets/rune-f-blink.png', icon = 'assets/spell-blink.png', accent = '#a96bff', position = 1 },
    { id = 'machina_reparatio', label = 'Machina Reparatio', letter = 'U', rune = 'u_reparatio', item = 'livro_machina_reparatio', image = 'assets/rune-u-reparatio.png', icon = 'assets/spell-machina_reparatio.png', accent = '#a96bff', position = 2 },
    { id = 'vitae_restituo', label = 'Vitae Restituo', letter = 'R', rune = 'r_vitae', item = 'livro_vitae_restituo', image = 'assets/rune-r-vitae.png', icon = 'assets/spell-vitae_restituo.png', accent = '#a96bff', position = 3 },
    { id = 'petrificus', label = 'Glacies', letter = 'U', rune = 'u_petrificus', item = 'livro_petrificus', image = 'assets/rune-u-petrificus.png', icon = 'assets/spell-petrificus.png', accent = '#a96bff', position = 4 },
    { id = 'portus', label = 'Portus', letter = 'S', rune = 's_portus', item = 'livro_portus', image = 'assets/rune-s-portus.png', icon = 'assets/spell-portus.png', accent = '#a96bff', position = 5 },
    { id = 'invulneris', label = 'Invulneris', letter = 'A', rune = 'a_invulneris', item = 'livro_invulneris', image = 'assets/rune-a-invulneris.png', icon = 'assets/spell-invulneris.png', accent = '#a96bff', position = 6 },
    { id = 'ignis_conflagratio', label = 'Ignis Conflagratio', letter = 'T', rune = 't_ignis', item = 'livro_ignis_conflagratio', image = 'assets/rune-t-ignis.png', icon = 'assets/spell-ignis_conflagratio.png', accent = '#a96bff', position = 7 },
    { id = 'metamorphus_fauna', label = 'Metamorphus Fauna', letter = 'O', rune = 'o_fauna', item = 'livro_metamorphus_fauna', image = 'assets/rune-o-fauna.png', icon = 'assets/spell-metamorphus_fauna.png', accent = '#a96bff', position = 8 },
}
