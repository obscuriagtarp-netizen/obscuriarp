Config = {}

Config.Framework = "qbox"
Config.FactionGroupType = "gang"
Config.Locale = "pt-br"

Config.AdminPermissions = { "god", "admin" }
Config.AdminJobs = {
    police = 4
}

Config.PlayerClass = {
    metadataKey = "classe",
    selectorResource = "classeSelector",
    databaseTable = "classe_selector",
    definitions = {
        bruxa = { label = "Bruxa", affinity = "Magia", weakness = "Fogo" },
        vampiro = { label = "Vampiro", affinity = "Sangue", weakness = "Luz" },
        curandeira = { label = "Curandeira", affinity = "Cura", weakness = "Veneno" },
        humano = { label = "Humano", affinity = "Versatilidade", weakness = "Fragilidade" }
    }
}

Config.Rankings = {
    limit = 10,
    cacheSeconds = 60,
    playersTable = "players",
    vehiclesTable = "player_vehicles",
    donationsTable = "magic_pause_vip_orders",
    donationProductId = "rune_deposit"
}

Config.Runes = {
    resource = "",
    getExport = "",
    removeExport = "",
    addExport = "",
    account = "crypto"
}

Config.VipStore = {
    enabled = true,
    title = "Loja VIP",
    subtitle = "Produtos especiais, vantagens e utilidades premium.",
    currencyLabel = "Runas",
    historyLimit = 8,
    productTemplate = "web/imgs/vipstore/bg_template.png",
    maxExtraCharacterSlots = 8,

    runeDeposit = {
        enabled = true,
        runesPerReal = 10,
        minimum = 10,
        maximum = 50000,
        step = 10,
        presets = { 100, 250, 500, 1000, 2500, 5000 }
    },

    pix = {
        enabled = true,
        apiUrl = "https://obscuriaapi.up.railway.app",
        -- Prefira o convar; ele mantém o segredo fora desta resource.
        apiTokenConvar = "magicpause_pix_api_token",
        apiToken = "",
        createPath = "/orders",
        statusPath = "/orders/%s",
        timeout = 15000,
        productPayments = false,
        security = {
            createCooldownSeconds = 8,
            statusCooldownSeconds = 2,
            maxPendingPerPlayer = 3,
            pendingLifetimeMinutes = 30,
            deliveryClaimTimeoutSeconds = 120
        }
    },

    categories = {
        { id = "featured", label = "Planos VIP", icon = "fa-solid fa-crown" },
        { id = "services", label = "Personagem", icon = "fa-solid fa-user-gear" }
    },

    products = {
        {
            id = "vip_veu",
            category = "featured",
            title = "VIP VEU",
            subtitle = "30 dias de beneficios",
            description = "O primeiro nivel VIP da Obscuria, com renda extra, veiculo exclusivo e mais capacidade.",
            image = "web/imgs/vipstore/veu.png",
            icon = "fa-solid fa-moon",
            badge = "VEU",
            priceRunes = 399,
            pricePix = 39.90,
            payment = { runes = true, pix = false },
            features = {
                "$ 50.000 de dinheiro inicial",
                "$ 2.000 de salario extra por hora",
                "1 veiculo do catalogo VEU",
                "+10 kg de capacidade enquanto o VIP estiver ativo",
                "5% de desconto em veiculos",
                "Tag VEU no Discord"
            },
            deliveries = {
                { type = "vip", vip = "veu", days = 30 }
            }
        },
        {
            id = "vip_eclipse",
            category = "featured",
            title = "VIP ECLIPSE",
            subtitle = "30 dias de beneficios",
            description = "Beneficios Eclipse com dois veiculos, mais capacidade e descontos em servicos.",
            image = "web/imgs/vipstore/eclipse.png",
            icon = "fa-solid fa-circle-half-stroke",
            badge = "ECLIPSE",
            priceRunes = 799,
            pricePix = 79.90,
            payment = { runes = true, pix = false },
            features = {
                "$ 120.000 de dinheiro inicial",
                "$ 4.000 de salario extra por hora",
                "2 veiculos do catalogo ECLIPSE",
                "+20 kg de capacidade enquanto o VIP estiver ativo",
                "10% em veiculos, combustivel e hospital",
                "1 Troca de Nome",
                "Tag ECLIPSE no Discord"
            },
            deliveries = {
                { type = "vip", vip = "eclipse", days = 30 }
            }
        },
        {
            id = "vip_arcano",
            category = "featured",
            title = "VIP ARCANO",
            subtitle = "30 dias de beneficios",
            description = "O nivel maximo, com tres veiculos, capacidade maxima e os maiores descontos.",
            image = "web/imgs/vipstore/arcano.png",
            icon = "fa-solid fa-wand-sparkles",
            badge = "ARCANO",
            priceRunes = 1499,
            pricePix = 149.90,
            payment = { runes = true, pix = false },
            features = {
                "$ 250.000 de dinheiro inicial",
                "$ 7.500 de salario extra por hora",
                "3 veiculos do catalogo ARCANO",
                "+30 kg de capacidade enquanto o VIP estiver ativo",
                "15% em veiculos, combustivel e hospital",
                "2 Trocas de Nome",
                "Tag ARCANO no Discord"
            },
            deliveries = {
                { type = "vip", vip = "arcano", days = 30 }
            }
        },
        {
            id = "trocar_raca",
            category = "services",
            title = "Trocar a raça",
            subtitle = "Escolha uma nova classe",
            description = "Receba um selo para refazer a escolha de raça do personagem quando desejar.",
            image = "web/imgs/vipstore/troca_raca.png",
            icon = "fa-solid fa-arrows-rotate",
            badge = "RAÇA",
            layout = "portrait",
            priceRunes = 100,
            payment = { runes = true, pix = false },
            features = {
                "Item entregue no inventário",
                "Uso único",
                "Abre novamente o seletor de raça"
            },
            deliveries = {
                { type = "item", item = "troca_raca", amount = 1 }
            }
        },
        {
            id = "trocar_nome",
            category = "services",
            title = "Trocar o nome",
            subtitle = "Novo nome e sobrenome",
            description = "Receba um documento para alterar o nome completo do personagem quando desejar.",
            image = "web/imgs/vipstore/troca_nome.png",
            icon = "fa-solid fa-signature",
            badge = "NOME",
            layout = "portrait",
            priceRunes = 50,
            payment = { runes = true, pix = false },
            features = {
                "Item entregue no inventário",
                "Uso único",
                "Altera nome e sobrenome"
            },
            deliveries = {
                { type = "item", item = "troca_nome", amount = 1 }
            }
        },
        {
            id = "personagem_extra",
            category = "services",
            title = "Mais um personagem",
            subtitle = "Uma vaga adicional no multichar",
            description = "Adiciona permanentemente uma vaga de personagem à sua conta.",
            image = "web/imgs/vipstore/personagem_a_mais.png",
            icon = "fa-solid fa-user-plus",
            badge = "VAGA",
            layout = "portrait",
            priceRunes = 200,
            payment = { runes = true, pix = false },
            features = {
                "Benefício vinculado à licença",
                "Liberação permanente",
                "Visível ao retornar ao multichar"
            },
            deliveries = {
                { type = "character_slot", amount = 1 }
            }
        },
        {
            id = "refazer_personagem",
            category = "services",
            title = "Refazer personagem",
            subtitle = "Personalização completa",
            description = "Receba um selo para abrir novamente a criação completa de aparência do personagem.",
            image = "web/imgs/vipstore/refazer_personagem.png",
            icon = "fa-solid fa-wand-magic-sparkles",
            badge = "VISUAL",
            layout = "portrait",
            priceRunes = 50,
            payment = { runes = true, pix = false },
            features = {
                "Item entregue no inventário",
                "Uso único",
                "Rosto, corpo, cabelo, roupas e tatuagens"
            },
            deliveries = {
                { type = "item", item = "refazer_personagem", amount = 1 }
            }
        }
    }
}

