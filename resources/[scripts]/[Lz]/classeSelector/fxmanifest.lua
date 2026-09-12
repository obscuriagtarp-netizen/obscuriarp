fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'discord: sinclain'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/assets/*.js',
    'html/assets/*.css',
    'html/img/*.png',
    'audio/*.ogg',
    'audio/*.mp3',
    'audio/*.wav',
    'audio/classes/*.ogg',
    'audio/classes/*.mp3',
    'audio/classes/*.wav',
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql',
    'ob_essencias',
    'magicSpells'
}
