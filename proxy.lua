require 'luarocks.require' -- http://www.luarocks.org/
require 'async'
require 'travian'

local function handler(browser)
  local url, err = async.receive(browser, '*l')
  print('working: ', url)

  local host = string.match(url, 'http://([%a%d\.-]+):*%d*/') or string.match(url, '[%a]+ ([%a%d\.-]+):*%d*')
  local port = string.match(url, 'http://[%a%d\.-]+:(%d+)/') or string.match(url, '[%a]+ [%a%d\.-]+:(%d+)')
  if not host then return nil, 'unparsable url'..url end
  local srv = async.connect(host, port or 80)

  local body_length
  local request = {url, 'Connection: close'}
  repeat
    local line = async.receive(browser, '*l')
    if not string.find(line, 'Proxy--Connection') then
      table.insert(request, line)
      if string.find(line, 'Content--Length') then
        body_length = string.match(line, 'Content--Length: (%d+)')
      end
    end
  until line == ''
  
  if body_length then
    local body = async.receive(browser, body_length)
    table.insert(request, body)
  else
    table.insert(request, '')
  end

  async.send(srv, table.concat(request, '\r\n'))

  local data, err, left = async.receive(srv, '*a')  
  local response = data or left

  response = travian.filter(url, 'mimetype', request, response)

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
