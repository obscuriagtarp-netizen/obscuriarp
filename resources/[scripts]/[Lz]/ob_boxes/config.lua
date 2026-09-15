Config = Config or {}

Config.ClassMetadataKey = 'classe'
Config.HumanBaseMaxHealth = 200
Config.EquipmentSlots = {
    amulet = 6,
    necklace = 7,
    belt = 8,
    ring = 9,
}

Config.Effects = {
    regenIntervalMs = 60 * 1000,
    wrongPotionDurationMs = 60 * 1000,
    essenceCostMultiplier = 0.5,
    potionMultiplier = 1.25,
    healerPowerMultiplier = 1.25,
    staminaRechargeMultiplier = 1.10,
    underwaterTimeMultiplier = 1.10,
    baseUnderwaterSeconds = 10.0,
}

Config.Boxes = {
    caixa_colares = {
        label = 'Caixa de Colares de Classe',
        description = 'Escolha um colar. A escolha é permanente e consome a caixa.',
        options = {
            { item = 'colar_foco_cristalino', label = 'Colar do Foco Cristalino', description = 'Bruxa: +25 de mana máxima.', image = 'nui://ox_inventory/web/images/colar_foco_cristalino.png' },
            { item = 'colar_pulso_sereno', label = 'Colar do Pulso Sereno', description = 'Curandeira: +25 de energia máxima.', image = 'nui://ox_inventory/web/images/colar_pulso_sereno.png' },
            { item = 'colar_veu_noturno', label = 'Colar do Véu Noturno', description = 'Vampiro: +25 de sangue máximo.', image = 'nui://ox_inventory/web/images/colar_veu_noturno.png' },
            { item = 'colar_latente', label = 'Colar da Sabedoria Ancestral', description = 'Humano: +25 de vida máxima.', image = 'nui://ox_inventory/web/images/goldchain.png' },
        },
    },
    caixa_elixires = {
        label = 'Caixa de Elixires',
        description = 'Escolha um elixir. A escolha é permanente e consome a caixa.',
        options = {
            { item = 'pocao_mana', label = 'Poção de Mana', description = 'Restaura a mana de uma bruxa.', image = 'nui://ox_inventory/web/images/pocao_mana.png' },
            { item = 'elixir_fadas', label = 'Elixir das Fadas', description = 'Restaura a energia de uma curandeira.', image = 'nui://ox_inventory/web/images/elixir_fadas.png' },
            { item = 'elixir_sangue', label = 'Elixir de Sangue', description = 'Restaura o sangue de um vampiro.', image = 'nui://ox_inventory/web/images/elixir_sangue.png' },
            { item = 'elixir_sabedoria', label = 'Elixir da Sabedoria', description = 'Cura e acelera um humano temporariamente.', image = 'nui://ox_inventory/web/images/elixir_sabedoria.png' },
        },
    },
    caixa_amuletos = {
        label = 'Caixa de Amuletos de Classe',
        description = 'Escolha um amuleto de classe válido por 30 dias.',
        options = {
            { item = 'amuleto_veu_arcano', label = 'Amuleto do Véu Arcano', description = 'Bruxa: regenera 5 de mana por minuto.', image = 'nui://ox_inventory/web/images/amuleto_veu_arcano.png' },
            { item = 'amuleto_seiva_sagrada', label = 'Amuleto da Seiva Sagrada', description = 'Curandeira: regenera energia e fortalece os poderes, exceto voo.', image = 'nui://ox_inventory/web/images/amuleto_seiva_sagrada.png' },
            { item = 'amuleto_eclipse', label = 'Amuleto do Eclipse', description = 'Vampiro: proteção contra a luz solar.', image = 'nui://ox_inventory/web/images/amuleto_eclipse.png' },
            { item = 'amuleto_latente', label = 'Amuleto do Fôlego Ancestral', description = 'Humano: stamina e respiração submersa 10% melhores.', image = 'nui://ox_inventory/web/images/10kgoldchain.png' },
        },
    },
    caixa_aneis = {
        label = 'Caixa de Anéis de Classe',
        description = 'Escolha um anel de classe válido por 30 dias.',
        options = {
            { item = 'anel_eco_runico', label = 'Anel do Eco Rúnico', description = 'Bruxa: reduz pela metade o custo dos poderes.', image = 'nui://ox_inventory/web/images/anel_eco_runico.png' },
            { item = 'anel_segundo_folego', label = 'Anel do Segundo Fôlego', description = 'Curandeira: reduz pela metade o custo dos poderes.', image = 'nui://ox_inventory/web/images/anel_segundo_folego.png' },
            { item = 'anel_sangue_ancestral', label = 'Anel do Sangue Ancestral', description = 'Vampiro: reduz pela metade o custo dos poderes.', image = 'nui://ox_inventory/web/images/anel_sangue_ancestral.png' },
            { item = 'anel_latente', label = 'Anel do Vigor Ancestral', description = 'Humano: regenera 5 de vida por minuto.', image = 'nui://ox_inventory/web/images/diamond_ring.png' },
        },
    },
    caixa_cintos = {
        label = 'Caixa de Cintos de Classe',
        description = 'Escolha um cinto de classe válido por 30 dias.',
        options = {
            { item = 'cinto_selo_da_lua', label = 'Cinto do Selo da Lua', description = 'Bruxa: aumenta em 25% a eficiência das poções.', image = 'nui://ox_inventory/web/images/cinto_selo_da_lua.png' },
            { item = 'cinto_guardiao_vital', label = 'Cinto do Guardião Vital', description = 'Curandeira: aumenta em 25% a eficiência das poções.', image = 'nui://ox_inventory/web/images/cinto_guardiao_vital.png' },
            { item = 'cinto_presa_carmesim', label = 'Cinto da Presa Carmesim', description = 'Vampiro: aumenta em 25% a eficiência das poções.', image = 'nui://ox_inventory/web/images/cinto_presa_carmesim.png' },
            { item = 'cinto_latente', label = 'Cinto do Alento Humano', description = 'Humano: aumenta em 25% a eficiência das poções.', image = 'nui://ox_inventory/web/images/harness.png' },
        },
    },
    caixa_pocoes_2 = {
        label = 'Caixa de Poções II',
        description = 'Escolha uma poção de restauração total para a sua classe.',
        options = {
            { item = 'pocao_restauracao_arcana', label = 'Poção de Restauração Arcana', description = 'Bruxa: restaura completamente os status.', image = 'nui://ox_inventory/web/images/pocao_restauracao_arcana.png' },
            { item = 'pocao_restauracao_feerica', label = 'Poção de Restauração Feérica', description = 'Curandeira: restaura completamente os status.', image = 'nui://ox_inventory/web/images/pocao_restauracao_feerica.png' },
            { item = 'pocao_restauracao_sanguinea', label = 'Poção de Restauração Sanguínea', description = 'Vampiro: restaura completamente os status.', image = 'nui://ox_inventory/web/images/pocao_restauracao_sanguinea.png' },
            { item = 'pocao_restauracao_humana', label = 'Poção de Restauração Humana', description = 'Humano: restaura completamente os status.', image = 'nui://ox_inventory/web/images/pocao_restauracao_humana.png' },
        },
    },
}

