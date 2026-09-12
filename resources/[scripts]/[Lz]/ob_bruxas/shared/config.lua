Config = Config or {}

Config.ClassId = 'bruxa'
Config.ClassMetadataKey = 'classe'

Config.Hud = {
    positions = {
        normal = {
            right = '2.2vw',
            bottom = '1.8vh',
            scale = 1.18,
        },
        grimoire = {
            right = '4.6vw',
            bottom = '41vh',
            scale = 1.18,
        },
    },
    theme = {
        accent = '#a878d0',
        accentSoft = '#24152f',
        frameHue = '0deg',
    },
}

Config.Familiar = {
    model = 'a_c_cat_01',
    textureVariation = 1,
    transitionTime = 1350,
    smokeDuration = 1550,
    returnCooldown = 55000,
    sustainCost = 2,
    sustainInterval = 8000,
    sustainGrace = 3000,
    preserveHealth = true,
    transformationFx = {
        smokeAsset = 'core',
        smokeName = 'exp_grd_grenade_smoke',
        smokeColor = { 0.12, 0.0, 0.2 },
        smokeAlpha = 0.9,
        smokeScale = 1.2,
        trailAsset = 'scr_powerplay',
        trailName = 'sp_powerplay_beast_appear_trails',
        trailColor = { 0.46, 0.035, 0.68 },
        trailAlpha = 0.58,
        trailScale = 4.4,
        pulses = 3,
        pulseInterval = 125,
        syncRange = 65.0,
    },
}

Config.SentidoArcano = {
    cooldown = 50000,
    sustainCost = 2,
    sustainInterval = 3000,
    sustainGrace = 1800,
    snapshotRefresh = 3500,
    renderDistance = 80.0,
    showCreaturesWithoutResidue = false,
    creatureDistance = 42.0,
    defaultResidueDuration = 120000,
    residueMergeDistance = 3.0,
    residueMergeWindow = 12000,
    maxResidues = 256,
    maxVisibleResidues = 48,
    cleanupInterval = 30000,
    residueFx = {
        asset = 'scr_powerplay',
        effect = 'sp_powerplay_beast_appear_trails',
        scale = 1.65,
        alpha = 0.68,
        height = 0.1,
        spread = 0.12,
        nearDistance = 24.0,
        middleDistance = 48.0,
        nearInterval = 180,
        middleInterval = 350,
        farInterval = 650,
        updateInterval = 100,
    },
    colors = {
        bruxa = { 155, 72, 225 },
        vampiro = { 218, 38, 54 },
        curandeira = { 61, 201, 105 },
        ritual = { 166, 91, 255 },
        enchanted = { 69, 214, 225 },
        creature = { 239, 190, 88 },
        mana = { 155, 72, 225 },
        magic = { 155, 72, 225 },
    },
}

Config.EloArcano = {
    castTime = 2200,
    duration = 10000,
    cooldown = 250000,
    targetDistance = 14.0,
    tickInterval = 1000,
    selfManaPerTick = 5,
    allyManaPerTick = 9,
    animation = {
        dict = 'kiml@magic@export@nib@wizardsv_wand_attack_b3',
        name = 'nib@wizardsv_wand_attack_b3',
        flag = 33,
    },
    fx = {
        asset = 'scr_powerplay',
        effect = 'scr_powerplay_beast_vapor',
        scale = 0.82,
        syncRange = 80.0,
        palette = {
            main = { 0.68, 0.16, 1.0 },
            feet = { 0.42, 0.08, 0.82 },
            marker = { 168, 68, 255 },
            pulse = { 0.76, 0.28, 1.0 },
        },
    },
}

Config.NevoaBruxas = {
    duration = 20000,
    cooldown = 150000,
    essenceCost = 25,
    radius = 8.5,
    syncRange = 90.0,
    castTime = 1100,
    animation = {
        dict = 'kiml@magic@export@nib@wizardsv_wand_attack_b3',
        name = 'nib@wizardsv_wand_attack_b3',
        flag = 33,
    },
    fx = {
        height = -0.42,
        referenceRadius = 8.5,
        smoke = {
            asset = 'ob_nevoa_bruxas',
            effect = 'ob_nevoa_bruxas',
            color = { 0.30, 0.10, 0.42 },
            alpha = 0.92,
            scale = 3.6,
        },
    },
}

Config.Mana = {
    metadataKey = 'mana',
    maxMetadataKeys = { 'maxMana', 'manaMax', 'mana_max' },
    defaultMax = 100,

    resource = 'ob_essencias',
    serverExport = 'AddEssencia',
}
