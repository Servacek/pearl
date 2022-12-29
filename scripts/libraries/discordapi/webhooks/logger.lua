--[[
    This file adds a Logger class to the mod's environment. It's a class that manages
    the message creation and buffering process. As a buffer it uses the Message container itself.

    This means that when the buffering process ends, we already have a message baked and ready to be sent.
--]]


local MARKDOWN = PEARL.loadfile("libraries/markdown")
local LogLine = PEARL.loadfile("libraries/discordapi/models/logline")
local Message = PEARL.loadfile("libraries/discordapi/models/message")
local Webhook = PEARL.loadfile("libraries/discordapi/models/webhook")

-------------------------------------
-- [[ Handlers ]]
-------------------------------------

local function on_message_post_construct(message, force, self)
    if force then
        return self:_LogBufferedMessage()
    end

    --- Start buffered timeout task here
    self:_StartBufferTimeout()
end

-------------------------------------
-- [[ Class Declarations ]]
-------------------------------------

--- @class Logger
local Logger = Class(function(self)
    self._disabled = not PEARL.CONFIG.DISCORD.LHOOK.ENABLED
    if self._disabled then
        return
    end

    self._webhook = Webhook(PEARL.CONFIG.DISCORD.LHOOK.ID, PEARL.CONFIG.DISCORD.LHOOK.TOKEN)

    self._buffered_message = Message()
        :SetPostConstructFn(on_message_post_construct, self)
    --- @type Task
    self._buffer_timeout_task = nil
    self._buffer_timeout = 0

    PEARL.EventProcessor:AddEventHandler("quit", function()
        self:_LogBufferedMessage()
    end)
end)

-------------------------------------
-- [[ Private Functions ]]
-------------------------------------

function Logger:_LogBufferedMessage(force)
    PEARL.debug("Logger:_LogBufferedMessage")

    self:_StopBufferTimeout()

    local _, json_data = self._buffered_message:ToJson()
    if not json_data then
        return PEARL.error("Logger", "JSON failed to encode the message!")
    end

    PEARL.DiscordRestAPI:ExecuteWebhook(self._webhook, json_data, force)

    -- Clear the buffer when we are done
    self._buffered_message:Clear()
end

function Logger:_StartBufferTimeout()
    if not self._buffer_timeout_task then
        PEARL.debug("Wrap timeout has started!")

        self._buffer_timeout_task = PEARL.Scheduler:ExecuteInTime(
            self._buffer_timeout, self._OnBufferTimeout, nil, self
        )
    end
end

function Logger:_StopBufferTimeout()
    if self._buffer_timeout_task then
        self._buffer_timeout_task:Cancel()
        self._buffer_timeout_task = nil
    end
end

function Logger:_OnBufferTimeout()
    PEARL.debug("Wrap timeout has ended!")
    self:_LogBufferedMessage()
end

-------------------------------------
-- [[ Setters ]]
-------------------------------------

function Logger:SetBufferTimeout(buffer_timeout)
    self._buffer_timeout = buffer_timeout

    return self
end

function Logger:SetIsDisabled(disabled)
    self._disabled = disabled

    return self
end

-------------------------------------
-- [[ Getters ]]
-------------------------------------
-- Warning: This can be nil if we are disabled!
function Logger:GetBufferedMessage()
    return self._buffered_message
end

function Logger:IsDisabled()
    return self._disabled
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
    if not self._buffered_message:AddEmbed(embed) then
        self:_LogBufferedMessage()

        -- Retry with a cleared buffered message
        if not self._buffered_message:AddEmbed(embed) then
            -- If still no success, the embed is most likely invalid.
            return PEARL.error("Attempted to add an invalid embed!", embed)
        end
    end

    if force then
        return self:_LogBufferedMessage(force)
    end

    self:_StartBufferTimeout()
    return self._buffered_message
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

    -- Returns nil if adding the embed has failed.
    -- Try to not use recursion here, it can introduce a nasty vulnerability.
    if not self._buffered_message:AddLogLine(logline) then
        self:_LogBufferedMessage()

        -- Retry with a cleared buffered message
        if not self._buffered_message:AddLogLine(logline) then
            -- If still no success, the embed is most likely invalid.
            return PEARL.error("Attempted to add an invalid logline!", logline)
        end
    end

    if force then
        return self:_LogBufferedMessage(force)
    end

    self:_StartBufferTimeout()
    return self._buffered_message
end

--- @param str string The string to be logged.
--- @param icon string? The icon of the logline to be logged.
--- @return Message? bmessage The buffered message. This is nil when force is set to true.
function Logger:LogStringRaw(str, icon, ...)
    if self:IsDisabled() then
        return
    end

    local logline = LogLine(str)
    if icon then
        logline:SetHeader(nil, icon)
    end

    return self:LogLine(logline, ...)
end

function Logger:LogString(str, ...)
    return self:LogStringRaw(MARKDOWN.codeline(str), ...)
end

function Logger:LogStringHighlighted(str, ...)
    return self:LogStringRaw(MARKDOWN.bold(str), ...)
end

-------------------------------------

return Logger