Config.Necklaces = {
    colar_foco_cristalino = { label = 'Colar do Foco Cristalino', class = 'bruxa', essenceBonus = 25 },
    colar_pulso_sereno = { label = 'Colar do Pulso Sereno', class = 'curandeira', essenceBonus = 25 },
    colar_veu_noturno = { label = 'Colar do Véu Noturno', class = 'vampiro', essenceBonus = 25 },
    colar_latente = { label = 'Colar da Sabedoria Ancestral', class = 'humano', maxHealthBonus = 25 },
}

Config.Artifacts = {
    amuleto_veu_arcano = { label = 'Amuleto do Véu Arcano', class = 'bruxa', slot = 'amulet', essenceRegen = 5 },
    amuleto_seiva_sagrada = { label = 'Amuleto da Seiva Sagrada', class = 'curandeira', slot = 'amulet', essenceRegen = 5, healerPowerMultiplier = Config.Effects.healerPowerMultiplier },
    amuleto_eclipse = { label = 'Amuleto do Eclipse', class = 'vampiro', slot = 'amulet', solarProtection = true },
    amuleto_latente = { label = 'Amuleto do Fôlego Ancestral', class = 'humano', slot = 'amulet', staminaRechargeMultiplier = Config.Effects.staminaRechargeMultiplier, underwaterTimeMultiplier = Config.Effects.underwaterTimeMultiplier },
    anel_eco_runico = { label = 'Anel do Eco Rúnico', class = 'bruxa', slot = 'ring', essenceCostMultiplier = Config.Effects.essenceCostMultiplier },
    anel_segundo_folego = { label = 'Anel do Segundo Fôlego', class = 'curandeira', slot = 'ring', essenceCostMultiplier = Config.Effects.essenceCostMultiplier },
    anel_sangue_ancestral = { label = 'Anel do Sangue Ancestral', class = 'vampiro', slot = 'ring', essenceCostMultiplier = Config.Effects.essenceCostMultiplier },
    anel_latente = { label = 'Anel do Vigor Ancestral', class = 'humano', slot = 'ring', healthRegen = 5 },
    cinto_selo_da_lua = { label = 'Cinto do Selo da Lua', class = 'bruxa', slot = 'belt', potionMultiplier = Config.Effects.potionMultiplier },
    cinto_guardiao_vital = { label = 'Cinto do Guardião Vital', class = 'curandeira', slot = 'belt', potionMultiplier = Config.Effects.potionMultiplier },
    cinto_presa_carmesim = { label = 'Cinto da Presa Carmesim', class = 'vampiro', slot = 'belt', potionMultiplier = Config.Effects.potionMultiplier },
    cinto_latente = { label = 'Cinto do Alento Humano', class = 'humano', slot = 'belt', potionMultiplier = Config.Effects.potionMultiplier },
}

