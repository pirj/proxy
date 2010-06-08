require 'luarocks.require' -- http://www.luarocks.org/
require 'async'
require 'travian'
require 'util'
local gzip = require 'lib/deflatelua'

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
    -- print('req line', line)
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

  local mimetype, encoding, encoding_header
  local response_headers = {}
  repeat
    local line = async.receive(srv, '*l')
    -- print('resp line', line)

    if string.find(line, 'Content--Encoding') then
      encoding_header, encoding = string.match(line, '(Content--Encoding: ([%a/]+))')
    else
      table.insert(response_headers, line)
      if string.find(line, 'Content--Type') then
        mimetype = string.match(line, 'Content--Type: ([%a/; -=]+)')
      end
    end
  until line == ''
  print('response mimetype', mimetype, 'encoding', encoding)
  
  local data, err, left = async.receive(srv, '*a')
  local response = data or left

  -- !! IMPLEMENT AS PROXY to skip unpacking of files from unrelated sites and mimetypes
  if encoding == 'gzip' then
    local decoded = {}
    gzip.gunzip {input=content, output=function(byte) table.insert(decoded, string.char(byte)) end}
    response = table.concat(decoded)
  else if encoding then
    table.insert(response_headers, encoding_header)
  end
  
  response = travian.filter(url, mimetype, request, response)

  table.insert(response_headers, '')
  async.send(browser, table.concat(response_headers, '\r\n'))
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
