fx_version 'cerulean'
game 'gta5'

author 'discord: sinclain'
version '3.2.2'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua',
    'spells/**/shared-*.lua',
}

client_scripts {
    'core/client-helpers.lua',
    'core/client-hud.lua',
    'core/client-main.lua',
    'core/client-spellsHud.lua',
    'core/client-grimoire.lua',
    'spells/**/client-*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'core/server-main.lua',
    'spells/**/server-*.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/icons/*.png',
    'html/assets/*.png',
}

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'ob_essencias',
    'ob_aprendizado',
    'grimorio_bola_de_fogo',
    'grimorio_victoria',
    'gelo_assets_preview'
}
