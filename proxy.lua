require 'luarocks.require' -- http://www.luarocks.org/

require 'async'
require 'travian'

local function handler(client, co)
  local url, err = client:receive('*l')

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
  local server = async.connect(host, port or 80, co)

  local request = url
  repeat
    local line = client:receive('*l')
    if not string.find(line, 'Proxy--Connection') then
      request = request..'\r\n'..line
    end
  until line == ''
  request = request..'Connection: keep-alive\r\n'
  request = request..'\r\n'
  print('['..request..']')
  -- async.send(url, server, request)
  server:send(request)
  print('requested: ', url)

  -- local response, err = async.receive(url, server, '*a')
  local response, err = server:receive('*a')
  if response then
    print('response received: ', url, #response)
  else
    print('response err for', url, err)
    client.close()
    return
  end

  response = travian.filter(url, 'mimetype', response)

  client:send(response)
  -- client:close()
  -- server:close()
  print('done: ', url)
end

async.server(3128, handler)
