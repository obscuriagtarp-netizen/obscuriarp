fx_version 'cerulean'
game 'gta5'

author 'discord: sinclain'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/core.lua',
    'client/familiar.lua',
    'client/sentido.lua',
    'client/elo.lua',
    'client/nevoa.lua',
}

server_script 'server/main.lua'

ui_page 'web/sentido.html'

files {
    'web/sentido.html',
    'web/sentido.css',
    'web/sentido.js',
    'web/icons/*.png',
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ob_essencias',
    'magicSpells',
    'obscuriaHud',
}
