require 'luarocks.require' -- http://www.luarocks.org/

require 'socket' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/
require 'socket.http' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/
require 'async'
require 'server'

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

local function travian_filter(url, mimetype, data)
  if string.find(url, 'travian') then
    print('travian')
    return check_captcha(data)
  else
    return data
  end
end

local function handler(sock_in)
  print('receiving')
  local url, err = async.receive('', sock_in, '*l')
  print('received', url)

  if not url or url == '' then
    print('error: empty input', err)
    return nil
  else
    print('working: ', url)
  end

  -- where to?
  local host = string.match(url, 'http://([%a%d\.-]+):*%d*/')
  local port = string.match(url, 'http://[%a%d\.-]+:(%d+)/')
  if not host then
    print('error:unparsable url'..url)
    return nil
  end
  local sock_out = socket.connect(host, port or 80)

  async.send(url, sock_out, url..'\r\n')
  repeat
    local line = async.receive(url, sock_in, '*l')
    if not string.find(line, 'Proxy--Connection') then
      async.send(url, sock_out, line..'\r\n')
    end
  until line == ''
  async.send(url, sock_out, 'Connection: keep-alive\r\n\r\n')
  print('requested: ', url)

  local response, err = async.receive(url, sock_out, '*a')
  if response then
    print('response received: ', url, #response)
  else
    print('response err for', url, err)
  end

  response = travian_filter(url, 'mimetype', response)

  print('sending to client')
  async.send(url, sock_in, response)
  print('done: ', url)
end

server.start(3128, handler)
