module(..., package.seeall)

local http = require('socket.http')
local ltn12 = require('ltn12')

local function check_captcha(data)
  print('data')
  
  -- searching captcha on the page
  local captcha = string.match(data, '<iframe src="(http://api.recaptcha.net/noscript??k=[%a%d_]+&amp;lang=en)')
  
  if captcha then
    print('got captcha: '..captcha)
    -- optionally transforming url to google to avoid http redirect
    -- http://api.recaptcha.net/noscript?k=6LfdmAsAAAAAAPb_3Zn53hlv5fR3oUS0FeXc7a9h&amp;lang=en
    -- http://www.google.com/recaptcha/api/noscript?k=6LfdmAsAAAAAAPb_3Zn53hlv5fR3oUS0FeXc7a9h&amp;lang=en
    -- local google = string.gsub(captcha, 'http://api.recaptcha.net/noscript', 'http://www.google.com/recaptcha/api/noscript')
    
    -- downloading google's nojavascript recaptcha page
    local captcha_page = http.request(captcha)
    print('got page: '..captcha_page)
    
    -- find image link
    -- src="image?c=03AHJ_VuvCYZT-aZL96WJa7bTVx6rlUcqAWPtNkM-zQ5NHKQYinkjcV5DT-u-qm5mfTgnqlqrKTwAzZWcMwo5cumK7bbSRddzQtevH1NuYwkfpj33cALtgJ3rygojWGaTJ_xhbGrOqly7G9fDZlEqb0qNVseZ517ui0w"
    local image_link = 'http://api.recaptcha.net/'..string.match(captcha_page, 'src="image??c=[%d%a%-_]+)"')
    print('image link:'..image_link)

    -- download image
    local image = http.request(image_link)
    print('got image, size='..#image)
    
    -- post image to rosa server
    http.request{
      url = 'http://dewpel.com',
      -- [sink = LTN12 sink,]
      [method = string,]
      headers = {['Content-Length'] = #image}
      [source = LTN12 source],
      [step = LTN12 pump step,]
      -- [proxy = string,]
      -- [redirect = boolean,]
      -- [create = function]
    }

    local source = ltn12.source.file()
    local sink = ltn12.sink.file()
    
    local transferring_image = true
    while transferring_image do
      transferring_image = ltn12.pump.all(source, sink)
    end
    
    
    
    
    
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
