fx_version 'cerulean'
game 'gta5'

author 'discord: sinclain'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client.lua',
}

server_script 'server.lua'

dependencies {
    'qbx_core',
    'ox_lib',
    'ob_manalimit',
}
