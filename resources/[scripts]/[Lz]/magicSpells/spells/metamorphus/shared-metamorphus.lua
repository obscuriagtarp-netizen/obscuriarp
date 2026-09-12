Config.RegisterSpell("metamorphus_fauna", {
    order = 80,
    label = "Metamorphus Fauna",
    shortLabel = "Fauna",
    description = "Transforma temporariamente um alvo em galinha.",
    item = "livro_metamorphus_fauna",
    essenceCost = 16,
    distance = 12.0,
    castTime = 3000,
    selfCastTime = 1433,
    chargeTime = 0,
    cooldown = 30000,
    icon = "assets/spell-metamorphus_fauna.png",
    cancelTipDelay = 0,
    duration = 20000,
    transformDelay = 1900,
    transformSmokeTime = 2400,
    selfCast = true,
    actionPrimary = {
        key = "Mouse esquerdo",
        label = "Transformar alvo"
    },
    actionSecondary = {
        key = "Mouse direito",
        label = "Transformar-se"
    },
    animation = {
        resource = "grimorio_victoria",
        dict = "grimorio_victoria",
        anim = "cast_upper",
        flag = 48,
        duration = 3000,
        loadTimeout = 8000,
        blendIn = 4.0,
        blendOut = 2.0,
        playbackRate = 1.0
    },
    transformAnimation = {
        dict = "amb@world_human_bum_standing@drunk@idle_a",
        anim = "idle_b",
        flag = 49,
        duration = 1900,
        loadTimeout = 1400
    },
    transformTremble = {
        enabled = true,
        headingStrength = 6.0,
        interval = 75,
        cameraShake = true,
        cameraIntensity = 0.24
    }
})
