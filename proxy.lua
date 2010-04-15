require 'luarocks.require' -- http://www.luarocks.org/

local http = require 'socket.http' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/
local socket = require 'socket' -- same

local HOME_URL = 'localhost'
local PORT = '1080'

require 'copas' -- http://keplerproject.github.com/copas/

local function simple(host, port, handler)
  print("starting at "..host..':'..port)
  return copas.addserver(assert(socket.bind(host, port)),
    function(c)
      return handler(copas.wrap(c), c:getpeername())
    end
  )
end

local function daytime_handler(c, host, port)
    print("daytime connection from", host, port)
    c:send(os.date() .. '\r\n')
end

local function echo_handler(c, host, port)
    print("echo connection from", host, port)
    repeat
        local line = c:receive"*l"
        if line then c:send(line .. '\r\n') end
    until not line
    print("echo termination from", host, port)
end

local shutdown = false

local function shutdown_handler(c, host, port)
  print("shutting down", host, port)
  shutdown = true
end

-- Use 0 to listen on the standard (privileged) ports.
local offset = ... or 10000

simple("*", offset + 7, echo_handler)
simple("*", offset + 9, shutdown_handler)
simple("*", offset + 13, daytime_handler)

while not shutdown do
  copas.step()

end
