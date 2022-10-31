setfenv(1, _G.SUB.env)
local os, table = os, table


local function calc_time_for_task(period, curtime)
    return (curtime or os.clock()) + period
end


local Task = Class(function(self, time, fn, limit, id, exec_time, ...)
    self.time = time
    self.fn = fn
    self.limit = limit
    self.id = id
    self.exec_time = exec_time
    self.args = ...

    self.finished = false
end)

function Task:Run()
    if self.finished or not self.fn then return end

    self.fn(self.args)
    if self.limit then
        self.limit = self.limit - 1
    end

    if not self.limit or self.limit > 0 then
        self.exec_time = calc_time_for_task(self.time, self.exec_time)
    else
        self:Cancel()
    end
end

function Task:Cancel()
    self.time = nil
    self.fn = nil
    self.exec_time = nil
    self.limit = nil
    self.id = nil
    self.args = nil

    self.finished = true
end

function Task:__tostring()
    return string.format("<TASK %s: %s -> %s>", tostring(self.id), tostring(self.time), tostring(self.fn))
end

---------------------------------------------------------------

-- Special scheduler for scheduling tasks when the server is paused
--
-- This works basically the same as the default sheduler except that
-- it executes the tasks even when TheSim is paused.
local WallScheduler = Class(function(self)
    self.sleeping = {}
    --self.lasttime = 0
end)

function WallScheduler:CreateTask(period, processfn, limit, initialdelay, id, ...)
    local exec_time = calc_time_for_task(initialdelay or period)
    return Task(period, processfn, limit, id, exec_time,  ...)
end

function WallScheduler:AddTask(task)
    if task ~= nil then
        SUB.debug("WallScheduler", "Registering task:", tostring(task))
        self.sleeping[#self.sleeping + 1] = task
    end

    return task
end

--- Executes the given function after the given n seconds and stops the task
--- @param timefromnow integer The time in seconds after which this task should be executed
--- @param processfn function The callback of the task
--- @param id integer? The id of the task used for debuging
--- @param ... any Additional arguments to the callback function
--- @return Task? task The new created task
function WallScheduler:ExecuteInTime(timefromnow, processfn, id, ...)
    return self:AddTask(self:CreateTask(timefromnow, processfn, 1, nil, id, ...))
end

--- Executes the given function every n seconds until the given limit is exceeded
--- or the task is stopped.
--- @param period integer The period in which the task should be executed (in seconds)
--- @param processfn function The callback of the task
--- @param limit integer? The task execution limit, if this is exceeded the task will be stopped
--- @param initialdelay integer? Time until the first execution
--- @param id integer? The id of the task used for debug
--- @param ... any Additional arguments to the callback function
--- @return Task? task The new created task
function WallScheduler:ExecutePeriodic(period, processfn, limit, initialdelay, id, ...)
    return self:AddTask(self:CreateTask(period, processfn, limit, initialdelay, id, ...))
end

--------------------------------------

function WallScheduler:OnWallUpdate()
    if #self.sleeping <= 0 then return end

    local curtime = os.clock()
    for i = 1, #self.sleeping do
        local task = self.sleeping[i]

        if task ~= nil and not task.finished then
            if task.exec_time <= curtime then
                local success, error_msg = pcall(task.Run, task)
                if not success and error_msg then
                    SUB.error("WallSheduler", "Failed to run task: ", error_msg)
                end
            end
        else
            table.remove(self.sleeping, i)
        end
    end
end

--------------------------------

_G.SUB.WallScheduler = WallScheduler()
