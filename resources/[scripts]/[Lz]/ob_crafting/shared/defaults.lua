Config = Config or {}

Config.Debug = false
Config.InteractionDistance = 2.0
Config.ServerDistance = 4.5
Config.MinimumDuration = 3
Config.MaximumDuration = 120
Config.MinimumStepDuration = 2
Config.MaxCraftQuantity = 20
Config.QuantityTimeIncreasePercent = 0.12
Config.StageMoveTimeout = 15000
Config.StageArrivalDistance = 0.8
Config.PreviewCommand = 'craftteste'
Config.AdminAce = 'ob.crafting.admin'
Config.AdminPermissions = { 'admin', 'god' }
Config.ClassMetadataKey = 'classe'

Config.Kinds = {
    kitchen = {
        label = 'Cozinha',
        eyebrow = 'Mise en place',
        description = 'Prepare cada receita com calma e organizacao.',
        accent = '#d49a62'
    },
    weapons = {
        label = 'Armeiro',
        eyebrow = 'Bancada técnica',
        description = 'Monte componentes e calibre o mecanismo com precisão.',
        accent = '#9ca8b8'
    },
    narcotics = {
        label = 'Laboratório',
        eyebrow = 'Síntese controlada',
        description = 'Dose reagentes e estabilize a mistura sem desperdício.',
        accent = '#7fc0a0'
    },
    utility = {
        label = 'Oficina',
        eyebrow = 'Produção especializada',
        description = 'Combine materiais e conclua o processo de montagem.',
        accent = '#a985d6'
    }
}

Config.ImmersiveScenes = {
    weapons = {
        enabled = true,
        propHeightOffset = -0.12,
        alignPlayer = true,
        playerOffset = vec3(0.0, -0.92, 0.0),
        playerHeadingOffset = 0.0,
        camera = {
            offset = vec3(1.48, -1.62, 1.24),
            focus = vec3(0.0, 0.08, 0.78),
            fov = 43.0
        },
        bench = {
            models = { 'gr_prop_gr_bench_03b', 'prop_tool_bench02_ld' },
            offset = vec3(0.0, 0.0, 0.0),
            rotation = vec3(0.0, 0.0, 0.0)
        },
        decorations = {
            { models = { 'prop_tool_box_04', 'prop_tool_box_03' }, offset = vec3(-0.48, 0.10, 0.84), rotation = vec3(0.0, 0.0, -12.0) },
            { models = { 'prop_tool_drill', 'prop_tool_screwdvr01' }, offset = vec3(0.48, 0.15, 0.86), rotation = vec3(0.0, 82.0, 18.0) },
            { models = { 'prop_box_ammo03a', 'prop_box_ammo04a' }, offset = vec3(-0.35, 0.34, 0.88), rotation = vec3(0.0, 0.0, 8.0) }
        },
        result = {
            offset = vec3(0.08, 0.02, 0.91),
            rotation = vec3(88.0, 0.0, 92.0)
        },
        stepProps = {
            assemble = { models = { 'prop_tool_screwdvr02', 'prop_tool_screwdvr01' }, offset = vec3(0.36, -0.10, 0.89), rotation = vec3(0.0, 86.0, 24.0) },
            calibrate = { models = { 'prop_tool_caligrip', 'prop_tool_screwdvr03' }, offset = vec3(0.34, -0.08, 0.89), rotation = vec3(0.0, 82.0, -18.0) },
            weld = { models = { 'prop_weld_torch', 'prop_tool_blowtorch' }, offset = vec3(0.38, -0.04, 0.90), rotation = vec3(0.0, 78.0, 12.0) },
            seal = { models = { 'prop_tool_hammer', 'prop_tool_mallet' }, offset = vec3(0.36, -0.06, 0.90), rotation = vec3(0.0, 84.0, 28.0) }
        }
    },
    narcotics = {
        enabled = true,
        propHeightOffset = -0.12,
        alignPlayer = true,
        playerOffset = vec3(0.0, -0.94, 0.0),
        playerHeadingOffset = 0.0,
        camera = {
            offset = vec3(1.44, -1.55, 1.28),
            focus = vec3(0.0, 0.08, 0.77),
            fov = 42.0
        },
        bench = {
            models = { 'bkr_prop_meth_table01a', 'prop_tool_bench02_ld' },
            offset = vec3(0.0, 0.0, 0.0),
            rotation = vec3(0.0, 0.0, 0.0)
        },
        decorations = {
            { models = { 'bkr_prop_meth_acetone', 'prop_cs_spray_can' }, offset = vec3(-0.46, 0.12, 0.86), rotation = vec3(0.0, 0.0, -8.0) },
            { models = { 'bkr_prop_meth_pseudoephedrine', 'prop_cs_script_bottle_01' }, offset = vec3(0.46, 0.18, 0.86), rotation = vec3(0.0, 0.0, 10.0) },
            { models = { 'bkr_prop_meth_scoop_01a', 'prop_cs_bowl_01' }, offset = vec3(-0.30, 0.36, 0.89), rotation = vec3(0.0, 0.0, -15.0) }
        },
        result = {
            offset = vec3(0.10, 0.02, 0.91),
            rotation = vec3(0.0, 0.0, 8.0)
        },
        stepProps = {
            dose = { models = { 'bkr_prop_meth_sacid', 'prop_cs_script_bottle_01' }, offset = vec3(0.30, -0.08, 0.90), rotation = vec3(0.0, 0.0, 8.0) },
            synthesize = { models = { 'bkr_prop_meth_scoop_01a', 'prop_cs_bowl_01' }, offset = vec3(0.30, -0.05, 0.90), rotation = vec3(0.0, 0.0, -10.0) },
            heat = { models = { 'bkr_prop_meth_chiller_01a', 'prop_cs_kettle_01' }, offset = vec3(0.31, -0.03, 0.90), rotation = vec3(0.0, 0.0, 5.0) },
            stabilize = { models = { 'bkr_prop_meth_openbag_01a', 'prop_meth_bag_01' }, offset = vec3(0.31, -0.06, 0.90), rotation = vec3(0.0, 0.0, 7.0) },
            package = { models = { 'bkr_prop_meth_openbag_01a', 'prop_meth_bag_01' }, offset = vec3(0.31, -0.06, 0.90), rotation = vec3(0.0, 0.0, 7.0) }
        }
    },
    utility = {
        enabled = true,
        propHeightOffset = -0.12,
        alignPlayer = true,
        playerOffset = vec3(0.0, -0.92, 0.0),
        playerHeadingOffset = 0.0,
        camera = { offset = vec3(1.45, -1.60, 1.20), focus = vec3(0.0, 0.05, 0.76), fov = 43.0 },
        bench = { models = { 'prop_tool_bench02_ld' }, offset = vec3(0.0, 0.0, 0.0), rotation = vec3(0.0, 0.0, 0.0) },
        decorations = {},
        result = { offset = vec3(0.08, 0.02, 0.91), rotation = vec3(0.0, 0.0, 0.0) },
        stepProps = {}
    }
}

