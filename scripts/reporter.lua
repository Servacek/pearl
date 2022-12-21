
local MARKDOWN = require("libraries/markdown")
local Webhook = require("libraries/discordapi/models/webhook")
local Message = require("libraries/discordapi/models/message")
local LogLine = require("libraries/discordapi/models/logline")

-------------------------------------
-- [[ Constants ]]
-------------------------------------

local MAX_TRACEBACK_LENGHT = 1024

-------------------------------------
-- [[ Class Declarations ]]
-------------------------------------

--- @class Reporter
local Reporter = Class(function(self)
    self._webhook = Webhook(PEARL.CONFIG.DISCORD.RHOOK.ID, PEARL.CONFIG.DISCORD.RHOOK.TOKEN)
end)

-------------------------------------
-- [[ Public Functions ]]
-------------------------------------

function Reporter:ReportModError(err)
    if not type(err) == "string" then
        return
    end

    if #err > MAX_TRACEBACK_LENGHT then
        err = err:ltake(MAX_TRACEBACK_LENGHT).."..."
    end

    local _, json_data = Message()
        :SetContent(MARKDOWN.codeblock(err, "lua"))
        :ToJson()

    PEARL.DiscordRestAPI:ExecuteWebhook(self._webhook, json_data, true)
end

-------------------------------------

return Reporter
