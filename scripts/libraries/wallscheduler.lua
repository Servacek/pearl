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


-- For optimalization
local unpack = unpack
local pcall = pcall
local type = type

local table_remove = table.remove
local table_contains = table.contains
local table_sort = table.sort

local toarrayornil = toarrayornil

--------------------------------------
-- [[ Class Declaration ]]
--------------------------------------

--- @class WallScheduler
local WallScheduler = {
    TPS         = 60,
    TICK_TIME   = 1 / 60,
}

------------------------------------------
-- [[ Contants ]]
------------------------------------------

local Q_SIZE_ALLOC = 2^5
local Q_NARR_ALLOC = 2^5

--------------------------------------
-- [[ Locals ]]
--------------------------------------

-- The number that will be added to wtime every wlimit
-- By default, we increase wtime every 60 ticks by 1.
local wtdelta   = 1 -- in seconds
local wlimit    = 60 -- in ticks

local wtick = 0
-- These are relative.
local wtime = 0 -- in ticks

---@type table<Task>
local tasks = table.create(Q_SIZE_ALLOC, Q_NARR_ALLOC)
tasks.n = 0

-- flags
local looping = false
local started = false
local srt_def = false

--------------------------------------
-- [[ Private Functions ]]
--------------------------------------

-- Return whether t1 < t2
local function task_comp(t1, t2)
    return t1._ext and t2._ext and t1._ext > t2._ext
end

-- Sort the tasks according to the execution time (ext)
--
-- Re-sort of tasks is needed when:
-- - we change the _ext of a task
-- - we add a new task to the stack.
local function sort_tasks()
    -- checks if t1 < t2
    return table_sort(tasks, task_comp)
end

-- Adds the given task to the end of the stack.
--- @return Task?
local function add_task(task, nosort)
    if type(task) ~= "table" then
        return PEARL.error("Attempted to add an invalid task!")
    end

    PEARL.debug("Registering task:", task.time)
    local prev = tasks[tasks.n]
    tasks.n = tasks.n + 1
    tasks[tasks.n] = task

    -- If this is called from inside the wall update loop then deffer the sort.
    if looping then
        srt_def = true
    elseif not nosort and prev and prev._ext and prev._ext < task._ext then
        -- Else sort immediately if it's required.
        sort_tasks()
    end

    return task
end

local function has_task(task)
    return tasks.n > 0 and table_contains(tasks, task)
end

--- @param time number Time from now in seconds.
--- @param fn function The callback that should be called after 'time'.
--- @param limit number? The maximum number of times this task should be executed.
--- @param initialdelay number? The time we should wait until executing the task for the first time.
--- @param id any? The identifier of the task. Used for debugging purposes only.
--- @param ... any? All the additional parameters for the callback function.
local function create_task(time, fn, limit, initialdelay, id, ...)
    if type(fn) ~= "function" or type(time) ~= "number" then
        return PEARL.error("Attempted to create a task with invalid parameters!")
    end

    local task = {
        _time = time / wtdelta,
        _ext = wtime + (initialdelay or time) / wtdelta,
        _fn = fn,
        _limit = limit,
        -- Leave this public
        running = true, -- The task is running from the start by default
        _id = id,
        _args = toarrayornil(...),
    }

    -- Function definitions

    function task:run()
        --print("task:run")
        if not self.running or not self._fn then
            return error("attempted to run an invalid task")
        end

        if self._limit ~= nil then
            self._limit = self._limit - 1
        end

        if self._args then
            self._fn(unpack(self._args))
        else
            self._fn()
        end

        if (self._limit or 1) <= 0 then
            self:cancel()
        end

        self._ext = wtime + self._time
    end

    -- Even running tasks can be restarted.
    function task:restart()
        --print("task:restart", self:tostring())
        if type(limit) == "number" or type(self._time) ~= "number" then
            return PEARL.warn("This task doesn't support restarting...")
        end

        self.running = true
        self._ext = wtime + self._time

        if not has_task(self) then
            -- Re-Add the task back to the stack since we were removed.
            add_task(self)
        end
    end

    function task:stop()
        --print("task:stop", CalledFrom())

        if not self.running then
            return PEARL.warn("Task already stopped!")
        end

        if limit ~= nil then
            return PEARL.error("This type of task doesn't support stopping!")
        end

        -- Our reference to the task should be removed soon, but we assume
        -- that there is a reference kept somewhere in the usage code.
        self.running = false
    end

    function task:tostring()
        return string.format("Task[%s]<limit=%s,time=%s,ext=%s,running=%s>",
            tostring(self._id), tostring(self._limit), tostring(self._time), tostring(self._ext), tostring(self.running)
        )
    end

    function task:cancel()
        --print("task:cancel", self:tostring())
        self._time = 0
        self._fn = nil
        self._ext = nil
        self._limit = 0 -- Disable the task.
        self._id = nil

        self._args = nil

        self.running = false
    end

    return task