Config.Operations = {
    prep = { label = 'Organizar ingredientes', description = 'Separe os ingredientes na ordem do preparo.', animation = 'assembly', stage = 'cutting' },
    chop = { label = 'Cortar ingredientes', description = 'Fatie cada parte sobre a guia da bancada.', animation = 'cutting', stage = 'cutting' },
    portion = { label = 'Porcionar', description = 'Divida o preparo em porcoes uniformes.', animation = 'assembly', stage = 'cutting' },
    knead = { label = 'Trabalhar a massa', description = 'Pressione e dobre a massa ate atingir elasticidade.', animation = 'assembly', stage = 'cutting' },
    shape = { label = 'Modelar', description = 'Modele cada porcao com pressao uniforme.', animation = 'assembly', stage = 'cutting' },
    grill = { label = 'Grelhar', description = 'Controle a chapa e retire no ponto correto.', animation = 'stove', stage = 'cooking' },
    fry = { label = 'Fritar', description = 'Mantenha o oleo dentro da temperatura ideal.', animation = 'stove', stage = 'cooking' },
    bake = { label = 'Assar', description = 'Controle o calor ate o cozimento ficar uniforme.', animation = 'stove', stage = 'cooking' },
    boil = { label = 'Cozinhar', description = 'Estabilize a temperatura durante o cozimento.', animation = 'stove', stage = 'cooking' },
    melt = { label = 'Derreter', description = 'Aplique calor gradualmente sem queimar o preparo.', animation = 'stove', stage = 'cooking' },
    pour = { label = 'Dosar liquidos', description = 'Sirva exatamente a quantidade indicada.', animation = 'drinks', stage = 'assembly' },
    mix = { label = 'Misturar', description = 'Mexa continuamente ate atingir a textura correta.', animation = 'drinks', stage = 'assembly' },
    whisk = { label = 'Bater', description = 'Incorpore ar com movimentos circulares constantes.', animation = 'drinks', stage = 'assembly' },
    sauce = { label = 'Adicionar molho', description = 'Dose o molho sem ultrapassar a medida da receita.', animation = 'drinks', stage = 'assembly' },
    season = { label = 'Temperar', description = 'Acerte o ponto para distribuir o tempero por igual.', animation = 'assembly', stage = 'assembly' },
    assemble = { label = 'Montar', description = 'Organize os componentes na sequencia indicada.', animation = 'assembly', stage = 'assembly' },
    plate = { label = 'Empratar', description = 'Disponha os componentes do prato na ordem correta.', animation = 'assembly', stage = 'assembly' },
    decorate = { label = 'Decorar', description = 'Finalize a apresentacao no momento de precisao.', animation = 'assembly', stage = 'assembly' },
    chill = { label = 'Resfriar', description = 'Interrompa o resfriamento quando atingir o ponto.', animation = 'assembly', stage = 'assembly' },
    package = { label = 'Embalar', description = 'Dobre, pressione e sele o produto final.', animation = 'assembly', stage = 'assembly' },
    measure = { label = 'Medir componentes', description = 'Separe a quantidade exata indicada na receita.', animation = 'drinks', stage = 'cutting' },
    dose = { label = 'Dosar reagentes', description = 'Adicione a medida exata de cada reagente.', animation = 'narcotics' },
    synthesize = { label = 'Sintetizar', description = 'Misture os compostos sem perder estabilidade.', animation = 'narcotics' },
    heat = { label = 'Aquecer composto', description = 'Controle a temperatura da reacao.', animation = 'narcotics' },
    stabilize = { label = 'Estabilizar', description = 'Confirme os pulsos no momento exato.', animation = 'narcotics' },
    calibrate = { label = 'Calibrar', description = 'Ajuste o mecanismo dentro da tolerancia.', animation = 'weapons' },
    weld = { label = 'Soldar componentes', description = 'Una os componentes sem ultrapassar o calor.', animation = 'weapons' },
    seal = { label = 'Selar montagem', description = 'Confirme o fechamento de cada ponto.', animation = 'weapons' },
    refine = { label = 'Refinar material', description = 'Processe o material ate ficar uniforme.', animation = 'utility' }
}

