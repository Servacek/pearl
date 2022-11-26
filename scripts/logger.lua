--[[
    This file adds a Logger class to the mod's environment. It's a class that manages
    the message creation and buffering process. As a buffer it uses the Message container itself.

    This means that when the buffering process ends, we already have a message baked and ready to be sent.
--]]


local MARKDOWN = require("libraries/markdown")
local LogLine = require("libraries/discordapi/models/logline")
local Message = require("libraries/discordapi/models/message")
local Webhook = require("libraries/discordapi/models/webhook")

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

function Logger:_LogBufferedMessage()
    PEARL.info("_LogBufferedMessage")

    self:_StopBufferTimeout()

    local success, json_data = self._buffered_message:ToJson()
    if not success then
        return PEARL.error("Logger", "JSON failed to encode the message!")
    end

    PEARL.DiscordRestAPI:ExecuteWebhook(self._webhook, json_data)

    -- Clear the buffer when we are done
    self._buffered_message:Clear()
end

function Logger:_StartBufferTimeout()
    PEARL.info("_StartBufferTimeout")

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
end

-------------------------------------
-- [[ Getters ]]
-------------------------------------

function Logger:GetBufferedMessage()
    return self._buffered_message
end

-------------------------------------
-- [[ Public Functions ]]
-------------------------------------

--- @param embed Embed The embed to be logged.
--- @param force boolean If the buffering proccess should be skipped.
--- @return Message? bmessage The buffered message. This is nil when force is set to true.
function Logger:LogEmbed(embed, force)
    -- Returns nil if adding the embed has failed
    if not self._buffered_message:AddEmbed(embed) then
        self:_LogBufferedMessage()

        return self:LogEmbed(embed, force)
    end

    if force then
        return self:_LogBufferedMessage()
    end

    self:_StartBufferTimeout()
    return self._buffered_message
end

--- @param logline LogLine The embed to be logged.
--- @param force boolean If the buffering proccess should be skipped.
--- @return Message? bmessage The buffered message. This is nil when force is set to true.
function Logger:LogLine(logline, force)
    if not self._buffered_message:AddLogLine(logline) then
        self:_LogBufferedMessage()

        return self:LogLine(logline, force)
    end

    if force then
        return self:_LogBufferedMessage()
    end

    self:_StartBufferTimeout()
    return self._buffered_message
end

--- @param str string The string to be logged.
--- @param icon string The icon of the logline to be logged.
--- @return Message? bmessage The buffered message. This is nil when force is set to true.
function Logger:LogStringRaw(str, icon, ...)
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
