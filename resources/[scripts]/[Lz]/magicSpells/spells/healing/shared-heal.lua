Config.RegisterSpell("vitae_restituo", {
    order = 30,
    label = "Vitae Restituo",
    shortLabel = "Vitae",
    description = "Restaura lentamente a vitalidade de um aliado ou de si mesmo.",
    item = "livro_vitae_restituo",
    essenceCost = 14,
    distance = 15.0,
    castTime = 2200,
    healDuration = 10000,
    cooldown = 10000,
    icon = "assets/spell-vitae_restituo.png",
    cancelTipDelay = 1500,
    targetHealFraction = 1.0,
    selfHealFraction = 0.5,
    selfCast = true,
    actionPrimary = {
        key = "Mouse esquerdo",
        label = "Curar aliado"
    },
    actionSecondary = {
        key = "Mouse direito",
        label = "Curar-se"
    },
    animation = {
        resource = "grimorio_victoria",
        dict = "grimorio_victoria",
        anim = "cast_upper",
        flag = 48,
        duration = 2200,
        loadTimeout = 8000,
        blendIn = 4.0,
        blendOut = 2.0,
        playbackRate = 1.0
    },
    fxAsset = "scr_powerplay",
    fxEffect = "scr_powerplay_beast_vapor",
    fxScale = 1.08
})
