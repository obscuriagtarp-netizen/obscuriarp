fx_version 'cerulean'
game 'gta5'

author 'Obscuria | discord: sinclain'
description 'Integracao autenticada de tickets, whitelist e cargos Discord com Qbox'
version '1.1.0'

server_scripts {
    'config.lua',
    'server/profile.lua',
    'server/game.lua',
    'server/roles.lua',
    'server/main.js',
    'server/discord-sync.js'
}
client_script 'client/main.lua'

dependencies { '/onesync', 'qbx_core', 'screenshot-basic' }