Config.Potions = {
    pocao_mana = { label = 'Poção de Mana', class = 'bruxa', essence = 40 },
    elixir_fadas = { label = 'Elixir das Fadas', class = 'curandeira', essence = 40 },
    elixir_sangue = { label = 'Elixir de Sangue', class = 'vampiro', essence = 40 },
    elixir_sabedoria = { label = 'Elixir da Sabedoria', class = 'humano', health = 50, speedMultiplier = 1.25, durationMs = 10 * 60 * 1000 },
    pocao_restauracao_arcana = { label = 'Poção de Restauração Arcana', class = 'bruxa', fullRestore = true },
    pocao_restauracao_feerica = { label = 'Poção de Restauração Feérica', class = 'curandeira', fullRestore = true },
    pocao_restauracao_sanguinea = { label = 'Poção de Restauração Sanguínea', class = 'vampiro', fullRestore = true },
    pocao_restauracao_humana = { label = 'Poção de Restauração Humana', class = 'humano', fullRestore = true },
}

Config.Messages = {
    invalidBox = 'Esta caixa não está configurada.',
    invalidChoice = 'A opção escolhida não é válida.',
    boxMoved = 'A caixa mudou de lugar. Abra novamente para escolher.',
    inventoryFull = 'Você não tem espaço para receber este item.',
    redeemFailed = 'Não foi possível abrir a caixa agora.',
    wrongClass = 'Esta poção não pertence à sua classe. Ela não fez efeito.',
    wrongArtifact = 'O artefato rejeitou sua classe e começou a corromper você.',
    incapacitated = 'Você não consegue usar uma poção nesse estado.',
    alreadyFull = 'Sua essência já está cheia.',
    potionFailed = 'A poção não conseguiu aplicar o efeito.',
    fullRestore = 'Todos os seus status foram restaurados.',
}
