local G = GLOBAL
local json = G.json

--------------------------------------

local WEBHOOK_URL = "https://discord.com/api/webhooks/774292141660176414/zm2JrHhVl5ATowmrIj_7WUwYYAjUqlOU_igarvSFJB1IdV13IJPy1S_26Nl_B57XzGAE"

--------------------------------------

local http = {}

-- Logging
local function PostCallback(result, is_successful, http_code)
    print("[Webhook] ["..http_code.."] "..result)
end

-- TODO - add emebed and file support
function http.send(content)
    if content ~= nil then
        -- os needs to be global
        local timestamp = G.os.date("%H:%M:%S", G.os.time())

        G.TheSim:QueryServer(
            WEBHOOK_URL, -- target URL
            PostCallback, -- Callback
            "POST", -- Request method
            json.encode_compliant({  -- json data string
                content="`["..timestamp.."]:` "..tostring(content),
                allowed_mentions={
                    parse={},
                },
            })
        )
    end
end

function http.sendEmbed(title, description, footer)
    if title or description or footer then
        G.TheSim:QueryServer(
            WEBHOOK_URL, -- target URL
            PostCallback, -- Callback
            "POST", -- Request method
            json.encode_compliant({  -- json data string
                embeds={{
                    title=title,
                    description=description,
                    footer={
                        text=footer
                    }
                }},
                allowed_mentions={
                    parse={},
                },
            })
        )
    end
end


G.http = http
