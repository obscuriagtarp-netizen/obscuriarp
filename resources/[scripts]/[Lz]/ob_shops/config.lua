Config = {}

Config.Debug = false
Config.ClassMetadataKey = 'classe'
Config.OpenControl = 38 -- E
Config.AccessRefreshMs = 15000
Config.ServerDistance = 6.0

Config.Marker = {
    resource = 'ob_markers',
    image = 'loja',
    drawDistance = 10.0,
    openDistance = 1.8,
    height = 1.0,
    size = 0.92,

    fallback = {
        type = 2,
        zOffset = 0.2,
        scale = vec3(0.28, 0.28, 0.28),
        color = { r = 164, g = 100, b = 205, a = 175 },
        bob = true,
        rotate = true,
    },
}

Config.Shops = {
    ambulance = {
        enabled = true,
        label = 'Loja Hospital',
        access = {
            jobs = { ambulance = 0 },
            requireDuty = true,
        },
        locations = {
            vec3(-1030.6, -440.97, 38.62),
        },
        inventory = {
			{ name = 'gauze', price = 10 },
			{ name = 'bandage', price = 10 },
			{ name = 'painkillers', price = 10 },
			{ name = 'firstaid', price = 10 },
			{ name = 'medical_kit', price = 10 },
			{ name = 'medical_stretcher', price = 10 },
        },
    },
    mechanic = {
        enabled = true,
        label = 'Loja Mecânico',
        access = {
            jobs = { mechanic = 0 },
            requireDuty = true,
        },
        locations = {
            vec3(-349.35, -140.34, 38.06),
        },
        inventory = {
			{ name = 'repairkit', price = 10 },
			{ name = 'tirerepairkit', price = 10 },
        },
    },
    mechanicFood = {
        enabled = true,
        label = 'Loja de comida',
        -- access = {
        --     jobs = { mechanic = 0 },
        --     requireDuty = true,
        -- },
        locations = {
            vec3(-344.77, -154.75, 38.06),
        },
        inventory = {
			{ name = 'coca_cola', price = 12 },
			{ name = 'agua', price = 8 },
			{ name = 'taco', price = 18 },
			{ name = 'chocolate', price = 10 },
			{ name = 'mochila_pequena', price = 1200 },
        },
    },

    -- gang_example = {
    --     enabled = false,
    --     label = 'Loja da Gang',
    --     access = {
    --         gangs = { ballas = 0 },
    --     },
    --     locations = {
    --         vec3(0.0, 0.0, 0.0),
    --     },
    --     inventory = {
    --         { name = 'bandage', price = 25 },
    --     },
    -- },

    -- class_example = {
    --     enabled = false,
    --     label = 'Loja dos Vampiros',
    --     access = {
    --         classes = { vampiro = true },
    --     },
    --     locations = {
    --         vec3(0.0, 0.0, 0.0),
    --     },
    --     inventory = {
    --         { name = 'water', price = 10 },
    --     },
    -- },
}

