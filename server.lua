module(..., package.seeall)

function start(port, handler)
  server = socket.bind('localhost', port)
  server:settimeout(0.01)
  print('proxy started at port '..port)

  local cos = {}

  while true do
    local client = server:accept()

    if client then
      print('accepted')
      client:settimeout(0, 'b')
      local co = coroutine.create(function()
        handler(client)
      end)
  
      table.insert(cos, co)
    end

    local dead = {}
    for i, co in ipairs(cos) do
      coroutine.resume(co)
      if coroutine.status(co) == 'dead' then
        table.insert(dead, i)
      end
    end

    for _, i in pairs(dead) do
      table.remove(cos, i)
    end
  end
end

