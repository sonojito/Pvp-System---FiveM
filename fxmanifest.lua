fx_version 'cerulean'
game 'gta5'

name 'Sistema PVP'
author 'NeonDevs/SonoJito'
version '1.4.0'
description 'Sistema Arena PVP 1v1 con interfaccia NUI moderna'

shared_scripts {
    'config/arena.lua',
    'config/discord.lua'
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/arena.lua'
}

client_scripts {
    '@es_extended/locale.lua',
    'client/arena.lua'
}

-- NUI Interface
ui_page 'html/index.html'

files {
    'html/index.html'
}

dependencies {
    'es_extended',
    'mysql-async'
}