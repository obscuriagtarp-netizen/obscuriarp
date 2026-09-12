Config.RegisterSpell("machina_reparatio", {
    order = 20,
    label = "Machina Reparatio",
    shortLabel = "Reparatio",
    description = "Restaura um veiculo marcado pela varinha.",
    item = "livro_machina_reparatio",
    essenceCost = 6,
    distance = 12.0,
    repairTime = 6000,
    cooldown = 15000,
    icon = "assets/spell-machina_reparatio.png",
    markFx = {
        radius = 2.45,
        color = { r = 86, g = 235, b = 218, a = 118 }
    },
    channelFx = {
        asset = "scr_sum2_hal",
        fx = "scr_sum2_hal_rider_death_orange",
        scale = 0.48,
        interval = 420,
        color = vec4(0.45, 0.95, 1.0, 0.85)
    },
    repairFx = {
        asset = "scr_ie_tw",
        fx = "scr_impexp_tw_take_zone",
        scale = 0.9,
        burstScale = 1.55
    },
    animation = {
        resource = "grimorio_victoria",
        dict = "grimorio_victoria",
        anim = "cast_upper",
        flag = 48,
        duration = 6000,
        loadTimeout = 8000,
        blendIn = 4.0,
        blendOut = 2.0,
        playbackRate = 1.0
    }
})
