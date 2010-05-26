module(..., package.seeall)

local function check_captcha(data)
  print('data')
  
  -- search captcha
  if string.find(data, 'captcha') then
    -- download image
    -- send to server
    -- yield in loop for 5 sec
    -- yield in loop asking server for resolved, wait 1 sec
    
    -- post to travian
    -- get result, pass back
    return result
  else
    return data
  end
end

function filter(url, mimetype, data)
  -- !! html only ??
  if string.find(url, 'travian') then
    print('travian')
    return check_captcha(data)
  else
    return data
  end
end
