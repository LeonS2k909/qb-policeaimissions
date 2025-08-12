fx_version 'cerulean'
game 'gta5'

name 'qb-policeaimissions'
author 'Leon'
description 'Two NPCs fight. Police can aim to make them surrender, qb-target to have them follow, seat them in a police car, and process them. Uses ps-dispatch CustomAlert.'
version '1.0.0'
lua54 'yes'

dependencies {
    'qb-core',
    'qb-target',
    'ps-dispatch'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}
