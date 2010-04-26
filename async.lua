module(..., package.seeall)

require 'socket' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/

local connections_coroutines = {} -- socket: coroutine
local connections = {} -- sockets

function connect(host, port, co)
  local sock = socket.tcp()
  sock:settimeout(0)
  table.insert(connections, sock)
  connections_coroutines[sock] = co
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
  return sock
end

function receive(url, sock, pattern)
  local data1, err1
  while not data1 do
    data1, err1 = sock:receive(pattern)
    if err1 == 'timeout' then
      -- print('receive timeout', url)
      coroutine.yield()
    elseif err1 then
      print('async receive err:', err1)
      return nil, err1
    end
  end

  return data1
end

function send(url, sock, data_to_send)
  local data, err
  while not data do
    print('sending via sock', sock)
    data, err = sock:send(data_to_send)
    if err == 'timeout' then
      print('send timeout', url)
      coroutine.yield()
    elseif err then
      print('async send err:', err)
      return nil, err
    end
  end
  print('sent', data)

  return data
end

function server(port, handler)
  server = socket.bind('localhost', port)
  server:settimeout(0)
  print('proxy started at port '..port)
  table.insert(connections, server)

  while true do
    print('connections', #connections)
    local ins, outs, err = socket.select(connections, connections, 1)
    print('select', #ins, #outs, err)
    
    local cos_to_wake_up = {}
    for i, connection in ipairs(ins) do
      if not connections_coroutines[connection] then
        local client, err = connection:accept()
        print('incoming')
        connections_coroutines[client] = coroutine.create(function(co)
          handler(client, co)
        end)
        table.insert(connections, client)
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
      coroutine.resume(co, co)
      if coroutine.status(co) == 'dead' then
        for i, connection in ipairs(connections) do
          if connections_coroutines[connection] == co then
            connections_coroutines[connection] = nil
            table.remove(connections, i) -- remove both server and incoming!!!
            print('removed')
            break
          end
        end
        for i, connection in ipairs(connections) do
          if connections_coroutines[connection] == co then
            connections_coroutines[connection] = nil
            table.remove(connections, i) -- remove both server and incoming!!!
            print('removed 2')
            break
          end
        end
      end
    end
    
  end
end
