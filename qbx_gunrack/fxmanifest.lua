fx_version 'cerulean'
game 'gta5'

name 'qbx_gunrack'
description 'QBX Gun Rack System - Vehicle-based weapon storage for police'
author 'ChrizzyStyle'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_inventory',
    'ox_target'
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'