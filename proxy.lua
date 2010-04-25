require 'luarocks.require' -- http://www.luarocks.org/

require 'socket' -- http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/
require 'async'
require 'travian'

local function handler(sock_in)
  local url, err = async.receive('', sock_in, '*l')

  if not url or url == '' then
    print('error: empty input', err)
    return nil
  else
    print('working: ', url)
  end

  local host = string.match(url, 'http://([%a%d\.-]+):*%d*/')
  local port = string.match(url, 'http://[%a%d\.-]+:(%d+)/')
  if not host then
    print('error:unparsable url'..url)
    return nil
  end
  local sock_out = socket.connect(host, port or 80)

  local request = url..'\r\n'
  repeat
    local line = async.receive(url, sock_in, '*l')
    if not string.find(line, 'Proxy--Connection') then
      request = request..line..'\r\n'
    end
  until line == ''
  request = request..'Connection: keep-alive\r\n'
  request = request..'\r\n'
  async.send(url, sock_out, request)
  print('requested: ', url)

  local response, err = async.receive(url, sock_out, '*a')
  if response then
    print('response received: ', url, #response)
  else
    print('response err for', url, err)
  end

  response = travian.filter(url, 'mimetype', response)

  async.send(url, sock_in, response)
  print('done: ', url)
end

async.server(3128, handler)
