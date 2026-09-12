fx_version 'cerulean'
game 'gta5'
author 'atiysu'
lua54 'yes'

game "gta5"

ui_page 'ui/index.html'

shared_scripts{
  "shared/locale.lua",
  "shared/*.lua",
}

client_scripts {
  "client/utils.lua",
  "client/*.lua",
}
server_script {
  "server/utils.lua",
  "server/*.lua",
}

files {
	'ui/index.html',
	'ui/**/*',
}

escrow_ignore {
  "shared/*.lua",
  "client/*.lua",
  "server/*.lua",
}
dependency '/assetpacks'