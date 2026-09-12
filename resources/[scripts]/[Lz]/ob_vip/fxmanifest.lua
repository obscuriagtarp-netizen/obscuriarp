fx_version 'cerulean'
game 'gta5'

name 'ob_vip'
author 'Obscuria'
description 'Sistema central de VIP para Qbox'
version '2.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}
