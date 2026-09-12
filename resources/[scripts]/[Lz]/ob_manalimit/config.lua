Config = {}

Config.Enabled = true
Config.ClassMetadataKey = 'classe'
Config.MetadataKey = 'excesso_arcano'
Config.RecoveryCooldownMetadataKey = 'excesso_arcano_recuperacao'
Config.Max = 100.0

Config.Classes = {
    bruxa = {
        label = 'Bruxa',
        growthMultiplier = 1.0,
        recovery = {
            label = 'Silenciando a magia...',
            durationMs = 90000,
            cooldownMinutes = 30,
            reduction = { min = 14, max = 20 },
            scenario = 'WORLD_HUMAN_YOGA',
        },
        messages = {
            failure = 'A magia se desfez antes de ganhar forma.',
            backlash = 'O feitico voltou contra voce.',
            catastrophe = 'A sobrecarga rompeu o controle e explodiu em suas maos.',
        },
    },
    curandeira = {
        label = 'Curandeira',
        growthMultiplier = 0.92,
        recovery = {
            label = 'Aterrando a energia vital...',
            durationMs = 90000,
            cooldownMinutes = 30,
            reduction = { min = 14, max = 20 },
            scenario = 'WORLD_HUMAN_YOGA',
        },
        messages = {
            failure = 'A energia vital recusou a canalizacao.',
            backlash = 'O fluxo vital retornou pelo seu corpo.',
            catastrophe = 'A energia acumulada entrou em colapso dentro de voce.',
        },
    },
    vampiro = {
        label = 'Vampiro',
        growthMultiplier = 0.82,
        recovery = {
            label = 'Estabilizando a essencia com sangue de puma...',
            durationMs = 60000,
            cooldownMinutes = 25,
            reduction = { min = 12, max = 18 },
            item = 'sangue_puma',
            itemCount = 1,
            anim = {
                dict = 'mp_player_intdrink',
                clip = 'loop_bottle',
                flag = 49,
            },
        },
        messages = {
            failure = 'Sua propria fome interrompeu a habilidade.',
            backlash = 'O sangue rebelou-se contra o seu corpo.',
            catastrophe = 'Sua essencia perdeu o controle e comecou a consumir voce.',
        },
    },
}


Config.Growth = {
    freePressure = 34.0,
    pressureDecayPerSecond = 0.22,
    maximumPressure = 180.0,
    gainPerSpentPoint = 0.26,
    highPressure = 90.0,
    highPressureMultiplier = 1.25,
    criticalPressure = 135.0,
    criticalPressureMultiplier = 1.55,
}

Config.PassiveRecovery = {
    enabled = true,
    intervalMs = 60000,
    maximumLevel = 49.99,
    amountPerMinute = 0.08,
}

Config.Consequences = {
    minimumCostToRoll = 5,
    rollCooldownMs = 3000,
    blockedCostRatio = {
        failure = 0.35,
        backlash = 0.75,
        catastrophe = 1.0,
    },
    tiers = {
        { minimum = 95, id = 'rupture', label = 'Ruptura', failure = 14.0, backlash = 6.0, catastrophe = 1.5 },
        { minimum = 85, id = 'critical', label = 'Critico', failure = 10.0, backlash = 3.0, catastrophe = 0.4 },
        { minimum = 70, id = 'unstable', label = 'Instavel', failure = 6.0, backlash = 1.2, catastrophe = 0.1 },
        { minimum = 50, id = 'strained', label = 'Sob tensao', failure = 2.5, backlash = 0.3, catastrophe = 0.0 },
        { minimum = 0, id = 'stable', label = 'Estavel', failure = 0.0, backlash = 0.0, catastrophe = 0.0 },
    },
    damage = {
        bruxa = { backlash = 12, catastrophe = 42 },
        curandeira = { backlash = 10, catastrophe = 36 },
        vampiro = { backlash = 12, catastrophe = 42 },
    },
    vampireCatastropheExtraDrain = 18,
}

Config.Commands = {
    status = 'excesso',
    recover = 'conterexcesso',
    set = 'setexcesso',
    add = 'addexcesso',
    adminPermission = 'group.admin',
}

Config.Debug = false