end

--------------------------------------
-- [[ Update Loop ]]
--------------------------------------

-- TheSim:GetStep() -> Returns the current tick number.
-- This runs on every game tick.
--
-- dt = time_passed - time_now
-- dt is 0 if the server is paused
local function OnWallUpdate()
    --return false

    if tasks.n < 1 then
        return
    end

    if wtick < wlimit then
        wtick = wtick + 1
    else
        wtick = 0
        wtime = wtime + wtdelta
    end

    -- If the lowest exec_time is still higher than wall time, NONE of the tasks
    -- is going to be executed. So just return.
    -- This should be never nil, the check if just in case.
    if tasks[tasks.n] and tasks[tasks.n]._ext and tasks[tasks.n]._ext > wtime then
        return
    end

    -- Iterate over the table from the back because we are removing the tasks during the
    -- iteration.
    looping = true
    for i = tasks.n, 1, -1 do
        -- The task should always be a non-nil value.
        -- If it's not... we should crash!
        local task = tasks[i]

        -- If the task is running, task.ext and task.run should never be nil!
        -- Also since the limit only decreses on task 'cancel' and 'run' internally,
        -- it should be nil or higher than 0 if running is set to true as well.
        if task.running then
            if task._ext > wtime then
                break
            end

            local success, result = pcall(task.run, task)
            if not success then
                PEARL.error("Failed to run task:", task:tostring(), "Reason:\n", result)
                task:cancel()
            end
        end

        -- Check the task again since after calling the callback it could be stopped or canceled.
        if not task.running then
            -- Use table.remove so the holes caused by periodic tasks are patched.
            table_remove(tasks, i)
            tasks.n = tasks.n - 1
        end
    end
    looping = false

    if srt_def == true then
        sort_tasks()
        srt_def = false
    end
end

--------------------------------------
-- [[ Public Methods ]]
--------------------------------------

--- Returns the array of all currently registered tasks.
--- @return table<Task> tasks
function WallScheduler:GetTasks()
    return tasks
end

--- Executes the given function after the given n seconds and stops the task
--- @param time integer The time in seconds after which this task should be executed
--- @param fn function The callback of the task
--- @param id integer? The id of the task used for debuging
--- @param ... any? Additional arguments to the callback function
---
--- @return Task? task The new created task
function WallScheduler:ExecuteInTime(time, fn, id, ...)
    return add_task(create_task(
        time, fn, 1, nil, id, ...)
    )
end

--- Executes the given function every n seconds until the given limit is exceeded
--- or the task is stopped.
--- @param period integer The period in which the task should be executed (in seconds)
--- @param fn function The callback of the task
--- @param limit integer? The task execution limit, if this is exceeded the task will be stopped
--- @param initialdelay integer? Time until the first execution
--- @param id integer? The id of the task used for debug
--- @param ... any? Additional arguments to the callback function
---
--- @return Task? task The new created task
function WallScheduler:ExecutePeriodic(period, fn, limit, initialdelay, id, ...)
    return add_task(create_task(
        period, fn, limit, initialdelay, id, ...)
    )
end

function WallScheduler:StartWallUpdate()
    PEARL.debug("WallScheduler:StartWallUpdate()")
    if started then
        return PEARL.warn("The wall scheduler has already started!")
    end

    started = true

    if PEARL.CONFIG.DEBUG_MODE then
        PEARL.AddGlobalFunctionPreCall("WallUpdate", function()
            -- Always call TheSim:ProfilerPop after this, else we will crash.
            TheSim:ProfilerPush("PWallScheduler:OnUpdate")
            OnWallUpdate()
            TheSim:ProfilerPop()
        end)
    else
        -- Adds just one additional scope to the main function
        PEARL.AddGlobalFunctionPreCall("WallUpdate", OnWallUpdate)
    end
end

function WallScheduler:SetPrecision(delta, limit)
    if started then
        return PEARL.error("The wall scheduler has already started! Can't change the precision anymore!")
    end

    wtdelta = delta
    wlimit = limit
end

--------------------------------------
-- [[ Return ]]
--------------------------------------

return WallScheduler
