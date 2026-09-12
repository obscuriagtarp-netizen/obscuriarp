fx_version 'cerulean'
game 'gta5'

author 'discord: sinclain'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/core.lua',
    'client/bite_animation.lua',
    'client/puma_spawner.lua',
    'client/puma_farm.lua',
    'client/passo_sombrio.lua',
    'client/forma_morcego.lua',
    'client/hipnose.lua',
    'client/abraco_noite.lua',
}

server_scripts {
    'server/puma_spawner.lua',
    'server/main.lua',
}

files {
    'web/icons/*.png',
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'ob_sol_vampiros',
    'ob_essencias',
    'magicSpells',
    'obscuriaHud',
}
