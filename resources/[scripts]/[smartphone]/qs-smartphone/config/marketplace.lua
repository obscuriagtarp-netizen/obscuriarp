--──────────────────────────────────────────────────────────────────────────────
-- Marketplace · default shops                                                [EDIT]
-- [INFO] `id` is stable marketId for UI, DB threads, and ratings.
--        `job` lists framework job names allowed to toggle duty for this shop.
--──────────────────────────────────────────────────────────────────────────────

Config.Marketplace = {}

---@type table[]
Config.Marketplace.Shops = {
    {
        id = 5001,
        name = 'Mission Row PD',
        description = 'Los Santos Police Department — front desk and citizen services.',
        job = { 'police' },
        coords = vec3(441.7, -981.9, 30.7),
        image = 'https://picsum.photos/seed/market5001/256/256',
    },
    {
        id = 5002,
        name = 'Pillbox Medical',
        description = 'Emergency care, EMS dispatch, and health services.',
        job = { 'ambulance' },
        coords = vec3(304.2, -600.3, 43.3),
        image = 'https://picsum.photos/seed/market5002/256/256',
    },
    {
        id = 5003,
        name = 'Bennys Motorworks',
        description = 'Performance tuning, repairs, and custom work.',
        job = { 'mechanic' },
        coords = vec3(-205.7, -1310.7, 31.3),
        image = 'https://picsum.photos/seed/market5003/256/256',
    },
    {
        id = 5004,
        name = 'Downtown Cab Co.',
        description = 'City-wide taxi service and dispatch.',
        job = { 'taxi' },
        coords = vec3(895.1, -179.1, 74.7),
        image = 'https://picsum.photos/seed/market5004/256/256',
    },
    {
        id = 5005,
        name = 'Burger Shot',
        description = 'Fast food, catering, and franchise support.',
        job = { 'burgershot' },
        coords = vec3(-1192.9, -898.5, 13.9),
        image = 'https://picsum.photos/seed/market5005/256/256',
    },
    {
        id = 5006,
        name = 'Real Estate Partners',
        description = 'Property listings, viewings, and brokerage.',
        job = { 'realestate' },
        coords = vec3(-706.1, 268.6, 83.1),
        image = 'https://picsum.photos/seed/market5006/256/256',
    },
}
