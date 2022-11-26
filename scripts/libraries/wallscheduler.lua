--[[
    NOTES:
        RESOLVED
        - It looks like os.clock() is causing some trouble
        on long running servers using 32bit binaries.

        Maybe this problem could be resolved by replacing it with os.time().
]]


--local APP_ARCHITECTURE = APP_ARCHITECTURE
local PEARL = PEARL
local GetTimeRealSeconds = GetTimeRealSeconds
local table, string = table, string
-- Support for long running 32 bit servers
--local walltime = APP_ARCHITECTURE == "x64" and os.clock or os.time


local function calc_time_for_task(period, curtime)
    return (curtime or GetTimeRealSeconds()) + period
end

----------------------------------------------

--- @class Task
local Task = Class(function(self, time, fn, limit, id, exec_time, ...)
    self.time = time
    self.fn = fn
    self.limit = limit
    self.id = id
    self.exec_time = exec_time
    --- @TODO: This saves just the first argument (enough for now
    -- but can potentially cause problems in the future)
    self.args = ...

    self.finished = false
end)

function Task:Run()
    if self.finished or not self.fn then return end

    self.fn(self.args)
    if self.limit then
        self.limit = self.limit - 1
    end

    -- Check if this task was not already canceled by the callback function
    if not self.finished and (not self.limit or self.limit > 0) then
        self.exec_time = calc_time_for_task(self.time)
    else
        self:Cancel()
    end
end

function Task:Cancel()
    self.time = nil
    self.fn = nil
    self.exec_time = nil
    self.limit = 0
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
--
-- Note: This should be a singleton.

--- @class WallScheduler
local WallScheduler = Class(function(self)
    self.tasks = {}

    self:StartWallUpdate()
end)

function WallScheduler:CreateTask(period, processfn, limit, initialdelay, id, ...)
    local exec_time = calc_time_for_task(initialdelay or period)
    return Task(period, processfn, limit, id, exec_time,  ...)
end

function WallScheduler:AddTask(task)
    if task ~= nil then
        PEARL.debug("WallScheduler", "Registering task:", tostring(task))
        self.tasks[#self.tasks + 1] = task
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

function WallScheduler:StartWallUpdate()
    PEARL.debug("Starting WallUpdate!")
    local _WallUpdate = rawget(_G, "WallUpdate")
    if type(_WallUpdate) ~= "function" then
        error("Invalid WallUpdate function!")
    end

    rawset(_G, "WallUpdate", function(...)
        self:OnWallUpdate()

        return _WallUpdate(...)
    end)
end

--------------------------------------

function WallScheduler:OnWallUpdate()
    if #self.tasks <= 0 then
        return
    end

    local time = GetTimeRealSeconds()
    for i = 1, #self.tasks do
        local task = self.tasks[i]

        if not task or task.finished then
            table.remove(self.tasks, i)
        elseif task.exec_time <= time then
            local success, result = PEARL.SafeRun(task.Run, task)
            if not success then
                PEARL.error("WallScheduler", "Failed to run task:", task)
                PEARL.error("WallScheduler", "Error Traceback: ", result)

                PEARL.info("WallScheduler", "Canceling and removing this task...")
                task:Cancel()
                table.remove(self.tasks, i)
            end
        end
    end
end

--------------------------------

return WallScheduler
