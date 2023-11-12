--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--[[
    This file adds a Logger class to the mod's environment. It's a class that manages
    the message creation and buffering process. As a buffer it uses the Message container itself.

    This means that when the buffering process ends, we already have a message baked and ready to be sent.
--]]


local MARKDOWN = PEARL.loadfile("libraries/markdown")
local LogLine = PEARL.loadfile("libraries/discordapi/models/logline")
local BufferedMessage = PEARL.loadfile("libraries/discordapi/models/bufferedmessage")
local Webhook = PEARL.loadfile("libraries/discordapi/models/webhook")

-------------------------------------
-- [[ Class Declarations ]]
-------------------------------------

--- @class Logger
local Logger = Class(function(self)
    self._disabled = not PEARL.CONFIG.DISCORD.LHOOK.ENABLED
    if self._disabled then
        return
    end

    --- @type Webhook
    self._webhook = Webhook(PEARL.CONFIG.DISCORD.LHOOK.ID, PEARL.CONFIG.DISCORD.LHOOK.TOKEN)

    if not self._webhook:IsValid() then
        self:SetIsDisabled(true)
        return PEARL.error("Token and/or ID is not configured for the logger webhook correctly!")
    end

    --- @type BufferedMessage
    self._buffered = BufferedMessage()
    self._buffered:SetTimeout(PEARL.CONFIG.DISCORD.LHOOK.BUFFER_TIMEOUT)
    self._buffered:SetOnTimeout(self._LogBufferedMessage, self)

    self._shutting_down = false

    PEARL.EventProcessor:AddSafeEventHandler("quit", function()
        self._shutting_down = true

        if self._buffered:IsBuffering() then
            PEARL.debug("Shutting down logger webhook...")

            self:_ForceLogBuffer()
        end
    end)
end)

-------------------------------------
-- [[ Private Functions ]]
-------------------------------------

function Logger:_LogBufferedMessage(force)
    if not self._buffered or not self._buffered:IsValid() then
        return PEARL.error("Attempted to send an invalid or non-existent buffered message!")
    end

    return self._webhook:PostMessage(self._buffered, force)
end

function Logger:_ForceLogBuffer()
    self._buffered:Stop()
    self:_LogBufferedMessage(true)
    self._buffered:Clear()
end

function Logger:_OnNewLog(force)
    -- Skip the buffering process when forcing a message
    if force or self._shutting_down then
        return self:_ForceLogBuffer()
    end

    self._buffered:Start()
    return self._buffer
end

-------------------------------------
-- [[ Setters ]]
-------------------------------------

function Logger:SetIsDisabled(disabled)
    self._disabled = disabled

    return self
end

-------------------------------------
-- [[ Getters ]]
-------------------------------------

-- Warning: This can be nil if we are disabled!
function Logger:GetBufferedMessage()
    return self._buffer
end

function Logger:IsDisabled()
    return self._disabled
end

function Logger:IsEnabled()
    return not self._disabled
end

-------------------------------------
-- [[ Public Functions ]]
-------------------------------------

--- @param embed Embed The embed to be logged.
--- @param force boolean? If the buffering proccess should be skipped.
--- @return Message? bmessage The buffered message. This is nil when force is set to true.
function Logger:LogEmbed(embed, force)
    if self:IsDisabled() then
        return
    end

    if type(embed) ~= "table" then
        return PEARL.error("Attempted to add an invalid embed!", embed)
    end

    -- Returns nil if adding the embed has failed.
    -- Try to not use recursion here, it can introduce a nasty vulnerability.
    if not self._buffered:AddEmbed(embed) then
        self._buffered:Timeout()

        -- Retry with a cleared buffered message
        if not self._buffered:AddEmbed(embed) then
            -- If still no success, the embed is most likely invalid.
            return PEARL.error("Attempted to add an invalid embed!", embed)
        end
    end

    return self:_OnNewLog(force)
end

--- @param logline LogLine The embed to be logged.
--- @param force boolean? If the buffering proccess should be skipped.
--- @return Message? bmessage The buffered message. This is nil when force is set to true.
function Logger:LogLine(logline, force)
    if self:IsDisabled() then
        return
    end

    if type(logline) ~= "table" then
        return PEARL.error("Attempted to send an invalid logline!", logline)
    end

    local success, rest = self._buffered:AddLogLine(logline)
    if rest then
        self._buffered:Timeout()

        PEARL.info("Sending the rest of the message...")
        return self:LogLine(rest:SetIsRaw(true), force)
    end

    -- Returns nil if adding the logline has failed.
    -- Try to not use recursion here, it can introduce a nasty vulnerability.
    if not success then
        -- Send and clear the current buffer.
        self._buffered:Timeout()

        -- Retry with a cleared buffered message
        if not self._buffered:AddLogLine(logline) then
            -- If still no success, the logline is most likely invalid.
            return PEARL.error("Attempted to add an invalid logline!", logline)
        end
    end

    -- Start new buffer cycle if message was sent successfully.
    return self:_OnNewLog(force)
end

--- @param message Message
--- @return Request? request
function Logger:LogMessage(message)
    if self:IsDisabled() or not message:IsValid() then
        return PEARL.error("Attempted to send an invalid message or the webhook is disabled!")
    end

    -- Send and clear the current buffer.
    -- This is here in order to keep some order of the messages.
    self._buffered:Timeout()

    self._webhook:PostMessage(message)
end

--- @param str string The string to be logged.
--- @param icon string? The icon of the logline to be logged.
--- @return Message? bmessage The buffered message. This is nil when force is set to true.
function Logger:LogStringRaw(str, icon, ...)
    if self:IsDisabled() then
        return
    end

    PEARL.debug("Logger:LogString", str)

    local logline = LogLine(str)
    if icon then
        logline:SetHeader(nil, icon)
    end

    return self:LogLine(logline, ...)
end

function Logger:LogString(str, icon, ...)
    return self:LogStringRaw(MARKDOWN.codeline(str), icon, ...)
end

function Logger:LogStringHighlighted(str, icon, ...)
    return self:LogStringRaw(MARKDOWN.bold(str), icon, ...)
end

-------------------------------------
-- [[ Return ]]
-------------------------------------

return Logger