Config.KitchenProfiles = {
    meal = { 'prep', 'chop', 'grill', 'season', 'plate' },
    fried = { 'prep', 'chop', 'fry', 'season', 'package' },
    pasta = { 'prep', 'measure', 'knead', 'portion', 'boil', 'sauce', 'plate' },
    sweets = { 'prep', 'measure', 'mix', 'shape', 'bake', 'decorate' },
    bakery = { 'prep', 'measure', 'knead', 'shape', 'bake', 'chill' },
    drinks = { 'measure', 'pour', 'mix', 'decorate' },
    cold = { 'prep', 'chop', 'mix', 'plate' },
    combo = { 'prep', 'assemble', 'package' },
    default = { 'prep', 'chop', 'grill', 'assemble' }
}

Config.KitchenCategoryProfiles = {
    meals = 'meal', pratos = 'meal', lanches = 'meal', sandwiches = 'meal',
    fried = 'fried', frituras = 'fried', porcoes = 'fried',
    pasta = 'pasta', massas = 'pasta', macarrao = 'pasta',
    sweets = 'sweets', desserts = 'sweets', sobremesas = 'sweets', doces = 'sweets',
    bakery = 'bakery', padaria = 'bakery', paes = 'bakery',
    drinks = 'drinks', bebidas = 'drinks',
    salads = 'cold', saladas = 'cold', frios = 'cold',
    combos = 'combo', kits = 'combo'
}

