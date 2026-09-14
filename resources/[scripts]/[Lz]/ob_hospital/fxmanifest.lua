fx_version 'cerulean'
game 'gta5'

author 'discord: sinclain'
description 'Sistema hospitalar completo da Obscuria'

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/assets/**/*'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/stretcher.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'ob_hospital_assets',
    'qbx_core',
    'qbx_medical',
    'qbx_ambulancejob',
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'ox_target'
}
