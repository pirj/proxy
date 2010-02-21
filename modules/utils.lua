-----------------------------------------------------------------------------
-- Description: Utility Functions.
-- Author: Gal Dubitski
-- Version: 0.1
-- Last Update: 2008-01-15
-----------------------------------------------------------------------------

require "modules.datadumper"

-----------------------------------------------------------------------------
-- String functions
-----------------------------------------------------------------------------

-- Define a shortcut function for testing
function dump2(...)
  print(DataDumper(...), "\n---")
end

function dump(t,n)
	assert(type(t) == 'table')
	if n == nil then n = 0 end
	for k,v in pairs(t) do
		if type(v) == 'table' then
			dump(v,n+2)
		else
			print(string.rep(" ",n)..k.." => "..v)
		end
	end
end

function trim(str)
	if str ~= nil then
   		return (string.gsub(str, "^%s*(.-)%s*$", "%1"))
   	else
   		return nil
   	end
end

function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
	 	table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

function findText(str,regex)
	local lastPosition = 1
	local words = {}
	repeat
		local temp,pos,w = string.find(str,regex,lastPosition)
		if w ~= nil then
			table.insert(words,w)
			lastPosition = pos + 1
		end
	until w == nil
	return words
end

function string.beginTag(str,tagName,spaces,opened)
	local newline = [[
	
]]
	if opened then
		return str..newline..string.rep(" ",spaces).."<"..tagName..">" , spaces+2 , true
	else
		return str..string.rep(" ",spaces).."<"..tagName..">" , spaces+2 , true
	end
end

function string.endTag(str,tagName,spaces,closed)
	local newline = [[
	
]]
	if closed then
		return str..string.rep(" ",spaces-2).."</"..tagName..">"..newline , spaces-2 , false
	else
		return str.."</"..tagName..">"..newline , spaces-2 , false
	end
end

-- return a copy of the table t
function clone(t)
  local new = {}
  local i, v = next(t, nil)
  while i do
  	if type(v)=="table" then v=clone(v) end
    new[i] = v
    i, v = next(t, i)
  end
  return new
end

--- this function converts a lom object to a string
function lomToString(t)
	assert(type(t)=='table')
	local res = ""
	res = res .. "<" .. t.tag
	if t.attr ~= nil then
		attrs = t.attr
		for i,v in ipairs(attrs) do
			if type(v) == 'string' and type(attrs[v]) == 'string' then
				res = res .. " " .. v .. "=\"" .. attrs[v] .. "\""
			end
		end
	end
	res = res .. ">"
	if type(t[1]) == 'string' then res = res .. t[1] end
	for i,v in ipairs(t) do
		if type(v) == 'table' and v.tag ~= nil then
			res = res .. lomToString(v)
		end
	end
	res = res.."</"..t.tag..">"
	return res
end

