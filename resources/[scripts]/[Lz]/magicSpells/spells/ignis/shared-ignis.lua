Config.RegisterSpell("ignis_conflagratio", {
    order = 70,
    label = "Ignis Conflagratio",
    shortLabel = "Ignis",
    description = "Carrega uma rajada de fogo e incendeia o alvo na mira.",
    item = "livro_ignis_conflagratio",
    essenceCost = 10,
    distance = 50.0,
    chargeTime = 0,
    cooldown = 15000,
    icon = "assets/spell-ignis_conflagratio.png",
    cancelTipDelay = 0,
    syncRadius = 70.0,
    releaseDelay = 2800,
    burnDuration = 8000,
    burnTick = 500,
    burnDamage = 4,
    npcBurnDuration = 14000,
    impactExplosion = {
        enabled = false,
        type = 7,
        damageScale = 0.45,
        audible = true,
        invisible = false,
        cameraShake = 0.45
    },
    trail = {
        asset = "core",
        fx = "fire_petroltank_heli",
        step = 2.2,
        scale = 1.12,
        maxNodes = 28,
        travelMs = 180,
        tailMsBase = 380,
        tailMsLast = 1500,
        color = vec4(1.0, 0.08, 0.02, 1.0)
    },
    handFx = {
        asset = "ob_fogo_vermelho",
        fx = "ob_fogo_vermelho",
        scale = 0.42,
        duration = 900,
        offset = vec3(0.16, 0.0, 0.0),
        bones = { 57005 }
    },
    chargeOrbFx = {
        asset = "ob_fogo_vermelho",
        fx = "ob_fogo_vermelho",
        bone = 18905,
        offset = vec3(0.075, 0.0, 0.0),
        startDelay = 900,
        startScale = 0.12,
        endScale = 0.52,
        color = vec4(1.0, 0.06, 0.01, 1.0)
    },
    groundFx = {
        asset = "scr_sum2_hal",
        fx = "scr_sum2_hal_rider_weak_greyblack",
        scale = 1.15,
        color = vec4(1.0, 0.0, 0.0, 1.0)
    },
    hitMapFx = {
        asset = "core",
        fx = "ent_ray_meth_fires",
        scale = 1.6,
        duration = 3000
    },
    hitPedFx = {
        asset = "core",
        fx = "fire_petroltank_heli",
        scale = 0.75,
        duration = 2600,
        bones = { 57005, 18905, 24818, 11816 }
    },
    animation = {
        resource = "grimorio_bola_de_fogo",
        dict = "grimorio_bola_de_fogo",
        anim = "fireball_upper",
        flag = 48,
        duration = 4600,
        loadTimeout = 8000,
        blendIn = 4.0,
        blendOut = 2.0,
        playbackRate = 1.0
    },
    releaseAnimation = {
        resource = "grimorio_bola_de_fogo",
        dict = "grimorio_bola_de_fogo",
        anim = "fireball_upper",
        flag = 48,
        duration = 4600,
        loadTimeout = 8000,
        blendIn = 4.0,
        blendOut = 2.0,
        playbackRate = 1.0
    }
})
