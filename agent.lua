require 'util'
require 'luarocks.require' -- http://www.luarocks.org/

local http = require 'socket.http' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/
local json = require 'json' -- http://luaforge.net/projects/luajson/
local html = require 'lib/html' -- http://luaforge.net/projects/html/
local lom = require 'lxp.lom' -- http://www.keplerproject.org/luaexpat/
local xpath = require 'lib/xpath' -- http://luaxpath.luaforge.net/

local bot_container = 'http://dozorni.heroku.com/'
-- local bot_container = 'http://localhost:9292/'

local body, status = http.request(bot_container..'whatnow', '')
print(status)
print(body)

local dec = json.decode(body)

local url = 'http://s5.travian.ru'
local htmlf = http.request(url..dec[2])

local parsed_html = html.parsestr(htmlf)
local xml = to_html(parsed_html[1])

local parsed = lom.parse(xml)

local found = xpath.selectNodes(parsed, "//form//input[@name='login']")

print(to_string(found))

print(#found)
print(found[1].tag)
print(found[1].attr.value)
print(found[1].attr.name)
print(found[1].attr.id)
