require 'luarocks.require' -- http://www.luarocks.org/
require 'async'
require 'travian'
require "profiler"

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
  print('conn: ', url, host)
  local srv = async.connect(host, port or 80)
  print('connd: ', url, host)

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

  if data then
    print('RECEIVE SUCCESS', url, #data)
  else
    print('RECEIVE ERR', url, err)
  end

  local response = data or left

  print('b: ', url)
  response = travian.filter(url, 'mimetype', response)

  print('c: ', url)
  browser:send(response)
  -- browser:close()
  -- srv:close()
  print('done: ', url)
end

-- profiler.start()
async.server(3128, handler)
