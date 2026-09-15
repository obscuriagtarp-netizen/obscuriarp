Config = {}

Config.Debug = false
Config.AdminCommand = 'restauranteadmin'
Config.AdminAce = 'ob.restaurantes.admin'
Config.AdminPermissions = { 'admin', 'god' }
Config.ManagerGrade = 4
Config.CraftMaxQuantity = 20

-- Todas as novas receitas usam este unico item no ox_inventory. Nome, imagem,
-- peso, tipo e efeitos de cada produto ficam na metadata criada pelo restaurante.
Config.RestaurantProduct = {
    item = 'produto_restaurante',
    defaultType = 'food',
    defaultWeight = 250,
    minWeight = 10,
    maxWeight = 5000,
    useTime = 2500
}

Config.InteractionDistance = 2.2
Config.NearbyCustomerDistance = 5.0
Config.DisplayRenderDistance = 16.0
Config.DisplayRefreshMs = 5000
Config.DisplayQueuedExpiryMinutes = 15
Config.PaymentExpiryMinutes = 10
Config.ServiceCallCooldownSeconds = 60
Config.ServiceCallBlipSeconds = 90
Config.CommissionRate = 0.30
Config.ManagementLimits = {
    maxPrice = 1000000,
    maxWithdrawal = 100000000,
    maxIngredients = 24,
    maxContents = 24,
    maxAmountPerIngredient = 1000,
    maxOutputAmount = 100,
    maxPrepSeconds = 1800
}
Config.AllowedPaymentAccounts = {
    cash = true,
    bank = true
}

Config.RecipeEffects = {
    maxSelected = 2,
    maxAmount = 50,
    defaultAmount = 20,
    items = {
        hamburguer = { fallback = { hunger = 25 } },
        batata_frita = { fallback = { hunger = 15 } },
        refrigerante = { fallback = { thirst = 22 } },
        combo_box = { fallback = { hunger = 30, thirst = 25 } }
    }
}

Config.CompanyBank = {
    provider = 'internal',
    resource = '',
    export = '',
    accountPrefix = 'restaurant_'
}

Config.TTS = {
    enabled = true,
    language = 'pt-BR',
    rate = 0.92,
    pitch = 1.0,
    volume = 1.0,
    maxDistance = 32.0,
    dedupeSeconds = 8,
    retryCount = 1,
    external = {
        enabled = true,
        provider = 'murf',
        url = 'https://api.murf.ai/v1/speech/generate',
        apiKeyConvar = 'ob_restaurant_tts_key',
        authorizationHeader = 'api-key',
        authorizationPrefix = '',
        voiceId = 'pt-BR-isadora',
        locale = 'pt-BR',
        format = 'MP3',
        sampleRate = 24000,
        style = 'Conversational'
    }
}

Config.Restaurants = {
    {
        id = 'vanilla',
        label = 'Vanilla',
        job = 'vanilla',
        managerGrade = 4,
        commissionRate = 0.30,
        callPrefix = 'V',
        description = 'Atendimento, entretenimento e produtos do estabelecimento.',
        locationLabel = 'Local do estabelecimento',
        callText = 'Abra um chamado para solicitar atendimento.',
        enabled = true,
        theme = 'vanilla'
    },
    {
        id = 'bahama_mamas',
        label = 'Bahama Mamas',
        job = 'bahama',
        managerGrade = 4,
        commissionRate = 0.30,
        callPrefix = 'B',
        description = 'Atendimento, entretenimento e produtos do estabelecimento.',
        locationLabel = 'Local do estabelecimento',
        callText = 'Abra um chamado para solicitar atendimento.',
        enabled = true,
        theme = 'bahama'
    },
    {
        id = 'club_77',
        label = 'Club 77',
        job = 'club77',
        managerGrade = 4,
        commissionRate = 0.30,
        callPrefix = 'C',
        description = 'Atendimento, entretenimento e produtos do estabelecimento.',
        locationLabel = 'Local do estabelecimento',
        callText = 'Abra um chamado para solicitar atendimento.',
        enabled = true,
        theme = 'club77'
    },
    {
        id = 'moomoo_cafe',
        label = 'MooMoo Cafe',
        job = 'moomoo',
        managerGrade = 4,
        commissionRate = 0.30,
        callPrefix = 'M',
        description = 'Cafeteria, refeições e atendimento ao público.',
        locationLabel = 'Local do estabelecimento',
        callText = 'Abra um chamado para solicitar atendimento.',
        enabled = true,
        theme = 'moomoo'
    },
    {
        id = 'dreamycoffee',
        label = 'Dreamy Coffee',
        job = 'cafebeans',
        managerGrade = 4,
        commissionRate = 0.30,
        callPrefix = 'D',
        description = 'Cafeteria, refeições e atendimento ao público.',
        locationLabel = 'Local do estabelecimento',
        callText = 'Abra um chamado para solicitar atendimento.',
        enabled = true,
        theme = 'cafebeans'
    },
    {
        id = 'chinese_seoul',
        label = 'Chinese Seoul',
        job = 'chinese',
        managerGrade = 4,
        commissionRate = 0.30,
        callPrefix = 'S',
        description = 'Culinária, bebidas e atendimento ao público.',
        locationLabel = 'Local do estabelecimento',
        callText = 'Abra um chamado para solicitar atendimento.',
        enabled = true,
        theme = 'chinese'
    }
}