Config.Animations = {
    cutting = {
        dict = 'anim@amb@business@coc@coc_unpack_cut_left@',
        clip = 'coke_cut_v5_coccutter',
        fallbackScenario = 'PROP_HUMAN_BBQ',
        prop = { model = 'prop_knife', bone = 57005, pos = vec3(0.12, 0.02, -0.02), rot = vec3(-80.0, 0.0, 0.0) }
    },
    stove = { scenario = 'PROP_HUMAN_BBQ' },
    drinks = { scenario = 'WORLD_HUMAN_STAND_MOBILE' },
    assembly = { scenario = 'PROP_HUMAN_BBQ' },
    weapons = { scenario = 'WORLD_HUMAN_HAMMERING' },
    weapon_assemble = {
        dict = 'mini@repair',
        clip = 'fixing_a_ped',
        fallbackScenario = 'WORLD_HUMAN_HAMMERING',
        prop = { models = { 'prop_tool_screwdvr02', 'prop_tool_screwdvr01' }, bone = 57005, pos = vec3(0.11, 0.02, -0.02), rot = vec3(-92.0, 5.0, 12.0) }
    },
    weapon_calibrate = {
        dict = 'mini@repair',
        clip = 'fixing_a_ped',
        fallbackScenario = 'WORLD_HUMAN_VEHICLE_MECHANIC',
        prop = { models = { 'prop_tool_caligrip', 'prop_tool_screwdvr03' }, bone = 57005, pos = vec3(0.12, 0.02, -0.01), rot = vec3(-88.0, 4.0, 8.0) }
    },
    weapon_weld = { scenario = 'WORLD_HUMAN_WELDING' },
    weapon_finish = { scenario = 'WORLD_HUMAN_HAMMERING' },
    narcotics = { scenario = 'WORLD_HUMAN_STAND_MOBILE' },
    narcotics_dose = {
        dict = 'anim@amb@business@meth@meth_smash_weight_check@',
        clip = 'break_weigh_v3_char01',
        fallbackScenario = 'WORLD_HUMAN_STAND_MOBILE'
    },
    narcotics_mix = {
        dict = 'anim@amb@business@meth@meth_smash_weight_check@',
        clip = 'break_weigh_v3_char01',
        fallbackScenario = 'PROP_HUMAN_BBQ'
    },
    narcotics_heat = {
        dict = 'anim@amb@business@meth@meth_monitoring_cooking@monitoring@',
        clip = 'look_around_v5_monitor',
        fallbackScenario = 'WORLD_HUMAN_STAND_MOBILE'
    },
    narcotics_inspect = { scenario = 'WORLD_HUMAN_CLIPBOARD' },
    narcotics_package = {
        dict = 'anim@amb@business@coc@coc_unpack_cut_left@',
        clip = 'coke_cut_v5_coccutter',
        fallbackScenario = 'WORLD_HUMAN_STAND_MOBILE'
    },
    utility = { scenario = 'WORLD_HUMAN_HAMMERING' }
}

Config.KindAnimations = {
    weapons = {
        assemble = 'weapon_assemble',
        calibrate = 'weapon_calibrate',
        weld = 'weapon_weld',
        seal = 'weapon_finish',
        refine = 'weapon_assemble'
    },
    narcotics = {
        measure = 'narcotics_dose',
        dose = 'narcotics_dose',
        synthesize = 'narcotics_mix',
        heat = 'narcotics_heat',
        stabilize = 'narcotics_inspect',
        package = 'narcotics_package'
    }
}

Config.Restaurant = {
    resource = 'ob_restaurantes',
    pointTypes = {
        cutting = { label = 'Bancada de preparo', kind = 'kitchen', animation = 'cutting' },
        stove = { label = 'Fogão e chapa', kind = 'kitchen', animation = 'stove' },
        drinks = { label = 'Estação de bebidas', kind = 'kitchen', animation = 'drinks' },
        assembly = { label = 'Montagem de pedidos', kind = 'kitchen', animation = 'assembly' }
    },
    recipeStations = {
        ravenwood_burger = 'cutting',
        ravenwood_fries = 'stove',
        ravenwood_soda = 'drinks',
        ravenwood_combo = 'assembly'
    },
    categoryDefaults = {
        meals = 'stove',
        drinks = 'drinks',
        combos = 'assembly'
    }
}

