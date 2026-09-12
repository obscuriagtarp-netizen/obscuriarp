fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ob_concessionaria'
author 'discord: sinclain'

ui_page 'web/index.html'

dependencies {
    'ox_lib',
    'qbx_core',
    'qbx_garages',
    'ob_markers',
    'oxmysql'
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
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
    'web/src/main.ts',
    'web/package.json',
    'web/tsconfig.json',
    'web/vite.config.ts',
    'web/assets/images/*.jpeg',
    'web/assets/images/*.webp',
    'web/assets/images/*.png',
    'web/assets/icons/*.png'
}

escrow_ignore {
    'shared/config.lua',
    'client/main.lua',
    'server/main.lua',
    'sql/install.sql',
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/src/main.ts'
}
