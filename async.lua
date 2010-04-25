module(..., package.seeall)

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
