fx_version 'cerulean'

game 'gta5'

lua54 'yes'

name 'ob_bank'
author 'Obscuria'
description 'Aplicativo bancario Obscuria para qs-smartphone'
version '1.0.0'

shared_script 'config.lua'

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/credit.lua',
    'server/main.lua',
}

files {
    'ui/build/**/*',
}

escrow_ignore {
    'config.lua',
    'client/main.lua',
    'server/main.lua',
}