-- Mantém os dados históricos, mas remove estabelecimentos antigos da listagem.
Config.DisabledRestaurants = {
    'ravenwood_cafe'
}

Config.SeedCategories = {
    { key = 'meals', label = 'Pratos', icon = 'utensils', sortOrder = 1 },
    { key = 'drinks', label = 'Bebidas', icon = 'cup-soda', sortOrder = 2 },
    { key = 'combos', label = 'Combos', icon = 'package-open', sortOrder = 3 }
}

Config.CraftActions = {
    prep = { label = 'Organizar ingredientes', description = 'Separe os ingredientes na ordem do preparo.' },
    chop = { label = 'Cortar ingredientes', description = 'Fatie os ingredientes nos pontos indicados.' },
    portion = { label = 'Porcionar', description = 'Divida o preparo em porcoes uniformes.' },
    knead = { label = 'Trabalhar a massa', description = 'Pressione e dobre a massa ate atingir elasticidade.' },
    shape = { label = 'Modelar', description = 'Modele cada porcao com pressao uniforme.' },
    grill = { label = 'Grelhar', description = 'Controle a chapa e retire no ponto certo.' },
    fry = { label = 'Fritar', description = 'Mantenha a temperatura dentro da faixa ideal.' },
    bake = { label = 'Assar', description = 'Controle o calor ate finalizar o cozimento.' },
    boil = { label = 'Cozinhar', description = 'Mantenha o preparo em temperatura constante.' },
    melt = { label = 'Derreter', description = 'Aplique calor gradualmente sem queimar o preparo.' },
    measure = { label = 'Medir componentes', description = 'Separe a quantidade exata indicada na receita.' },
    pour = { label = 'Dosar liquidos', description = 'Sirva a quantidade exata da receita.' },
    mix = { label = 'Misturar', description = 'Misture de forma continua ate atingir o ponto.' },
    whisk = { label = 'Bater', description = 'Incorpore ar com movimentos circulares.' },
    sauce = { label = 'Adicionar molho', description = 'Dose o molho na medida da receita.' },
    season = { label = 'Temperar', description = 'Distribua o tempero no ponto correto.' },
    assemble = { label = 'Montar', description = 'Organize os componentes na ordem correta.' },
    plate = { label = 'Empratar', description = 'Organize os componentes no prato.' },
    decorate = { label = 'Decorar', description = 'Finalize a apresentacao com precisao.' },
    chill = { label = 'Resfriar', description = 'Interrompa o resfriamento no ponto correto.' },
    package = { label = 'Embalar', description = 'Finalize e lacre o pedido para entrega.' }
}

