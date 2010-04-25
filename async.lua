module(..., package.seeall)

require 'socket' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/

local connections_coroutines = {} -- socket: coroutine
local connections = {} -- sockets

function connect(host, port, co)
  local sock = socket.tcp()
  -- sock:settimeout(0)
  local res, err = sock:connect(host, port)
  table.insert(connections, sock)
  connections_coroutines[sock] = co
  print('setting', sock, 'to', co)
  if not res then
    print('CONN ERR:', err)
    return nil, err
  end
  print('CONN out', sock, res)
  return sock
end

function receive(url, sock, ...)
  local data, err
  while not data do
    data, err = sock:receive(...)
    if err == 'timeout' then
      print('timeout', url)
      coroutine.yield()
    elseif err then
      print('async receive err:', err)
      return data, err
    end
  end

  return data
end

function send(url, sock, ...)
  local data, err
  while not data do
    data, err = sock:send(...)
    if err == 'timeout' then
      print('timeout', url)
      coroutine.yield()
    elseif err then
      print('async send err:', err)
      return data, err
    end
  end

  return data, err
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
        connections_coroutines[client] = coroutine.create(function(co)
          handler(client, co)
        end)
        table.insert(connections, client)
        connection = client
      end
      cos_to_wake_up[connections_coroutines[connection]] = true
    end

    for i, connection in ipairs(outs) do
      print('outs', connection, connections_coroutines[connection])
      if connections_coroutines[connection] then
        cos_to_wake_up[connections_coroutines[connection]] = true
      end
    end
    
    for co in pairs(cos_to_wake_up) do
      coroutine.resume(co, co)
      if coroutine.status(co) == 'dead' then
        for i, connection in ipairs(connections) do
          if connections_coroutines[connection] == co then
            connections_coroutines[connection] = nil
            table.remove(connections, i)
            break
          end
        end
      end
    end
    
  end
end
