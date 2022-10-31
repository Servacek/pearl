require('class')

local MessageQueue = require('components/messagequeue')
local Message = require('models/message')

--------------------------------------

setfenv(1, _G.SUB.env)
local TheSim, TheNet = TheSim, TheNet
local SUB = SUB
local json = json

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
        local response_msg = json.decode(result)
        if response_msg ~= nil then
            SUB.info("Webhook", "["..http_code.."] "..response_msg)
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
    if http_code == 404 then
        SUB.CONSTANTS.DISCORD_LOGS_ENABLED = false

        if self.queue then
            self.queue:CleanUp()
        end
    end
end

-- Sends message object to discord via POST request
function Webhook:_send(message)
    if not SUB.CONSTANTS.DISCORD_LOGS_ENABLED then
        return
    end

    if message ~= nil and message:IsValid() then
        local success, result = message:ToJson()
        if not success then
            return SUB.error("Webhook", "JSON failed to encode the message:", result)
        end

        TheSim:QueryServer(SUB.CONSTANTS.WEBHOOK_URL, function(...)
            self:_callback(...)
        end, "POST", result)
    end
end

-------------------------------------
-- [[ Public functions ]]
-------------------------------------

-- Schedules the given message for sending to discord
function Webhook:SendMessageToDiscord(message, force)
    if not SUB.CONSTANTS.DISCORD_LOGS_ENABLED then return end

    if force or TheNet:IsServerPaused() or not self.queue then
        -- try to send the message directly to discord
        self:_send(message)
    else
        -- queue the message for a future send task
        self.queue:AddMessage(message)
    end
end

function Webhook:SendAnnouncement(content, icon, ...)
    return self:SendMessageToDiscord(Message(
        string.codeblock(content), string.to_emoji(icon)
    ), ...)
end

function Webhook:SendNotifyImportant(content, unsafe_content, ...)
    if unsafe_content then
        content = string.DDF(content)
    end

    return self:SendMessageToDiscord(Message(
        string.bold(content)
    ),  ...)
end

function Webhook:DoTask()
    if self.queue:IsEmpty() then
        -- print("We are done for now. Cancelling task...")
        -- self.queue:StopProcessing()
        return
    end

    local message
    for i, v in pairs(self.queue:ToTable()) do
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
