fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'ChrizzyStyle'
description 'Head Bag Script for QBX Core'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua'
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
    'ox_target',
    'ox_lib'
}