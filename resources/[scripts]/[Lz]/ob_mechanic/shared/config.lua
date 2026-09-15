MechanicConfig = {}

MechanicConfig.Debug = false

MechanicConfig.Keys = {
    open = 38
}

MechanicConfig.RequireDuty = true

MechanicConfig.Jobs = {
    mechanic = {
        'mechanic'
    }
}

MechanicConfig.Items = {
    repairKit = 'repairkit',
    tire = 'tirerepairkit'
}

MechanicConfig.Locations = {
    {
        id = 'central',
        label = 'Automotiva Akuma',
        radius = 3.0,
        points = {
            { coords = vec3(-336.36, -138.79, 39.06) },
            { coords = vec3(-332.92, -129.89, 39.06) },
            { coords = vec3(-329.99, -121.92, 39.06) },
            { coords = vec3(-327.19, -114.52, 39.06) },
            { coords = vec3(-347.66, -122.56, 39.06) },
            { coords = vec3(-345.14, -114.51, 39.06) },
        },
        jobs = { 'mechanic' },
        marker = {
            enabled = true,
            type = 36,
            color = { r = 142, g = 92, b = 255, a = 120 },
            scale = vec3(0.75, 0.75, 0.75),
            bob = true,
            rotate = true
        },
        blip = {
            enabled = true,
            sprite = 446,
            color = 27,
            scale = 0.72,
            name = 'Automotiva Akuma'
        }
    }
}

MechanicConfig.Shop = {
    requireVehicle = true,
    requireDriver = true,
    usePayment = true,
    saveVehicle = true,
    savePendingModifications = true,
    paymentAccounts = { 'cash', 'bank' },
    maxCheckout = 1000000,
    checkoutCooldownMs = 1500,
    sessionDurationMs = 1800000,
    societyBank = {
        provider = 'renewed',
        resource = 'Renewed-Banking',
        account = 'mechanic'
    },
    defaultPrice = 1000,
    repairPrice = 2500,
    prices = {
        performance = 18000,
        body = 7500,
        wheels = 5500,
        colors = 3500,
        lights = 4500,
        extras = 3000
    },
    levelPricing = {
        step = 0.5,
        options = {
            engine = true,
            brakes = true,
            transmission = true,
            suspension = true,
            armor = true
        }
    },
    billableOptions = {
        performance = { 'engine', 'brakes', 'transmission', 'suspension', 'armor', 'turbo' },
        body = {
            'spoiler', 'front_bumper', 'rear_bumper', 'skirts', 'exhaust', 'frame',
            'grille', 'hood', 'fender', 'right_fender', 'roof'
        },
        wheels = {
            'wheel_type', 'front_wheels', 'back_wheels', 'custom_tires',
            'bulletproof_tires', 'tire_smoke', 'tire_smoke_color'
        },
        colors = { 'paint_color', 'pearlescent', 'wheel_color' },
        lights = {
            'xenon', 'xenon_color', 'neon_left', 'neon_right', 'neon_front',
            'neon_back', 'neon_color'
        },
        extras = {
            'plate', 'window_tint', 'livery', 'extra_1', 'extra_2', 'extra_3',
            'extra_4', 'extra_5', 'extra_6', 'extra_7', 'extra_8'
        }
    }
}

MechanicConfig.UI = {
    brand = 'Obscuria',
    eyebrow = 'Oficina autorizada',
    categoryImages = {
        performance = 'images/categories/performance.png?v=2.1.0',
        body = 'images/categories/bodywork.png?v=2.1.0',
        wheels = 'images/categories/wheels.png?v=2.1.0',
        colors = 'images/categories/colors.png?v=2.1.0',
        lights = 'images/categories/lights.png?v=2.1.0',
        extras = 'images/categories/extras.png?v=2.1.0'
    },
    optionImages = {}
}

MechanicConfig.Repair = {
    distance = 4.0,
    duration = 8500,
    mechanicFree = true,
    fixEngine = true,
    fixBody = true,
    fixTank = true,
    fixDeformation = true,
    animation = {
        dict = 'mini@repair',
        anim = 'fixing_a_ped',
        flag = 1
    }
}

MechanicConfig.Tire = {
    distance = 2.1,
    duration = 5500,
    mechanicFree = true,
    animation = {
        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        anim = 'machinic_loop_mechandplayer',
        flag = 1
    }
}

MechanicConfig.Messages = {
    noPermission = 'Você não está autorizado a usar esta oficina.',
    offDuty = 'Entre em serviço antes de acessar a oficina.',
    needVehicle = 'Entre no veículo para iniciar a personalização.',
    driverOnly = 'Assuma o banco do motorista para personalizar este veículo.',
    npcVehicle = 'Este veículo é de NPC. Você pode repará-lo, mas não pode tuná-lo.',
    noVehicleNearby = 'Nenhum veículo próximo.',
    repairCancelled = 'Reparo cancelado.',
    repairDone = 'Veículo reparado.',
    tireDone = 'Pneu reparado.',
    noBurstTire = 'Nenhum pneu estourado próximo.',
    normalTire = 'Este pneu não precisa de reparo.',
    itemConsumed = 'Item utilizado.',
    mechanicFree = 'Serviço realizado sem consumir o item da oficina.',
    checkoutDone = 'Alterações aplicadas e registradas no veículo.',
    notEnoughMoney = 'Saldo insuficiente para concluir o serviço.',
    invalidCheckout = 'Não foi possível validar esse orçamento.',
    savePendingQuestion = 'Saldo insuficiente. Deseja salvar esta configuração?',
    resumePendingQuestion = 'Existe uma configuração pendente para este veículo. Deseja retomá-la?',
    pendingSaved = 'Configuração salva. Retorne com este veículo para continuar.',
    pendingSaveFailed = 'Não foi possível salvar esta configuração.',
    pendingLoaded = 'Configuração retomada.',
    pendingDiscarded = 'Configuração pendente descartada.',
    restored = 'Alterações restauradas.'
}
