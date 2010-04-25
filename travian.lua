module(..., package.seeall)

require 'util'

local html = require 'lib/html' -- http://luaforge.net/projects/html/
local lom = require 'lxp.lom' -- http://www.keplerproject.org/luaexpat/
local xpath = require 'lib/xpath' -- http://luaxpath.luaforge.net/

local function check_captcha(data)
  print('data')
  -- print(to_string(data))
  local parsed_html = html.parsestr(data)
  print('parsed')
  -- print(to_string(parsed_html))
  local xml = to_html(parsed_html[1])
  print('xml')
  print(to_string(xml))
  local parsed = lom.parse(xml)
  print('xpath')
  local found = xpath.selectNodes(parsed, "//div//center//span")
  -- asok.sleep(5000)
  return to_string(found)
end

function filter(url, mimetype, data)
  if string.find(url, 'travian') then
    print('travian')
    return check_captcha(data)
  else
    return data
  end
end
