fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mz_clothing'
author 'Mazus'
description 'Clothing shop for the MZ ecosystem'
version '0.1.0'

ui_page 'web/index.html'

shared_scripts {
  '@ox_lib/init.lua',
  'shared/config.lua',
  'shared/catalog.lua',
  'shared/shops.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/database.lua',
  'server/main.lua'
}

client_scripts {
  'client/appearance.lua',
  'client/camera.lua',
  'client/inventory_preview.lua',
  'client/shops.lua',
  'client/nui.lua',
  'client/main.lua'
}

files {
  'web/index.html',
  'web/style.css',
  'web/script.js'
}

dependencies {
  'oxmysql',
  'ox_lib',
  'mz_core',
  'mz_economy',
  'mz_inventory'
}
