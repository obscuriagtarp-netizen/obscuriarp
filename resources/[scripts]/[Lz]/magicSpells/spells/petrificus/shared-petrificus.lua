Config.RegisterSpell("petrificus", {
    order = 40,
    label = "Glacies",
    shortLabel = "Glacies",
    description = "Dispara uma rajada glacial que congela o alvo sob uma camada de geada arcana.",
    item = "livro_petrificus",
    essenceCost = 12,
    distance = 28.0,
    castTime = 2200,
    castReleaseDelay = 1433,
    beamDuration = 700,
    freezeDuration = 7000,
    cooldown = 12000,
    icon = "assets/spell-petrificus.png",
    actionPrimary = {
        key = "Mouse esquerdo",
        label = "Lancar raio glacial"
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
    iceFx = {
        resource = "gelo_assets_preview",
        cast = "codex_ice_cast",
        impact = "codex_ice_impact",
        frost = "codex_ice_frost",
        castScale = 1.05,
        impactScale = 1.15,
        frostScale = 0.72,
        frostBones = { 31086, 24818, 57005, 18905, 58271, 51826 }
    }
})
