return {
    ['testburger'] = {
        label = 'Test Burger',
        weight = 220,
        degrade = 60,
        client = {
            image = 'burger_chicken.png',
            status = { hunger = 200000 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            export = 'ox_inventory_examples.testburger'
        },
        server = {
            export = 'ox_inventory_examples.testburger',
            test = 'what an amazingly delicious burger, amirite?'
        },
        buttons = {
            {
                label = 'Lick it',
                action = function(slot)
                    print('You licked the burger')
                end
            },
            {
                label = 'Squeeze it',
                action = function(slot)
                    print('You squeezed the burger :(')
                end
            },
            {
                label = 'What do you call a vegan burger?',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('A misteak.')
                end
            },
            {
                label = 'What do frogs like to eat with their hamburgers?',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('French flies.')
                end
            },
            {
                label = 'Why were the burger and fries running?',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('Because they\'re fast food.')
                end
            }
        },
        consume = 0.3
    },

    ['gauze'] = {
        label = 'Gaze estéril',
        weight = 80,
        stack = true,
        close = true,
        client = { image = 'gauze.png' }
    },
    
    ['bandage'] = {
        label = 'Bandagem',
        weight = 115,
        stack = true,
        close = true,
        client = { image = 'bandage.png' }
    },
    
    ['painkillers'] = {
        label = 'Analgésico',
        weight = 400,
        stack = true,
        close = true,
        description = 'Alivia a dor e reduz o estresse.',
        client = { image = 'painkillers.png' }
    },
    
    ['firstaid'] = {
        label = 'Kit de primeiros socorros',
        weight = 2500,
        stack = true,
        close = true,
        description = 'Suprimentos para estabilização e reanimação.',
        client = { image = 'firstaid.png' }
    },
    
    ['medical_kit'] = {
        label = 'Kit médico',
        weight = 2800,
        stack = true,
        close = true,
        client = { image = 'medikit.png' }
    },
    
    ['medical_stretcher'] = {
        label = 'Maca dobrável',
        weight = 8500,
        stack = false,
        close = true,
        description = 'Permite transportar pacientes com segurança.'
    },

    ['burger'] = {
        label = 'Burger',
        weight = 220,
        client = {
            status = { hunger = 200000 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            notification = 'You ate a delicious burger'
        },
    },

    ['mochila_pequena'] = {
        label = 'Mochila Pequena',
        weight = 900,
        stack = false,
        close = true,
        consume = 1,
        description = 'Consuma para aumentar a capacidade do inventario em 10 kg ate a morte.',
        client = {
            image = 'mochila_pequena.png',
        },
        server = { export = 'ob_vip.useBackpack' },
    },

    ['mochila_media'] = {
        label = 'Mochila Média',
        weight = 1200,
        stack = false,
        close = true,
        consume = 1,
        description = 'Consuma para aumentar a capacidade do inventario em 20 kg ate a morte.',
        client = {
            image = 'mochila_media.png',
        },
        server = { export = 'ob_vip.useBackpack' },
    },

    ['mochila_grande'] = {
        label = 'Mochila Grande',
        weight = 1600,
        stack = false,
        close = true,
        consume = 1,
        description = 'Consuma para aumentar a capacidade do inventario em 30 kg ate a morte.',
        client = {
            image = 'mochila_grande.png',
        },
        server = { export = 'ob_vip.useBackpack' },
    },

    ['troca_nome'] = {
        label = 'Troca de Nome',
        weight = 10,
        stack = true,
        close = true,
        consume = 0,
        description = 'Permite alterar o nome e o sobrenome do personagem uma vez.',
        client = {
            image = 'troca_nome.png',
            event = 'ob_vip:client:useNameChange',
        },
    },

    ['troca_raca'] = {
        label = 'Troca de Raça',
        weight = 10,
        stack = true,
        close = true,
        consume = 0,
        description = 'Permite escolher novamente a raça do personagem uma vez.',
        client = {
            image = 'troca_raca.png',
            event = 'classeSelector:client:useRaceChangeVoucher',
        },
    },

    ['refazer_personagem'] = {
        label = 'Refazer Personagem',
        weight = 10,
        stack = true,
        close = true,
        consume = 0,
        description = 'Permite refazer a aparência completa do personagem uma vez.',
        client = {
            image = 'refazer_personagem.png',
            event = 'MagicPause:client:useAppearanceVoucher',
        },
    },
    ['sprunk'] = {
        label = 'Sprunk',
        weight = 350,
        client = {
            status = { thirst = 200000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_can_01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) },
            usetime = 2500,
            notification = 'You quenched your thirst with a sprunk'
        }
    },

    ['parachute'] = {
        label = 'Parachute',
        weight = 8000,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 1500
        }
    },

    ['garbage'] = {
        label = 'Garbage',
    },

    ['paperbag'] = {
        label = 'Paper Bag',
        weight = 1,
        stack = false,
        close = false,
        consume = 0
    },

    ['panties'] = {
        label = 'Knickers',
        weight = 10,
        consume = 0,
        client = {
            status = { thirst = -100000, stress = -25000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_cs_panties_02`, pos = vec3(0.03, 0.0, 0.02), rot = vec3(0.0, -13.5, -1.5) },
            usetime = 2500,
        }
    },

    ['victoriawand'] = {
        label = 'Varinha Bruxa',
        weight = 250,
        stack = false,
        close = true,
        consume = 0,
        description = 'Varinha ritualistica usada para canalizar o grimorio.',
        client = {
            event = 'magic:client:useWandItem'
        }
    },

    ['livro_blink'] = {
        label = 'Livro de Blink',
        weight = 300,
        stack = true,
        close = true,
        consume = 0,
        description = 'Um tomo runico que guarda o aprendizado de Blink.',
        client = {
            image = 'livro_blink.png',
            event = 'ob_aprendizado:client:useLearningItem'
        }
    },

    ['livro_machina_reparatio'] = {
        label = 'Livro de Machina Reparatio',
        weight = 300,
        stack = true,
        close = true,
        consume = 0,
        description = 'Um tomo runico que guarda o aprendizado de Machina Reparatio.',
        client = {
            image = 'livro_machina_reparatio.png',
            event = 'ob_aprendizado:client:useLearningItem'
        }
    },

    ['livro_vitae_restituo'] = {
        label = 'Livro de Vitae Restituo',
        weight = 300,
        stack = true,
        close = true,
        consume = 0,
        description = 'Um tomo runico que guarda o aprendizado de Vitae Restituo.',
        client = {
            image = 'livro_vitae_restituo.png',
            event = 'ob_aprendizado:client:useLearningItem'
        }
    },

    ['livro_petrificus'] = {
        label = 'Livro de Glacies',
        weight = 300,
        stack = true,
        close = true,
        consume = 0,
        description = 'Um tomo runico que guarda o aprendizado de Glacies.',
        client = {
            image = 'livro_petrificus.png',
            event = 'ob_aprendizado:client:useLearningItem'
        }
    },

    ['livro_portus'] = {
        label = 'Livro de Portus',
        weight = 300,
        stack = true,
        close = true,
        consume = 0,
        description = 'Um tomo runico que guarda o aprendizado de Portus.',
        client = {
            image = 'livro_portus.png',
            event = 'ob_aprendizado:client:useLearningItem'
        }
    },

    ['livro_invulneris'] = {
        label = 'Livro de Invulneris',
        weight = 300,
        stack = true,
        close = true,
        consume = 0,
        description = 'Um tomo runico que guarda o aprendizado de Invulneris.',
        client = {
            image = 'livro_invulneris.png',
            event = 'ob_aprendizado:client:useLearningItem'
        }
    },

    ['livro_ignis_conflagratio'] = {
        label = 'Livro de Ignis Conflagratio',
        weight = 300,
        stack = true,
        close = true,
        consume = 0,
        description = 'Um tomo runico que guarda o aprendizado de Ignis Conflagratio.',
        client = {
            image = 'livro_ignis_conflagratio.png',
            event = 'ob_aprendizado:client:useLearningItem'
        }
    },

    ['livro_metamorphus_fauna'] = {
        label = 'Livro de Metamorphus Fauna',
        weight = 300,
        stack = true,
        close = true,
        consume = 0,
        description = 'Um tomo runico que guarda o aprendizado de Metamorphus Fauna.',
        client = {
            image = 'livro_metamorphus_fauna.png',
            event = 'ob_aprendizado:client:useLearningItem'
        }
    },

    ['witch_pouch'] = {
        label = 'Bolsa Arcana',
        weight = 350,
        stack = false,
        close = true,
        consume = 0,
        description = 'Uma bolsinha encantada vinculada a sua proprietaria.',
        client = {
            image = 'witch_pouch.png',
            event = 'ox_inventory:openWitchPouch'
        }
    },

    ['amuleto_latente'] = {
        label = 'Amuleto do Fôlego Ancestral',
        weight = 80,
        stack = false,
        close = false,
        consume = 0,
        degrade = 43200,
        decay = true,
        equipment = 'amulet',
        attributes = {
            artifact = true,
            artifactId = 'amuleto_latente',
            artifactClass = 'humano',
            durationDays = 30,
        },
        description = 'Melhora em 10% a recuperação de stamina e a respiração submersa de humanos. Válido por 30 dias.',
        client = {
            image = '10kgoldchain.png'
        }
    },

    ['colar_latente'] = {
        label = 'Colar da Sabedoria Ancestral',
        weight = 90,
        stack = false,
        close = false,
        consume = 0,
        degrade = 10080,
        decay = true,
        equipment = 'necklace',
        attributes = {
            artifact = true,
            artifactId = 'colar_latente',
            artifactClass = 'humano',
            durationDays = 7,
        },
        description = 'Aumenta em 25 a vida máxima de humanos. Válido por 7 dias.',
        client = {
            image = 'goldchain.png'
        }
    },

    ['cinto_latente'] = {
        label = 'Cinto do Alento Humano',
        weight = 220,
        stack = false,
        close = false,
        consume = 0,
        degrade = 43200,
        decay = true,
        equipment = 'belt',
        attributes = {
            artifact = true,
            artifactId = 'cinto_latente',
            artifactClass = 'humano',
            durationDays = 30,
        },
        description = 'Aumenta em 25% a eficiência das poções usadas por humanos. Válido por 30 dias.',
        client = {
            image = 'harness.png'
        }
    },

    ['anel_latente'] = {
        label = 'Anel do Vigor Ancestral',
        weight = 20,
        stack = false,
        close = false,
        consume = 0,
        degrade = 43200,
        decay = true,
        equipment = 'ring',
        attributes = {
            artifact = true,
            artifactId = 'anel_latente',
            artifactClass = 'humano',
            durationDays = 30,
        },
        description = 'Regenera 5 de vida por minuto quando equipado por um humano. Válido por 30 dias.',
        client = {
            image = 'diamond_ring.png'
        }
    },

    ['lockpick'] = {
        label = 'Lockpick',
        weight = 160,
    },

    ['phone'] = {
        label = 'Celular',
        weight = 190,
        stack = false,
        consume = 0
    },  

    ['wireless_earbuds'] = {
        label = 'Wireless Earbuds',
        weight = 120,
        stack = true,
        close = true,
        server = {
            export = 'qs-smartphone.useWirelessEarbuds'
        }
    },

    ['powerbank'] = {
        label = 'Powerbank',
        weight = 300,
        stack = true,
        close = true,
        server = {
            export = 'qs-smartphone.usePowerbank'
        }
    },

    ['phone_sim'] = {
        label = 'SIM Card',
        weight = 45,
        stack = false,
        consume = 0,
        close = true,
        server = {
            export = 'qs-smartphone.useSimCard'
        }
    },

    ['mustard'] = {
        label = 'Mustard',
        weight = 500,
        client = {
            status = { hunger = 25000, thirst = 25000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_food_mustard`, pos = vec3(0.01, 0.0, -0.07), rot = vec3(1.0, 1.0, -1.5) },
            usetime = 2500,
            notification = 'You... drank mustard'
        }
    },

    ['water'] = {
        label = 'Water',
        weight = 500,
        client = {
            status = { thirst = 200000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
            usetime = 2500,
            cancel = true,
            notification = 'You drank some refreshing water'
        }
    },

    ['coca_cola'] = {
        label = 'Coca-Cola',
        weight = 350,
        stack = true,
        close = true,
        client = {
            image = 'coca_cola.png',
            status = { thirst = 180000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ecola_can`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) },
            usetime = 2500,
            cancel = true,
            notification = 'Você bebeu uma Coca-Cola gelada.'
        }
    },

    ['agua'] = {
        label = 'Água',
        weight = 500,
        stack = true,
        close = true,
        client = {
            image = 'agua.png',
            status = { thirst = 220000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
            usetime = 2500,
            cancel = true,
            notification = 'Você bebeu uma água refrescante.'
        }
    },

    ['taco'] = {
        label = 'Taco',
        weight = 260,
        stack = true,
        close = true,
        client = {
            image = 'taco.png',
            status = { hunger = 220000 },
            anim = 'eating',
            prop = { model = `prop_taco_01`, pos = vec3(0.02, 0.01, -0.02), rot = vec3(-70.0, 0.0, 0.0) },
            usetime = 2500,
            cancel = true,
            notification = 'Você comeu um taco.'
        }
    },

    ['chocolate'] = {
        label = 'Chocolate',
        weight = 120,
        stack = true,
        close = true,
        client = {
            image = 'chocolate.png',
            status = { hunger = 100000, stress = -100000 },
            anim = 'eating',
            prop = { model = `prop_choc_ego`, pos = vec3(0.02, 0.01, -0.02), rot = vec3(-70.0, 0.0, 0.0) },
            usetime = 1800,
            cancel = true,
            notification = 'Você comeu um chocolate e se sentiu mais tranquilo.'
        }
    },

    -- Compatibilidade com as recompensas opcionais do tw-litejobpack.
    ['water_bottle'] = {
        label = 'Água',
        weight = 500,
        stack = true,
        close = true,
        client = {
            image = 'water_bottle.png',
            status = { thirst = 200000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
            usetime = 2500,
            cancel = true,
            notification = 'Você bebeu uma água refrescante.'
        }
    },

    ['armour'] = {
        label = 'Bulletproof Vest',
        weight = 3000,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 3500
        }
    },

    ['clothing'] = {
        label = 'Clothing',
        consume = 0,
    },

    ['money'] = {
        label = 'Money',
    },

    ['black_money'] = {
        label = 'Dirty Money',
    },

    ['id_card'] = {
        label = 'Identification Card',
    },

    ['driver_license'] = {
        label = 'Drivers License',
    },

    ['weaponlicense'] = {
        label = 'Weapon License',
    },

    ['lawyerpass'] = {
        label = 'Lawyer Pass',
    },

    ['radio'] = {
        label = 'Rádio',
        weight = 1000,
        allowArmed = true,
        consume = 0,
        client = {
            image = 'radio.png',
            export = 'aty_radio.useRadio'
        }
    },

    ['jammer'] = {
        label = 'Radio Jammer',
        weight = 10000,
        allowArmed = true,
        client = {
            event = 'mm_radio:client:usejammer'
        }
    },

    ['radiocell'] = {
        label = 'AAA Cells',
        weight = 1000,
        stack = true,
        allowArmed = true,
        client = {
            event = 'mm_radio:client:recharge'
        }
    },

    ['advancedlockpick'] = {
        label = 'Advanced Lockpick',
        weight = 500,
    },

    ['screwdriverset'] = {
        label = 'Screwdriver Set',
        weight = 500,
    },

    ['electronickit'] = {
        label = 'Electronic Kit',
        weight = 500,
    },

    ['dispositivo_hacking'] = {
        label = 'Dispositivo de Hacking',
        weight = 650,
        stack = false,
        close = true,
        description = 'Terminal portatil preparado para romper sistemas bancarios.',
        client = {
            image = 'electronickit.png',
        },
    },

    ['cleaningkit'] = {
        label = 'Cleaning Kit',
        weight = 500,
    },

    ['repairkit'] = {
        label = 'Kit de Reparo',
        weight = 2500,
        stack = true,
        close = true,
        description = 'Ferramentas para reparos mecânicos emergenciais.',
        client = { image = 'repairkit.png' },
    },

    ['tirerepairkit'] = {
        label = 'Kit de Reparo de Pneu',
        weight = 1800,
        stack = true,
        close = true,
        description = 'Ferramentas e remendos para substituir um pneu danificado.',
        client = { image = 'tirerepairkit.png' },
    },

    ['advancedrepairkit'] = {
        label = 'Advanced Repair Kit',
        weight = 4000,
    },

    ['diamond_ring'] = {
        label = 'Diamond',
        weight = 1500,
    },

    ['rolex'] = {
        label = 'Golden Watch',
        weight = 1500,
    },

    ['goldbar'] = {
        label = 'Gold Bar',
        weight = 1500,
    },

    ['goldchain'] = {
        label = 'Golden Chain',
        weight = 1500,
    },

    ['crack_baggy'] = {
        label = 'Crack Baggy',
        weight = 100,
    },

    ['cokebaggy'] = {
        label = 'Bag of Coke',
        weight = 100,
    },

    ['coke_brick'] = {
        label = 'Coke Brick',
        weight = 2000,
    },

    ['coke_small_brick'] = {
        label = 'Coke Package',
        weight = 1000,
    },

    ['xtcbaggy'] = {
        label = 'Bag of Ecstasy',
        weight = 100,
    },

    ['meth'] = {
        label = 'Methamphetamine',
        weight = 100,
    },

    ['oxy'] = {
        label = 'Oxycodone',
        weight = 100,
    },

    ['weed_ak47'] = {
        label = 'AK47 2g',
        weight = 200,
    },

    ['weed_ak47_seed'] = {
        label = 'AK47 Seed',
        weight = 1,
    },

    ['weed_skunk'] = {
        label = 'Skunk 2g',
        weight = 200,
    },

    ['weed_skunk_seed'] = {
        label = 'Skunk Seed',
        weight = 1,
    },

    ['weed_amnesia'] = {
        label = 'Amnesia 2g',
        weight = 200,
    },

    ['weed_amnesia_seed'] = {
        label = 'Amnesia Seed',
        weight = 1,
    },

    ['weed_og-kush'] = {
        label = 'OGKush 2g',
        weight = 200,
    },

    ['weed_og-kush_seed'] = {
        label = 'OGKush Seed',
        weight = 1,
    },

    ['weed_white-widow'] = {
        label = 'OGKush 2g',
        weight = 200,
    },

    ['weed_white-widow_seed'] = {
        label = 'White Widow Seed',
        weight = 1,
    },

    ['weed_purple-haze'] = {
        label = 'Purple Haze 2g',
        weight = 200,
    },

    ['weed_purple-haze_seed'] = {
        label = 'Purple Haze Seed',
        weight = 1,
    },

    ['weed_brick'] = {
        label = 'Weed Brick',
        weight = 2000,
    },

    ['weed_nutrition'] = {
        label = 'Plant Fertilizer',
        weight = 2000,
    },

    ['joint'] = {
        label = 'Joint',
        weight = 200,
    },

    ['rolling_paper'] = {
        label = 'Rolling Paper',
        weight = 0,
    },

    ['empty_weed_bag'] = {
        label = 'Empty Weed Bag',
        weight = 0,
    },


    ['ifaks'] = {
        label = 'Individual First Aid Kit',
        weight = 2500,
    },


    ['firework1'] = {
        label = '2Brothers',
        weight = 1000,
    },

    ['firework2'] = {
        label = 'Poppelers',
        weight = 1000,
    },

    ['firework3'] = {
        label = 'WipeOut',
        weight = 1000,
    },

    ['firework4'] = {
        label = 'Weeping Willow',
        weight = 1000,
    },

    ['steel'] = {
        label = 'Steel',
        weight = 100,
    },

    ['rubber'] = {
        label = 'Rubber',
        weight = 100,
    },

    ['metalscrap'] = {
        label = 'Metal Scrap',
        weight = 100,
    },

    ['iron'] = {
        label = 'Iron',
        weight = 100,
    },

    ['copper'] = {
        label = 'Copper',
        weight = 100,
    },

    ['aluminum'] = {
        label = 'Aluminium',
        weight = 100,
    },

    ['plastic'] = {
        label = 'Plastic',
        weight = 100,
    },

    ['glass'] = {
        label = 'Glass',
        weight = 100,
    },

    ['gatecrack'] = {
        label = 'Gatecrack',
        weight = 1000,
    },

    ['cryptostick'] = {
        label = 'Crypto Stick',
        weight = 100,
    },

    ['trojan_usb'] = {
        label = 'Trojan USB',
        weight = 100,
    },

    ['toaster'] = {
        label = 'Toaster',
        weight = 5000,
    },

    ['small_tv'] = {
        label = 'Small TV',
        weight = 100,
    },

    ['security_card_01'] = {
        label = 'Security Card A',
        weight = 100,
    },

    ['security_card_02'] = {
        label = 'Security Card B',
        weight = 100,
    },

    ['drill'] = {
        label = 'Drill',
        weight = 5000,
    },

    ['thermite'] = {
        label = 'Thermite',
        weight = 1000,
    },

    ['diving_gear'] = {
        label = 'Diving Gear',
        weight = 30000,
    },

    ['diving_fill'] = {
        label = 'Diving Tube',
        weight = 3000,
    },

    ['antipatharia_coral'] = {
        label = 'Coral Antipatharia',
        weight = 1000,
        stack = true,
        close = true,
        description = 'Coral negro, também conhecido como coral-espinho.',
        client = { image = 'antipatharia_coral.png' },
    },

    ['dendrogyra_coral'] = {
        label = 'Coral Dendrogyra',
        weight = 1000,
        stack = true,
        close = true,
        description = 'Coral raro, também conhecido como coral-pilar.',
        client = { image = 'dendrogyra_coral.png' },
    },

    ['jerry_can'] = {
        label = 'Jerrycan',
        weight = 3000,
    },

    ['nitrous'] = {
        label = 'Nitrous',
        weight = 1000,
    },

    ['wine'] = {
        label = 'Wine',
        weight = 500,
    },

    ['grape'] = {
        label = 'Grape',
        weight = 10,
    },

    ['grapejuice'] = {
        label = 'Grape Juice',
        weight = 200,
    },

    ['coffee'] = {
        label = 'Coffee',
        weight = 200,
    },

    ['vodka'] = {
        label = 'Vodka',
        weight = 500,
    },

    ['whiskey'] = {
        label = 'Whiskey',
        weight = 200,
    },

    ['beer'] = {
        label = 'Beer',
        weight = 200,
    },

    ['sandwich'] = {
        label = 'Sandwich',
        weight = 200,
    },

    ['walking_stick'] = {
        label = 'Walking Stick',
        weight = 1000,
    },

    ['lighter'] = {
        label = 'Lighter',
        weight = 200,
    },

    ['binoculars'] = {
        label = 'Binoculars',
        weight = 800,
    },

    ['stickynote'] = {
        label = 'Sticky Note',
        weight = 0,
    },

    ['empty_evidence_bag'] = {
        label = 'Empty Evidence Bag',
        weight = 200,
    },

    ['filled_evidence_bag'] = {
        label = 'Filled Evidence Bag',
        weight = 200,
    },

    ['harness'] = {
        label = 'Harness',
        weight = 200,
    },

    ['handcuffs'] = {
        label = 'Handcuffs',
        weight = 200,
    },

    ['pao'] = {
        label = 'Pão artesanal',
        weight = 100,
        stack = true,
        client = { image = 'sandwich.png' },
    },

	['carne'] = {
		label = 'Carne preparada',
		weight = 180,
		stack = true,
		client = { image = 'burger.png' },
	},

    ['produto_restaurante'] = { 
        label = 'Produto de restaurante', 
        description = 'Produto preparado por um estabelecimento.', 
        weight = 0, 
        stack = true, 
        close = true, 
        consume = 1, 
        client = { 
            image = 'burger.png', 
            export = 'ob_restaurantes.useRestaurantProduct' 
        } 
    },


	['frasco_vazio'] = {
		label = 'Frasco vazio',
		description = 'Um frasco limpo usado para armazenar sangue sobrenatural.',
		weight = 80,
		stack = true,
		close = true,
		client = { image = 'frasco_vazio.png' },
	},

	['sangue_puma'] = {
		label = 'Sangue de puma',
		description = 'Sangue sobrenatural extraído de um puma recém-abatido.',
		weight = 320,
		stack = true,
		close = true,
		client = { image = 'sangue_puma.png' },
	},

	['carne_puma'] = {
		label = 'Carne de puma',
		description = 'Carne crua obtida durante a coleta de uma carcaça de puma.',
		weight = 420,
		stack = true,
		close = true,
		client = { image = 'carne_puma.png' },
	},

	['couro_puma'] = {
		label = 'Couro de puma',
		description = 'Couro resistente retirado de um puma abatido.',
		weight = 650,
		stack = true,
		close = true,
		client = { image = 'couro_puma.png' },
	},
    ['caixa_colares'] = {
		label = 'Caixa de Colares de Classe',
		description = 'Permite escolher um dos quatro colares de classe.',
		weight = 900,
		stack = false,
		close = true,
		consume = 0,
		client = { image = 'caixa_colares.png' },
		server = { export = 'ob_boxes.useBox' },
	},

	['caixa_elixires'] = {
		label = 'Caixa de Elixires',
		description = 'Permite escolher um dos quatro elixires de classe.',
		weight = 700,
		stack = false,
		close = true,
		consume = 0,
		client = { image = 'caixa_elixires.png' },
		server = { export = 'ob_boxes.useBox' },
	},

	['caixa_amuletos'] = {
		label = 'Caixa de Amuletos de Classe',
		description = 'Permite escolher um dos quatro amuletos de classe, válidos por 30 dias.',
		weight = 900,
		stack = false,
		close = true,
		consume = 0,
		client = { image = 'caixa_amuletos.png' },
		server = { export = 'ob_boxes.useBox' },
	},

	['caixa_aneis'] = {
		label = 'Caixa de Anéis de Classe',
		description = 'Permite escolher um dos quatro anéis de classe, válidos por 30 dias.',
		weight = 650,
		stack = false,
		close = true,
		consume = 0,
		client = { image = 'caixa_aneis.png' },
		server = { export = 'ob_boxes.useBox' },
	},

	['caixa_cintos'] = {
		label = 'Caixa de Cintos de Classe',
		description = 'Permite escolher um dos quatro cintos de classe, válidos por 30 dias.',
		weight = 1100,
		stack = false,
		close = true,
		consume = 0,
		client = { image = 'caixa_cintos.png' },
		server = { export = 'ob_boxes.useBox' },
	},

	['caixa_pocoes_2'] = {
		label = 'Caixa de Poções II',
		description = 'Permite escolher uma poção de restauração total para uma classe.',
		weight = 700,
		stack = false,
		close = true,
		consume = 0,
		client = { image = 'caixa_pocoes_2.png' },
		server = { export = 'ob_boxes.useBox' },
	},

	['pocao_mana'] = {
		label = 'Poção de Mana',
		description = 'Restaura 40 de mana. Uso exclusivo para bruxas.',
		weight = 250,
		stack = true,
		close = true,
		consume = 1,
		client = {
			image = 'pocao_mana.png',
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.02, 0.02, 0.02), rot = vec3(0.0, 0.0, -1.5) },
			usetime = 3500,
		},
		server = { export = 'ob_boxes.usePotion' },
	},

	['elixir_fadas'] = {
		label = 'Elixir das Fadas',
		description = 'Restaura 40 de energia. Uso exclusivo para curandeiras.',
		weight = 250,
		stack = true,
		close = true,
		consume = 1,
		client = {
			image = 'elixir_fadas.png',
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.02, 0.02, 0.02), rot = vec3(0.0, 0.0, -1.5) },
			usetime = 3500,
		},
		server = { export = 'ob_boxes.usePotion' },
	},

	['elixir_sangue'] = {
		label = 'Elixir de Sangue',
		description = 'Restaura 40 de sangue. Uso exclusivo para vampiros.',
		weight = 280,
		stack = true,
		close = true,
		consume = 1,
		client = {
			image = 'elixir_sangue.png',
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.02, 0.02, 0.02), rot = vec3(0.0, 0.0, -1.5) },
			usetime = 3500,
		},
		server = { export = 'ob_boxes.usePotion' },
	},

	['elixir_sabedoria'] = {
		label = 'Elixir da Sabedoria',
		description = 'Cura 50 de vida e deixa a velocidade em 1.25 por 10 minutos. Uso exclusivo para humanos.',
		weight = 280,
		stack = true,
		close = true,
		consume = 1,
		client = {
			image = 'elixir_sabedoria.png',
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.02, 0.02, 0.02), rot = vec3(0.0, 0.0, -1.5) },
			usetime = 3500,
		},
		server = { export = 'ob_boxes.usePotion' },
	},

	['pocao_restauracao_arcana'] = {
		label = 'Poção de Restauração Arcana',
		description = 'Restaura totalmente vida, fome, sede, stress, sangramentos e dores. Uso exclusivo para bruxas.',
		weight = 300,
		stack = true,
		close = true,
		consume = 1,
		client = {
			image = 'pocao_restauracao_arcana.png',
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.02, 0.02, 0.02), rot = vec3(0.0, 0.0, -1.5) },
			usetime = 3500,
		},
		server = { export = 'ob_boxes.usePotion' },
	},

	['pocao_restauracao_feerica'] = {
		label = 'Poção de Restauração Feérica',
		description = 'Restaura totalmente vida, fome, sede, stress, sangramentos e dores. Uso exclusivo para curandeiras.',
		weight = 300,
		stack = true,
		close = true,
		consume = 1,
		client = {
			image = 'pocao_restauracao_feerica.png',
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.02, 0.02, 0.02), rot = vec3(0.0, 0.0, -1.5) },
			usetime = 3500,
		},
		server = { export = 'ob_boxes.usePotion' },
	},

	['pocao_restauracao_sanguinea'] = {
		label = 'Poção de Restauração Sanguínea',
		description = 'Restaura totalmente vida, fome, sede, stress, sangramentos e dores. Uso exclusivo para vampiros.',
		weight = 320,
		stack = true,
		close = true,
		consume = 1,
		client = {
			image = 'pocao_restauracao_sanguinea.png',
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.02, 0.02, 0.02), rot = vec3(0.0, 0.0, -1.5) },
			usetime = 3500,
		},
		server = { export = 'ob_boxes.usePotion' },
	},

	['pocao_restauracao_humana'] = {
		label = 'Poção de Restauração Humana',
		description = 'Restaura totalmente vida, fome, sede, stress, sangramentos e dores. Uso exclusivo para humanos.',
		weight = 300,
		stack = true,
		close = true,
		consume = 1,
		client = {
			image = 'pocao_restauracao_humana.png',
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.02, 0.02, 0.02), rot = vec3(0.0, 0.0, -1.5) },
			usetime = 3500,
		},
		server = { export = 'ob_boxes.usePotion' },
	},


	['amuleto_eclipse'] = {
		label = 'Amuleto do Eclipse',
		description = 'Protege vampiros da luz solar quando equipado. Válido por 30 dias.',
		weight = 180,
		stack = false,
		close = false,
		consume = 0,
		degrade = 43200,
		decay = true,
		equipment = 'amulet',
		attributes = {
			artifact = true,
			artifactId = 'amuleto_eclipse',
			artifactClass = 'vampiro',
			durationDays = 30,
			solarProtection = true,
		},
		client = { image = 'amuleto_eclipse.png' },
	},

	['anel_sangue_ancestral'] = {
		label = 'Anel do Sangue Ancestral',
		description = 'Reduz pela metade o custo de sangue dos poderes de vampiro. Custos de 1 não são reduzidos. Válido por 30 dias.',
		weight = 35,
		stack = false,
		close = false,
		consume = 0,
		degrade = 43200,
		decay = true,
		equipment = 'ring',
		attributes = {
			artifact = true,
			artifactId = 'anel_sangue_ancestral',
			artifactClass = 'vampiro',
			durationDays = 30,
		},
		client = { image = 'anel_sangue_ancestral.png' },
	},

	['colar_veu_noturno'] = {
		label = 'Colar do Véu Noturno',
		description = 'Um colar frio que parece absorver a luz ao redor. Válido por 7 dias.',
		weight = 90,
		stack = false,
		close = false,
		consume = 0,
		degrade = 10080,
		decay = true,
		equipment = 'necklace',
		attributes = {
			artifact = true,
			artifactId = 'colar_veu_noturno',
			artifactClass = 'vampiro',
			durationDays = 7,
		},
		client = { image = 'colar_veu_noturno.png' },
	},

	['cinto_presa_carmesim'] = {
		label = 'Cinto da Presa Carmesim',
		description = 'Aumenta em 25% a eficiência das poções usadas por vampiros. Válido por 30 dias.',
		weight = 190,
		stack = false,
		close = false,
		consume = 0,
		degrade = 43200,
		decay = true,
		equipment = 'belt',
		attributes = {
			artifact = true,
			artifactId = 'cinto_presa_carmesim',
			artifactClass = 'vampiro',
			durationDays = 30,
		},
		client = { image = 'cinto_presa_carmesim.png' },
	},

	['amuleto_veu_arcano'] = {
		label = 'Amuleto do Véu Arcano',
		description = 'Regenera 5 de mana por minuto quando equipado por uma bruxa. Válido por 30 dias.',
		weight = 80,
		stack = false,
		close = false,
		consume = 0,
		degrade = 43200,
		decay = true,
		equipment = 'amulet',
		attributes = {
			artifact = true,
			artifactId = 'amuleto_veu_arcano',
			artifactClass = 'bruxa',
			durationDays = 30,
		},
		client = { image = 'amuleto_veu_arcano.png' },
	},

	['anel_eco_runico'] = {
		label = 'Anel do Eco Rúnico',
		description = 'Reduz pela metade o custo de mana dos poderes de bruxa. Custos de 1 não são reduzidos. Válido por 30 dias.',
		weight = 30,
		stack = false,
		close = false,
		consume = 0,
		degrade = 43200,
		decay = true,
		equipment = 'ring',
		attributes = {
			artifact = true,
			artifactId = 'anel_eco_runico',
			artifactClass = 'bruxa',
			durationDays = 30,
		},
		client = { image = 'anel_eco_runico.png' },
	},

	['colar_foco_cristalino'] = {
		label = 'Colar do Foco Cristalino',
		description = 'Um cristal lapidado para estabilizar a concentração arcana. Válido por 7 dias.',
		weight = 95,
		stack = false,
		close = false,
		consume = 0,
		degrade = 10080,
		decay = true,
		equipment = 'necklace',
		attributes = {
			artifact = true,
			artifactId = 'colar_foco_cristalino',
			artifactClass = 'bruxa',
			durationDays = 7,
		},
		client = { image = 'colar_foco_cristalino.png' },
	},

	['cinto_selo_da_lua'] = {
		label = 'Cinto do Selo da Lua',
		description = 'Aumenta em 25% a eficiência das poções usadas por bruxas. Válido por 30 dias.',
		weight = 200,
		stack = false,
		close = false,
		consume = 0,
		degrade = 43200,
		decay = true,
		equipment = 'belt',
		attributes = {
			artifact = true,
			artifactId = 'cinto_selo_da_lua',
			artifactClass = 'bruxa',
			durationDays = 30,
		},
		client = { image = 'cinto_selo_da_lua.png' },
	},

	['amuleto_seiva_sagrada'] = {
		label = 'Amuleto da Seiva Sagrada',
		description = 'Regenera 5 de energia por minuto e fortalece os poderes da curandeira, exceto voo. Válido por 30 dias.',
		weight = 85,
		stack = false,
		close = false,
		consume = 0,
		degrade = 43200,
		decay = true,
		equipment = 'amulet',
		attributes = {
			artifact = true,
			artifactId = 'amuleto_seiva_sagrada',
			artifactClass = 'curandeira',
			durationDays = 30,
		},
		client = { image = 'amuleto_seiva_sagrada.png' },
	},

	['anel_segundo_folego'] = {
		label = 'Anel do Segundo Fôlego',
		description = 'Reduz pela metade o custo de energia dos poderes da curandeira. Custos de 1 não são reduzidos. Válido por 30 dias.',
		weight = 30,
		stack = false,
		close = false,
		consume = 0,
		degrade = 43200,
		decay = true,
		equipment = 'ring',
		attributes = {
			artifact = true,
			artifactId = 'anel_segundo_folego',
			artifactClass = 'curandeira',
			durationDays = 30,
		},
		client = { image = 'anel_segundo_folego.png' },
	},

	['colar_pulso_sereno'] = {
		label = 'Colar do Pulso Sereno',
		description = 'A pedra azul acompanha o ritmo da energia vital. Válido por 7 dias.',
		weight = 90,
		stack = false,
		close = false,
		consume = 0,
		degrade = 10080,
		decay = true,
		equipment = 'necklace',
		attributes = {
			artifact = true,
			artifactId = 'colar_pulso_sereno',
			artifactClass = 'curandeira',
			durationDays = 7,
		},
		client = { image = 'colar_pulso_sereno.png' },
	},

	['cinto_guardiao_vital'] = {
		label = 'Cinto do Guardião Vital',
		description = 'Aumenta em 25% a eficiência das poções usadas por curandeiras. Válido por 30 dias.',
		weight = 195,
		stack = false,
		close = false,
		consume = 0,
		degrade = 43200,
		decay = true,
		equipment = 'belt',
		attributes = {
			artifact = true,
			artifactId = 'cinto_guardiao_vital',
			artifactClass = 'curandeira',
			durationDays = 30,
		},
		client = { image = 'cinto_guardiao_vital.png' },
	},

	['relicario_crepusculo'] = {
		label = 'Relicário do Crepúsculo',
		description = 'Artefato híbrido de bruxa e vampiro reservado ao Passe. Válido por 7 dias.',
		weight = 100,
		stack = false,
		close = false,
		consume = 0,
		degrade = 10080,
		decay = true,
		equipment = 'amulet',
		attributes = {
			artifact = true,
			artifactId = 'relicario_crepusculo',
			artifactClasses = { bruxa = true, vampiro = true },
			hybrid = true,
			passArtifact = true,
			durationDays = 7,
		},
		client = { image = 'relicario_crepusculo.png' },
	},

	['broche_lua_rubra'] = {
		label = 'Broche da Lua Rubra',
		description = 'Artefato híbrido de vampiro e curandeira reservado ao Passe. Válido por 7 dias.',
		weight = 70,
		stack = false,
		close = false,
		consume = 0,
		degrade = 10080,
		decay = true,
		equipment = 'necklace',
		attributes = {
			artifact = true,
			artifactId = 'broche_lua_rubra',
			artifactClasses = { vampiro = true, curandeira = true },
			hybrid = true,
			passArtifact = true,
			durationDays = 7,
		},
		client = { image = 'broche_lua_rubra.png' },
	},

	['selo_alvorada_arcana'] = {
		label = 'Selo da Alvorada Arcana',
		description = 'Artefato híbrido de bruxa e curandeira reservado ao Passe. Válido por 7 dias.',
		weight = 35,
		stack = false,
		close = false,
		consume = 0,
		degrade = 10080,
		decay = true,
		equipment = 'ring',
		attributes = {
			artifact = true,
			artifactId = 'selo_alvorada_arcana',
			artifactClasses = { bruxa = true, curandeira = true },
			hybrid = true,
			passArtifact = true,
			durationDays = 7,
		},
		client = { image = 'selo_alvorada_arcana.png' },
	},

	['cinturao_convergencia'] = {
		label = 'Cinturão da Convergência',
		description = 'Artefato híbrido das três essências reservado ao Passe. Válido por 7 dias.',
		weight = 220,
		stack = false,
		close = false,
		consume = 0,
		degrade = 10080,
		decay = true,
		equipment = 'belt',
		attributes = {
			artifact = true,
			artifactId = 'cinturao_convergencia',
			artifactClasses = { bruxa = true, vampiro = true, curandeira = true },
			hybrid = true,
			passArtifact = true,
			durationDays = 7,
		},
		client = { image = 'cinturao_convergencia.png' },
	},

    ['salad'] = {
        label = 'Salada fresca',
        weight = 80,
        stack = true,
    },

    ['batata'] = {
        label = 'Batata',
        weight = 120,
        stack = true,
        client = { image = 'fries.png' },
    },

    ['xarope'] = {
        label = 'Xarope de refrigerante',
        weight = 120,
        stack = true,
        client = { image = 'cola.png' },
    },

    ['hamburguer'] = {
        label = 'Hambúrguer Ravenwood',
        weight = 280,
        stack = true,
        close = true,
        consume = 1,
        client = { image = 'burger.png', anim = 'eating', prop = 'burger', usetime = 2500, cancel = true },
    },

    ['batata_frita'] = {
        label = 'Batatas da Casa',
        weight = 180,
        stack = true,
        close = true,
        consume = 1,
        client = {
            image = 'fries.png',
            anim = 'eating',
            prop = { model = `prop_food_bs_chips`, pos = vec3(0.02, 0.01, -0.02), rot = vec3(-70.0, 0.0, 0.0) },
            usetime = 2500,
            cancel = true
        },
    },

    ['refrigerante'] = {
        label = 'Refrigerante',
        weight = 300,
        stack = true,
        close = true,
        consume = 1,
        client = {
            image = 'cola.png',
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_can_01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) },
            usetime = 2500,
            cancel = true
        },
    },

    ['combo_box'] = {
        label = 'Box Ravenwood',
        weight = 850,
        stack = false,
        close = true,
        consume = 1,
        client = { image = 'pizza_ham_box.png', anim = 'eating', prop = 'burger', usetime = 3200, cancel = true },
    },

    -- tw-litejobpack: pesca
    ['fish_anchovy'] = {
        label = 'Anchova',
        weight = 100,
        stack = true,
        description = 'Uma anchova fresca.',
        client = { image = 'fish_anchovy.png' },
    },

    ['fish_trout'] = {
        label = 'Truta',
        weight = 200,
        stack = true,
        description = 'Uma truta fresca.',
        client = { image = 'fish_trout.png' },
    },

    ['fish_mackerel'] = {
        label = 'Cavala',
        weight = 150,
        stack = true,
        description = 'Uma cavala fresca.',
        client = { image = 'fish_mackerel.png' },
    },

    ['fish_salmon'] = {
        label = 'Salmão',
        weight = 300,
        stack = true,
        description = 'Um salmão fresco.',
        client = { image = 'fish_salmon.png' },
    },

    ['fish_snapper'] = {
        label = 'Pargo',
        weight = 250,
        stack = true,
        description = 'Um pargo fresco.',
        client = { image = 'fish_snapper.png' },
    },

    ['fish_tuna'] = {
        label = 'Atum',
        weight = 500,
        stack = true,
        description = 'Um atum fresco.',
        client = { image = 'fish_tuna.png' },
    },

    ['fish_grouper'] = {
        label = 'Garoupa',
        weight = 400,
        stack = true,
        description = 'Uma garoupa fresca.',
        client = { image = 'fish_grouper.png' },
    },

    ['fish_swordfish'] = {
        label = 'Peixe-espada',
        weight = 600,
        stack = true,
        description = 'Um peixe-espada fresco.',
        client = { image = 'fish_swordfish.png' },
    },

    ['fish_shark'] = {
        label = 'Tubarão',
        weight = 1000,
        stack = true,
        description = 'Carne de tubarão.',
        client = { image = 'fish_shark.png' },
    },

    -- tw-litejobpack: varas reutilizáveis
    ['standartrod'] = {
        label = 'Vara de pesca padrão',
        weight = 100,
        stack = false,
        close = true,
        consume = 0,
        description = 'Uma vara simples para começar a pescar.',
        client = { image = 'standartrod.png' },
    },

    ['carbonrod'] = {
        label = 'Vara de carbono',
        weight = 200,
        stack = false,
        close = true,
        consume = 0,
        description = 'Uma vara de pesca feita com fibra de carbono.',
        client = { image = 'carbonrod.png' },
    },

    ['prorod'] = {
        label = 'Vara de pesca profissional',
        weight = 300,
        stack = false,
        close = true,
        consume = 0,
        description = 'Uma vara profissional para pescadores experientes.',
        client = { image = 'prorod.png' },
    },

    -- tw-litejobpack: iscas
    ['basicbait'] = {
        label = 'Isca de minhoca',
        weight = 50,
        stack = true,
        description = 'Uma isca básica de minhoca.',
        client = { image = 'basicbait.png' },
    },

    ['spoonlure'] = {
        label = 'Isca colher',
        weight = 100,
        stack = true,
        description = 'Uma isca metálica em formato de colher.',
        client = { image = 'spoonlure.png' },
    },

    ['threesided'] = {
        label = 'Isca triangular',
        weight = 100,
        stack = true,
        description = 'Uma isca de pesca com três lados.',
        client = { image = 'threesided.png' },
    },

    ['tailfish'] = {
        label = 'Isca rabo de peixe',
        weight = 100,
        stack = true,
        description = 'Uma isca que imita o movimento de um peixe.',
        client = { image = 'tailfish.png' },
    },

    ['doublehook'] = {
        label = 'Isca de anzol duplo',
        weight = 100,
        stack = true,
        description = 'Uma isca equipada com anzol duplo.',
        client = { image = 'doublehook.png' },
    },

    ['triplehook'] = {
        label = 'Isca de anzol triplo',
        weight = 100,
        stack = true,
        description = 'Uma isca equipada com anzol triplo.',
        client = { image = 'triplehook.png' },
    },

    -- tw-litejobpack: detector de metais (usados se lootAsItem for ativado)
    ['md_scrap'] = {
        label = 'Sucata enferrujada',
        weight = 500,
        stack = true,
        description = 'Um pedaço de metal enferrujado encontrado na areia.',
    },

    ['md_coin'] = {
        label = 'Moeda antiga',
        weight = 50,
        stack = true,
        description = 'Uma moeda antiga marcada pelo tempo.',
    },

    ['md_silver'] = {
        label = 'Peça de prata',
        weight = 100,
        stack = true,
        description = 'Um pequeno pedaço de prata manchada.',
    },

    ['md_gold'] = {
        label = 'Pepita de ouro',
        weight = 200,
        stack = true,
        description = 'Uma pequena pepita de ouro.',
    },

    ['md_relic'] = {
        label = 'Relíquia rara',
        weight = 300,
        stack = true,
        description = 'Uma relíquia rara de origem desconhecida.',
    },
}