Config.Tickets = {
    maxOpenPerPlayer = 3,
    maxTitleLength = 80,
    maxMessageLength = 900,
    listLimit = 80,
    closedRetentionDays = 2,
    transcript = {
        webhook = "",
        username = "Obscuria Tickets",
        avatar = "",
        deleteAfterSend = true
    },
    categories = {
        { id = "support", label = "Suporte", icon = "fa-solid fa-headset" },
        { id = "purchase", label = "Compras", icon = "fa-solid fa-bag-shopping" },
        { id = "bug", label = "Problema técnico", icon = "fa-solid fa-bug" },
        { id = "report", label = "Denúncia", icon = "fa-solid fa-triangle-exclamation" }
    },
    statuses = {
        { id = "open", label = "Aberto", color = "#9b72cf" },
        { id = "answered", label = "Respondido", color = "#4eaa88" },
        { id = "waiting", label = "Aguardando", color = "#c99548" },
        { id = "closed", label = "Fechado", color = "#85818f" }
    }
}

Config.BattlePass = {
    defaultTitle = "Crônicas de Obscuria",
    defaultSubtitle = "Complete jornadas e resgate recompensas da temporada.",
    defaultDurationDays = 30,
    defaultPremiumPrice = 1000,
    defaultXpPerLevel = 1000,
    maxSlots = 200,
    maxSlotsLoaded = 250,
    initialSlots = {
        { title = "Primeiro Presságio", subtitle = "Início da jornada", freeReward = { type = "coins", label = "25 Runas", amount = 25 }, premiumReward = { type = "coins", label = "75 Runas", amount = 75 } },
        { title = "Passos na Névoa", subtitle = "Etapa II", freeReward = { type = "money", label = "$ 500", amount = 500 }, premiumReward = { type = "coins", label = "100 Runas", amount = 100 } },
        { title = "Segredo Antigo", subtitle = "Etapa III", freeReward = { type = "coins", label = "50 Runas", amount = 50 }, premiumReward = { type = "money", label = "$ 1.500", amount = 1500 } },
        { title = "Véu de Obscuria", subtitle = "Etapa IV", freeReward = { type = "money", label = "$ 750", amount = 750 }, premiumReward = { type = "coins", label = "150 Runas", amount = 150 } },
        { title = "Marca do Destino", subtitle = "Etapa V", freeReward = { type = "coins", label = "75 Runas", amount = 75 }, premiumReward = { type = "coins", label = "200 Runas", amount = 200 } },
        { title = "Ecos da Cidade", subtitle = "Etapa VI", freeReward = { type = "money", label = "$ 1.000", amount = 1000 }, premiumReward = { type = "money", label = "$ 3.000", amount = 3000 } },
        { title = "Pacto Noturno", subtitle = "Etapa VII", freeReward = { type = "coins", label = "100 Runas", amount = 100 }, premiumReward = { type = "coins", label = "300 Runas", amount = 300 } },
        { title = "Crônica Completa", subtitle = "Recompensa final", freeReward = { type = "money", label = "$ 2.000", amount = 2000 }, premiumReward = { type = "coins", label = "500 Runas", amount = 500 } }
    }
}

