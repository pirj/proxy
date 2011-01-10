require 'async'
require 'travian'
local http = require 'http'

local function https(client, server)
  close_callback = function()
    client.close()
    server.close()
  end
  
  client.receive_subscribe(function(data)
    -- print('https client recv:', data and #data)
    server.send(data)
  end, close_callback)
  
  server.receive_subscribe(function(data)
    -- print('https server recv:', data and #data)
    client.send(data)
  end, close_callback)
end

local function default_port(method)
  return method == 'CONNECT' and 443 or 80
end

local function handler(filter, client_socket)
  local begin_time = os.time()
  local client = async.pipe(client_socket)
  local request = http.request(client)

  local host_header = request.headers('Host')
  if not host_header then return nil, 'unparsable host header: nil' end
  local host, port = string.match(request.headers('Host'), '([%a%d\.-]+)(:*%d*)')
  if not host then return nil, 'unparsable host'..request.headers('Host') end
  port = (not port == '') and port or default_port(request.method())

  request.headers('Proxy-Connection', nil)

  print('in: ', request.request_line(), host, port)

  local server_socket = async.connect(host, port)
  local server = async.pipe(server_socket)

  if request.method() == 'CONNECT' then
    local sent_to_server, err = client.send("HTTP/1.0 200 Connection established\r\nProxy-agent: BotHQ-Agent/1.2\r\n\r\n")
    print('https transparent connection')
    https(client, server)
    return
  end
  request.headers('Connection', 'close')
  server.send(request.raw())
  local response = http.response(server)

  if filter.pre(request, response) then
    filter.filter(request, response)
  end

  client.send(response.raw())

-- todo : respect keep-alive
  client.close()
  server.close()
  print('done '..request.request_line()..' in', os.time() - begin_time)
end

local PORT = 3128
local proxy_server = assert(socket.bind('localhost', PORT))
print('proxy started at port '..PORT)
async.add_server(proxy_server, function(client) handler(travian, client) end)
async.loop()
