Config = Config or {}

Config.ClassMetadataKey = 'classe'
Config.NecklaceSlot = 7

Config.Boxes = {
    caixa_colares = {
        label = 'Caixa de Colares de Classe',
        description = 'Escolha um colar. A escolha é permanente e consome a caixa.',
        options = {
            { item = 'colar_foco_cristalino', label = 'Colar do Foco Cristalino', description = 'Bruxa: +25 de mana máxima.', image = 'nui://ox_inventory/web/images/colar_foco_cristalino.png' },
            { item = 'colar_pulso_sereno', label = 'Colar do Pulso Sereno', description = 'Curandeira: +25 de energia máxima.', image = 'nui://ox_inventory/web/images/colar_pulso_sereno.png' },
            { item = 'colar_veu_noturno', label = 'Colar do Véu Noturno', description = 'Vampiro: +25 de sangue máximo.', image = 'nui://ox_inventory/web/images/colar_veu_noturno.png' },
            { item = 'colar_sabedoria_ancestral', label = 'Colar da Sabedoria Ancestral', description = 'Humano: +25 de vida máxima.', image = 'nui://ox_inventory/web/images/colar_sabedoria_ancestral.png' },
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
}

Config.Necklaces = {
    colar_foco_cristalino = {
        label = 'Colar do Foco Cristalino',
        class = 'bruxa',
        essenceBonus = 25,
    },
    colar_pulso_sereno = {
        label = 'Colar do Pulso Sereno',
        class = 'curandeira',
        essenceBonus = 25,
    },
    colar_veu_noturno = {
        label = 'Colar do Véu Noturno',
        class = 'vampiro',
        essenceBonus = 25,
    },
    colar_sabedoria_ancestral = {
        label = 'Colar da Sabedoria Ancestral',
        class = 'humano',
        maxHealthBonus = 25,
    },
}

Config.HumanBaseMaxHealth = 200

Config.Potions = {
    pocao_mana = {
        label = 'Poção de Mana',
        class = 'bruxa',
        essence = 40,
    },
    elixir_fadas = {
        label = 'Elixir das Fadas',
        class = 'curandeira',
        essence = 40,
    },
    elixir_sangue = {
        label = 'Elixir de Sangue',
        class = 'vampiro',
        essence = 40,
    },
    elixir_sabedoria = {
        label = 'Elixir da Sabedoria',
        class = 'humano',
        health = 50,
        speedMultiplier = 1.25,
        durationMs = 10 * 60 * 1000,
    },
}

Config.Messages = {
    invalidBox = 'Esta caixa não está configurada.',
    invalidChoice = 'A opção escolhida não é válida.',
    boxMoved = 'A caixa mudou de lugar. Abra novamente para escolher.',
    inventoryFull = 'Você não tem espaço para receber este item.',
    redeemFailed = 'Não foi possível abrir a caixa agora.',
    wrongClass = 'Este elixir não pertence à sua classe.',
    alreadyFull = 'Sua essência já está cheia.',
    potionFailed = 'O elixir não conseguiu aplicar o efeito.',
}
