local MessageQueue = require('components/messagequeue')
local Message = require('models/message')

--------------------------------------

setfenv(1, _G.SUB.env)
local TheSim, TheNet = TheSim, TheNet
local SUB = SUB
local json = json

-- Represents the REST API client
local Webhook = Class(function(self)
    self.queue = nil

    if SUB.CONSTANTS.REQUEST_FREQUENCY > 0 then
        self.queue = MessageQueue()
        self.queue:SetProcessFunction(self.DoTask, self)
    end
end)

-------------------------------------
-- [[ Private functions ]]
-------------------------------------

-- The REST client request callback
function Webhook:_callback(result, is_successful, http_code)
    if result and string.len(result) > 1 then
        local decoded_result = json.decode(result)
        if decoded_result ~= nil and decoded_result.message then
            SUB.info("Webhook", "["..http_code.."] "..decoded_result.message)
        end
    else
        if is_successful then
            SUB.info("Webhook", "["..http_code.."] Request succeeded")
        else
            SUB.info("Webhook", "["..http_code.."] Request failed, reason unknown.")
        end
    end

    -- This should NEVER happen!!!
    -- Here we have exceeded the limit so we need to carefully
    -- shutdown the request manager before discord temporary blocks us.
    if http_code == 429 then
        SUB.info("Webhook", "["..http_code.."] Disabling logging to discord...")
        SUB.CONSTANTS.DISCORD_LOGS_ENABLED = false

        if self.queue then
            self.queue:CleanUp()
        end
    end
end

-- Sends message object to discord via POST request
function Webhook:_send(message)
    if not SUB.CONSTANTS.DISCORD_LOGS_ENABLED then return end

    if message ~= nil and message:IsValid() then
        local success, result = message:ToJson()
        if not success then
            return SUB.error("Webhook", "JSON failed to encode the message:", result)
        end

        TheSim:QueryServer(SUB.CONSTANTS.WEBHOOK_URL, function(...)
            self:_callback(...)
        end, "POST", result)
  	else
    	SUB.error("Webhook", "Attempted to send an invalid message!")
  	end
end

function Webhook:_send_report(message)
    if message ~= nil and message:IsValid() then
        local success, result = message:ToJson()
        if not success then
            return
        end

        TheSim:QueryServer(SUB.CONSTANTS.REPORT_WEBHOOK_URL,
            function(...) end, "POST", result
        )
    end
end

-------------------------------------
-- [[ Public functions ]]
-------------------------------------

--- Schedules the given message for sending to discord
--- @param message Message The message object to be sent
--- @param force boolean? Whether the message should be sent directly
--- to discord or cached and scheduled for the send task
--- @return boolean success
function Webhook:SendMessage(message, force)
    if not SUB.CONSTANTS.DISCORD_LOGS_ENABLED or not message then return false end

    if force or TheNet:IsServerPaused() or not self.queue then
        -- try to send the message directly to discord
        self:_send(message)
    else
        -- queue the message for a future send task
        self.queue:AddMessage(message)
    end

    return true
end

--- @param embed Embed The embed to be sent
--- @param ... any The aditional arguments to the SendMessage function
--- @return boolean success
function Webhook:SendEmbed(embed, ...)
    if not embed then return false end

    return SUB.Webhook:SendMessage(Message()
        :AddEmbed(embed), ...
    )
end

function Webhook:SendReport(error_message)
    SUB.info("Sending error report...")
    local message = Message(
        string.bold("<@481731484982444052> Chyba spôsobená modom:\n")
        ..string.codeblock(tostring(error_message))
    )
    message:AllowMentionsForType(Message.MENTION_TYPES.USERS)

    self:_send_report(message)
end

--- @param content string The content of the announcement
--- @param icon string The icon of the announcement
--- @param ... any The aditional arguments to the SendMessage function
--- @return boolean success
function Webhook:SendAnnouncement(content, icon, ...)
    return self:SendMessage(Message(
        string.codeline(content), string.to_emoji(icon)
    ), ...)
end

--- @param content string The content of the notification
--- @param unsafe_content string Whether the content should be DDFed before sending it to discord
--- @param ... any The aditional arguments to the SendMessage function
--- @return boolean success
function Webhook:SendNotifyImportant(content, unsafe_content, ...)
    if unsafe_content then
        content = string.DDF(content)
    end

    return self:SendMessage(Message(
        string.bold(content, not unsafe_content)
    ),  ...)
end

-- The cache task handler executed by the MessageQueue task
function Webhook:DoTask()
    if self.queue:IsEmpty() then
        -- print("We are done for now. Cancelling task...")
        -- self.queue:StopProcessing()
        return
    end

    local message
    for i, v in ipairs(self.queue:ToTable()) do
        if message ~= nil then
            -- If this returns false it's usualy because it would exceed the limit,
            -- so in this case we want to leave the queued message for another task
            if not message:CanMerge(v) then
                SUB.debug("Webhook", "Message would be too long so leaving the rest for next task")
                break
            end

            message:Concatenate(v)
        else
            message = v
        end

        self.queue:RemoveMessageAtIndex(i)
    end

    self:_send(message)
end

-------------------------------------
-- [[ Handler functions ]]
-------------------------------------

function Webhook:OnSimPostInit()
    if self.queue then
        self.queue:StartProcessing()
    end
end

-- function Webhook:OnSimPaused()
--     if self.queue.state == MessageQueue.STATES.PROCESSING then
--         self.queue:ProcessAll()
--         self.queue:SetState(MessageQueue.STATES.PAUSED)
--     end
-- end

-- function Webhook:OnSimUnpaused()
--     if self.queue.state == MessageQueue.STATES.PAUSED then
--         self.queue:SetState(MessageQueue.STATES.PROCESSING)
--     end
-- end

----------------------------------

SUB.Webhook = Webhook()
