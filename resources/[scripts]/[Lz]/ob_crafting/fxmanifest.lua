fx_version 'cerulean'
game 'gta5'

author 'discord: sinclain'

dependency 'ob_markers'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/styles.css',
    'web/app.js',
    'web/assets/**/*'
}

shared_scripts {
    'shared/defaults.lua',
    'shared/crafts.lua',
    'config.lua',
    'shared/compile.lua'
}

client_script 'client/main.lua'
server_script 'server/main.lua'
