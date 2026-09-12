-- Author: Ayazwai <https://ayazwai.dev>
-- Github: https://github.com/ayazwai
-- Discord: https://discord.gg/0resmon
-- LinkendIn: https://www.linkedin.com/in/ayaz-ekrem-770305212/

use_experimental_fxv2_oal 'yes'
fx_version 'bodacious'
lua54 'yes'
game 'gta5'

--[[ Resource Information ]]--

author 'Ayazwai'
version '1.3.0'
scriptname 'wais-hudv6'
description 'FiveM hud with customizable, advanced user interface and features.'

--[[ Resource Information ]]--

shared_scripts {
    'config.lua',
    'locales/*.lua',
    'bridge/editable/location.lua',
    'bridge/editable/weapons.lua',
    'bridge/editable/postal.lua',
    'bridge/framework.lua',
    '@ox_lib/init.lua',
    'bridge/speaker.lua',
}

client_scripts {
    'bridge/editable/belt.lua',
    'bridge/editable/client.lua',
    'bridge/esx/client.lua',
    'bridge/qb/client.lua',
    'client/client.lua',
}

server_scripts {
    'bridge/editable/server.lua',
    'bridge/esx/server.lua',
    'bridge/qb/server.lua',
    'server/server.lua',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/editable/*.lua',
}

dependencys {
    'xsound',
    'ox_lib',
}

ui_page "web/dist/index.html"
files {
    'web/dist/*.js',
    'web/dist/index.html',

    'web/public/*.json',
    'web/public/**/*.png',
    'web/public/css/*.*',
    'web/public/fonts/*.*',
    'web/public/locales/*.json',
}

dependency '/assetpacks'