fx_version 'cerulean'
game 'gta5'

author 'discord: sinclain'
description 'Exposicao solar configuravel para vampiros da Obscuria'
version '1.0.0'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
}

server_script 'server/main.lua'

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_inventory',
}

