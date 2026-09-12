Config = {}

Config.Debug = false
Config.EnableDelete = true
Config.LoadingModelTimeout = 30000

Config.InitialTutorial = {
    enabled = true,
    resource = 'ob_initial',
}

local function IsLeapYear(year)
    return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

local function DateYearsAgo(years)
    local today

    if type(GetLocalTime) == 'function' then
        local year, month, day = GetLocalTime()
        today = { year = year, month = month, day = day }
    elseif type(os) == 'table' and type(os.date) == 'function' then
        today = os.date('*t')
    else
        today = { year = 2026, month = 1, day = 1 }
    end

    local year = today.year - years
    local day = today.day

    if today.month == 2 and day == 29 and not IsLeapYear(year) then
        day = 28
    end

    return ('%04d-%02d-%02d'):format(year, today.month, day)
end

Config.Character = {
    minAge = 18,
    maxAge = 120,
    dateMin = DateYearsAgo(120),
    dateMax = DateYearsAgo(18),
    defaultNationality = 'Brasileira',
    nationalities = {
        'Brasileira',
        'Argentina',
        'Chilena',
        'Colombiana',
        'Mexicana',
        'Norte-americana',
        'Canadense',
        'Portuguesa',
        'Espanhola',
        'Francesa',
        'Italiana',
        'Alemã',
        'Britânica',
        'Irlandesa',
        'Angolana',
        'Moçambicana',
        'Japonesa',
        'Chinesa',
        'Sul-coreana',
        'Russa',
        'Ucraniana',
    },
    minNameLength = 2,
    maxNameLength = 24,
}

Config.Spawn = {
    useQbxSpawn = true,
    default = vec4(-540.58, -212.02, 37.65, 208.88),
}

Config.Appearance = {
    coords = vec4(-1054.81, -2766.81, 4.63, 328.82),
}

Config.Scene = {
    locations = {
        {
            ped = vec4(-1023.45, -418.42, 67.66, 205.69),
            camera = vec4(-1021.8, -421.7, 68.14, 27.11),
            fov = 38.0,
        },
        {
            ped = vec4(-1004.5, -478.51, 50.03, 28.19),
            camera = vec4(-1006.36, -476.19, 50.50, 210.38),
            fov = 38.0,
        },
        {
            ped = vec4(969.25, 72.61, 116.18, 276.55),
            camera = vec4(972.2, 72.9, 116.68, 97.27),
            fov = 40.0,
        },
    },
}

Config.Classes = {
    bruxa = { label = 'Bruxa', icon = 'assets/classes/bruxa.png', accent = '#9f79d7' },
    vampiro = { label = 'Vampiro', icon = 'assets/classes/vampiro.png', accent = '#b85d68' },
    curandeira = { label = 'Curandeira', icon = 'assets/classes/curandeira.png', accent = '#78b891' },
    humano = { label = 'Humano', icon = 'assets/classes/humano.png', accent = '#c4a56e' },
    indefinida = { label = 'Não definida', icon = 'assets/classes/indefinida.png', accent = '#9d96a7' },
}
