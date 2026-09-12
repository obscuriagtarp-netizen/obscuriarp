fx_version 'cerulean'
game 'gta5'

author 'discord: sinclain'
lua54 'yes'

ui_page 'web/build/index.html'

files {
    'web/build/**/*',
    'web/audio.js',
    'web/class-variants.js',
    'web/script.js',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/utils.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/core.lua',
    'client/minigames.lua',
    'client/effects.lua',
    'client/drops.lua',
    'client/atm.lua',
    'client/robberies.lua',
    'client/debug.lua',
}

server_scripts {
    'server/core.lua',
    'server/drops.lua',
    'server/atm.lua',
    'server/robberies.lua',
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'ob_essencias',
}
