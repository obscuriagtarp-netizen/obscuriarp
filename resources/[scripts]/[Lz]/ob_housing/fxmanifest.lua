fx_version 'cerulean'
game 'gta5'

name 'ob_housing'
author 'Obscuria'
description 'Apartamentos e casas instanciadas para Qbox'
version '1.1.0'

lua54 'yes'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/styles.css',
    'web/app.js',
    'web/tt-commons.woff',
    'web/images/**/*'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}
