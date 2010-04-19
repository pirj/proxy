require 'luarocks.require' -- http://www.luarocks.org/

local copas = require 'copas' -- http://keplerproject.github.com/copas/
local socket = require 'socket' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/

local function handler(sock_in)
  sock_in = copas.wrap(sock_in)
  local line = sock_in:receive('*l')

  if not line or line == '' then
    print('error: empty input')
    return nil
  end

  -- where to?
  local url = string.match(line, 'http://([%a%d\.-]+):*%d*/')
  local port = string.match(line, 'http://[%a%d\.-]+:(%d+)/')
  if not url then
    print('error:unparsable url'..line)
    return nil
  end
  local sock_out = socket.connect(url, port or 80)

  if string.find(line, 'travian') then
    print('travian')

  else
    repeat
      sock_out:send(line..'\r\n')
      line = sock_in:receive('*l')
    until line == ''
    sock_out:send('Connection: close\r\n')
    sock_out:send('\r\n')

    local response = sock_out:receive('*a')
    if line then sock_in:send(response) end
  end
end

copas.addserver(socket.bind('localhost', 3128), handler)

copas.loop()
