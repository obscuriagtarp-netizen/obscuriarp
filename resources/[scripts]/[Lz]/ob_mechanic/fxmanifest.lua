fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ob_mechanic'
description 'Automotiva Akuma - customizacao e manutencao veicular da Obscuria'
author 'discord: sinclain'
version '2.1.1'

ui_page 'web/index.html'

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_inventory',
    'oxmysql'
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/assets/*.woff',
    'web/assets/*.png',
    'web/images/**/*.png',
    'web/images/**/*.jpg',
    'web/images/**/*.webp'
}

escrow_ignore {
    'shared/config.lua',
    'client/main.lua',
    'server/main.lua',
    'web/index.html',
    'web/style.css',
    'web/app.js'
}
