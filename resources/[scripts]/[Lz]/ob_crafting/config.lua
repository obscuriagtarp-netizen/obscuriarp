Config = Config or {}

Config.CraftLocations = {
    weapons_bench = {
        enabled = false,
        operation = 'weapons_basic',
        coords = vec4(0.0, 0.0, 0.0, 0.0),
        spawnBench = true,
        jobs = { gunsmith = 0 }
    },

    narcotics_lab = {
        enabled = false,
        operation = 'narcotics_basic',
        coords = vec4(0.0, 0.0, 0.0, 0.0),
        spawnBench = true
    }
}

Config.RestaurantStages = {
    ravenwoodcafe = {
        enabled = false,
        cutting = vec4(0.0, 0.0, 0.0, 0.0),
        cooking = vec4(0.0, 0.0, 0.0, 0.0),
        assembly = vec4(0.0, 0.0, 0.0, 0.0)
    },

    burgershot = {
        enabled = false,
        cutting = vec4(0.0, 0.0, 0.0, 0.0),
        cooking = vec4(0.0, 0.0, 0.0, 0.0),
        assembly = vec4(0.0, 0.0, 0.0, 0.0)
    }
}
