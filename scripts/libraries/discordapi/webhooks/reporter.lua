--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--- @TODO: Think about a way to reduce duplication here...

local MARKDOWN = PEARL.loadfile("libraries/markdown")
local EMBEDS = PEARL.loadfile("utils/embeds")

local Webhook = PEARL.loadfile("libraries/discordapi/models/webhook")
local Message = PEARL.loadfile("libraries/discordapi/models/message")

-------------------------------------
-- [[ Constants ]]
-------------------------------------

local MAX_TRACEBACK_LENGHT = 1024
local MAX_REPORTED_CACHE = 5
local ERROR_ID_PATTERN = "^(.*)\n.*"

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

    if not self._webhook:IsValid() then
        self:SetIsDisabled(true)
        return PEARL.error("Token and/or ID is not configured for the reporter webhook correctly!")
    end

    --- @type table<string>
    self._reported = {}
end)

-------------------------------------
-- [[ Private Functions ]]
-------------------------------------

--- @param content string
--- @param force boolean?
function Reporter:_SendReportMessage(content, force)
    if type(content) ~= "string" then
        return PEARL.error("Attempted to send an invalid report message...")
    end

    PEARL.info("Sending error log to discord...")
    return self:SendRawReportMessage(Message(content), force)
end

function Reporter:_GetErrorID(traceback)
    return traceback and traceback:match(ERROR_ID_PATTERN)
end

function Reporter:_WasErrorReported(error_id)
    if not error_id then
        return false
    end

    for i = 1, #self._reported do
        if self._reported[i] == error_id then
            return true
        end
    end

    return false
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

--- @param message Message
--- @param force boolean?
function Reporter:SendRawReportMessage(message, force)
    local _, json_data = message:ToJson()

    return PEARL.DiscordRestAPI:ExecuteWebhook(
        self._webhook, json_data, force
    )
end

--- @param str string
--- @param force boolean?
function Reporter:SendRawReportString(str, force)
    return self:SendRawReportMessage(Message(str), force)
end

--- @param reason string A short description of the issue that has occured.
function Reporter:ReportFailedHTTPRequest(reason)
    if type(reason) ~= "string" or self:IsDisabled() then
        return
    end

    reason = MARKDOWN.codeblock(reason:ltake(MAX_TRACEBACK_LENGHT, nil, "..."))
    return self:_SendReportMessage(MARKDOWN.bold(STRINGS.PEARL.LOGS.HTTP_ERROR:format(
        MARKDOWN.codeline(PEARL.GetShardFancyName()), reason
    )))
end

--- WARNING: Uses force sending to send the report. Use with caution!
--- The reporter will be disabled after calling this for safety reasons.
--- We expect that the server will shutdown after an uncatched error.
--- @param traceback string
function Reporter:ReportUncatchedLuaError(traceback)
    if type(traceback) ~= "string" or self:IsDisabled() then
        return
    end

    -- Disable to prevent any looping since these reports are sent by force.
    self:SetIsDisabled(true)

    traceback = MARKDOWN.codeblock(traceback:ltake(MAX_TRACEBACK_LENGHT, nil, "..."), "lua")
    return self:_SendReportMessage(MARKDOWN.bold(STRINGS.PEARL.LOGS.EXCEPTION_UNCATCHED:format(
        MARKDOWN.codeline(PEARL.GetShardFancyName()), traceback
    )), true) -- Force-send uncatched errors.
end

--- @param traceback string
function Reporter:ReportCatchedLuaError(traceback)
    if type(traceback) ~= "string" or self:IsDisabled() then
        return
    end

    --- @TODO
    -- Some attempts to reduce duplication...
    -- local error_id = self:_GetErrorID(traceback)
    -- print("ERROR ID:", error_id)
    -- if self:_WasErrorReported(error_id) then
    --     return PEARL.debug("!!!!!!!!!!!!!!!!!!!! ALREADY REPORTED!!!!!")
    -- end
    -- self._reported[#self._reported+1] = error_id

    traceback = MARKDOWN.codeblock(traceback:ltake(MAX_TRACEBACK_LENGHT, nil, "..."), "lua")
    return self:_SendReportMessage(MARKDOWN.bold(STRINGS.PEARL.LOGS.EXCEPTION_CATCHED:format(
        MARKDOWN.codeline(PEARL.GetShardFancyName()), traceback
    )))
end

--- @param userid string The identifier of the client where the error happened on.
--- @param traceback string
function Reporter:ReportUncatchedClientLuaError(userid, traceback)
    if type(traceback) ~= "string" or self:IsDisabled() then
        return
    end

    traceback = MARKDOWN.codeblock(traceback:ltake(MAX_TRACEBACK_LENGHT, nil, "..."), "lua")
    local message = Message(MARKDOWN.bold(STRINGS.PEARL.LOGS.EXCEPTION_UNCATCHED_CL:format(
        MARKDOWN.codeline(userid), traceback
    )))

    -- If the client has some mods enabled, send that info to the server as well.
    local client_cfd = PEARL.ServerNetwork:GetCachedCFDFor(userid)
    if type(client_cfd) == "table" and not IsTableEmpty(client_cfd) then
        message:AddEmbed(EMBEDS.ClientMods(client_cfd.enabled_mods, client_cfd.username))
    end

    return self:SendRawReportMessage(message)
end

-------------------------------------

return Reporter
