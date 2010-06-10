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
  local chunks = {}
  chunkie, chunk_size = readline(chunkie)

  repeat
    local chunk
    chunkie, chunk = readbytes(chunkie, tonumber(chunk_size, 16))
    if chunk then
      table.insert(chunks, chunk)
      chunkie, _ = readline(chunkie)
      chunkie, chunk_size = readline(chunkie)
    else
      chunk_size = nil
    end
  until not chunk_size or chunk_size == '0'
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
