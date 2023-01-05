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
    Special scheduler for scheduling tasks when the server is paused

    This works basically the same as the default sheduler except that
    it executes the tasks even when TheSim is paused.

    TODOS:
        - Try to replace the task with a simpler table and recycle it.
        - Other performance improvements.
        - Create a restart function for tasks.
]]


local PEARL = PEARL
local GetTimeRealSeconds = GetTimeRealSeconds
local table, string = table, string
local toarrayornil = toarrayornil
local unpack = unpack

------------------------------------------
-- [[ Contants ]]
------------------------------------------

-- local WALL_TICKS = 1 / 60

------------------------------------------
-- [[ Private Functions ]]
------------------------------------------

local function calc_time_for_task(period, curtime)
    return (curtime or GetTimeRealSeconds()) + period
end

------------------------------------------

--- @class Task
local Task = Class(function(self, time, fn, limit, id, exec_time, ...)
    self.time = time
    self.fn = fn
    self.limit = limit
    self.id = id
    self.exec_time = exec_time
    self.args = toarrayornil(...)

    self.finished = false
end)

function Task:Run()
    if self.finished or not self.fn then
        return
    end

    if self.args then
        self.fn(unpack(self.args))
    else
        self.fn()
    end

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

--------------------------------------
-- [[ Locals ]]
--------------------------------------

local tick = 0
local seconds = 0

---@type table<Task>
local tasks = {}

--------------------------------------
-- [[ Initialization ]]
--------------------------------------

--- @class WallScheduler
local WallScheduler = {}

function WallScheduler:_CreateTask(period, processfn, limit, initialdelay, id, ...)
    local exec_time = calc_time_for_task(initialdelay or period)
    return Task(period, processfn, limit, id, exec_time, ...)
end

function WallScheduler:_AddTask(task)
    if task ~= nil then
        --PEARL.debug("WallScheduler", "Registering task:", task)
        tasks[#tasks + 1] = task
    end

    return task
end

--- Executes the given function after the given n seconds and stops the task
--- @param timefromnow integer The time in seconds after which this task should be executed
--- @param processfn function The callback of the task
--- @param id integer? The id of the task used for debuging
--- @param ... any? Additional arguments to the callback function
---
--- @return Task task The new created task
function WallScheduler:ExecuteInTime(timefromnow, processfn, id, ...)
    return self:_AddTask(self:_CreateTask(timefromnow, processfn, 1, nil, id, ...))
end

--- Executes the given function every n seconds until the given limit is exceeded
--- or the task is stopped.
--- @param period integer The period in which the task should be executed (in seconds)
--- @param processfn function The callback of the task
--- @param limit integer? The task execution limit, if this is exceeded the task will be stopped
--- @param initialdelay integer? Time until the first execution
--- @param id integer? The id of the task used for debug
--- @param ... any? Additional arguments to the callback function
---
--- @return Task? task The new created task
function WallScheduler:ExecutePeriodic(period, processfn, limit, initialdelay, id, ...)
    return self:_AddTask(self:_CreateTask(period, processfn, limit, initialdelay, id, ...))
end

function WallScheduler:StartWallUpdate()
    PEARL.debug("WallScheduler:StartWallUpdate()")

    -- if PEARL.OPTIMIZED_SCHEDULER then
    --     PEARL.AddGlobalFunctionPreCall("WallUpdate", self.OnWallUpdateOptimized)
    -- else
    PEARL.AddGlobalFunctionPreCall("WallUpdate", self.OnWallUpdate)
    -- end
end

--------------------------------------

-- Note: 1 second = 60 wall-ticks
-- dt = time_passed - time_now
-- dt is 0 if the server us paused
function WallScheduler.OnWallUpdate(dt)
    if #tasks <= 0 then
        return
    end

    local time = GetTimeRealSeconds()
    for i = 1, #tasks do
        local task = tasks[i]

        if not task or task.finished then
            table.remove(tasks, i)
        elseif task.exec_time <= time then
            local success, result = PEARL.SafeRun(task.Run, task)
            if not success then
                PEARL.error("WallScheduler", "Failed to run task:", task)
                PEARL.error("WallScheduler", "Error Traceback: ", result)

                PEARL.info("WallScheduler", "Canceling and removing this task...")
                task:Cancel()
                table.remove(tasks, i)
            end
        end
    end
end

--- @TODO
-- function WallScheduler.OnWallUpdateOptimized()
--     if tick * WALL_TICKS < 1 or #tasks <= 1 then
--         tick = tick + 1
--         return
--     end

--     tick = 0
--     seconds = seconds + 1

--     for i = 1, #tasks do
--         local task = tasks[i]

--         if not task or task.finished then
--             table.remove(tasks, i)
--         elseif task.exec_time <= seconds then
--             local success, result = pcall(task.Run, task)
--             if not success then
--                 PEARL.error("WallScheduler", "Failed to run task:", task)
--                 PEARL.error("WallScheduler", "Error Traceback: ", result)

--                 PEARL.info("WallScheduler", "Canceling and removing this task...")
--                 task:Cancel()
--                 table.remove(tasks, i)
--             end
--         end
--     end
-- end

--------------------------------

return WallScheduler