Config.JobsEnabled = false

Config.MenuOptions = {
    { id = "geral", label = "Geral", description = "Informações do personagem.", icon = "fa-solid fa-user" },
    { id = "ranking", label = "Ranking", description = "Destaques da cidade.", icon = "fa-solid fa-ranking-star" },
    { id = "factions", label = "Clãs", description = "Liderança e gestão dos clãs.", icon = "fa-solid fa-building-shield" },
    { id = "vip", label = "Loja VIP", description = "Produtos, Pix, Runas e vantagens.", icon = "fa-solid fa-gem" },
    { id = "empregos", label = "Empregos", description = "Indisponível no momento.", icon = "fa-solid fa-briefcase", disabled = not Config.JobsEnabled },
    { id = "estabelecimentos", label = "Estabelecimentos", description = "Locais e utilidades.", icon = "fa-solid fa-store" },
    { id = "battlepass", label = "Passe de Batalha", description = "Temporada, progresso e recompensas.", icon = "fa-solid fa-shield-halved" },
    { id = "tickets", label = "Suporte", description = "Tickets e atendimento com a equipe.", icon = "fa-solid fa-headset" }
}

Config.FactionDefaults = {
    memberLimit = 20,
    leaderGrade = 3,
    memberGrade = 0
}

Config.FactionTexts = {
    noFactionTitle = "Você não faz parte de um clã",
    noFactionDescription = "A entrada em um clã é definida pela staff.",
    staffDescription = "Como staff, você pode definir líderes e administrar os clãs cadastrados."
}

