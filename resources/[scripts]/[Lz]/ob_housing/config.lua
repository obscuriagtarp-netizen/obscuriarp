Config = {}

Config.Debug = false

-- A resource não declara dependencies no fxmanifest. Mantenha a ordem de ensure:
-- oxmysql, ox_lib, qbx_core, ox_inventory, ox_target (opcional), bob74_ipl, ob_housing.
Config.Resources = {
    framework = 'qbx_core',
    inventory = 'ox_inventory',
    target = 'ox_target',
    appearance = 'illenium-appearance',
    ipl = 'bob74_ipl'
}

Config.AdminPermissions = {
    'group.admin',
    'admin'
}

Config.Interaction = {
    distance = 1.8,
    targetDistance = 2.2,
    serverValidationDistance = 5.0,
    markerDistance = 18.0,
    useTargetWhenAvailable = true
}

Config.Visitors = {
    enabled = true,
    requestTimeoutSeconds = 30,
    inviteTimeoutSeconds = 15,
    cooldownSeconds = 20,
    maxResidentsListed = 40
}

Config.InteriorPreview = {
    enabled = true,
    maxSeconds = 300
}

Config.CatalogOffice = {
    enabled = true,
    coords = vec3(-716.55, 261.22, 84.14),
    radius = 1.25,
    blip = {
        enabled = true,
        sprite = 374,
        color = 27,
        scale = 0.72,
        label = 'Imobiliária Obscuria'
    }
}

Config.Purchase = {
    enabled = true,
    defaultAccount = 'bank',
    maxHousesPerCitizen = 3,
    actionCooldownMs = 900
}

Config.Access = {
    expiryCheckSeconds = 60
}

Config.Images = {
    maxPerProperty = 8,
    maxLength = 500,
    fallback = 'images/olho-branco.png'
}

Config.Routing = {
    propertyBucketBase = 20000,
    previewBucketBase = 700000
}

Config.StarterApartment = {
    enabled = true,
    autoGrant = true,
    propertyKey = 'apartamento_inicial',
    label = 'Apartamento Inicial',
    description = 'Um espaço compacto para começar sua história em Obscuria.',
    entrance = vec4(-935.45, -378.63, 37.96, 290.29),
    interior = 'bob_studio',
    stashSlots = 20,
    stashWeight = 30000
}

