Config = Config or {}

Config.ClassId = 'curandeira'
Config.ClassMetadataKey = 'classe'

Config.Hud = {
    position = {
        right = '2.2vw',
        bottom = '1.8vh',
        scale = 1.18,
    },
    wingMenuPosition = {
        right = '2.2vw',
        bottom = 'clamp(462px, 44vh, 488px)',
        scale = 1.12,
    },
    theme = {
        accent = '#86c57c',
        accentSoft = '#152819',
        frameHue = '88deg',
    },
}

Config.WingMenu = {
    enabled = true,
    command = 'asascurandeira',
    key = 'F6',
    resource = 'MathStoreFairyWing-V7',
    stateKey = 'activeWingResource',
    selectionStateKey = 'obCurandeiraWing',
    colorStateKey = 'obCurandeiraWingFx',
    unlockMetadataKey = 'obCurandeiraWings',
    freeColor = 79,
    runeCurrency = {
        resource = 'magicPauseObscuria',
        getExport = 'GetRunes',
        removeExport = 'RemoveRunes',
        addExport = 'AddRunes',
        defaultPrice = 750,
    },

    visibleColors = { 79, 103, 1, 106, 36, 114, 105, 37, 51, 40, 2 },
    showUnavailable = true,
    actionCooldown = 500,
}

Config.WingUnlocks = {
    [79] = {
        label = 'Asas da Aurora',
        description = 'A manifestação vital concedida a todas as Curandeiras.',
        tier = 'Curandeira',
        permissions = {
            classes = { 'curandeira' },
            jobs = {},
            groups = {},
            citizenids = {},
        },
    },

    [103] = {
        label = 'Asas do Crepúsculo',
        description = 'Uma manifestação rosada marcada por olhos etéreos.',
        tier = 'Bloqueado',
        priceRunes = 750,
        permissions = {
            classes = {},
            jobs = {},
            groups = {},
            citizenids = {},
        },
    },

}

Config.Essence = {
    resource = 'ob_essencias',
    removeExport = 'RemoveEssencia',
}

