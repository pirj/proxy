module(..., package.seeall)

local http = require('socket.http')
local mime = require('mime')
local ltn12 = require('ltn12')
require 'async'

local server = 'http://dewpel.com'
local rosa_user = 'pirj@mail.ru'
local rosa_password = 'Q2w3E4'

local function url_encode(str)
  str = string.gsub (str, "([^%w ])",
      function (c) return string.format ("%%%02X", string.byte(c)) end)
  str = string.gsub (str, " ", "+")
  return str	
end

local function yield_for(seconds)
    local expected = os.time() + seconds
    async.add_regular(coroutine.running())
    while os.time() < expected do
      coroutine.yield()
    end
    async.remove_regular(coroutine.running())
end

function filter(url, mimetype, request_headers, data)
  -- searching captcha on the page
  local captcha = string.match(data, '<iframe src="(http://api.recaptcha.net/noscript??k=[%a%d_]+&amp;lang=en)')
  
  if not captcha then
    -- print('not matched')
    -- yahoo, no captcha! proceeding
    return data
  end
  
  -- print('got captcha: '..captcha)
  
  -- downloading google's nojavascript recaptcha page
  local captcha_page = http.request(captcha)
  -- print('got page: '..captcha_page)
  
  -- find image link
  -- src="image?c=03AHJ_VuvCYZT-aZL96WJa7bTVx6rlUcqAWPtNkM-zQ5NHKQYinkjcV5DT-u-qm5mfTgnqlqrKTwAzZWcMwo5cumK7bbSRddzQtevH1NuYwkfpj33cALtgJ3rygojWGaTJ_xhbGrOqly7G9fDZlEqb0qNVseZ517ui0w"
  local image_link = 'http://api.recaptcha.net/'..string.match(captcha_page, 'src="(image??c=[%d%a%-_]+)"')
  print('image link:'..image_link)
  
  -- <form action="" method="POST"><input type="hidden" name="recaptcha_challenge_field" id="recaptcha_challenge_field" value="03AHJ_Vus1DNaUUxmLppQiGmbYTEN4Yl1orZhsDZQhjeCedmTNUmjmBM4GiXagAfY8CDH7ibRywvz2HubPsnAJksY_LK5wp6o-Pi7wugdC81nOAC-1WQ-3EIqJ1VsIq9yFK0bCmDWJxark_OX_CXS7bXRQ6fP_qEH76A">
  local challenge = string.match(captcha_page, 'id="recaptcha_challenge_field" value="([%d%a%-_=]+)">')
  print('challenge:'..challenge)

  -- post image link to rosa server
  local captcha_id

  local status = 0
  repeat
    captcha_id = {}
    print('sending AG request, yield 1 sec')
    _, status = http.request {
      url = server..'/captcha/upload/'..mime.b64(image_link),
      headers = {['Authorization'] = 'Basic '..mime.b64(rosa_user..':'..rosa_password) },
      sink = ltn12.sink.table(captcha_id)
    }
    print('resp:', table.concat(captcha_id))
    yield_for(1)
  until status == 200

  captcha_id = table.concat(captcha_id)
  print('waiting id, yield 4 sec:'..captcha_id)
  
  -- yield in loop for 4 sec
  yield_for(4)

  print('waiting id2:'..captcha_id)
  
  -- yield in loop asking server for resolved, wait 1 sec
  local resolved
  local status = 0
  repeat
    resolved = {}
    print('waiting id, yield 1 sec:'..captcha_id)
    yield_for(1)
    _, status = http.request {
      url = server..'/captcha/'..captcha_id,
      headers = {['Authorization'] = 'Basic '..mime.b64(rosa_user..':'..rosa_password) },
      sink = ltn12.sink.table(resolved)
    }
  until status == 200
  
  resolved = table.concat(resolved)
  print('resolved:'..resolved)

  -- recaptcha_challenge_field  02JU_v-DFLIW47OAVaPx6-S87AAUZnbWyPvKzSFx3tM_EY_GKOZbCCOlQ_KEI7ohYapxkgTeG7YQbPzWqTfkyslA-qU52MwvHC7t3MoEk3xCwMq7jvdeHZq34hqraoKuSq2NrddkeTecKvBlV0L2sA8oUcj2Pv3jhxe-sHyWkNon4Qgbh_1CApy7hQyeZ1Tf1-lu_9fxH08s1d15Kz373h0ZgoAubu2GXPmB631cDNykMTcEJ-ipJUVsKLepes7qvzjxqeZ_FJeBjDtk1nfnmHWq16KusB
  -- recaptcha_response_field may ullman
  local post_data = 
    'recaptcha_challenge_field='..url_encode(challenge)..'&'..
    'recaptcha_response_field='..url_encode(resolved)
  print('post_data:'..post_data)
  
-- Host s4.travian.ru
-- User-Agent Mozilla/5.0 (Macintosh; U; PPC Mac OS X 10.4; en-US; rv:1.9.1.2) Gecko/20090729 Firefox/3.5.2
-- Accept text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
-- Accept-Language  en-us,en;q=0.5
-- Accept-Encoding  gzip,deflate
-- Accept-Charset ISO-8859-1,utf-8;q=0.7,*;q=0.7
-- Keep-Alive 300
-- Connection keep-alive
-- Referer  http://s4.travian.ru/dorf1.php
-- Cookie T3E=ldDOwEjZ0EGZ2ozM1ETM3QzNyo34zgTOzoTMzEjN1gTN3ITM6UjO2gjN3kDZxMmY5oTI6CNsQrL0g4L0yCtOzETM3ATM6AzI5YjN2kzIzETM3ATM
-- Content-Type application/x-www-form-urlencoded
-- Content-Length 348

  print('original headers:'..table.concat(request_headers, '\r\n'))
  
  request_headers['Content-Type'] = 'application/x-www-form-urlencoded'
  request_headers['Content-Length'] = #post_data
  
  -- post to travian
  print('posting['..post_data..']')
  local host = string.match(url, '%a+ (http://[%a%d\./:-]+)')
  local result = {}
  r, c, d, e = http.request {
    method = 'POST',
    url = host,
    headers = request_headers,
    sink = ltn12.sink.table(result)
  }
  print('response:')
  print(r, c, d, e)
  print(table.concat(result))
  
  -- get result, pass back
  return table.concat(result), true
end

function pre(url, mimetype, request_headers)
  return string.find(url, 'travian') and mimetype and string.find(mimetype, 'text/html')
end
