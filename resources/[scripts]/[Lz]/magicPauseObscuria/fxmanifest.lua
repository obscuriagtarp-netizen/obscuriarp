fx_version 'cerulean'
game 'gta5'

name 'Magic Pause Obscuria'
author 'discord: sinclain'

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/**/*',
    'web/imgs/**/*',
}

shared_script {
    'config/config.lua',
    'config/locales/*.lua'
}

client_scripts {
    'client/main.lua',
    'client/views/*.lua',

}

server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "server/utils.lua",
    'server/main.lua',
    'server/views/*.lua',

}

dependencies {
    'qbx_core',
    'oxmysql'
}