Config.Factions = {
    ballas = {
        label = "Ballas",
        group = "ballas",
        image = "",
        product = "Produto químico",
        modules = { craft = "ballas_product", farm = "chemical_supplies" },
        description = "Operação criminal com estrutura pronta para liderança e expansão do clã.",
        accent = "#a855f7",
        memberLimit = 20,
        leaderGrade = 3
    },
    vagos = {
        label = "Vagos",
        group = "vagos",
        image = "",
        product = "Produto químico",
        modules = { craft = "vagos_product", farm = "chemical_supplies" },
        description = "Estrutura preparada para produção, distribuição e gestão do clã.",
        accent = "#eab308",
        memberLimit = 20,
        leaderGrade = 3
    }
}

Config.Subscription = {
    periodDays = 30,
    overdueDays = 5,
    blockedDays = 7
}

Config.PositionReset = {
    singlePrice = 30,
    allPrice = 100
}

Config.GarageSpawn = {
    maxPoints = 2,
    maxDistance = 20.0
}

Config.ModuleModels = {
    storage = {
        main_storage_1t = {
            label = "Baú principal",
            maxSlots = 120,
            maxWeight = 1000
        },
        extra_storage_200 = {
            label = "Baú adicional",
            maxSlots = 50,
            maxWeight = 200
        }
    },
    garage = {
        faction_personal = {
            label = "Garagem do clã",
            kind = "job",
            teleportIntoVehicle = false,
            spawnOffsets = {
                { forward = 4.0, right = 0.0 },
                { forward = 4.0, right = 3.0 }
            }
        }
    },
    farm = {
        chemical_supplies = {
            label = "Iniciar rota química",
            route = "drug_supplies"
        },
        weapon_supplies = {
            label = "Iniciar rota de peças",
            route = "weapon_parts"
        }
    },
    craft = {
        ballas_product = {
            label = "Mesa Ballas",
            subtitle = "Refino e embalagem",
            kind = "drugs",
            icon = "fa-flask",
            recipes = { "cocaine_bag" },
            prop = {
                enabled = true,
                model = "bkr_prop_coke_table01a",
                offset = vec3(0.0, 0.0, -1.0),
                heading = 0.0,
                placeOnGround = true,
                freeze = true
            }
        },
        vagos_product = {
            label = "Mesa Vagos",
            subtitle = "Refino e embalagem",
            kind = "drugs",
            icon = "fa-flask",
            recipes = { "cocaine_bag" },
            prop = {
                enabled = true,
                model = "bkr_prop_coke_table01a",
                offset = vec3(0.0, 0.0, -1.0),
                heading = 0.0,
                placeOnGround = true,
                freeze = true
            }
        }
    }
}

Config.FixedModules = {

}

Config.IncludedFeatures = {
    { id = "main_storage", label = "Baú principal", type = "storage", model = "main_storage_1t", icon = "fa-solid fa-box-archive", weight = 1000, limit = 1 },
    { id = "private_garage", label = "Garagem pessoal", type = "garage", model = "faction_personal", icon = "fa-solid fa-car", limit = 1 },
    { id = "management_panel", label = "Painel do clã", type = "panel", icon = "fa-solid fa-tablet-screen-button", limit = 1, automatic = true },
    { id = "product_craft", label = "Mesa de fabricação", type = "craft", modelFromFaction = true, icon = "fa-solid fa-flask", limit = 1 },
    { id = "farm_route", label = "Iniciar rota", type = "farm", modelFromFaction = true, icon = "fa-solid fa-route", limit = 1 }
}

