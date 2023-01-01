
--- @TODO: Think about a way to reduce duplication here...

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
-- [[ Private Functions ]]
-------------------------------------

--- @param content string
--- @param force boolean
function Reporter:_SendReportMessage(content, force)
    if type(content) ~= "string" then
        return
    end

    PEARL.info("Sending error log to discord...")
    PEARL.DiscordRestAPI:ExecuteWebhook(
        self._webhook, Message():SetContent(content):ToJson(), force
    )
end

-------------------------------------
-- [[ Public Functions ]]
-------------------------------------

function Reporter:IsDisabled()
    return self._disabled
end

function Reporter:IsEnabled()
    return not self._disabled
end

function Reporter:SetIsDisabled(disabled)
    self._disabled = disabled
end

--- @param reason string A short description of the issue that has occured.
function Reporter:ReportFailedHTTPRequest(reason)
    if type(reason) ~= "string" or self:IsDisabled() then
        return
    end

    reason = MARKDOWN.codeblock(reason:ltake(MAX_TRACEBACK_LENGHT, nil, "..."))
    return self:_SendReportMessage(Message()
        :SetContent(MARKDOWN.bold(STRINGS.PEARL.LOGS.HTTP_ERROR:format(
            MARKDOWN.codeline(PEARL.GetShardName()), reason
        )))
    )
end

--- WARNING: Uses force sending to send the report. Use with caution!
--- @param traceback string
function Reporter:ReportUncatchedLuaError(traceback)
    if type(traceback) ~= "string" or self:IsDisabled() then
        return
    end

    traceback = MARKDOWN.codeblock(traceback:ltake(MAX_TRACEBACK_LENGHT, nil, "..."), "lua")
    return self:_SendReportMessage(Message()
        :SetContent(MARKDOWN.bold(STRINGS.PEARL.LOGS.EXCEPTION_UNCATCHED:format(
            MARKDOWN.codeline(PEARL.GetShardName()), traceback
        ))), true -- Force-send uncatched errors.
    )
end

--- @param traceback string
function Reporter:ReportCatchedLuaError(traceback)
    if type(traceback) ~= "string" or self:IsDisabled() then
        return
    end

    traceback = MARKDOWN.codeblock(traceback:ltake(MAX_TRACEBACK_LENGHT, nil, "..."), "lua")
    return self:_SendReportMessage(Message()
        :SetContent(MARKDOWN.bold(STRINGS.PEARL.LOGS.EXCEPTION_CATCHED:format(
            MARKDOWN.codeline(PEARL.GetShardName()), traceback
        )))
    )
end

-------------------------------------

return Reporter
