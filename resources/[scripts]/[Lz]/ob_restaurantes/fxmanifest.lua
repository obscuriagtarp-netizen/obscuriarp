fx_version 'cerulean'
game 'gta5'

author 'discord: sinclain'

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/assets/**/*'
}

shared_script 'config/config.lua'

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/utils.lua',
    'server/main.lua'
}

dependencies {
    'qbx_core',
    'oxmysql',
    'ox_inventory',
    'ox_target'
}
