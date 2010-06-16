require 'luarocks.require' -- http://www.luarocks.org/
require 'async'
require 'travian'
require 'util'
local gzip = require 'lib/deflatelua'

local function handler(filter, browser)
  local url, err = async.receive(browser, '*l')
  -- local begin_time = os.time()
  -- print('in: ', url)

  local host = string.match(url, 'http://([%a%d\.-]+):*%d*/') or string.match(url, '[%a]+ ([%a%d\.-]+):*%d*')
  local port = string.match(url, 'http://[%a%d\.-]+:(%d+)/') or string.match(url, '[%a]+ [%a%d\.-]+:(%d+)')
  if not host then return nil, 'unparsable url'..url end
  local srv = async.connect(host, port or 80)

  local body_length
  local request = {url, 'Connection: close'}
  repeat
    local line = async.receive(browser, '*l')
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

  local data, err, left = async.receive(srv, '*a')
  local response = data or left

  if filter.pre(url, mimetype, request_headers) then
    local original_response = response
    -- dechunking
    if transfer_encoding == 'chunked' then
      response = dechunk(response)
    end

    -- gunzipping
    if encoding == 'gzip' then
      local decoded = {}
      gzip.gunzip {input=response, output=function(byte) table.insert(decoded, string.char(byte)) end}
      response = table.concat(decoded)
    end

    local changed, filter_response = filter.filter(url, mimetype, request, response)
    if changed then
      -- sending filtered
      async.send(browser, filter_response)
    else
      -- passing through
      async.send(browser, table.concat(response_headers, '\r\n')..'\r\n'..original_response)
    end
  else
    -- passing through
    async.send(browser, table.concat(response_headers, '\r\n')..'\r\n'..response)
  end

  browser:close()
  srv:close()
  -- print('done: ', os.time() - begin_time, url)
end

local PORT = 3128
local server = assert(socket.bind('localhost', PORT))
print('proxy started at port '..PORT)
async.add_server(server, function(browser) handler(travian, browser) end)
async.loop()
