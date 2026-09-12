fx_version 'cerulean'

game 'gta5'

lua54 'yes'

version '3.1.46'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/functions.lua',
    'shared/utils.lua',
    'shared/core.lua',
    'shared/phone_number_config.lua',

    'config/main.lua',
    'config/music.lua',
    'config/marketplace.lua',
    'config/store.lua',
    'config/tips.lua',
    'config/peachstore.lua',
    'config/appstorage.lua',

    'shared/locale.lua',
    'shared/app_access.lua',
}

client_scripts {
    'client/profiler.lua',
    'client/modules/**',
    'client/apps/**',
    'custom/client.lua',
    'client/custom/**',
    'client/main.lua'
}

ox_libs {
    'table',
    'math',
}

-- ui_page 'http://localhost:3005/' -- Dev
ui_page 'web/build/index.html'

files {
    'web/build/**',
    'web/images/**',
    'web/sounds/**',
    'web/locales/**',
    'custom/**',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/webhooks.lua',
    'custom/server.lua',
    'server/custom/**',

    'server/main.lua',
    'server/modules/**',
    'server/apps/**',

}

dependencies {
    '/onesync',
    'ox_lib',
    'oxmysql',
    'smartphone-prop',
    'xsound',
    -- Uncomment when using vRP framework (Config.Framework = 'vrp'):
    -- 'vrp',
}

--[[
    vRP framework (optional):
    If LoadResourceFile bootstrap fails, uncomment in server_scripts / client_scripts:
    '@vrp/lib/utils.lua',
    and add 'vrp' to dependencies above. Ensure vrp starts before qs-smartphone.
]]

escrow_ignore {
    'client/custom/**',
    'server/custom/**',

    'client/modules/phone_animations.lua',

    'client/apps/houses.lua',
    'server/apps/houses.lua',

    'server/modules/cloudflare_turn.lua',

    'client/apps/icar.lua',
    'server/apps/icar.lua',

    'client/apps/health.lua',

    'client/modules/faceunlock.lua',

    'custom/**/*',
    'server/webhooks.lua',
    'config/*',
    'types.lua',
}

dependency '/assetpacks'