Config.Preview = {
    kitchen = {
        station = { id = 'preview_kitchen', label = 'Bancada Ravenwood', kind = 'kitchen', animation = 'cutting' },
        recipes = {
            { id = 'burger', name = 'Hamburguer Ravenwood', description = 'Pao tostado, carne selada e salada fresca.', image = 'burger.png', duration = 8, difficulty = 0.58, craftSteps = { 'chop', 'grill', 'assemble' }, output = { item = 'hamburguer', label = 'Hamburguer Ravenwood', amount = 1 }, ingredients = { { item = 'pao', label = 'Pao artesanal', amount = 1, count = 4 }, { item = 'carne', label = 'Carne preparada', amount = 1, count = 3 }, { item = 'salad', label = 'Salada fresca', amount = 1, count = 5 } } },
            { id = 'fries', name = 'Batatas da Casa', description = 'Porcao cortada e finalizada na temperatura certa.', image = 'fries.png', duration = 6, difficulty = 0.62, craftSteps = { 'chop', 'fry', 'package' }, output = { item = 'batata_frita', label = 'Batatas da Casa', amount = 1 }, ingredients = { { item = 'batata', label = 'Batata', amount = 2, count = 8 } } },
            { id = 'fresh_pasta', name = 'Massa Fresca', category = 'massas', description = 'Massa trabalhada, porcionada e servida com molho.', duration = 14, difficulty = 0.5, craftSteps = { 'prep', 'measure', 'knead', 'portion', 'boil', 'sauce', 'plate' }, output = { item = 'ob_massa_fresca', label = 'Massa Fresca', amount = 1 }, ingredients = { { item = 'ob_farinha', label = 'Farinha', amount = 2, count = 6 }, { item = 'ob_ovo', label = 'Ovos', amount = 2, count = 5 }, { item = 'water', label = 'Agua', amount = 1, count = 4 } } },
            { id = 'pastry_box', name = 'Doce de Forno', category = 'sobremesas', description = 'Massa aerada, modelada e decorada apos assar.', image = 'pizza_ham_box.png', duration = 13, difficulty = 0.47, craftSteps = { 'prep', 'measure', 'whisk', 'shape', 'bake', 'decorate' }, output = { item = 'ob_doce_forno', label = 'Doce de Forno', amount = 2 }, ingredients = { { item = 'ob_farinha', label = 'Farinha', amount = 1, count = 6 }, { item = 'ob_acucar', label = 'Acucar', amount = 1, count = 4 }, { item = 'ob_ovo', label = 'Ovos', amount = 2, count = 5 } } },
            { id = 'house_drink', name = 'Refresco da Casa', category = 'bebidas', description = 'Bebida dosada, misturada e finalizada na hora.', image = 'cola.png', duration = 5, difficulty = 0.6, craftSteps = { 'measure', 'pour', 'mix', 'decorate' }, output = { item = 'refrigerante', label = 'Refresco da Casa', amount = 1 }, ingredients = { { item = 'water', label = 'Agua', amount = 1, count = 4 }, { item = 'xarope', label = 'Xarope', amount = 1, count = 3 } } },
            { id = 'combo', name = 'Box Ravenwood', description = 'Pedido completo organizado para entrega.', image = 'pizza_ham_box.png', duration = 12, difficulty = 0.5, craftSteps = { 'assemble', 'package' }, output = { item = 'combo_box', label = 'Box Ravenwood', amount = 1 }, ingredients = { { item = 'hamburguer', label = 'Hamburguer', amount = 1, count = 2 }, { item = 'batata_frita', label = 'Batatas', amount = 1, count = 3 }, { item = 'refrigerante', label = 'Refrigerante', amount = 1, count = 3 } } }
        }
    },
    weapons = {
        station = { id = 'preview_weapons', label = 'Bancada de armamentos', kind = 'weapons', animation = 'weapons' },
        recipes = {
            { id = 'pistol', name = 'Pistola compacta', description = 'Armação montada e mecanismo calibrado sobre a bancada.', duration = 24, difficulty = 0.38, craftSteps = { 'refine', 'assemble', 'calibrate', 'weld', 'seal' }, visual = { type = 'weapon', weapon = 'WEAPON_PISTOL' }, output = { item = 'WEAPON_PISTOL', label = 'Pistola compacta', amount = 1 }, ingredients = { { item = 'steel', label = 'Aço', amount = 5, count = 14 }, { item = 'aluminum', label = 'Alumínio', amount = 3, count = 10 }, { item = 'rubber', label = 'Borracha', amount = 2, count = 8 } } },
            { id = 'ammo', name = 'Kit de munição', description = 'Componentes prensados, separados e conferidos.', image = 'pistol_ammo.png', duration = 12, difficulty = 0.42, craftSteps = { 'assemble', 'calibrate', 'seal' }, visual = { type = 'object', models = { 'prop_box_ammo03a', 'prop_box_ammo04a' } }, output = { item = 'pistol_ammo', label = 'Munição de pistola', amount = 2 }, ingredients = { { item = 'steel', label = 'Aço', amount = 3, count = 12 }, { item = 'aluminum', label = 'Alumínio', amount = 2, count = 10 }, { item = 'rubber', label = 'Borracha', amount = 1, count = 8 } } }
        }
    },
    narcotics = {
        station = { id = 'preview_narcotics', label = 'Mesa de sintese', kind = 'narcotics', animation = 'narcotics' },
        recipes = {
            { id = 'compound', name = 'Composto sintético', description = 'Reagentes dosados, aquecidos e estabilizados na bancada.', image = 'meth_baggy.png', duration = 18, difficulty = 0.34, craftSteps = { 'dose', 'synthesize', 'heat', 'stabilize', 'package' }, visual = { type = 'object', models = { 'bkr_prop_meth_openbag_01a', 'prop_meth_bag_01' } }, output = { item = 'meth_baggy', label = 'Composto embalado', amount = 2 }, ingredients = { { item = 'acetone', label = 'Acetona', amount = 1, count = 4 }, { item = 'aluminum', label = 'Alumínio', amount = 2, count = 8 }, { item = 'water', label = 'Água', amount = 1, count = 6 } } }
        }
    }
}
