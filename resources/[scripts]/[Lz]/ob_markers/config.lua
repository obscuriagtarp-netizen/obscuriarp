Config = {}

Config.BlipCategories = {
    [1] = { label = 'Empregos', enabled = true, prefix = true },
    [2] = { label = 'Serviços', enabled = true, prefix = true },
    [3] = { label = 'Lojas', enabled = true, prefix = true },
    [4] = { label = 'Locais', enabled = true, prefix = true },
    [5] = { label = 'Restaurantes', enabled = true, prefix = true }
}

Config.Blips = {
    { category = 5, name = 'Mirror Park', coords = vec3(1222.39, -417.43, 66.78), sprite = 93, color = 27, scale = 0.75, shortRange = true },
    { category = 5, name = 'MooMoo Cafe', coords = vec3(-581.28, -1067.74, 21.33), sprite = 93, color = 27, scale = 0.75, shortRange = true },
    { category = 5, name = 'Club 77', coords = vec3(190.94, -3166.99, 4.79), sprite = 93, color = 27, scale = 0.75, shortRange = true },
    { category = 5, name = 'Bahama Mamas', coords = vec3(-1390.76, -602.22, 29.21), sprite = 93, color = 27, scale = 0.75, shortRange = true },
    { category = 5, name = 'Vanilla', coords = vec3(129.46, -1296.64, 31.73), sprite = 93, color = 27, scale = 0.75, shortRange = true },
    { category = 5, name = 'Chinese Seoul', coords = vec3(-654.97, -885.34, 23.66), sprite = 93, color = 27, scale = 0.75, shortRange = true },
    -- { category = 2, name = 'Automotiva Akuma', coords = vec3(-341.62, -136.24, 43.63), sprite = 446, color = 5, scale = 0.75, shortRange = true },
    { category = 2, name = 'Instituto Médico de Obscuria', coords = vec3(-1025.07, -415.06, 41.86), sprite = 61, color = 1, scale = 0.75, shortRange = true },
}

Config.MarkerDefaults = {
    drawDistance = 10.0,
    height = 1.0,
    size = 0.92
}

Config.Markers = {
    -- { image = 'garagem', coords = vec3(215.12, -810.32, 30.73) },
    -- { image = 'banco', coords = vec3(149.84, -1040.71, 29.37), height = 1.2, size = 0.85 },
    -- { image = 'loja', coords = vec3(25.74, -1347.28, 29.50), drawDistance = 8.0 },
}
