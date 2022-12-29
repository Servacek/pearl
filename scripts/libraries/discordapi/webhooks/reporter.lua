
local MARKDOWN = PEARL.loadfile("libraries/markdown")
local Webhook = PEARL.loadfile("libraries/discordapi/models/webhook")
local Message = PEARL.loadfile("libraries/discordapi/models/message")

-------------------------------------
-- [[ Constants ]]
-------------------------------------

local MAX_TRACEBACK_LENGHT = 1024

-------------------------------------
-- [[ Class Declarations ]]
-------------------------------------

--- @class Reporter
local Reporter = Class(function(self)
    self._disabled = not PEARL.CONFIG.DISCORD.RHOOK.ENABLED
    if self._disabled then
        return
    end

    self._webhook = Webhook(PEARL.CONFIG.DISCORD.RHOOK.ID, PEARL.CONFIG.DISCORD.RHOOK.TOKEN)
end)

-------------------------------------
-- [[ Public Functions ]]
-------------------------------------

function Reporter:IsEnabled()
    return not self._disabled
end

function Reporter:ReportModError(err)
    if type(err) ~= "string" then
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
