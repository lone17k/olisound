fx_version 'cerulean'
games { 'gta5' }

name         'olisound'
description  'High-performance audio library for FiveM'
version      '1.0.0'
author       'lonedev'

client_scripts {
    "config.lua",
    "client/main.lua",
    "client/events.lua",
    "client/vehicle.lua",
    "client/exports/info.lua",
    "client/exports/play.lua",
    "client/exports/manipulation.lua",
    "client/exports/events.lua",
    "client/exports/effects.lua",
}

server_scripts {
    "config.lua",
    "server/exports/play.lua",
    "server/exports/manipulation.lua",
}

ui_page "html/index.html"

files {
    "html/index.html",
    "html/scripts/engine.js",
}
