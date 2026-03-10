
fx_version 'cerulean'
lua54 'yes'
game 'gta5'

name 'Advance ATM Robbery'
author 'PulseScripts - pulsescripts.com'
version '2.0.4'

description 'Atm Robbery by PulseScripts https://discord.gg/72Y7WKsP9M'

shared_scripts {
	'@ox_lib/init.lua',
	'shared/config.lua',
	'locales/locale.lua',
}

client_scripts {
	'client/utils.lua',
	'client/shop.lua',
	'client/main.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/bridge/*',
	'server/shop.lua',
	'server/main.lua'
}

files {
	'locales/*.lua',
	'locales/*.json'
}

dependency {
	'ox_lib'
}