Config.Upgrades = {
    {
        id = "members_10",
        label = "+10 membros",
        description = "Amplia permanentemente a capacidade do clã.",
        icon = "fa-solid fa-users",
        price = 350,
        type = "member_capacity",
        amount = 10,
        permanent = true,
        repeatable = true,
        requiresLocation = false
    },
    {
        id = "storage_200",
        label = "+1 Baú de 200Kg",
        description = "Cria um novo baú ou aumenta o peso de um baú existente.",
        icon = "fa-solid fa-box",
        price = 150,
        type = "storage",
        model = "extra_storage_200",
        weight = 200,
        permanent = true,
        repeatable = true,
        requiresLocation = true
    },
    {
        id = "garage_extra",
        label = "+1 Garagem pessoal",
        description = "Novo ponto de garagem no local escolhido.",
        icon = "fa-solid fa-square-parking",
        price = 120,
        type = "garage",
        model = "faction_personal",
        permanent = true,
        repeatable = true,
        requiresLocation = true
    },
    {
        id = "sound_blip",
        label = "+1 Blip de som",
        description = "Ponto de som para a sede.",
        icon = "fa-solid fa-music",
        price = 100,
        type = "sound",
        permanent = true,
        repeatable = true,
        requiresLocation = true
    },
    {
        id = "clothing_blip",
        label = "+1 Blip de roupa",
        description = "Loja de roupas no local escolhido.",
        icon = "fa-solid fa-shirt",
        price = 500,
        type = "clothing",
        permanent = true,
        repeatable = true,
        requiresLocation = true
    },
    {
        id = "convenience_store",
        label = "+1 Loja de conveniência",
        description = "Ponto comercial mensal para o clã.",
        icon = "fa-solid fa-store",
        price = 350,
        type = "store",
        permanent = false,
        recurring = true,
        repeatable = true,
        requiresLocation = true
    }
}

Config.OpenWithESC = true

Config.RaspadinhaTable = "magic_raspadinhas"

Config.RaspadinhaDailyLimit = 1

Config.RaspadinhasRewards = {
    {
        id     = "money_1",
        type   = "money",
        amount = {100, 10000},
        chance = 20,
        label  = "Você ganhou dinheiro!",
        image  = "dollars"
    },
    {
        id     = "cellphone",
        type   = "item",
        amount = 1,
        item   = "cellphone",
        chance = 35,
        label  = "Você ganhou um telefone!",
        image  = "celular"
    },
    {
        id     = "radio",
        type   = "item",
        amount = 1,
        item   = "radio",
        chance = 35,
        label  = "Você ganhou um rádio!",
        image  = "radio"
    },
    {
        id         = "vip_veu",
        type       = "premium",
        permission = "VEU",
        duration   = 7 * 86400,
        chance     = 3,
        label      = "Você ganhou 7 dias de VIP VÉU!"
    },
    {
        id        = "vehicle_7d",
        type      = "vehicle",
        vehicle   = "sultan",
        days      = 7,
        block     = false,
        chance    = 5,
        label     = "Você ganhou um Sultan por 7 dias!",
        image     = "veiculo"
    },
}

Config.MaxLevel = 10
Config.JobProgression = {
  incomeBonusPerLevel = 2.0,
  executionBonusPerLevel = 1.25,
  masteryStep = 1000,
  rankingLimit = 10,
  rewardAccount = "bank",
  payoutCommand = "premiarjobranking",
  rewards = {
    overall = { 15000, 10000, 7500 },
    service = { 5000, 3000, 2000 }
  }
}

