Config = Config or {}

Config.CraftOperations = {
    weapons_basic = {
        label = 'Bancada de armamentos',
        kind = 'weapons',
        animation = 'weapons',
        recipes = {
            {
                id = 'pistol_ammo_pack',
                name = 'Kit de municao de pistola',
                description = 'Estojo montado, conferido e pronto para uso.',
                image = 'pistol_ammo.png',
                duration = 12,
                craftSteps = { 'assemble', 'calibrate', 'seal' },
                visual = { type = 'object', models = { 'prop_box_ammo03a', 'prop_box_ammo04a' } },
                output = { item = 'pistol_ammo', label = 'Municao de pistola', amount = 2 },
                ingredients = {
                    { item = 'steel', label = 'Aco', amount = 3 },
                    { item = 'aluminum', label = 'Aluminio', amount = 2 },
                    { item = 'rubber', label = 'Borracha', amount = 1 }
                }
            },
            {
                id = 'compact_pistol',
                name = 'Pistola compacta',
                description = 'Armacao montada, mecanismo calibrado e acabamento conferido.',
                duration = 32,
                craftSteps = { 'refine', 'assemble', 'calibrate', 'weld', 'seal' },
                visual = { type = 'weapon', weapon = 'WEAPON_PISTOL' },
                output = { item = 'WEAPON_PISTOL', label = 'Pistola compacta', amount = 1 },
                ingredients = {
                    { item = 'steel', label = 'Aco', amount = 12 },
                    { item = 'aluminum', label = 'Aluminio', amount = 8 },
                    { item = 'rubber', label = 'Borracha', amount = 4 }
                }
            }
        }
    },

    narcotics_basic = {
        label = 'Mesa de sintese',
        kind = 'narcotics',
        animation = 'narcotics',
        recipes = {
            {
                id = 'meth_batch',
                name = 'Composto sintetico',
                description = 'Mistura estabilizada e embalada em pequenas porcoes.',
                image = 'meth_baggy.png',
                duration = 18,
                craftSteps = { 'dose', 'synthesize', 'heat', 'stabilize', 'package' },
                visual = { type = 'object', models = { 'bkr_prop_meth_openbag_01a', 'prop_meth_bag_01' } },
                output = { item = 'meth_baggy', label = 'Composto embalado', amount = 2 },
                ingredients = {
                    { item = 'acetone', label = 'Acetona', amount = 1 },
                    { item = 'aluminum', label = 'Aluminio', amount = 2 },
                    { item = 'water', label = 'Agua', amount = 1 }
                }
            }
        }
    }
}
