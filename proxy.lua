require 'luarocks.require' -- http://www.luarocks.org/
require 'async'
require 'travian'

local function handler(browser)
  local url, err = browser:receive('*l')

  if not url or url == '' then
    print('error: empty input', err)
    return nil
  else
    print('working: ', url)
  end

  local host = string.match(url, 'http://([%a%d\.-]+):*%d*/') or string.match(url, '[%a]+ ([%a%d\.-]+):*%d*')
  local port = string.match(url, 'http://[%a%d\.-]+:(%d+)/') or string.match(url, '[%a]+ [%a%d\.-]+:(%d+)')
  if not host then
    print('error:unparsable url'..url)
    return nil
  end
  print('conn: ', url, host, port)
  local srv = async.connect(host, port or 80)
  -- local srv = socket.connect(host, port or 80)
  print('connd: ', url, host, port)

  local request = url
  repeat
    local line = browser:receive('*l')
    if not string.find(line, 'Proxy--Connection') then
      request = request..'\r\n'..line
    end
  until line == ''
  request = request..'Connection: keep-alive\r\n'
  request = request..'\r\n'
  async.send(url, srv, request)

  print('a: ', url)
  local data, err, left = async.receive(url, srv, '*a')

  print('aa: ', url, #data, err, #left)
  local response = data or left
  -- repeat
  --   -- local chunk, err = async.receive(url, srv, 512)
  --   local chunk, err, incomp = srv:receive(100)
  --   if chunk then
  --     -- print('response received: ', url, #chunk, '[', chunk, ']')
  --     s = s + #chunk
  --     print('response received: ', url, #chunk, s, incomp)
  --     table.insert(response, chunk)
  --     coroutine.yield()
  --   else
  --     print('response err for', url, err, incomp)
  --     srv:close()
  --     browser:close()
  --     return
  --   end
  -- until chunk == ''
  -- print('response received ALL ', url)

  print('b: ', url)
  response = travian.filter(url, 'mimetype', response)

  print('c: ', url)
  client:send(response)
  -- client:close()
  -- srv:close()
  print('done: ', url)
end

async.server(3128, handler)
