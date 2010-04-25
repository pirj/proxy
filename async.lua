module(..., package.seeall)

function connect(host, port)
  -- local sock = socket.tcp()
  -- sock:settimeout(0)
  -- local res, err = sock:connect(host, port)
  -- if not res then
  --   print('CONN ERR:', err)
  --   return nil, err
  -- end
  -- return res

  local sock, err = socket.connect(host, port)
  if not sock then
    print('CONN ERR:', err)
    return nil, err
  end
  sock:settimeout(0)
  return sock, err
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

  return data, err
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

  local cos = {}

  while true do
    local client, err = server:accept()

    if client then
      print('accepted')
      client:settimeout(0)
      local co = coroutine.create(function()
        handler(client)
      end)
  
      table.insert(cos, co)
    -- else
    --   print('accept failed:', err)
    end

    for i, co in ipairs(cos) do
      print('resuming', i)
      coroutine.resume(co)
      if coroutine.status(co) == 'dead' then
        print('removing', i)
        table.remove(cos, i)
        break
      end
    end
  end
end
