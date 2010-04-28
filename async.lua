module(..., package.seeall)

require 'socket' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/

local connections_coroutines = {} -- socket: coroutine
local read = {} -- sockets
local write = {} -- sockets

local function subscribe(read_or_write, sock, co)
  connections_coroutines[sock] = co
  table.insert(read_or_write, sock)
end

local function unsubscribe(read_or_write, sock)
  connections_coroutines[sock] = nil
  for i, connection in ipairs(read_or_write) do
    if sock == connection then
      table.remove(read_or_write, i)
      return
    end
  end
end

function connect(host, port)
  local sock = socket.tcp()
  sock:settimeout(0.1)
  subscribe(read, sock, coroutine.running())

  local res, err = sock:connect(host, port)
  if err == 'timeout' then
    while not sock:getpeername() do
      print('conn timeout, yield', host, port, sock:getpeername())
      coroutine.yield()
    end
  elseif err then
    print('async conn err:', err)
    return nil, err
  end
  print('CONN out', sock)

  unsubscribe(read, sock)
  return sock
end

function receive(url, sock, pattern)
  subscribe(read, sock, coroutine.running())

  local data, err, lo
  while not data do
    print('receiving', sock, url)
    data, err, lo = sock:receive(pattern)
    if err == 'timeout' then
      print('receive timeout', url)
      coroutine.yield()
      print('receive resumed')
    elseif err then
      print('async receive err:', err)
      return nil, err, lo
    end
  end

  unsubscribe(read, sock)
  return data
end

function send(url, sock, data_to_send)
  subscribe(write, sock, coroutine.running())

  local data, err
  while not data do
    print('sending', sock, url)
    data, err = sock:send(data_to_send)
    if err == 'timeout' then
      print('send timeout', url)
      coroutine.yield()
      print('send resumed')
    elseif err then
      print('async send err:', err)
      return nil, err
    end
  end
  print('sent', data)

  unsubscribe(write, sock)
  return data
end

local function cleanup(co)
  for sock, coroutine in pairs(connections_coroutines) do
    if co == coroutine then
      connections_coroutines[sock] = nil
      unsubscribe(read, sock)
      unsubscribe(write, sock)
    end
  end
end

function server(port, handler)
  server = socket.bind('localhost', port)
  server:settimeout(0)
  print('proxy started at port '..port)
  table.insert(read, server)

  while true do
    print('connections', #read, #write)
    local read_ready, write_ready, err = socket.select(read, write, 1)
    print('select', #read_ready, #write_ready, err)
    
    local cos_to_wake_up = {}
    for i, connection in ipairs(read_ready) do
      if not connections_coroutines[connection] then
        local client, err = connection:accept()
        print('incoming')
        local co = coroutine.create(function()
          handler(client)
        end)
        -- subscribe(read, client, co)
        connection = client
        connections_coroutines[connection] = co
      end
      cos_to_wake_up[connections_coroutines[connection]] = true
    end

    for i, connection in ipairs(write_ready) do
      if connections_coroutines[connection] then
        cos_to_wake_up[connections_coroutines[connection]] = true
      end
    end

    for co in pairs(cos_to_wake_up) do
      print('')
      print('resuming', co)
      local result, err = coroutine.resume(co)
      print('returned ', co, result, err, coroutine.status(co))
      if coroutine.status(co) == 'dead' then
        cleanup(co)
        break
      elseif not result then
        print('ERR:', err)
        cleanup(co)
        break
      end
      print('')
    end
    
  end
end
