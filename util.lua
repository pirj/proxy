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

  while chunk_size and tonumber(chunk_size, 16) > 0 do
    chunkie, chunk = readbytes(chunkie, tonumber(chunk_size, 16))

    table.insert(chunks, chunk)
    chunkie, chunk_size = readline(chunkie)
    if not chunk_size or chunk_size == '' then -- sometimes there's a crlf, sometimes not
      chunkie, chunk_size = readline(chunkie)
    end
  end

  return table.concat(chunks)
end

function url_encode(str)
  return string.gsub(str, "([^a-zA-Z0-9_\*\'\(\)\.\+\!$\-])", function(c) return string.format("%%%02X", string.byte(c)) end)
end

-- This unpack doesn't cut trailing nils
-- {1, 2, 3, nil} => 1, 2, 3, nil instead of 1, 2, 3 for unpack()
function unpack_with_nils(t, i)
  i = i or 1
  if i <= t.n then
    return t[i], unpack_with_nils(t, i + 1)
  end
end
