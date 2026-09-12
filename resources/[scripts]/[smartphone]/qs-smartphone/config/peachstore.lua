---@class PeachStoreProduct
---@field id string
---@field title string
---@field subtitle string
---@field price integer
---@field item string
---@field image? string
---@field metadata? table

Config.PeachStore = {
    paymentAccounts = { 'money', 'bank' },

    products = {
        {
            id = 'powerbank',
            title = 'Peach Power',
            subtitle = 'High‑density cells. All‑day peace of mind.',
            price = 250,
            item = Config.Battery.powerbank.itemName,
            image = 'https://i.ibb.co/n8sctc1m/powerbank.png',
        },
        {
            id = 'wireless_earbuds',
            title = 'Peach Buds',
            subtitle = 'Spatial audio. Feather‑light fit.',
            price = 450,
            item = Config.Earbuds.itemName,
            image = 'https://i.ibb.co/TqcFr9ny/wireless-earbuds.png',
        },
        {
            id = 'sim_card',
            title = 'Peach SIM',
            subtitle = 'New number. Swap anytime in Settings.',
            price = 180,
            item = Config.SimCard.itemName,
            image = 'https://i.ibb.co/kV6b3Gjy/phone-sim.png',
        },
        {
            id = 'storage_64gb',
            title = 'Peach Cloud 64GB',
            subtitle = 'Instant storage upgrade for your phone.',
            price = 1200,
            storageUpgradeMb = 65536,
            image = 'https://i.ibb.co/5WHZgpBz/storage.png',
        },
        {
            id = 'storage_128gb',
            title = 'Peach Cloud 128GB',
            subtitle = 'Double your breathing room for apps and media.',
            price = 2200,
            storageUpgradeMb = 131072,
            image = 'https://i.ibb.co/5WHZgpBz/storage.png',
        },
    },
}
