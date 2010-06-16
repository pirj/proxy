function DEC_HEX(IN)
  local B,K,OUT,I,D=16,"0123456789ABCDEF","",0
  while IN>0 do
    I=I+1
    IN,D=math.floor(IN/B),math.mod(IN,B)+1
    OUT=string.sub(K,D,D)..OUT
  end
  return OUT
end

local function readline(s)
  local _, e, result = string.find(s, '([^\r\n]+\r\n)')
  if e then return string.sub(s, e + 1), result end
end

local function readbytes(s, n)
  return string.sub(s, n + 1), string.sub(s, 1, n)
end

function dechunk(chunkie)
  local chunk_size
  local chunk
  local chunks = {}
  chunkie, chunk_size = readline(chunkie)

  while tonumber(chunk_size, 16) > 0 do
    chunkie, chunk = readbytes(chunkie, tonumber(chunk_size, 16))

    table.insert(chunks, chunk)
    chunkie, chunk_size = readline(chunkie)
    if not chunk_size or chunk_size == '' then -- sometimes there's a crlf, sometimes not
      chunkie, chunk_size = readline(chunkie)
    end
  end

  return table.concat(chunks)
end

table.collect = function(t, f)
  r = {}
  for k,v in pairs(t) do
    if f(v) then
      r[k] = v
    end
  end
  return r
end

function url_encode(str)
  return string.gsub(str, "([^a-zA-Z0-9_\*\'\(\)\.\+\!$\-])", function(c) return string.format("%%%02X", string.byte(c)) end)
end
