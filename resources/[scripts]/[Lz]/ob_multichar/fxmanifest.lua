fx_version 'cerulean'
game 'gta5'

author 'discord: sinclain'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/assets/fonts/*.woff',
    'web/assets/ui/*.png',
    'web/assets/classes/*.png',
}

dependencies {
    'qbx_core',
    'ox_lib',
}
