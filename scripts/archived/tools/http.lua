local json = require('tools/json')

--------------------------------------

local WEBHOOK_URL = "https://discord.com/api/webhooks/774292141660176414/zm2JrHhVl5ATowmrIj_7WUwYYAjUqlOU_igarvSFJB1IdV13IJPy1S_26Nl_B57XzGAE"

--------------------------------------

local http = {}

-- Logging
local function PostCallback(result, is_successful, http_code)
    SUB.info("Webhook", "["..http_code.."] "..result)
end

-- TODO - add emebed and file support
function http.send(content)
    if content ~= nil then
        local timestamp = os.date("%H:%M:%S", os.time())

        TheSim:QueryServer(
            WEBHOOK_URL, -- target URL
            PostCallback, -- Callback
            "POST", -- Request method
            json.encode({  -- json data string
                content="`["..timestamp.."]:` "..tostring(content),
                allowed_mentions={
                    parse={},
                },
            })
        )
    end
end



return http
