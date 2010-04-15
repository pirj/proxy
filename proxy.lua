require 'luarocks.require' -- http://www.luarocks.org/

local http = require 'socket.http' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/
local socket = require 'socket' -- same

local HOME_URL = 'localhost'
local PORT = '1080'

local server = socket.bind(HOME_URL, PORT)

require 'copas' -- http://keplerproject.github.com/copas/

copas.addserver(server, echoHandler)

function handler(sock)
  sock = copas.wrap(sock)
  while true do
    local data = sock:receive()
    if data == 'quit' then
      break
    end
    sock:send(data)
  end
end

while true do
  copas.step()

end