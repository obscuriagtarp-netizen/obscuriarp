fx_version 'cerulean'
game 'gta5'

author 'discord: sinclain'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/wing_catalog.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/core.lua',
    'client/effects.lua',
    'client/wings.lua',
    'client/voo.lua',
    'client/cura_vital.lua',
    'client/serenidade.lua',
    'client/estancar.lua',
}

server_script 'server/main.lua'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/assets/actions/*.png',
    'web/assets/wings/*.png',
    'web/assets/wings/*.json',
    'web/assets/wings/catalog/*.png',
    'web/icons/*.png',
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ob_essencias',
    'magicSpells',
    'obscuriaHud',
    'MathStoreFairyWing-V7',
    'Seatingposepack',
}
