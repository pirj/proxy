require 'luarocks.require' -- http://www.luarocks.org/

local http = require 'socket.http' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/
local socket = require 'socket' -- same
local ltn12 = require 'ltn12' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/ltn12.html
local copas = require 'copas' -- http://keplerproject.github.com/copas/

local PORT = '1080'

function socket_source(sock)
  return function()
    local line = sock:receive('*l')
    if line == '' then return nil end
    return line..'\r\n'
  end
end

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
  -- sock_out = copas.wrap(sock_out)

  if string.find(line, 'travian') then
    print('travian')

  else
    repeat
      if line then sock_out:send(line..'\r\n') end
      -- if line then sock_out:send(line) end
      line = sock_in:receive('*l')
    until not line or line == '\r\n' or line == '\n' or line == '\r' or line == ''
    sock_out:send('Connection: close\r\n')
    sock_out:send('\r\n')

    local response = sock_out:receive('*a')
    if line then sock_in:send(response) end
  end
end

local shutdown = false
local function shutdown_handler(c, host, port)
  print('shutting down')
  shutdown = true
end

copas.addserver(socket.bind('localhost', PORT + 1), shutdown_handler)
copas.addserver(socket.bind('localhost', PORT), handler)

-- copas.loop()
while not shutdown do
  copas.step()
  print('step')
  -- more logic in the loop
end
