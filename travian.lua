module(..., package.seeall)

local http = require('socket.http')
local mime = require("mime")

local server = 'http://dewpel.com'
local rosa_user = 'pirj@mail.ru'
local rosa_password = 'Q2w3E4'

local function check_captcha(data)
  print('data')
  
  -- searching captcha on the page
  local captcha = string.match(data, '<iframe src="(http://api.recaptcha.net/noscript??k=[%a%d_]+&amp;lang=en)')
  
  if captcha then
    print('got captcha: '..captcha)
    
    -- downloading google's nojavascript recaptcha page
    local captcha_page = http.request(captcha)
    print('got page: '..captcha_page)
    
    -- find image link
    -- src="image?c=03AHJ_VuvCYZT-aZL96WJa7bTVx6rlUcqAWPtNkM-zQ5NHKQYinkjcV5DT-u-qm5mfTgnqlqrKTwAzZWcMwo5cumK7bbSRddzQtevH1NuYwkfpj33cALtgJ3rygojWGaTJ_xhbGrOqly7G9fDZlEqb0qNVseZ517ui0w"
    local image_link = 'http://api.recaptcha.net/'..string.match(captcha_page, 'src="(image??c=[%d%a%-_]+)"')
    print('image link:'..image_link)

    -- post image to rosa server
    -- local captcha_id = http.request('http://'..rosa_user..':'rosa_password..'@dewpel.com/captcha/upload', image)

    r, c, d, e = http.request{
      url = server..'/captcha/upload/'..mime.b64(image_link),
      headers = {['Authorization'] = 'Basic '..mime.b64(rosa_user..':'..rosa_password) },
    }
    -- yield in loop for 5 sec
    -- yield in loop asking server for resolved, wait 1 sec
    
    -- post to travian
    -- get result, pass back
    return result
  else
    -- yahoo, no captcha! proceeding
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