-- Os pontos podem ser substituídos no painel administrativo usando a posição atual.
-- O Bob74 é chamado apenas quando estiver iniciado, portanto ob_housing inicia sozinho.
Config.Interiors = {
    bob_studio = {
        label = 'Estúdio compacto',
        provider = 'bob74_ipl',
        exportName = 'GetGTAOHouseLow1Object',
        entry = vec4(266.11, -1007.43, -101.01, 357.0),
        exit = vec4(266.11, -1007.43, -101.01, 357.0),
        stash = vec3(265.92, -999.38, -99.01),
        wardrobe = vec3(259.82, -1003.95, -99.01)
    },
    bob_house_mid = {
        label = 'Casa urbana',
        provider = 'bob74_ipl',
        exportName = 'GetGTAOHouseMid1Object',
        entry = vec4(346.52, -1012.96, -99.20, 1.0),
        exit = vec4(346.52, -1012.96, -99.20, 1.0),
        stash = vec3(351.86, -998.73, -99.20),
        wardrobe = vec3(350.70, -993.60, -99.20)
    },
    bob_apartment_high = {
        label = 'Apartamento de luxo - Integrity Way',
        provider = 'bob74_ipl',
        exportName = 'GetGTAOApartmentHi1Object',
        entry = vec4(-35.31, -580.42, 88.71, 70.0),
        exit = vec4(-35.31, -580.42, 88.71, 70.0),
        stash = vec3(-38.72, -583.78, 88.71),
        wardrobe = vec3(-37.52, -571.62, 88.71)
    },
    bob_apartment_del_perro = {
        label = 'Apartamento de luxo - Del Perro',
        provider = 'bob74_ipl',
        exportName = 'GetGTAOApartmentHi2Object',
        entry = vec4(-1477.14, -538.75, 55.53, 215.0),
        exit = vec4(-1477.14, -538.75, 55.53, 215.0),
        stash = vec3(-1468.74, -537.22, 50.73),
        wardrobe = vec3(-1467.49, -529.57, 50.72)
    },
    bob_mansion_wild_oats = {
        label = 'Mansão - Wild Oats Drive',
        provider = 'bob74_ipl',
        exportName = 'GetGTAOHouseHi1Object',
        entry = vec4(-174.08, 497.15, 137.67, 192.0),
        exit = vec4(-174.08, 497.15, 137.67, 192.0),
        stash = vec3(-170.56, 482.26, 137.24),
        wardrobe = vec3(-167.44, 487.76, 133.84)
    },
    bob_mansion_conker_2044 = {
        label = 'Mansão - North Conker 2044',
        provider = 'bob74_ipl',
        exportName = 'GetGTAOHouseHi2Object',
        entry = vec4(341.84, 437.70, 149.39, 118.0),
        exit = vec4(341.84, 437.70, 149.39, 118.0),
        stash = vec3(334.10, 428.50, 145.57),
        wardrobe = vec3(334.35, 436.92, 145.57)
    },
    bob_mansion_conker_2045 = {
        label = 'Mansão - North Conker 2045',
        provider = 'bob74_ipl',
        exportName = 'GetGTAOHouseHi3Object',
        entry = vec4(373.68, 423.83, 145.91, 167.0),
        exit = vec4(373.68, 423.83, 145.91, 167.0),
        stash = vec3(377.20, 407.55, 145.50),
        wardrobe = vec3(374.20, 411.62, 142.10)
    },
    bob_mansion_hillcrest_2862 = {
        label = 'Mansão - Hillcrest 2862',
        provider = 'bob74_ipl',
        exportName = 'GetGTAOHouseHi4Object',
        entry = vec4(-682.45, 592.03, 145.39, 218.0),
        exit = vec4(-682.45, 592.03, 145.39, 218.0),
        stash = vec3(-671.80, 580.63, 145.17),
        wardrobe = vec3(-671.55, 587.80, 141.57)
    },
    bob_mansion_hillcrest_2868 = {
        label = 'Mansão - Hillcrest 2868',
        provider = 'bob74_ipl',
        exportName = 'GetGTAOHouseHi5Object',
        entry = vec4(-758.81, 619.08, 144.15, 111.0),
        exit = vec4(-758.81, 619.08, 144.15, 111.0),
        stash = vec3(-767.90, 610.85, 144.14),
        wardrobe = vec3(-764.55, 618.97, 140.14)
    },
    bob_mansion_hillcrest_2874 = {
        label = 'Mansão - Hillcrest 2874',
        provider = 'bob74_ipl',
        exportName = 'GetGTAOHouseHi6Object',
        entry = vec4(-859.89, 690.72, 152.86, 193.0),
        exit = vec4(-859.89, 690.72, 152.86, 193.0),
        stash = vec3(-855.42, 674.96, 152.65),
        wardrobe = vec3(-852.73, 680.19, 148.65)
    },
    bob_mansion_whispymound = {
        label = 'Mansão - Whispymound Drive',
        provider = 'bob74_ipl',
        exportName = 'GetGTAOHouseHi7Object',
        entry = vec4(117.26, 559.79, 184.30, 187.0),
        exit = vec4(117.26, 559.79, 184.30, 187.0),
        stash = vec3(123.18, 544.38, 183.90),
        wardrobe = vec3(121.14, 548.75, 180.50)
    },
    bob_mansion_mad_wayne = {
        label = 'Mansão - Mad Wayne Thunder',
        provider = 'bob74_ipl',
        exportName = 'GetGTAOHouseHi8Object',
        entry = vec4(-1289.78, 449.45, 97.90, 180.0),
        exit = vec4(-1289.78, 449.45, 97.90, 180.0),
        stash = vec3(-1286.86, 433.37, 97.69),
        wardrobe = vec3(-1284.22, 438.18, 94.09)
    }
}
