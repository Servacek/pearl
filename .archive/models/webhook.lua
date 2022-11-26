--[[
    Represents the REST client who communicates with the discord API.

    TODOS:
        - Implement a message splitting mode for message longer than
          1900 characters.
--]]

local MARKDOWN = require("libraries/markdown")
local LogLine = require('libraries/discordapi/models/logline')
local Message = require('libraries/discordapi/models/message')
local MessageWrapper = require('libraries/discordapi/models/wrapper')

--------------------------------------

local PEARL = PEARL
local string = string
local Class = Class

-------------------------------------
-- [[ Constants ]]
-------------------------------------

local DISCORD_STATUS_CODES = {
    OK                  = 200, -- The request completed successfully.
    CREATED             = 201, -- The entity was created successfully.
    NO_CONTENT          = 204, -- The request completed successfully but returned no content.
    NOT_MODIFIED        = 304, -- The entity was not modified (no action was taken).
    BAD_REQUEST         = 400, -- The request was improperly formatted, or the server couldn't understand it.
    UNAUTHORIZED        = 401, -- The Authorization header was missing or invalid.
    FORBIDDEN           = 403, -- The Authorization token you passed did not have permission to the resource.
    NOT_FOUND           = 404, -- The resource at the location specified doesn't exist.
    METHOD_NOT_ALLOWED  = 405, -- The HTTP method used is not valid for the location specified.
    TOO_MANY_REQUESTS   = 429, -- You are being rate limited, see Rate Limits.
    GATEWAY_UNAVAILABLE = 502, -- There was not a gateway available to process your request. Wait a bit and retry.
    --5xx (SERVER ERROR)	The server had an error processing your request (these are rare).
}

-------------------------------------
-- [[ Private functions ]]
-------------------------------------

local function callbackfn(result, is_successful, http_code, request, self)
    if not is_successful then
        self:OnErrorStatusCode(http_code, result)
    end
end

-- Sends message object to discord via POST request
local function execute(message, self)
    if not (PEARL.CONFIG.DISCORD.ENABLED and message) and not self:IsDisabled() then
         return false
    end

    PEARL.debug("Executing...")

    local success, result = message:ToJson()
    -- Note: pcall for some reason returns false when the game crashes even
    if not PEARL.CONSTS.MOD_ERROR and not success then
        PEARL.error("JSON failed to encode the message:", result)
        return false
    end

    --PEARL.debug("SEND", result)

    local request = PEARL.RestClient:POST(self._url, callbackfn, result, nil, self)
        :SetSkipOnDeadline(false)

    if self:IsShuttingDown() then
        request:Send()
    else
        request:Queue()
    end

    return true
end

-------------------------------------
-- [[ Definition ]]
-------------------------------------

--- @class Webhook
local Webhook = Class(function(self, id, token)
    self._id = id
    self._token = token
    self._url = PEARL.CONSTS.DISCORD.WEBHOOK_URL_TEMPLATE:format(
        PEARL.CONSTS.DISCORD.API_VERSION, self._id, self._token
    )

    self._disabled = false
    self._shutting_down = false

    self._mw = MessageWrapper()
    self._mw:SetOnWrapFn(execute, self)

    -- [[ Events ]]
    PEARL.EventProcessor:AddEventHandler("quit", function()
        self:OnShutdown()
    end)
end)

-------------------------------------
-- [[ Meta Methods ]]
-------------------------------------

function Webhook:__tostring()
    return string.format(
        "Webhook(id=%s, rate_limited=%s)", self._id, tostring(self._disabled)
    )
end

-------------------------------------
-- [[ Setters ]]
-------------------------------------

function Webhook:SetIsDisabled(disable)
    self._disabled = disable
end

function Webhook:SetIsShuttingDown(shutting_down)
    self._shutting_down = shutting_down
end

-------------------------------------
-- [[ Getters ]]
-------------------------------------

function Webhook:IsDisabled()
    return self._disabled
end

function Webhook:IsShuttingDown()
    return self._shutting_down
end

function Webhook:GetMessageWrapper()
    return self._mw
end

function Webhook:CanExecute()
    return PEARL.CONFIG.DISCORD.ENABLED or self:IsDisabled() or self:IsShuttingDown()
end

-------------------------------------
-- [[ Public Methods ]]
-------------------------------------

--- Disables the webhook for the given amount of seconds
--- preventing it from execution.
--- @param seconds number
function Webhook:RateLimitFor(seconds)
    self:SetIsDisabled(true)

    if type(seconds) == "number" then
        PEARL.info("Webhook", "Disabling for", seconds, "seconds...")
        PEARL.Scheduler:ExecuteInTime(seconds, function()
            PEARL.info("Webhook", "Reanabling...")
            self:SetIsDisabled(false)
        end)
    else
        -- When seconds are nil, disable this webhook permanently.
        PEARL.info("Webhook", "Disabling...")
    end
end

-----------
--- Lower-Level Execution Methods
--- Used when more control over the objects is needed.

