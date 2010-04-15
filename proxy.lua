require 'luarocks.require' -- http://www.luarocks.org/

local http = require 'socket.http' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/
local socket = require 'socket' -- same

local PORT = '1080'

require 'copas' -- http://keplerproject.github.com/copas/

local function simple(host, port, handler)
  print('starting at '..host..':'..port)
  return copas.addserver(assert(socket.bind(host, port)),
    function(c)
      return handler(copas.wrap(c), c:getpeername())
    end
  )
end

local function echo_handler(c, host, port)
  print('echo connection from', host, port)
  repeat
    -- should use LTN12 http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/socket.html
    local line = c:receive('*l')
    if line then print('received'..line) end
    if line then c:send(line..'\r\n') end
  until not line
  print('echo termination from', host, port)
end

local shutdown = false
local function shutdown_handler(c, host, port)
  print('shutting down', host, port)
  shutdown = true
end

simple('localhost', PORT, echo_handler) -- * for address makes it available from any host, not just localhost
simple('localhost', PORT + 1, shutdown_handler)

while not shutdown do
  copas.step()
  -- more logic in the loop
end
