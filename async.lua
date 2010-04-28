module(..., package.seeall)

require 'socket' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/

local connections_coroutines = {} -- socket: coroutine
local read = {} -- sockets
local write = {} -- sockets

function connect(host, port)
  local sock = socket.tcp()
  sock:settimeout(0)

  table.insert(read, sock)
  connections_coroutines[sock] = coroutine.running()

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
  
  for i, connection in ipairs(read) do
    if sock == connection then
      table.remove(read, i)
    end
  end
  connections_coroutines[sock] = nil

  return sock
end

function receive(url, sock, pattern)
  table.insert(read, sock)
  connections_coroutines[sock] = coroutine.running()

  local data, err
  while not data do
    print('receiving via sock', sock, url)
    data, err = sock:receive(pattern)
    if err == 'timeout' then
      print('receive timeout', url)
      coroutine.yield()
      print('receive resumed')
    elseif err then
      print('async receive err:', err)
      return nil, err
    end
  end

  for i, connection in ipairs(read) do
    if sock == connection then
      table.remove(read, i)
    end
  end
  connections_coroutines[sock] = nil

  return data
end

function send(url, sock, data_to_send)
  table.insert(write, sock)
  connections_coroutines[sock] = coroutine.running()

  local data, err
  while not data do
    print('sending via sock', sock, url)
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

  for i, connection in ipairs(write) do
    if sock == connection then
      table.remove(write, i)
    end
  end
  connections_coroutines[sock] = nil

  return data
end

function server(port, handler)
  server = socket.bind('localhost', port)
  server:settimeout(0)
  print('proxy started at port '..port)
  table.insert(read, server)

  while true do
    print('connections', #read, #write)
    local ins, outs, err = socket.select(read, write, 1)
    print('select', #ins, #outs, err)
    
    local cos_to_wake_up = {}
    for i, connection in ipairs(ins) do
      if not connections_coroutines[connection] then
        local client, err = connection:accept()
        print('incoming')
        connections_coroutines[client] = coroutine.create(function()
          handler(client)
        end)
        table.insert(read, client)
        connection = client
      end
      cos_to_wake_up[connections_coroutines[connection]] = true
    end

    for i, connection in ipairs(outs) do
      -- print('outs', connection, connections_coroutines[connection])
      if connections_coroutines[connection] then
        cos_to_wake_up[connections_coroutines[connection]] = true
      end
    end

    for co in pairs(cos_to_wake_up) do
      print('resuming', co)
      local a, b = coroutine.resume(co)
      print('returned ', co, a, b)
    end
    
  end
end
