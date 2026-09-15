-- Presets usados quando o cliente consome uma refeicao.
-- Cada prop pode usar um preset pelo campo `animation` ou declarar sua propria
-- tabela de animacao com dict, clip e flag.
Config.RestaurantAnimations = {
    eat = {
        label = 'Comer',
        progressLabel = 'Comendo',
        duration = 2500,
        anim = {
            dict = 'mp_player_inteat@burger',
            clip = 'mp_player_int_eat_burger',
            flag = 49
        }
    },
    drink = {
        label = 'Beber',
        progressLabel = 'Bebendo',
        duration = 2500,
        anim = {
            dict = 'mp_player_intdrink',
            clip = 'loop_bottle',
            flag = 49
        }
    }
}

-- Use `*` para props disponiveis em todos os estabelecimentos e o ID do
-- restaurante para opcoes exclusivas. A opcao marcada como default sera usada
-- automaticamente nas receitas antigas ou quando nenhuma prop for escolhida.
--
-- Campos aceitos por prop:
-- label, image, type (food/drink), default, animation, duration e prop.
-- Em `prop`: model, bone (opcional), position e rotation.
Config.RestaurantProps = {
    ['*'] = {
        burger = {
            label = 'Hamburguer',
            image = 'nui://ox_inventory/web/images/burger.png',
            type = 'food',
            default = true,
            animation = 'eat',
            prop = {
                model = 'prop_cs_burger_01',
                position = vec3(0.02, 0.01, -0.02),
                rotation = vec3(-70.0, 0.0, 0.0)
            }
        },
        sandwich = {
            label = 'Sanduiche',
            image = 'nui://ox_inventory/web/images/sandwich.png',
            type = 'food',
            animation = 'eat',
            prop = {
                model = 'prop_sandwich_01',
                position = vec3(0.13, 0.05, 0.02),
                rotation = vec3(-50.0, 16.0, 60.0)
            }
        },
        donut = {
            label = 'Donut',
            image = 'nui://ox_inventory/web/images/donut.png',
            type = 'food',
            animation = 'eat',
            prop = {
                model = 'prop_amb_donut',
                position = vec3(0.12, 0.04, 0.01),
                rotation = vec3(-50.0, 16.0, 60.0)
            }
        },
        coffee = {
            label = 'Copo de cafe',
            image = 'nui://ox_inventory/web/images/coffee.png',
            type = 'drink',
            default = true,
            animation = 'drink',
            prop = {
                model = 'p_amb_coffeecup_01',
                position = vec3(0.01, 0.01, 0.00),
                rotation = vec3(0.0, 0.0, -180.0)
            }
        },
        soda_can = {
            label = 'Lata de refrigerante',
            image = 'nui://ox_inventory/web/images/coca_cola.png',
            type = 'drink',
            animation = 'drink',
            prop = {
                model = 'prop_ecola_can',
                position = vec3(0.01, 0.01, 0.06),
                rotation = vec3(5.0, 5.0, -180.5)
            }
        },
        water_bottle = {
            label = 'Garrafa de agua',
            image = 'nui://ox_inventory/web/images/water_bottle.png',
            type = 'drink',
            animation = 'drink',
            prop = {
                model = 'prop_ld_flow_bottle',
                position = vec3(0.03, 0.03, 0.02),
                rotation = vec3(0.0, 0.0, -1.5)
            }
        }
    },

    -- Opcoes exclusivas do Dreamy Coffee. Novos restaurantes
    -- seguem o mesmo formato usando exatamente o ID cadastrado no sistema.
    dreamycoffee = {
        dreamy_coffee = {
            label = 'Cafe Dreamy Coffee',
            image = 'nui://ox_inventory/web/images/coffee.png',
            type = 'drink',
            animation = 'drink',
            prop = {
                model = 'p_amb_coffeecup_01',
                position = vec3(0.01, 0.01, 0.00),
                rotation = vec3(0.0, 0.0, -180.0)
            }
        }
    }
}
