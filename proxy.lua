require 'luarocks.require' -- http://www.luarocks.org/

require 'lib/copas' -- http://keplerproject.github.com/copas/
require 'socket' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/
require 'socket.http' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/

require 'util'

-- local html = require 'lib/html' -- http://luaforge.net/projects/html/
-- local lom = require 'lxp.lom' -- http://www.keplerproject.org/luaexpat/
-- local xpath = require 'lib/xpath' -- http://luaxpath.luaforge.net/

local function check_captcha(data)
  return data
  -- print('data')
  -- print(to_string(data))
  -- local parsed_html = html.parsestr(data)
  -- print('parsed')
  -- print(to_string(parsed_html))
  -- local xml = to_html(parsed_html[1])
  -- print('xml')
  -- print(to_string(xml))
  -- local parsed = lom.parse(xml)
  -- local found = xpath.selectNodes(parsed, "//div//center//span")
  -- 
  -- return to_string(found)
end

local function handler(sock_in)
  sock_in = copas.wrap(sock_in)
  local url = sock_in:receive('*l')
  print(url)

  if not url or url == '' then
    print('error: empty input')
    return nil
  end

  -- where to?
  local host = string.match(url, 'http://([%a%d\.-]+):*%d*/')
  local port = string.match(url, 'http://[%a%d\.-]+:(%d+)/')
  if not host then
    print('error:unparsable url'..url)
    return nil
  end
  local sock_out = socket.connect(host, port or 80)

  sock_out:send(url..'\r\n')
  repeat
    local line = sock_in:receive('*l')
    sock_out:send(line..'\r\n')
  until line == ''
  sock_out:send('Connection: close\r\n')
  sock_out:send('\r\n')

  local response = sock_out:receive('*a')
  if string.find(host, 'travian') then
    print('travian')
    response = check_captcha(response)
  end
  sock_in:send(response)
end

copas.addserver(socket.bind('localhost', 3128), handler)
copas.loop()
