fx_version 'cerulean'
game 'gta5'

name 'Sistema PVP'
author 'NeonDevs/SonoJito'
version '1.3.0'

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

dependencies {
    'es_extended',
    'mysql-async'
}