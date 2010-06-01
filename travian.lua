module(..., package.seeall)

local http = require('socket.http')
local mime = require('mime')
local ltn12 = require('ltn12')

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

    -- post image link to rosa server
    local captcha_id = {}
    r, c, d, e = http.request{
      url = server..'/captcha/upload/'..mime.b64(image_link),
      headers = {['Authorization'] = 'Basic '..mime.b64(rosa_user..':'..rosa_password) },
      sink = ltn12.sink.table(captcha_id)
    }
    
    captcha_id = table.concat(captcha_id)
    print('waiting id:'..captcha_id)
    
    -- yield in loop for 5 sec
    local expected = os.time() + 5
    while os.time() < expected do
      coroutine.yield()
    end
    
    -- yield in loop asking server for resolved, wait 1 sec
    local resolved
    local status
    until status == 200 do
      http.request{
        url = server..'/captcha/upload/'..mime.b64(image_link),
        headers = {['Authorization'] = 'Basic '..mime.b64(rosa_user..':'..rosa_password) },
        sink = ltn12.sink.table(captcha_id)
      }
    end
    
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
