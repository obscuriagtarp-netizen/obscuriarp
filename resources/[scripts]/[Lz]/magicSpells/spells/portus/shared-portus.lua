Config.RegisterSpell("portus", {
    order = 50,
    label = "Portus",
    shortLabel = "Portus",
    description = "Abre um portal temporario para um destino salvo.",
    item = "livro_portus",
    essenceCost = 20,
    castTime = 4000,
    cooldown = 20000,
    icon = "assets/spell-portus.png",
    cancelTipDelay = 1500,
    maxLocations = 3,
    runeEraseItem = "portus_rune_eraser",
    runeMarkDuration = 2200,
    portalRadius = 1.25,
    portalDuration = 15000,
    portalForwardOffset = 2.35,
    portalExitOffset = 1.85,
    portalDestinationZOffset = -1.0,
    portalRenderDistance = 80.0,
    portalTraversalTolerance = 1.0,
    portalVisualZOffset = 1.28,
    portalAuraRadius = 1.24,
    portalAuraMiddleRadius = 1.05,
    portalAuraInnerRadius = 0.88,
    portalAuraScale = 0.22,
    portalAuraMiddleScale = 0.18,
    portalAuraInnerScale = 0.14,
    portalAuraInterval = 180,
    portalGlowRange = 4.0,
    portalAuraAsset = "ob_fogo_roxo",
    portalAuraEffect = "ob_fogo_roxo",
    portalRuneFx = {
        [1] = {
            asset = "ob_fogo_roxo",
            effect = "ob_fogo_roxo"
        },
        [2] = {
            asset = "ob_fogo_azul",
            effect = "ob_fogo_azul"
        },
        [3] = {
            asset = "ob_fogo_verde",
            effect = "ob_fogo_verde"
        }
    },
    portalRuneColors = {
        [1] = {
            particle = { 0.76, 0.12, 1.0 },
            light = { 175, 48, 255 }
        },
        [2] = {
            particle = { 0.08, 0.55, 1.0 },
            light = { 30, 145, 255 }
        },
        [3] = {
            particle = { 0.10, 0.92, 0.45 },
            light = { 35, 235, 120 }
        }
    },
    portalFxAsset = "scr_powerplay",
    portalFxEffect = "sp_powerplay_beast_appear_trails",
    animation = {
        resource = "grimorio_victoria",
        dict = "grimorio_victoria",
        anim = "cast_upper",
        flag = 48,
        duration = 4000,
        loadTimeout = 8000,
        blendIn = 4.0,
        blendOut = 2.0,
        playbackRate = 1.0
    }
})