Config.Jobs = {

lenhador = {
    label = "Lenhador",
    description = "Colete e prepare madeira com precisão. A experiência aumenta seus ganhos e reduz o tempo necessário em cada etapa do serviço.",
    image = "imgs/jobs/lenhador.png",
    coords = { x = -552.46, y = 5348.87, z = 74.74 },
    levels = {
      [1] = 0,
      [2] = 150,
      [3] = 400,
      [4] = 800,
      [5] = 1300,
      [6] = 1900,
      [7] = 2600,
      [8] = 3400,
      [9] = 4300,
      [10] = 5300
    }
  },
minerador = {
    label = "Minerador",
    description = "Extraia e processe minérios em rotas de risco. Profissionais experientes trabalham mais rápido e recebem melhor por produção.",
    image = "imgs/jobs/minerador.png",
    coords = { x = 2946.73, y = 2795.12, z = 40.51 },
    levels = {
      [1] = 0,
      [2] = 120,
      [3] = 350,
      [4] = 700,
      [5] = 1200,
      [6] = 1800,
      [7] = 2500,
      [8] = 3300,
      [9] = 4200,
      [10] = 5200
    }
  },
leiteiro = {
    label = "Leiteiro",
    description = "Mantenha a cadeia de coleta e entrega funcionando. Regularidade e agilidade constroem sua posição no ranking.",
    image = "imgs/jobs/leiteiro.png",
    coords = { x = -552.46, y = 5348.87, z = 74.74 },
    levels = {
      [1] = 0,
      [2] = 150,
      [3] = 400,
      [4] = 800,
      [5] = 1300,
      [6] = 1900,
      [7] = 2600,
      [8] = 3400,
      [9] = 4300,
      [10] = 5300
    }
  },

taxi = {
    label = "Taxista",
    description = "Transporte passageiros pela cidade com eficiência. Corridas concluídas fortalecem sua carreira e melhoram a remuneração.",
    image = "imgs/jobs/taxi.png",
    coords = { x = 2946.73, y = 2795.12, z = 40.51 },
    levels = {
      [1] = 0,
      [2] = 120,
      [3] = 350,
      [4] = 700,
      [5] = 1200,
      [6] = 1800,
      [7] = 2500,
      [8] = 3300,
      [9] = 4200,
      [10] = 5200
    }
  },
onibus = {
    label = "Motorista de ônibus",
    description = "Cumpra linhas urbanas e mantenha os horários. A progressão valoriza constância, segurança e domínio das rotas.",
    image = "imgs/jobs/onibus.png",
    coords = { x = -552.46, y = 5348.87, z = 74.74 },
    levels = {
      [1] = 0,
      [2] = 150,
      [3] = 400,
      [4] = 800,
      [5] = 1300,
      [6] = 1900,
      [7] = 2600,
      [8] = 3400,
      [9] = 4300,
      [10] = 5300
    }
  },
mergulhador = {
    label = "Mergulhador",
    description = "Explore áreas submersas e recupere materiais raros. Experiência reduz o esforço das operações e amplia os ganhos.",
    image = "imgs/jobs/mergulhador.png",
    coords = { x = 2946.73, y = 2795.12, z = 40.51 },
    levels = {
      [1] = 0,
      [2] = 120,
      [3] = 350,
      [4] = 700,
      [5] = 1200,
      [6] = 1800,
      [7] = 2500,
      [8] = 3300,
      [9] = 4200,
      [10] = 5200
    }
  },
cacador = {
    label = "Caçador",
    description = "Rastreie recursos em regiões selvagens. Cada atividade concluída aumenta sua reputação profissional na cidade.",
    image = "imgs/jobs/cacador.png",
    coords = { x = -552.46, y = 5348.87, z = 74.74 },
    levels = {
      [1] = 0,
      [2] = 150,
      [3] = 400,
      [4] = 800,
      [5] = 1300,
      [6] = 1900,
      [7] = 2600,
      [8] = 3400,
      [9] = 4300,
      [10] = 5300
    }
  },
pescador = {
    label = "Pescador",
    description = "Domine pontos de pesca e entregas do litoral. Sua pontuação continua crescendo mesmo após alcançar o nível máximo.",
    image = "imgs/jobs/pescador.png",
    coords = { x = 2946.73, y = 2795.12, z = 40.51 },
    levels = {
      [1] = 0,
      [2] = 120,
      [3] = 350,
      [4] = 700,
      [5] = 1200,
      [6] = 1800,
      [7] = 2500,
      [8] = 3300,
      [9] = 4200,
      [10] = 5200
    }
  }
}