--- Appends an LogLine object to MessageWrapper's active message.
--- @param logline LogLine The embed to be appended.
--- @param ... any The aditional arguments to the MessageWrapper.AppendLogLine method
--- @return Message? message The active message this logline was appended to.
--- Returns nil if the Webhook is disabled or the given logline is invalid.
--- So ALWAYS check the return type of this function before calling any other method.
function Webhook:PushLogLine(logline, ...)
    if not self:CanExecute() then
        return
    end

    -- if not PEARL.InstanceOf(logline, LogLine) then
    --     PEARL.error("Webhook", "Attempted to send an invalid string!")
    --     return
    -- end

    return self._mw:AppendLogLine(logline, ...)
end

--- Appends an Embed object to MessageWrapper's active message.
--- @param embed Embed The embed to be appended.
--- @param ... any The aditional arguments to the MessageWrapper.AppendEmbed method
--- @return Message? message The active message this embed was appended to.
--- Returns nil if the Webhook is disabled or the given embed is invalid.
--- So ALWAYS check the return type of this function before calling any other method.
function Webhook:PushEmbed(embed, ...)
    if not self:CanExecute() then
        return
    end

    -- if not PEARL.InstanceOf(embed, Embed) then
    --     PEARL.error("Webhook", "Attempted to send an invalid embed!")
    --     return
    -- end

    return self._mw:AppendEmbed(embed, ...)
end

-- Up to 1800 characters
-- Long messages are not being wrapped.
function Webhook:InitLongMessage(content, ...)
    if #content > PEARL.CONSTS.DISCORD.MAX_MESSAGE_CONTENT_LENGTH then
        return PEARL.error("Message too long.")
    end

    return Message()
        :AddLogLine(LogLine()
            :SetIsLong(true)
            :SetContent(content)
            :SetHeader(...)
        )
end
-----------
--- Higher-Level Execution Methods
--- These don't return a message object since it constructs it
--- immediately after appending the given embed, but they return a boolean
--- representing the success of this operation instead.

--- @deprecated Use Webhook.SendLogLine instead!
function Webhook:SendMessage(...)
    return self:SendLogLine(...)
end

--- A higher-level wrapper for Webhook.PushLogLine.
function Webhook:SendLogLine(content, icon, force)
    if type(content) ~= "string" then
        PEARL.error("Webhook", "Attempt to send an invalid logline!")
        return false
    end

    local message = self:PushLogLine(LogLine(content)
        :SetHeader(nil, icon)
    )
    if message then
        message:Construct(force)
        return true
    end

    return false
end

-- Up to 1800 characters
-- Long messages are not being wrapped.
function Webhook:SendLongMessage(content, ...)
    if #content > PEARL.CONSTS.DISCORD.MAX_MESSAGE_CONTENT_LENGTH then
        return PEARL.error("Message too long.")
    end

    return Message()
        :AddLogLine(LogLine()
            :SetIsLong(true)
            :SetContent(content)
            :SetHeader(...)
        )
end

--- A higher level wrapper for the Webhook.PushEmbed function.
--- This doesn't return a message object since it constructs it
--- immediately after appending the given embed, but it returns a boolean
--- representing the success of this operation instead.
function Webhook:SendEmbed(...)
    local message = self:PushEmbed(...)
    if message ~= nil then
        message:Construct()
        return true
    end

    return false
end

function Webhook:SendErrorReport(error_message)
    PEARL.info("Sending an error report to discord...")

    return execute(Message():AddLogLine(LogLine(
        STRINGS.PEARL.LOGS.SERVER_REPORT:format(
            PEARL.CONSTS.DISCORD.ADMIN_ROLE_ID, tostring(error_message)
        )
    )):AllowMentionsForRole(PEARL.CONSTS.DISCORD.ADMIN_ROLE_ID), self)
end

function Webhook:ReportStatusCode(status_code, message)
    PEARL.error("Webhook", "Got a "..tostring(status_code).." status code from Discord!")
    self:SendErrorReport(STRINGS.PEARL.LOGS.STATUS_CODE_REPORT:format(
        status_code, message
    ))
end

--- @param content string The content of the announcement
--- @param icon string The icon of the announcement
--- @return boolean success
function Webhook:SendAnnouncement(content, icon)
    return self:SendLogLine(MARKDOWN.codeline(content), string.to_emoji(icon))
end

--- @param content string The content of the notification
--- @param ... any The aditional arguments to the SendMessage function
--- @return boolean success
function Webhook:SendNotifyImportant(content, icon, ...)
    return self:SendLogLine(MARKDOWN.bold(content),  icon, true, ...)
end

-------------------------------------
-- [[ Handler functions ]]
-------------------------------------

function Webhook:OnShutdown()
    PEARL.info(self, "Shutting down...")

    -- Make sure this is the last execution of the webhook on this instance.
    self:SetIsShuttingDown(true)
    if self._mw then
        self._mw:Wrap()
    end
end

-- Debug a bit more
function Webhook:OnErrorStatusCode(status_code, result)
    -- Handle rate limits first
    if status_code == DISCORD_STATUS_CODES.TOO_MANY_REQUESTS then
        local success, decoded_result = pcall(json.decode, result)
        return self:RateLimitFor(
            (success and decoded_result) and tonumber(decoded_result.retry_after)
            or nil
        )
    end

    if status_code == DISCORD_STATUS_CODES.NOT_FOUND then
        PEARL.error("Invalid webhook authentication data.")
        return self:SetIsDisabled(true)
    end
end
----------------------------------

return Webhook
