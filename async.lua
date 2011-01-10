module(..., package.seeall)

require 'socket' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/

local connections_coroutines = {} -- socket: coroutine list
local readwait = {}
local writewait = {}
local connwait = {}
local server_handlers = {}
local regular = {}

function add_regular()
  table.insert(regular, coroutine.running())
end

function remove_regular()
  local co = coroutine.running()
  for i, c in ipairs(regular) do
    if co == c then
      table.remove(regular, i)
      return
    end
  end
end

local function subscribe(read_or_write, sock)
  local cos = connections_coroutines[sock]
  if not cos then
    cos = {}
    connections_coroutines[sock] = cos
  end
  cos[coroutine.running()] = true
  table.insert(read_or_write, sock)
end

local function unsubscribe(read_or_write, sock)
  local cos = connections_coroutines[sock]
  cos[coroutine.running()] = nil

  for i, connection in ipairs(read_or_write) do
    if sock == connection then
      table.remove(read_or_write, i)
      return
    end
  end
  print('??', sock)
end

function connect(host, port)
  local sock = socket.tcp()
  sock:settimeout(1)
  subscribe(writewait, sock)
  subscribe(readwait, sock)

  local res, err = sock:connect(host, port)
  if err == 'timeout' then
    -- print('conn timeout, yield1', host, port, res, err)
    while not sock:getpeername() do
      -- print('conn timeout, yield', host, port, sock:getpeername())
      if coroutine.running() then
        coroutine.yield()
      else
        print("???")
      end
    end
    print('connected', host, res, err)
  elseif err then
    print('async conn err:', err)
    unsubscribe(writewait, sock)
    unsubscribe(readwait, sock)
    return nil, err
  end

  unsubscribe(writewait, sock)
  unsubscribe(readwait, sock)
  return sock
end

function receive_subscribe(sock, callback, close_callback)
  local co = coroutine.create(
    function()
      subscribe(readwait, sock)
      sock:settimeout(0) -- WTF not set before ???

      while true do
        local data, err, lo = sock:receive(8192)
        if err == 'timeout' then
          if lo and #lo > 0 then callback(lo) end
        elseif err == 'closed' then
          unsubscribe(readwait, sock)
          close_callback()
          return
        elseif err then
          print('async receive cb err:', err, lo and #lo)
          unsubscribe(readwait, sock)
          close_callback()
          return
        else
          callback(data)
        end
        coroutine.yield()
      end
    end
  )
  coroutine.resume(co)
end

function receive(sock, pattern)
  subscribe(readwait, sock)

  local data, err, lo
  local parts = {}
  while not data do
    sock:settimeout(0) -- WTF not set before ???
    -- print('receiving from', sock)
    data, err, lo = sock:receive(pattern)
    -- print('received from', sock, data and #data, err, lo and #lo)
    table.insert(parts, lo)
    if err == 'timeout' then
      -- print('receive timeout', data, err, lo and #lo)
      if coroutine.running() then coroutine.yield() end
      -- print('receive resumed')
    elseif err == 'closed' then
      print('closed on receive')
      unsubscribe(readwait, sock)
      return nil, err, table.concat(parts)

    elseif err then
      print('async receive err:', err, lo and #lo)

      unsubscribe(readwait, sock)
      return nil, err, table.concat(parts)
    end
  end

  -- print('received something', data and #data)
  unsubscribe(readwait, sock)
  table.insert(parts, data)
  return table.concat(parts)
end

function send(sock, data_to_send)
  subscribe(writewait, sock)

  local data, err
  while not data do
    -- print('sending', sock)
    data, err = sock:send(data_to_send)
    if err == 'timeout' then
      -- print('send timeout')
      if coroutine.running() then coroutine.yield() end
      -- print('send resumed')
    elseif err then
      print('async send err:', err)

      unsubscribe(writewait, sock)
      return nil, err
    end
  end
  -- print('sent', data)

  unsubscribe(writewait, sock)
  return data
end

local function cleanup(co)
  -- print("!!!! cleanup", co)
  for sock, coroutine in pairs(connections_coroutines) do
    if co == coroutine then
      connections_coroutines[sock] = {}
      unsubscribe(connwait, sock)
      unsubscribe(readwait, sock)
      unsubscribe(writewait, sock)
    end
  end
end

function add_server(server, handler)
  server:settimeout(0)
  server_handlers[server] = handler
  table.insert(connwait, server)
end

local timeout = 1
function set_timeout(user_timeout)
  timeout = user_timeout
end

function step()
  local c_ready, conn_ready, err = socket.select(connwait, connwait, timeout)
  -- print('select c', #c_ready..'/'..#connwait, #conn_ready..'/'..#connwait, err)
  
  local cos_to_wake_up = {}
  for i, connection in ipairs(c_ready) do
    local handler = server_handlers[connection]
    local client, err = connection:accept()
    local co = coroutine.create(function() handler(client) end)
    local cos = connections_coroutines[client]
    if not cos then
      cos = {}
      connections_coroutines[client] = cos
    end
    cos[co] = true
    cos_to_wake_up[co] = true
  end

  local read_ready, write_ready, err = socket.select(readwait, writewait, timeout)
  -- print('select', #read_ready..'/'..#readwait, #write_ready..'/'..#writewait, err)

  for i, connection in ipairs(read_ready) do
    local cos = connections_coroutines[connection]
    for co, _ in pairs(cos) do
      cos_to_wake_up[co] = true
    end
  end

  for i, connection in ipairs(write_ready) do
    cos_to_wake_up[connections_coroutines[connection]] = true
  end

  for co in pairs(cos_to_wake_up) do
    local result, err = coroutine.resume(co)
    if err then
      print('co err ', co, result, err, coroutine.status(co))
    end
    if coroutine.status(co) == 'dead' then
      cleanup(co)
      break
    end
  end
  
  for _, co in pairs(regular) do
    local result, err = coroutine.resume(co)
    if err then
      print('regular co err ', co, result, err, coroutine.status(co))
    end
    if coroutine.status(co) == 'dead' then
      remove_regular(co)
      break
    end
  end    
end

local shutdown

function loop()
  while not shutdown do
    step()
  end
end

function shut_down()
  shutdown = true
end

function pipe(socket)
  return {
    receive = function(pattern)
      return async.receive(socket, pattern)
    end,
    send = function(data)
      return async.send(socket, data)
    end,
    receive_subscribe = function(callback, close_callback)
      return async.receive_subscribe(socket, callback, close_callback)
    end,
    close = function()
      socket:close()
    end
  }
end
