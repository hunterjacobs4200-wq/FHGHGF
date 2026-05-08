--[[
    NPC Police Interactions
    A comprehensive NPC traffic stop and police interaction system for FiveM.
    Supports ESX, QBCore, and standalone mode with auto-detection.
]]

fx_version 'cerulean'
game 'gta5'

name 'npc_police_interactions'
description 'Realistic NPC traffic stop, police interaction, and arrest system'
author 'HuntersMods'
version '1.0.0'

lua54 'yes'

-- Shared files (loaded before client/server)
shared_scripts {
    'config.lua',
    'shared/utils.lua',
}

-- Client scripts
client_scripts {
    'client/main.lua',
    'client/npc_ai.lua',
    'client/pullover.lua',
    'client/menu.lua',
    'client/arrest.lua',
    'client/evidence.lua',
    'client/immersion.lua',
}

-- Server scripts
server_scripts {
    'server/main.lua',
}

-- Optional dependency on ox_lib for enhanced menus and progress bars
dependencies {
    '/server:5181',
}

-- Prefer ox_lib if available, but fall back gracefully
provide 'npc_police_interactions'
