Config = {}

Config.Debug = false

Config.StaffPermissions = { 'admin', 'god' }
Config.StaffAce = nil

Config.SeedDefaultStock = 0

Config.OpenDistance = 2.0

Config.RequireGarageVehicle = true
Config.VehicleGarage = 'pillboxgarage'

Config.TestDrive = {
    enabled = true,

    currency = 'money',

    price = 500,

    seconds = 45,

    bucketBase = 9000,
    spawn = vec4(-59.93, -1073.61, 27.2, 68.0)
}

Config.VehiclePeriods = {
    daily = { label = 'Diario', short = '24h', days = 1 },
    weekly = { label = 'Semanal', short = '7 dias', days = 7 },
    monthly = { label = 'Mensal', short = '30 dias', days = 30 },
    permanent = { label = 'Permanente', short = 'Permanente', days = 0 }
}

Config.DefaultVehiclePeriod = 'permanent'

Config.Taxes = {
    normal = { label = 'Taxa de emplacamento', percent = 0.08 },
    vip = { label = 'Taxa premium', percent = 0.03 }
}

Config.VipDiscount = {
    enabled = true,
    resource = 'ob_vip'
}

Config.FallbackImage = './assets/images/ss.png'

Config.Dealerships = {
    normal = {
        label = 'Concessionaria Central',
        subtitle = 'Catalogo publico',
        currency = 'money',
        coords = vec3(-56.39, -1096.52, 26.43),
        blip = { enabled = true, sprite = 225, color = 27, scale = 0.72, name = 'Concessionaria' },
        categories = {
            { id = 'carro', label = 'Carros', icon = 'car' },
            { id = 'moto', label = 'Motos', icon = 'bike' },
            { id = 'suv', label = 'SUVs', icon = 'suv' },
            { id = 'esportivo', label = 'Esportivos', icon = 'sport' },
            { id = 'classico', label = 'Classicos', icon = 'classic' },
            { id = 'outros', label = 'Outros', icon = 'grid' }
        }
    },

    vip = {
        label = 'Concessionaria VIP',
        subtitle = 'Veiculos premium por Cripto Qbox',
        currency = 'crypto',
        coords = vec3(-68.77, -1112.31, 26.44),
        blip = { enabled = true, sprite = 596, color = 27, scale = 0.72, name = 'Concessionaria VIP' },
        categories = {
            { id = 'carro', label = 'Carros', icon = 'car' },
            { id = 'moto', label = 'Motos', icon = 'bike' },
            { id = 'helicoptero', label = 'Helicopteros', icon = 'heli' }
        }
    }
}

Config.SeedVehicles = {}

return Config
