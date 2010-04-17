require 'luarocks.require' -- http://www.luarocks.org/

local http = require 'socket.http' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/
local socket = require 'socket' -- same
local ltn12 = require 'ltn12' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/ltn12.html
require 'copas' -- http://keplerproject.github.com/copas/

local PORT = '1080'

local function server(host, port, handler)
  print('starting at '..host..':'..port)
  return copas.addserver(assert(socket.bind(host, port)),
    function(c)
      return handler(copas.wrap(c), c:getpeername())
    end
  )
end

function filter2(chunk)
  -- first two cases are to maintain chaining logic that
  -- support expanding filters (see below)
  if chunk == nil then
    print('<< nil')
    return nil
  elseif chunk == "" then
    print('<< empty')
    return ""
  else
    print('<<'..chunk)
    -- process chunk and return filtered data
    return chunk
  end
end

function filter1(chunk)
  if chunk == nil then
    print('>> nil')
    return nil
  elseif chunk == "" then
    print('>> empty')
    return ""
  else
    print('>>'..chunk)
    -- process chunk and return filtered data
    return chunk
  end
end

function socket_source(sock)
  return function()
    return sock:receive('*l')
  end
end

local function handler(sock_in, host, port)
  print('incoming2: ', host, port)

  local line = sock_in:receive('*l')
  if line then
    print('received: '..line)
    if string.find(line, 'travian') then
      print('travian')

    else
      print('non-travian, pulling transparently')

      -- local source = socket.source('until-closed', sock_in)
      -- local source_compound = ltn12.source.cat(
      --   ltn12.source.string(line..'\r\n'),
      --   ltn12.source.string('Connection: close\r\n'),
      --   socket_source(sock_in),
      --   ltn12.source.string('\r\n'),
      --   ltn12.source.string('\r\n')
      -- ) -- ltn12.source.simplify(
      -- 
      -- source_compound = ltn12.source.chain(
      --   source_compound,
      --   filter2
      -- )

      -- local sink = ltn12.sink.chain(filter1,
      --   socket.sink('close-when-done', sock_out)
      -- )
      -- 
      -- ltn12.pump.all(source_compound, sink)

      local url = string.match(line, 'http://([%a%d\.-]+):*%d*/')
      local port = string.match(line, 'http://[%a%d\.-]+:(%d+)/')
      if not url then print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!: "..line) end
      print('url'..url)
      print(port)
      local sock_out = socket.connect(url, port or 80)

      repeat
        if line then print('['..line..']') end
        if line then sock_out:send(line..'\r\n') end
        -- if line then sock_out:send(line) end
        line = sock_in:receive('*l')
      until not line or line == '\r\n' or line == '\n' or line == '\r' or line == ''
      sock_out:send('Connection: close\r\n')
      sock_out:send('\r\n')

      source = socket.source('until-closed', sock_out)
      source = ltn12.source.chain(
        source,
        filter2
      )
      sink = socket.sink('close-when-done', sock_in)
      ltn12.pump.all(source, sink)
    end
  end
end

local shutdown = false
local function shutdown_handler(c, host, port)
  print('shutting down')
  shutdown = true
end

server('localhost', PORT, handler) -- * for address makes it available from any host, not just localhost
server('localhost', PORT + 1, shutdown_handler)

-- copas.loop()
while not shutdown do
  copas.step()
  -- more logic in the loop
end
