Config = {}

Config.Debug = false

-- Comandos: /setvip [id ou citizenid] [vip] [dias]
--           /removevip [id ou citizenid] [vip ou id da concessao]
--           /listvips [id ou citizenid]
Config.Commands = {
    enabled = true,
    permission = 'group.admin',
}

Config.Salary = {
    checkIntervalSeconds = 30,
    maxPaymentsPerCycle = 250,
    onlineOnly = true,
    payImmediately = false,
    notify = true,
}

Config.Inventory = {
    enabled = true,
    retryCount = 10,
    retryDelayMs = 500,
}

Config.VehicleGarage = 'pillboxgarage'
Config.VehicleImageDirectory = 'web/imgs/vipstore'

-- Mochilas sao consumiveis independentes de VIP. O bonus permanece ate a morte.
-- bonusWeight e informado em gramas: 10000 = 10 kg.
Config.Backpacks = {
    mochila_pequena = { label = 'Mochila Pequena', bonusWeight = 10000 },
    mochila_media = { label = 'Mochila Média', bonusWeight = 20000 },
    mochila_grande = { label = 'Mochila Grande', bonusWeight = 30000 },
}

-- Salarios sempre acumulam por concessao ativa. Os descontos usam o maior
-- percentual e nao somam entre planos simultaneos.
Config.Stacking = {
    vehicleDiscount = 'highest',
    fuelDiscount = 'highest',
    medicalDiscount = 'highest',
    inventoryWeight = 'highest',
}

-- A imagem de cada carro e carregada automaticamente como
-- web/imgs/vipstore/<spawn>.png.
Config.Vips = {
    veu = {
        label = 'VIP VÉU',
        priority = 10,
        initialMoney = { amount = 50000, account = 'bank' },
        salary = { amount = 2000, everyMinutes = 60, account = 'bank' },
        vehicleDiscount = 5,
        fuelDiscount = 0,
        medicalDiscount = 0,
        inventoryWeight = 10000,
        vehicles = {
            count = 1,
            catalog = {
                { model = '16charger', label = 'Lodge Charger' },
                { model = '2f2fgtr34', label = 'R34' },
                { model = '18performante', label = 'Huracan Performante' },
                { model = '19gv80', label = 'Tundra PRO' },
            },
        },
        nameChanges = 0,
        discordRoleId = '1547991547616952440',
    },

    eclipse = {
        label = 'VIP ECLIPSE',
        priority = 20,
        initialMoney = { amount = 120000, account = 'bank' },
        salary = { amount = 4000, everyMinutes = 60, account = 'bank' },
        vehicleDiscount = 10,
        fuelDiscount = 10,
        medicalDiscount = 10,
        inventoryWeight = 20000,
        vehicles = {
            count = 2,
            catalog = {
                { model = '16charger', label = 'Lodge Charger' },
                { model = '2f2fgtr34', label = 'R34' },
                { model = '18performante', label = 'Huracan Performante' },
                { model = '19gv80', label = 'Tundra PRO' },
                { model = '20xb7', label = 'X7 SPORT' },
                { model = '18Velar', label = 'Velar' },
                { model = '21rsq8', label = 'RS Q8' },
            },
        },
        nameChanges = 1,
        discordRoleId = '1547991741360111759',
    },

    arcano = {
        label = 'VIP ARCANO',
        priority = 30,
        initialMoney = { amount = 250000, account = 'bank' },
        salary = { amount = 7500, everyMinutes = 60, account = 'bank' },
        vehicleDiscount = 15,
        fuelDiscount = 15,
        medicalDiscount = 15,
        inventoryWeight = 30000,
        vehicles = {
            count = 3,
            catalog = {
                { model = '16charger', label = 'Lodge Charger' },
                { model = '2f2fgtr34', label = 'R34' },
                { model = '18performante', label = 'Huracan Performante' },
                { model = '19gv80', label = 'Tundra PRO' },
                { model = '20xb7', label = 'X7 SPORT' },
                { model = '18Velar', label = 'Velar' },
                { model = '21rsq8', label = 'RS Q8' },
                { model = '17mansorypnmr', label = 'Panamera Mansory' },
                { model = '2ncsbmwm8', label = 'M8 Kit' },
                { model = '2ncsx7', label = 'Cherooke' },
            },
        },
        nameChanges = 2,
        discordRoleId = '1547991774289727649',
    },
}
