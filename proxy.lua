require 'luarocks.require' -- http://www.luarocks.org/
require 'async'
require 'travian'

local function handler(browser)
  local url, err = async.receive(browser, '*l')

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
  local srv = async.connect(host, port or 80)

  local body_length
  local request = {url, 'Connection: close'}
  repeat
    local line = async.receive(browser, '*l')
    if not string.find(line, 'Proxy--Connection') then
      table.insert(request, line)
      if string.find(line, 'Content--Length') then
        -- print('>>!!!!!!!!['..line..']')
        body_length = string.match(line, 'Content--Length: (%d+)')
      end
    end
  until line == ''
  
  -- local line = async.receive(browser, '*l')
  -- print('>>!!!!!!!!['..line..']')  

  print('body? ', body_length)
  if body_length then
    print('receiving body ', body_length)
    local body = async.receive(browser, body_length)
    print('receiving body ', body and #body, '['..body..']')
    table.insert(request, body)
  else
    table.insert(request, '')
  end

  print('r', table.concat(request, '\r\n'))
  async.send(srv, table.concat(request, '\r\n'))

  local data, err, left = async.receive(srv, '*a')  

  -- local head = ''
  -- repeat
  --   local line = async.receive(srv, '*l')
  --     head = head..'\r\n'..line
  --     print('<<['..line..']')
  --   end
  -- until line == ''

  if data then
    print('RECEIVE SUCCESS', url, #data)
    print('RECEIVE SUCCESS', url, data)
  else
    print('RECEIVE ERR', url, err, left and #left)
  end

  local response = data or left

  response = travian.filter(url, 'mimetype', response)

  print('sending response to client: ', url, response and #response)
  async.send(browser, response)
  -- browser:close()
  -- srv:close()
  print('done: ', url)
end

local PORT = 3128
local server = assert(socket.bind('localhost', PORT))
print('proxy started at port '..PORT)
async.add_server(server, handler)
async.loop()
