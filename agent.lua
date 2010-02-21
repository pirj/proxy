require 'util'
require 'luarocks.require'

local http = require 'socket.http'

local bot_container = 'http://localhost:9292/whatnow'
local body, status = http.request(bot_container, '')

local json = require('json')
local dec = json.decode(body)

-- local url = 'http://localhost:9292'
local url = 'http://s5.travian.ru'
local htmlf = http.request(url..dec[2])

require 'html'
local parsed_html = html.parsestr(htmlf)
local xml = to_html(parsed_html[1])

local lom = require 'lxp.lom'
local parsed = lom.parse(xml)

local xpath = require 'xpath'
local found = xpath.selectNodes(parsed, "//form//input[@name='login']")

print(to_string(found))

-- print('xxx')
-- print(#found)
-- print(found[1].tag)
-- print(found[1][1])