Config.Flight = {
    cooldown = 150000,
    essenceCost = 2,
    sustainCost = 3,
    sustainInterval = 10000,
    controllerModel = 'prop_beachball_02',
    pedOffsetZ = 0.95,
    landingZOffset = 1.0,
    takeoffVelocity = 4.2,
    acceleration = 0.34,
    boostMultiplier = 4.5,
    maxSpeed = 10.0,
    maxBoostSpeed = 25.0,
    backwardMultiplier = 0.62,
    verticalAcceleration = 0.3,
    dive = {
        minimumHeight = 12.0,
        exitHeight = 6.0,
        groundScanDistance = 180.0,
        cameraPitchThreshold = -35.0,
        checkInterval = 150,
        speedMultiplier = 3.2,
        maxSpeed = 30.0,
    },
    idleDrag = 0.88,
    syncInterval = 125,
    syncInterpolation = 0.42,
    syncMaxPrediction = 0.16,
    syncRange = 160.0,
    remoteRenderInterval = 33,
    groundSafetyInterval = 90,
    animationCheckInterval = 250,
    lod = {
        refreshInterval = 750,
        maxCustomSyncFlights = 8,
        effectsDistance = 70.0,
        closeDistance = 40.0,
        mediumDistance = 90.0,
        closeRenderInterval = 33,
        mediumRenderInterval = 66,
        farRenderInterval = 125,
        closeSyncInterval = 125,
        mediumSyncInterval = 250,
        farSyncInterval = 500,
    },
    controls = {
        boost = 21,
        descend = 22,
        ascend = 36,
        frontView = 26,
    },
    wing = {
        required = true,
        resource = 'MathStoreFairyWing-V7',
        stateKey = 'activeWingResource',
        selectionStateKey = 'obCurandeiraWing',
        colorStateKey = 'obCurandeiraWingFx',
        animationCheckInterval = 400,
        modelColors = { 1, 2, 36, 37, 40, 51, 79, 103, 105, 106, 114 },
        animations = {
            normal = {
                dict = 'mts_fv7_loopfly',
                clip = 'mts_fv7_loopfly_clip',
                speed = 1.0,
            },
            dive = {
                dict = 'mts_fv7_op',
                clip = 'mts_fv7_op_clip',
                speed = 1.0,
            },
            open = {
                dict = 'mts_fv7_op',
                clip = 'mts_fv7_op_clip',
                speed = 1.0,
            },
        },
    },
    groundSafetyDistance = 2.2,
    groundScanDistance = 180.0,
    landingMinDuration = 1400,
    landingMaxDuration = 4200,
    hypnosisDescentSpeed = 8.0,
    hypnosisLandingMinDuration = 1800,
    hypnosisLandingMaxDuration = 9000,
    hypnosisFallbackDescentSpeed = 2.0,
    animations = {
        idle = {
            dict = 'flynolis1@animation',
            name = 'flynolis1_clip',
        },
        idleToMove = {
            dict = 'export@nib@super@basicflight_idle_to_fast',
            name = 'nib@super@basicflight_idle_to_fast',
        },
        moving = {
            dict = 'flynolis5@animation',
            name = 'flynolis5_clip',
        },
        diveMoving = {
            dict = 'export@nib@super@basicflight_fast_botharmsback',
            name = 'nib@super@basicflight_fast_botharmsback',
        },
        slowToIdle = {
            dict = 'flynolis1@animation',
            name = 'flynolis1_clip',
        },
        fastToIdle = {
            dict = 'flynolis1@animation',
            name = 'flynolis1_clip',
        },
        transitionDuration = 420,
        transitionSpeed = 1.5,
    },
    camera = {
        distance = 4.0,
        height = 1.4,
        yawSpeed = 8.0,
        pitchSpeed = 6.0,
        minPitch = -58.0,
        maxPitch = 30.0,
        normalFov = 50.0,
        boostFov = 57.0,
        frontViewDistance = 5.0,
        frontViewHeight = 1.55,
        frontViewLookHeight = 1.45,
        frontViewFov = 48.0,
        frontViewBlendSpeed = 0.16,
    },
    fx = {
        asset = 'scr_powerplay',
        effect = 'scr_powerplay_beast_vapor',
        color = { 0.78, 1.0, 0.58 },
        scale = 0.72,
    },
    boostFx = {
        smoke = {
            asset = 'scr_powerplay',
            effect = 'sp_powerplay_beast_appear_trails',
            color = { 0.08, 0.86, 0.24 },
            alpha = 0.46,
            scale = 6.0,
            bones = {
                24818, 24817, 24816, 31086, 2108, 20781, 2992,
                22711, 16335, 46078, 14201, 52301, 51826, 58271,
                11816, 23553, 6442, 23639, 57005, 18905,
            },
        },
        distortion = {
            asset = 'scr_xm_heat',
            effect = 'scr_xm_heat_camo',
            scale = 1.3,
            bones = { 24818, 23553 },
            boneDelay = 50,
        },
        retryInterval = 1500,
        remotePollInterval = 250,
    },
}

Config.VitalHeal = {
    distance = 14.0,
    cooldown = 50000,
    essenceCost = 15,
    channelDuration = 3200,
    healDuration = 10000,
    healFraction = 1.0,
}

Config.Serenity = {
    distance = 14.0,
    cooldown = 50000,
    essenceCost = 15,
    channelDuration = 3500,
    effectDuration = 30000,
}

Config.StopBleeding = {
    distance = 10.0,
    cooldown = 5000,
    essenceCost = 15,
    channelDuration = 3800,
    effectDuration = 6000,
    healDuration = 4000,
    healFraction = 0.15,
}

Config.TreatmentFx = {
    syncRange = 80.0,
    pulseInterval = 520,
    healSymbols = {
        count = 8,
        riseDuration = 2200,
        radius = 0.48,
        startOffset = -0.8,
        riseHeight = 2.25,
        size = 0.42,
        orbitSpeed = 0.78,
        turnsPerRise = 0.72,
        drawDistance = 65.0,
    },
    palettes = {
        heal = {
            main = { 0.18, 1.0, 0.42 },
            soft = { 0.62, 1.0, 0.72 },
        },
        serenity = {
            main = { 0.12, 0.88, 0.76 },
            soft = { 0.56, 1.0, 0.92 },
        },
        bleeding = {
            main = { 1.0, 0.36, 0.07 },
            soft = { 1.0, 0.76, 0.28 },
        },
    },
}

Config.CastAnimation = {
    dict = 'kiml@magic@export@nib@wizardsv_wand_attack_b3',
    name = 'nib@wizardsv_wand_attack_b3',
    flag = 33,
}

Config.Compatibility = {
    stressMetadataKey = 'stress',
    stressStateKey = 'stress',
    stressClientEvents = {
        'hud:client:UpdateStress',
    },
    medicalResource = 'qbx_medical',
    bleedingClientEvents = {}, 
}
