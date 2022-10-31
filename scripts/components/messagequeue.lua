local SUB = SUB

------------------------------

local MessageQueue = Class(function(self)
    self.queue = {}
    self.processfn = nil
    self.task = nil
    self.state = self.STATES.STOPPED
    self.scheduler = nil
    self.args = nil

    if not SUB.WallScheduler then
        local _OnSimPaused = OnSimPaused
        OnSimPaused = function(...)
            self:SetState(self.STATES.PAUSED)
            if not self:IsEmpty() then
                self:ProcessAll()
            end

            return _OnSimPaused(...)
        end
    end
end)

-------------------------------

function MessageQueue:IsEmpty()
    return not self.queue or #self.queue <= 0
end

function MessageQueue:IsPaused()
    return self.state == self.STATES.PAUSED
end

function MessageQueue:IsTaskStopped()
  	return not self.task or (self.task.limit and self.task.limit <= 0)
end

function MessageQueue:SetState(state)
    if state ~= nil then
        self.state = state
    end
end

function MessageQueue:AddMessage(message)
    if type(message) ~= "userdata" or not message:IsValid() then
        return
    end

    if self:IsTaskStopped() then
        SUB.info("MessageQueue", "Tried to append a new message but the task is stopped!")
        return
    end

    if #self.queue >= MessageQueue.MAX_QUEUE_SIZE then
        SUB.info("MessageQueue", "Tried to append a new message but the queue is full!")
        return
    end

    SUB.debug("MessageQueue", "Adding message to queue")
    table.insert(self.queue, message)
end

function MessageQueue:SetProcessFunction(fn, ...)
    self.processfn = fn
    self.args = ...
end

-- We use the wall scheduler for scheduling the sending task,
-- so it works even when TheSim is paused
function MessageQueue:StartProcessing()
    if self.processfn ~= nil and self:IsTaskStopped() then
    	SUB.info("MessageQueue", "Starting processing task...")
        self.task = SUB.Scheduler:ExecutePeriodic(
            SUB.CONSTANTS.REQUEST_FREQUENCY, self.processfn, nil, nil, 11, self.args
        )

        self.state = self.STATES.PROCESSING
    end
end

function MessageQueue:ProcessAll()
    if self.processfn and self.queue then
        SUB.debug("MessageQueue", "Processing all ("..#self.queue..") queued messages...")

        while not self:IsEmpty() do
            self.processfn(self.args)
        end
    end
end

function MessageQueue:StopProcessing()
    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil

        SUB.info("MessageQueue", "Stopping queue task...")
        self.state = self.STATES.STOPPED
    end
end

function MessageQueue:CleanUp()
    SUB.info("MessageQueue", "Cleaning up...")
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

MessageQueue.MAX_QUEUE_SIZE = 25
MessageQueue.STATES = {
    PAUSED      = 1,
    STOPPED     = 2,
    PROCESSING  = 3,
}

return MessageQueue