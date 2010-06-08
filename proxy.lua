require 'luarocks.require' -- http://www.luarocks.org/
require 'async'
require 'travian'
require 'util'
local gzip = require 'lib/deflatelua'

local function DEC_HEX(IN)
  local B,K,OUT,I,D=16,"0123456789ABCDEF","",0
  while IN>0 do
    I=I+1
    IN,D=math.floor(IN/B),math.mod(IN,B)+1
    OUT=string.sub(K,D,D)..OUT
  end
  return OUT
end

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

  local mimetype, encoding, encoding_header, transfer_encoding
  local response_headers = {}
  repeat
    local line = async.receive(srv, '*l')
    -- print('resp line', line)

    if string.find(line, 'Content--Encoding') then
      encoding_header, encoding = string.match(line, '(Content--Encoding: ([%a/]+))')
    elseif not (line == '') then
      table.insert(response_headers, line)
      if string.find(line, 'Content--Type') then
        mimetype = string.match(line, 'Content--Type: ([%a/; -=]+)')
      elseif string.find(line, 'Transfer--Encoding') then
        transfer_encoding = string.match(line, 'Transfer--Encoding: ([%a/]+)')
      end
    end
  until line == ''
  
  print('response mimetype', mimetype, 'encoding', encoding, 'transfer-encoding', transfer_encoding)
  
  -- !! IMPLEMENT AS PROXY to skip compounding of files from unrelated sites and mimetypes
  local response
  if transfer_encoding == 'chunked' then
    local chunks = {}
    local chunk_size = async.receive(srv, '*l')
    repeat
      local chunk, d, k, e = async.receive(srv, tonumber(chunk_size, 16))
      print('chunk:', chunk, d, k, e)
      if chunk then
        table.insert(chunks, chunk)
        chunk_size = async.receive(srv, '*l')
        print('chunk_size', chunk_size)
        chunk_size = async.receive(srv, '*l')
        print('chunk_size2', chunk_size)
      else
        chunk_size = nil
      end
    until not chunk_size or chunk_size == '0'
    response = table.concat(chunks)
    print('total size:', response)
  else
    local data, err, left = async.receive(srv, '*a')
    response = data or left
  end

  -- !! IMPLEMENT AS PROXY to skip unpacking of files from unrelated sites and mimetypes
  if encoding == 'gzip' then
    local decoded = {}
    gzip.gunzip {input=response, output=function(byte) table.insert(decoded, string.char(byte)) end}
    response = table.concat(decoded)
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

  browser:close()
  srv:close()
  print('done: ', url)
end

local PORT = 3128
local server = assert(socket.bind('localhost', PORT))
print('proxy started at port '..PORT)
async.add_server(server, handler)
async.loop()
