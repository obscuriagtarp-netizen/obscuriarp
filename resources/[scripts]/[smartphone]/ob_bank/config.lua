Config = Config or {}

Config.Debug = false

Config.App = {
    id = 'ob_bank',
    label = 'Obscuria Bank',
    category = 'Productivity & Finance',
    creator = 'Obscuria',
    description = 'Saldo, Pix, extrato, favoritos e cartão de crédito Obscuria.',
    age = '12+',
    appStoreOnly = false,
    sizeMb = 12,
    version = '1.0.0',
}

Config.Transfer = {
    minimum = 1,
    maximum = 1000000,
    cooldownMs = 1500,
    descriptionMaxLength = 80,
    unresolvedTimeoutSeconds = 120,
}

Config.HistoryLimit = 60
Config.RecentLimit = 8
Config.FavoritesLimit = 20

Config.Credit = {
    enabled = true,
    cycleDays = 7,
    blockAfterOverdueDays = 10,
    dailyInterestPercent = 1.0,
    maximumCharge = 1000000,
    scoreRefreshMinutes = 30,
    movementWindowDays = 30,
    historyLimit = 30,
    defaultScore = 350,
    minimumScore = 200,
    score = {
        balanceSteps = {
            { amount = 100000, points = 320 },
            { amount = 50000, points = 260 },
            { amount = 20000, points = 180 },
            { amount = 5000, points = 100 },
            { amount = 1000, points = 50 },
        },
        movementCountPoints = 5,
        movementCountCap = 100,
        movementVolumeDivisor = 2000,
        movementVolumeCap = 150,
        paidInvoicePoints = 25,
        paidInvoiceCap = 100,
        overdueInvoicePenalty = 150,
        overdueDayPenalty = 15,
        overduePenaltyCap = 400,
    },
    limits = {
        { score = 900, amount = 60000 },
        { score = 750, amount = 35000 },
        { score = 600, amount = 20000 },
        { score = 450, amount = 10000 },
        { score = 300, amount = 5000 },
        { score = 200, amount = 2000 },
    },
    automaticFallback = {
        enabled = true,
        accounts = { cash = true, bank = true },
    },
}
