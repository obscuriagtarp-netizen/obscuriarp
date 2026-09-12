fx_version 'cerulean'
game 'gta5'

author 'discord: sinclain'
lua54 'yes'

shared_script 'config.lua'
client_script 'client/main.lua'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/assets/ability-slot-frame.png',
    'web/assets/essence-vial-frame.png',
    'web/assets/overload-meter-frame.png',
    'web/assets/keybind-panel-frame.png',
    'web/icons/*.png',
}

dependencies {
    'ob_essencias',
    'ob_manalimit',
}
