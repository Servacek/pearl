require("class")

local SUB = SUB

------------------------------

local MessageQueue = Class(function(self)
    self.queue = {}
    self.processfn = nil
    self.task = nil
    self.state = self.STATES.STOPPED
    self.scheduler = nil
    self.args = nil

    local _OnSimPaused = OnSimPaused
    OnSimPaused = function(...)
        self:SetState(self.STATES.PAUSED)
        if not self:IsEmpty() then
            self:ProcessAll()
        end

        return _OnSimPaused(...)
    end
end)

-------------------------------

function MessageQueue:IsEmpty()
    return IsTableEmpty(self.queue)
end

function MessageQueue:IsPaused()
    return self.state == self.STATES.PAUSED
end

function MessageQueue:SetState(state)
    if state ~= nil then
        self.state = state
    end
end

function MessageQueue:AddMessage(message)
    if type(message) == "userdata" and message:IsValid() then
        SUB.debug("MessageQueue", "Adding message to queue")
        self.queue[#self.queue + 1] = message
    end
end

function MessageQueue:SetProcessFunction(fn, ...)
    self.processfn = fn
    self.args = ...
end

-- We use the wall scheduler for scheduling the sending task,
-- so it works even when TheSim is paused
function MessageQueue:StartProcessing()
    if self.processfn ~= nil and self.state == MessageQueue.STATES.STOPPED then
        self.task = scheduler:ExecutePeriodic(
            SUB.CONSTANTS.REQUEST_FREQUENCY, self.processfn, nil, nil, 11, self.args
        )

        SUB.debug("MessageQueue", "Processing...")
        self.state = self.STATES.PROCESSING
    end
end

-- Note: This can lead to multiple request in a short period of time
-- so it should be used carefully.
function MessageQueue:ProcessAll()
    SUB.debug("MessageQueue", "Processing all queued messages...")
    if self.processfn ~= nil then
        while not self:IsEmpty() do
            self.processfn(self.args)
        end
    end
end

function MessageQueue:StopProcessing()
    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil

        SUB.debug("MessageQueue", "Cancelling...")
        self.state = self.STATES.STOPPED
    end
end

function MessageQueue:CleanUp()
    self:StopProcessing()
    cleartable(self.queue)

    self.processfn = nil
    self.task = nil
    self.args = nil
end

function MessageQueue:RemoveMessageAtIndex(i)
    self.queue[i] = nil
end

function MessageQueue:ToTable()
    return self.queue
end

------------------------------

MessageQueue.STATES = {
    PAUSED      = 1,
    STOPPED     = 2,
    PROCESSING  = 3,
}

return MessageQueue