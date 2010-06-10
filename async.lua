module(..., package.seeall)

require 'socket' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/

local connections_coroutines = {} -- socket: coroutine
local read = {} -- read sockets
local write = {} -- write sockets
local server_handlers = {}
local regular = {}

function add_regular(co)
  table.insert(regular, co)
end

function remove_regular(co)
  for i, c in ipairs(regular) do
    if co == c then
      table.remove(regular, i)
      return
    end
  end
end

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
  sock:settimeout(0)
  subscribe(read, sock, coroutine.running()) -- one should be enough!!!
  subscribe(write, sock, coroutine.running())

  local res, err = sock:connect(host, port)
  if err == 'timeout' then
    while not sock:getpeername() do
      -- print('conn timeout, yield', host, port, sock:getpeername())
      if coroutine.running() then coroutine.yield() end
    end
  elseif err then
    print('async conn err:', err)
    return nil, err
  end

  unsubscribe(read, sock) -- one should be enough!!!
  unsubscribe(write, sock)
  return sock
end

function receive(sock, pattern)
  subscribe(read, sock, coroutine.running())

  local data, err, lo
  local parts = {}
  while not data do
    -- print('receiving', sock)
    data, err, lo = sock:receive(pattern)
    table.insert(parts, lo)
    if err == 'timeout' then
      -- print('receive timeout', data, err, lo and #lo)
      if coroutine.running() then coroutine.yield() end
      -- print('receive resumed')
    elseif err then
      -- print('async receive err:', err, lo and #lo)

      unsubscribe(read, sock)
      return nil, err, table.concat(parts)
    end
  end

  unsubscribe(read, sock)
  table.insert(parts, data)
  return table.concat(parts)
end

function send(sock, data_to_send)
  subscribe(write, sock, coroutine.running())

  local data, err
  while not data do
    -- print('sending', sock)
    data, err = sock:send(data_to_send)
    if err == 'timeout' then
      -- print('send timeout')
      if coroutine.running() then coroutine.yield() end
      -- print('send resumed')
    elseif err then
      -- print('async send err:', err)

      unsubscribe(write, sock)
      return nil, err
    end
  end
  -- print('sent', data)

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

function add_server(server, handler)
  server:settimeout(0)
  server_handlers[server] = handler
  table.insert(read, server)
end

local timeout = 1
function set_timeout(user_timeout)
  timeout = user_timeout
end

function step()
  local read_ready, write_ready, err = socket.select(read, write, timeout)
  -- print('select', #read_ready..'/'..#read, #write_ready..'/'..#write, err)
  
  local cos_to_wake_up = {}
  for i, connection in ipairs(read_ready) do
    if not connections_coroutines[connection] then
      local handler = server_handlers[connection]
      local client, err = connection:accept()
      local co = coroutine.create(function() handler(client) end)
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
      print('co err ', co, result, err, coroutine.status(co))
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
