fx_version 'cerulean'
game 'gta5'

description 'AI Street Crime Mini-Mission'
author 'Leon'
version '1.0.0'

shared_script '@ox_lib/init.lua'

client_scripts {
    'client.lua'
}

server_script 'server.lua'

dependency 'ox_lib'
lua54 'yes'