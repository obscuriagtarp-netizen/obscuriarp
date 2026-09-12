Config.RegisterSpell("invulneris", {
    order = 60,
    label = "Invulneris",
    shortLabel = "Invulneris",
    description = "Cria um domo arcano contra tiros, golpes e poderes. Quedas ainda ferem.",
    item = "livro_invulneris",
    essenceCost = 18,
    distance = 12.0,
    castTime = 1800,
    cooldown = 60000,
    icon = "assets/spell-invulneris.png",
    cancelTipDelay = 0,
    duration = 120000,
    targetDuration = 120000,
    selfDuration = 45000,
    selfCast = true,
    actionPrimary = {
        key = "Mouse esquerdo",
        label = "Marcar alvo"
    },
    actionSecondary = {
        key = "Mouse direito",
        label = "Proteger-se"
    },
    animation = {
        resource = "grimorio_victoria",
        dict = "grimorio_victoria",
        anim = "cast_upper",
        flag = 48,
        duration = 1800,
        loadTimeout = 8000,
        blendIn = 4.0,
        blendOut = 2.0,
        playbackRate = 1.0
    },
    orbit = {
        textureFile = "html/assets/invulneris-shield.png",
        textureDict = "ob_invulneris_runtime",
        textureName = "invulneris_shield",
        markerType = 9,
        shardCount = 6,
        radius = 0.84,
        centerOffset = 0.04,
        verticalWave = 0.2,
        size = 0.48,
        speed = 1.12,
        drawDistance = 80.0,
        baseOffset = -1.0,
        baseSize = 1.24,
        color = vec4(1.0, 1.0, 1.0, 0.94),
        baseColor = vec4(0.5, 0.16, 0.82, 0.3),
        previewCommand = "testinvulnerisfx",
        previewDuration = 25000
    }
})
