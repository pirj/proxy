-- Usage:
--
-- require 'async'
-- local http = require 'http'
--
-- local pipe = async.pipe(socket)
-- local request = http.request(pipe)
--
-- print request.request_line()
-- print request.method()
-- print request.uri()
-- print(table.concat(request.headers(), '\r\n'))
-- print(request.headers('Accept-Encoding'))
-- print request.body()
-- request.headers('User-Agent', 'Man_in_the_middle/1.0')
-- print request.raw()
--
--
-- local pipe = async.pipe(socket)
-- local response = http.response(pipe)
--
-- print response.status_line()
-- print response.status()
-- print response.headers()
-- print response.headers('Age')
-- print response.body()
-- response.set_body(string.gsub(response.body(), "<head>", "<head><script>alert('adding something')</script>"))
-- response.headers('Age', '2147483648')
-- print response.raw()

local gzip = require 'lib/deflatelua'
require 'util'

local function first_line(pipe, target)
-- Request-Line   = Method SP Request-URI SP HTTP-Version CRLF
  if not target.first_line then
    target.first_line = pipe.receive '*l'
  end
  return target.first_line
end

local function method(pipe, target)
-- Method = "OPTIONS" | "GET" | "HEAD" | "POST" | "PUT" | "DELETE" | "TRACE" | "CONNECT" | extension-method
  if not target.method then
    local rl = first_line(pipe, target)
    target.method, target.uri, target.http_version = string.match(rl, '([^%s]+)%s([^%s]+)%s(.+)')
  end
  return target.method
end

local function uri(pipe, target)
-- Request-URI    = "*" | absoluteURI | abs_path | authority
  if not target.uri then
    local rl = first_line(pipe, target)
    target.method, target.uri, target.http_version = string.match(rl, '([^%s]+)%s([^%s]+)%s(.+)')
  end
  return target.uri
end

local function status(pipe, target)
  if not target.method then
    local sl = first_line(pipe, target)
    target.method = string.match(sl, '([^%s]+)')
  end
  return target.method
end

local function header_access(pipe)
  local data = {}
  repeat
    local line = pipe.receive '*l'
    if line then
      local key, value = string.match(line, '([%a-]+): (.+)')
      -- print("parsing h", key, value)
      if key then
        data[key] = value
      end
    end
  until line == '' or line == nil

  return function(...)
    if arg.n == 0 then
      local hs = {}
      -- for k,v in pairs(data) do table.insert(hs, k..': '..v) end
      for k,v in pairs(data) do hs[k] = v end
      return hs
    end
    local key = arg[1]
    if arg.n == 1 then
      return data[key]
    else
      data[key] = arg[2]
    end
  end
end

local function headers(pipe, target, ...)
  if not target.first_line then
    first_line(pipe, target)
  end
  if not target.headers then
    target.headers = header_access(pipe)
  end
  
  return target.headers(unpack_with_nils(arg))
end

local function join_headers(headers)
  local t = {}
  for k,v in pairs(headers) do
    table.insert(t, k..': '..v)
  end
  return table.concat(t, '\r\n')
end

local function body_raw(pipe, target)
  -- print('br')
  if not target.headers then
    -- print('nh')
    headers(pipe, target)
  end
  -- print('jh', join_headers(headers(pipe, target)))
  if not target.body_raw then
    local content_length = target.headers()['Content-Length']
    local transfer_encoding = target.headers()['Transfer-Encoding']
    -- print("content_length", content_length)
    -- print("transfer_encoding", transfer_encoding)
    -- for i,j in pairs(target.headers()) do print(i,"=",j) end
    if transfer_encoding == 'chunked' or (content_length and tonumber(content_length) > 0) then
      -- print('recv body')
      local pattern = '*a'
      if content_length then
        pattern = tonumber(content_length)
      end
      local data, err, left = pipe.receive(pattern)
      -- print('recv body done', data and #data, err, left and #left)
      target.body_raw = data or left
    else
      target.body_raw = ''
      -- print('skipping body')
    end
  end
  
  return target.body_raw
end

local function body(pipe, target)
  if not target.body then
    target.body = body_raw(pipe, target)

    -- dechunking
    if headers(pipe, target)['Transfer-Encoding'] == 'chunked' then
      target.body = dechunk(target.body)
    end

    -- gunziping
    if headers(pipe, target)['Content-Encoding'] == 'gzip' and #target.body > 0 then
      local decoded = {}
      gzip.gunzip {input=target.body, output=function(byte) table.insert(decoded, string.char(byte)) end}
      target.body = table.concat(decoded)
    end
  end

  return target.body
end

local function set_body(pipe, target, ...)
	target.headers('Content-Encoding', nil)
	target.headers('Transfer-Encoding', nil)
  target.body_raw = arg[1]
end

local function request_raw(pipe, target)
  return first_line(pipe, target)..'\r\n'..join_headers(headers(pipe, target))..'\r\n\r\n'..body_raw(pipe, target)
end

-- todo: !!! watch for body changes
local function response_raw(pipe, target)
  return first_line(pipe, target)..'\r\n'..join_headers(headers(pipe, target))..'\r\n\r\n'..body_raw(pipe, target)
end

function parser(functions)
  return function(pipe)
    local data = {}
    local funs = {}
    for name, fun in pairs(functions) do
      funs[name] = function(...)
        return fun(pipe, data, unpack_with_nils(arg))
      end
    end

    return funs
  end
end

local request_functions = {
  request_line = first_line,
  method = method,
  uri = uri,
  headers = headers,
  body = body,
  body_raw = body_raw,
  raw = request_raw
}

local response_functions = {
  status_line = first_line,
  status = status,
  headers = headers,
  body_raw = body_raw,
  body = body,
  set_body = set_body,
  raw = response_raw
}

return {
  request = parser(request_functions),
  response = parser(response_functions)
}
