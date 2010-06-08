require 'luarocks.require' -- http://www.luarocks.org/
require 'async'
require 'travian'
require 'util'
local gzip = require 'lib/deflatelua'

local function handler(filters, browser)
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
    -- todo : respect keep-alive
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

  local mimetype, encoding, encoding_header, encoding_header_no, transfer_encoding
  local response_headers = {}
  repeat
    local line = async.receive(srv, '*l')
    -- print('resp line', line)

    table.insert(response_headers, line)
    if string.find(line, 'Content--Type') then
      mimetype = string.match(line, 'Content--Type: ([%a/; -=]+)')
    elseif string.find(line, 'Transfer--Encoding') then
      transfer_encoding = string.match(line, 'Transfer--Encoding: ([%a/]+)')
    elseif string.find(line, 'Content--Encoding') then
      encoding_header, encoding = string.match(line, '(Content--Encoding: ([%a/]+))')
      encoding_header_no = #response_headers
    end
  until line == ''

  print('response mimetype', mimetype, 'encoding', encoding, 'transfer-encoding', transfer_encoding)

  local data, err, left = async.receive(srv, '*a')
  local response = data or left

  local active_filters = table.collect(filters, function(filter) return filter.pre(url, mimetype, request_headers) end)
  
  if #active_filters == 0 then
    print('passing thru, filters pre-passed request')
    async.send(browser, table.concat(response_headers, '\r\n')..'\r\n'..response)
  else
    print('#active_filters', #active_filters)
    if transfer_encoding == 'chunked' then
      response = dechunk(response)
    end

    if encoding == 'gzip' then
      local decoded = {}
      gzip.gunzip {input=response, output=function(byte) table.insert(decoded, string.char(byte)) end}
      response = table.concat(decoded)
      print('b', to_string(response_headers))
      print('re gzip at', encoding_header_no)
      -- todo !! check if removes gzip header
      table.remove(response_headers, encoding_header_no)
      print('a', to_string(response_headers))
    elseif encoding then
      table.insert(response_headers, encoding_header)
    end
  
    response = travian.filter(url, mimetype, request, response)

    table.insert(response_headers, '')
    if transfer_encoding == 'chunked' then
      print('#response', #response, DEC_HEX(#response))
      async.send(browser, table.concat(response_headers, '\r\n')..'\r\n'..DEC_HEX(#response)..'\r\n'..response..'\r\n'..'0'..'\r\n')
    else
      async.send(browser, table.concat(response_headers, '\r\n')..response)
    end
  end

  browser:close()
  srv:close()
  print('done: ', url)
end

local PORT = 3128
local server = assert(socket.bind('localhost', PORT))
print('proxy started at port '..PORT)
local filters = {travian}
async.add_server(server, function(browser) handler(filters, browser) end)
async.loop()
