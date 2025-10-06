fx_version 'cerulean'
game 'gta5'

name 'qbx_zipties'
description 'Zip Ties System for QBX Framework'
author 'ChrizzyStyle'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

dependencies {
    'qbx_core',
    'ox_inventory',
    'ox_lib',
    'ox_target'
}