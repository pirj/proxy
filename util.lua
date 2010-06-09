local function trim(s)
  local n = s:find"%S"
  return n and s:match(".*%S", n) or ""
end

function to_html(h, indent)
  indent = indent or ''
  local res = ''
  if h._tag then
    res = res..indent..'<'..h._tag..attrs(h._attr)..'>\n'
  end
  if type(h) == 'table' then
    for i,v in ipairs(h) do
      res = res..to_html(v, h._tag and indent..'  ' or indent)
    end
  elseif type(h) == 'string' then
    local s = trim(h)
    if #s > 0 then
      -- res = res..'  ![CDATA['..s..']]'
      res = res..'  '..s..''
    end
  end
  if h._tag then
    res = res..indent..'</'..h._tag..'>\n'
  end
  
  return res
end

local function attrs(attrl)
  if attrl == nil then return '' end
  local res = ''
  for key, value in pairs(attrl) do
    res = res..' '..key..'="'..encode(value)..'"'
  end
  return res
end

local function encode(str)
	if "string" ~= type(str) then str = tostring(str) end
	local repl = {["<"] = "&lt;", [">"] = "&gt;", ["\""] = "&quot;", ["&"] = "&amp;", ["'"] = "&apos;"}
	return (string.gsub(str, "[<>\"&']", repl))
end

local function table_print (tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    local sb = {}
    for key, value in pairs (tt) do
      if type (value) == "table" and not done [value] then
        table.insert(sb, string.rep (" ", indent)) -- indent it
        done [value] = true
        table.insert(sb, "{\n");
        table.insert(sb, table_print (value, indent + 2, done))
        table.insert(sb, string.rep (" ", indent)) -- indent it
        table.insert(sb, "},\n");
      elseif "number" == type(key) then
        -- table.insert(sb, string.rep (" ", indent)) -- indent it
        -- table.insert(sb, string.format("\"%s\"\n", tostring(value)))
      else
        table.insert(sb, string.rep (" ", indent)) -- indent it
        table.insert(sb, string.format(
            "%s = \"%s\",\n", tostring (key), tostring(value)))
       end
    end
    return table.concat(sb)
  else
    return tt .. "\n"
  end
end

function to_string( tbl )
    if  "nil"       == type( tbl ) then
        return tostring(nil)
    elseif  "table" == type( tbl ) then
        return table_print(tbl)
    elseif  "string" == type( tbl ) then
        return tbl
    else
        return tostring(tbl)
    end
end

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
  print('total chinks:', #chunks)
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