Config.SeedRecipes = {
    {
        key = 'house_burger',
        category = 'meals',
        name = 'Hamburguer da Casa',
        description = 'Pao tostado, carne e salada fresca.',
        price = 280,
        prepTime = 8,
        outputItem = 'produto_restaurante',
        outputAmount = 1,
        productType = 'food',
        itemWeight = 280,
        icon = 'sandwich',
        effects = { hunger = 25 },
        ingredients = {
            { item = 'pao', label = 'Pao', amount = 1 },
            { item = 'carne', label = 'Carne', amount = 1 },
            { item = 'salad', label = 'Salada', amount = 1 }
        },
        craftSteps = { 'chop', 'grill', 'assemble' }
    },
    {
        key = 'house_fries',
        category = 'meals',
        name = 'Batatas da Casa',
        description = 'Porcao crocante preparada na hora.',
        price = 140,
        prepTime = 6,
        outputItem = 'produto_restaurante',
        outputAmount = 1,
        productType = 'food',
        itemWeight = 180,
        icon = 'salad',
        effects = { hunger = 15 },
        ingredients = {
            { item = 'batata', label = 'Batata', amount = 2 }
        },
        craftSteps = { 'chop', 'fry', 'package' }
    },
    {
        key = 'house_soda',
        category = 'drinks',
        name = 'Refrigerante',
        description = 'Bebida gelada servida no copo da casa.',
        price = 90,
        prepTime = 3,
        outputItem = 'produto_restaurante',
        outputAmount = 1,
        productType = 'drink',
        itemWeight = 300,
        icon = 'cup-soda',
        effects = { thirst = 22 },
        ingredients = {
            { item = 'water', label = 'Agua', amount = 1 },
            { item = 'xarope', label = 'Xarope', amount = 1 }
        },
        craftSteps = { 'pour', 'mix' }
    },
    {
        key = 'house_combo',
        category = 'combos',
        name = 'Combo da Casa',
        description = 'Hamburguer, batatas e bebida em uma unica embalagem.',
        price = 460,
        prepTime = 12,
        outputItem = 'produto_restaurante',
        outputAmount = 1,
        productType = 'food',
        itemWeight = 850,
        icon = 'package-open',
        isCombo = true,
        effects = { hunger = 30, thirst = 25 },
        ingredients = {
            { item = 'pao', label = 'Pao', amount = 1 },
            { item = 'carne', label = 'Carne', amount = 1 },
            { item = 'salad', label = 'Salada', amount = 1 },
            { item = 'batata', label = 'Batata', amount = 2 },
            { item = 'water', label = 'Agua', amount = 1 },
            { item = 'xarope', label = 'Xarope', amount = 1 }
        },
        contents = {
            { item = 'hamburguer', label = 'Hamburguer da Casa', amount = 1 },
            { item = 'batata_frita', label = 'Batatas da Casa', amount = 1 },
            { item = 'refrigerante', label = 'Refrigerante', amount = 1 }
        },
        craftSteps = { 'assemble', 'package' }
    }
}

Config.PointTypes = {
    pos = { label = 'Abrir caixa', icon = 'fa-solid fa-cash-register', employeeOnly = true },
    kitchen = { label = 'Abrir cozinha', icon = 'fa-solid fa-bell-concierge', employeeOnly = true },
    production = { label = 'Preparar receitas', icon = 'fa-solid fa-fire-burner', employeeOnly = true },
    cutting = { label = 'Usar bancada de preparo', icon = 'fa-solid fa-utensils', employeeOnly = true },
    stove = { label = 'Usar fogão e chapa', icon = 'fa-solid fa-fire-burner', employeeOnly = true },
    drinks = { label = 'Usar estação de bebidas', icon = 'fa-solid fa-martini-glass-citrus', employeeOnly = true },
    assembly = { label = 'Montar pedidos', icon = 'fa-solid fa-box-open', employeeOnly = true },
    menu = { label = 'Ver cardápio', icon = 'fa-solid fa-book-open', employeeOnly = false },
    terminal = { label = 'Pagar comanda', icon = 'fa-solid fa-receipt', employeeOnly = false },
    display = { label = 'Consultar pedidos', icon = 'fa-solid fa-tv', employeeOnly = false },
    admin = { label = 'Administrar restaurante', icon = 'fa-solid fa-gears', managerOnly = true }
}
