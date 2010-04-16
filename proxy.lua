require 'luarocks.require' -- http://www.luarocks.org/

local http = require 'socket.http' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/
local socket = require 'socket' -- same

local PORT = '1080'

require 'copas' -- http://keplerproject.github.com/copas/

local function server(host, port, handler)
  print('starting at '..host..':'..port)
  return copas.addserver(assert(socket.bind(host, port)),
    function(c)
      return handler(copas.wrap(c), c:getpeername())
    end
  )
end

local ltn12 = require 'ltn12' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/ltn12.html

local function handler(c, host, port)
  print('echo connection from', host, port)
--   repeat
  local line = c:receive('*l')
  if line then
    print('received: '..line)
    if string.find(line, 'travian') then
      print('travian')
    else
      print('non-travian')
    end
  end

--   if line then c:send(line..'\r\n') end
--   until not line
end

local shutdown = false
local function shutdown_handler(c, host, port)
  print('shutting down')
  shutdown = true
end

server('localhost', PORT, handler) -- * for address makes it available from any host, not just localhost
server('localhost', PORT + 1, shutdown_handler)

while not shutdown do
  copas.step()
  -- more logic in the loop
end

function source()
  -- we have data
  return chunk

  -- we have an error
  return nil, err

  -- no more data
  return nil
end

function sink(chunk, src_err)
  if chunk == nil then
    -- no more data to process, we won't receive more chunks
    if src_err then
      -- source reports an error, TBD what to do with chunk received up to now
    else
      -- do something with concatenation of chunks, all went well
    end
    return true -- or anything that evaluates to true
  elseif chunk == "" then
     -- this is assumed to be without effect on the sink, but may
     --   not be if something different than raw text is processed

     -- do nothing and return true to keep filters happy
     return true -- or anything that evaluates to true
  else 
     -- chunk has data, process/store it as appropriate
     return true -- or anything that evaluates to true
  end

  -- in case of error
  return nil, err
end

-- ret, err = pump.step(source, sink)
-- 
-- if ret == 1 then
--   -- all ok, continue pumping
-- elseif err then
--   -- an error occured in the sink or source. If in both, the sink
--   -- error is lost.
-- else -- ret == nil and err == nil
--   -- done, nothing left to pump
-- end
-- 
-- ret, err = pump.all(source, sink)
-- 
-- if ret == 1 then
--   -- all OK, done
-- elseif err then
--   -- an error occured
-- else
--   -- impossible
-- end

function filter(chunk)
  -- first two cases are to maintain chaining logic that
  -- support expanding filters (see below)
  if chunk == nil then
    return nil
  elseif chunk == "" then
    return ""
  else
    -- process chunk and return filtered data
    return data
  end
end

-- input = source.chain(source.file(io.stdin), normalize("\r\n"))
-- output = sink.file(io.stdout)
-- pump(input, output)
