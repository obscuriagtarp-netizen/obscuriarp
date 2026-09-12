Config = {}

Config.Enabled = true

Config.ClassMetadataKey = 'classe'
Config.VampireClass = 'vampiro'


Config.Protection = {
    refreshIntervalMs = 4000,
    requireEquipped = true,
    items = {
        {
            name = 'amuleto_eclipse',
            label = 'Amuleto do Eclipse',
            equipment = 'amulet',
            blocksWeakness = false,
        },
        -- Exemplo de amuleto que tambem remove todos os nerfs diurnos:
        -- {
        --     name = 'nome_do_amuleto_superior',
        --     label = 'Amuleto Superior',
        --     equipment = 'amulet',
        --     blocksWeakness = true,
        -- },
    },
}

Config.Daylight = {
    sunrise = 5.5,
    sunset = 20.0,
    minimumStrength = 0.20,

    southBias = -0.30,
    azimuthOffsetDegrees = 0.0,
}


Config.DayWeakness = {
    enabled = true,
    applyInShade = true,
    protectionBlocks = false,
}

Config.WeatherStrength = {
    EXTRASUNNY = 1.00,
    CLEAR = 1.00,
    NEUTRAL = 0.90,
    SMOG = 0.70,
    CLOUDS = 0.68,
    CLEARING = 0.55,
    OVERCAST = 0.45,
    HALLOWEEN = 0.40,
    FOGGY = 0.34,
    SNOW = 0.28,
    SNOWLIGHT = 0.24,
    XMAS = 0.22,
    RAIN = 0.12,
    THUNDER = 0.08,
    BLIZZARD = 0.05,
}

Config.Exposure = {
    checkIntervalMs = 350,
    exposureDelayMs = 1600,
    shadeGraceMs = 700,
    rayDistance = 220.0,

    rayFlags = 339,
    rayOptions = 4,
    minimumClearSamples = 1,
    minimumDirectionAgreement = 0.60,
    resultPollFrames = 20,
    ignoreInteriors = true,
    ignoreWater = true,
    useShelterNative = true,

    directionOffsets = {
        { azimuth = -12.0, elevation = 0.0 },
        { azimuth = 12.0, elevation = 0.0 },
        { azimuth = 0.0, elevation = -8.0 },
        { azimuth = 0.0, elevation = 8.0 },
    },

    sampleBones = {
        31086, -- SKEL_Head
        24818, -- SKEL_Spine2
        40269, -- SKEL_R_UpperArm
        45509, -- SKEL_L_UpperArm
    },
}

Config.Burning = {
    useEntityFire = true,
    reigniteIntervalMs = 900,

    additionalDamage = 0,
    damageIntervalMs = 1000,

    notify = true,
    startMessage = 'A luz do sol esta queimando sua pele.',
    protectionMessage = 'Seu artefato conteve a luz solar.',
}

Config.Debug = false
Config.DebugCommand = 'solvampiro'
