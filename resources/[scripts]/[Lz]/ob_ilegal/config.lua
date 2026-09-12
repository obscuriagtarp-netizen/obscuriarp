Config = {}

Config.ClassMetadataKey = 'classe'

Config.Reward = {
    item = 'money',
    minimum = 850,
    maximum = 1400,
    dropCount = {
        minimum = 7,
        maximum = 11,
    },
    dropLifetime = 90,
    pickupDistance = 1.35,
}

Config.Atm = {
    models = {
        'prop_atm_01',
        'prop_atm_02',
        'prop_atm_03',
        'prop_fleeca_atm',
    },
    interactionDistance = 2.0,
    serverDistance = 3.5,
    successCooldown = 20 * 60,
    failureCooldown = 0,
}

Config.Police = {
    minimum = 3,
    jobs = {
        police = true,
        sheriff = true,
    },
    alertDuration = 60,
    alertRadius = 90.0,
}

Config.Classes = {
    humano = {
        enabled = true,
        duration = 3,
        essenceCost = 0,
        rewardMultiplier = 1.0,
        alertChance = 0.25,
        requiredItem = {
            name = 'dispositivo_hacking',
            count = 1,
            consume = false,
        },
    },
    bruxa = {
        enabled = true,
        duration = 8,
        essenceCost = 18,
        rewardMultiplier = 1.1,
        alertChance = 0.42,
    },
    vampiro = {
        enabled = true,
        duration = 6,
        essenceCost = 14,
        rewardMultiplier = 0.95,
        alertChance = 0.85,
    },
    curandeira = {
        enabled = true,
        duration = 10,
        essenceCost = 16,
        rewardMultiplier = 1.05,
        alertChance = 0.30,
    },
}

Config.Minigames = {
    lock = {
        timeLimit = 24,
        attempts = 3,
        humano = { pins = 5, tolerance = 0.075 },
        bruxa = { timeLimit = 28, lineTolerance = 18 },
        vampiro = { chambers = 4, tolerance = 0.07 },
        curandeira = { timeLimit = 26 },
    },
    vault = {
        timeLimit = 44,
        attempts = 3,
        humano = { tumblers = 3, tolerance = 2.75 },
        bruxa = { rings = 5, attempts = 4 },
        vampiro = { attempts = 3 },
        curandeira = { blooms = 6, attempts = 3 },
    },
}

Config.Robberies = {
    central_bank = {
        enabled = true,
        label = 'Banco Central',
        cooldown = 90 * 60,
        sequenceTimeout = 30 * 60,
        minimumPolice = 0,
        alertOnStart = true,
        failureAlertsPolice = true,
        allowedClasses = {
            humano = true,
            bruxa = true,
            vampiro = true,
            curandeira = true,
        },
        reward = {
            item = 'black_money',
            minimum = 14000,
            maximum = 22000,
            dropCount = { minimum = 18, maximum = 28 },
            dropLifetime = 150,
            pickupDistance = 1.45,
        },
        stages = {
            {
                id = 'porta_externa',
                label = 'Violar fechadura externa',
                type = 'lock',
                coords = vec3(256.74, 220.17, 106.33),
                heading = 338.53,
                radius = 0.9,
                serverDistance = 3.0,
                doorId = 4,
                minigame = { pins = 4, timeLimit = 22, tolerance = 0.085 },
            },
            {
                id = 'porta_seguranca',
                label = 'Romper porta de segurança',
                type = 'lock',
                coords = vec3(261.54, 221.81, 106.28),
                heading = 223.68,
                radius = 0.9,
                serverDistance = 3.0,
                doorId = 6,
                minigame = { pins = 6, timeLimit = 28, tolerance = 0.065 },
            },
            {
                id = 'mecanismo_cofre',
                label = 'Decifrar mecanismo do cofre',
                type = 'vault',
                coords = vec3(253.86, 225.22, 101.88),
                heading = 164.98,
                radius = 1.1,
                serverDistance = 3.5,
                doorId = 7,
                minigame = { tumblers = 3, timeLimit = 42, tolerance = 3 },
            },
            {
                id = 'grade_interna',
                label = 'Abrir grade interna',
                type = 'lock',
                coords = vec3(252.62, 221.16, 101.68),
                heading = 158.69,
                radius = 0.9,
                serverDistance = 3.0,
                doorId = 8,
                minigame = { pins = 6, timeLimit = 26, tolerance = 0.06 },
            },
            {
                id = 'grade_interna2',
                label = 'Abrir grade interna',
                type = 'lock',
                coords = vec3(261.09, 215.18, 101.68),
                heading = 253.36,
                radius = 0.9,
                serverDistance = 3.0,
                doorId = 3,
                minigame = { pins = 6, timeLimit = 26, tolerance = 0.06 },
            },
            {
                id = 'tesouraria',
                label = 'Extrair dinheiro da tesouraria',
                type = 'loot',
                coords = vec3(263.33, 212.32, 101.68),
                heading = 167.06,
                radius = 1.3,
                serverDistance = 4.0,
                minigame = { timeLimit = 35 },
            },
        },
    },
}
