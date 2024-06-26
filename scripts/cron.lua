--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--[[
    A very simple implementation of the crontab scheduler with the most basic syntax.

    Used for scheduling tasks in places where third party software cannot be used reliable.

    It is built over the Wall Scheduler library using it's periodic tasks feature as the clock.
--]]

-- ┌───────────── minute (0–59)                                         - MIN
-- │ ┌───────────── hour (0–23)                                         - HOUR
-- │ │ ┌───────────── day of the month (1–31)                           - DOM
-- │ │ │ ┌───────────── month (1–12)                                    - MON
-- │ │ │ │ ┌───────────── day of the week (0–6) (Sunday to Saturday;    - DOW
-- │ │ │ │ │                                   7 is also Sunday on some systems)
-- │ │ │ │ │
-- │ │ │ │ │
-- * * * * * <command to execute>

--- SOURCES:
-- https://dl.acm.org/doi/pdf/10.1145/359763.359801
-- https://salsa.debian.org/debian/cron

--------------------------------
-- [[ Constants ]]
--------------------------------

local CRONTAB_FILE = "crontab"

local COMMENT_PREFIX = "#" -- Line to be ignored

local WILDCARD      = "*" -- Wildcard for all possible values
local VAL_LIST_SEP  = "," -- For multiple values
local RANGE         = "-" -- For a range of values
local FIELD_SPLIT   = " "

local NFIELDS       = 6
local NSTEPS        = 1
local NRANGE        = 2
local DEFAULT_STEP  = 1

local CLOCK_PERIOD  = 59 -- Minute is our smallest unit

local FIELDS = {
    MIN = 1, HOUR = 2, DOM = 3, MON = 4, DOW = 5, CMD = 6,
}

local FIELD_LIMITS = {
    [FIELDS.MIN]  = {MIN = 0, MAX = 59},
    [FIELDS.HOUR] = {MIN = 0, MAX = 23},
    [FIELDS.DOM]  = {MIN = 1, MAX = 31},
    [FIELDS.MON]  = {MIN = 1, MAX = 12},
    [FIELDS.DOW]  = {MIN = 0, MAX =  6},
}

--------------------------------
-- [[ Local Function ]]
--------------------------------

local date = function(...) return tonumber(os.date(...)) end

--- Splits a timestamp to the five crontab fields - m, h, wd, M, md
local function split_timestamp(timestamp)
    return date("%M", timestamp), date("%H", timestamp), date("%w", timestamp),
        date("%m", timestamp), date("%d", timestamp)
end

--------------------------------
-- [[ Class Definition ]]
--------------------------------

--- @singleton
--- @class Cron
local Cron = {
    jobs = {},
    clock = nil,
}


function Cron:New(min, hour, dom, mon, dow, cmd)
    if type(cmd) ~= "function" then
        local errmsg
        cmd, errmsg = loadstring(cmd)
        if not cmd or errmsg then
            return error("Attempted to create an invalid cron job! Reason:"..tostring(errmsg))
        end
    end

    return {
        [FIELDS.MIN]    = min or WILDCARD,
        [FIELDS.HOUR]   = hour or WILDCARD,
        [FIELDS.DOM]    = dom or WILDCARD,
        [FIELDS.MON]    = mon or WILDCARD,
        [FIELDS.DOW]    = dow or WILDCARD,
        [FIELDS.CMD]    = cmd,
    }
end

function Cron:StartClock()
    PEARL.debug("Cron:StartClock")

    if self.clock then
        return PEARL.debug("Clock already running!")
    end

    self.clock = PEARL.WallScheduler:ExecutePeriodic(CLOCK_PERIOD, function()
        for i = 1, #self.jobs do
            local job = self.jobs[i]
            if self:ShouldExecute(job) then
                self:ExecuteJob(job)
            end
        end
    end, nil, 60 - os.date("%S", os.time()))
end

function Cron:AddJob(job)
    self.jobs[#self.jobs + 1] = job

    if not self.clock then
        self:StartClock()
    end
end

function Cron:ExecuteJob(job)
    return PEARL.SafeRun(job[FIELDS.CMD])
end

function Cron:ShouldExecute(job)
    local min, hour, dom, mon, dow = split_timestamp(os.time())
    print(min, hour, dom, mon, dow)
    print( job[FIELDS.MIN], job[FIELDS.HOUR], job[FIELDS.DOM], job[FIELDS.MON], job[FIELDS.DOW])
    return (job[FIELDS.MIN] == WILDCARD or job[FIELDS.MIN] == min) and
           (job[FIELDS.HOUR] == WILDCARD or job[FIELDS.HOUR] == hour) and
           (job[FIELDS.DOM] == WILDCARD or job[FIELDS.DOM] == dom) and
           (job[FIELDS.MON] == WILDCARD or job[FIELDS.MON] == mon) and
           (job[FIELDS.DOW] == WILDCARD or job[FIELDS.DOW] == dow)
end

-- function Cron:Next(last_time, job)
--     local lmin, lh, lwday, lmonth, lmday = split_timestamp(last_time)
--     local cmin, ch, cwday, cmonth, cmday = split_timestamp(os.time())
--     local mins, hs, wdays, months, mdays = unpack(job)

--     local dt = {minutes = {}, hours = {}, wdays = {}, months = {}, mdays = {}}
--     for min in ipairs(mins) do
--         min_left = min - 1 + 60
--         if min_left > 60 then

--         end

--         local target_minute = 30
--         local current_minute = lmin

--         30 - 56 = -26
--         -26 + 60 = 34
--         local minutes_left = target_minute - current_minute
--         if minutes_left < 0 then
--             minutes_left = minutes_left + 60
--         end

--         print("Minutes left:", minutes_left)


--     end

--     os.time()
-- end

-- function Cron:Parse(line)
--     if line:startswith(COMMENT_PREFIX) then
--         return
--     end

--     local fields = line:split(FIELD_SPLIT)
--     local nfields = #fields
--     if nfields ~= NFIELDS then
--         return error("Invalid syntax of crontab job.")
--     end

--     local command = fields[nfields]
--     if not command or command:blank() then
--         return error("Invalid command for crontab job.")
--     end

--     local level = self.jobs
--     for fid, field in ipairs(line:split(FIELD_SPLIT)) do
--         if field == WILDCARD then
--             -- Convert wildcards to ranges.
--             field = tostring(FIELD_LIMITS.MIN).."-"..tostring(FIELD_LIMITS[fid].MAX)
--         end

--         local val_list = field:split(VAL_LIST_SEP)
--         for _, fval in ipairs(val_list) do
--             local step_sep = fval:split(STEP)
--             local val = step_sep[1]
--             local nsteps = #step_sep - 1
--             local step = tonumber(step_sep[2]) or DEFAULT_STEP
--             if nsteps > NSTEPS then
--                 return error("Only one step is allowed per field!")
--             end

--             local range = val:split(RANGE)
--             local nrange = #range
--             if nrange > NRANGE then
--                 return error("Invalid range provided!")
--             elseif nrange == NRANGE then
--                 for i = tonumber(range[1]), tonumber(range[2]), step do
--                     self.jobs[fid][i] = command
--                 end
--             elseif step ~= DEFAULT_STEP then
--                 error("Step requires a range or wildcard!")
--             end

--             level =
--         end

--         level = level[]
--     end
-- end

-- PEARL.ModPersistence:ForEachLineIn(CRONTAB_FILE, function(line)
--     Cron:Parse(line)
-- end, true)

--------------------------------
-- [[ Return ]]
--------------------------------

return Cron
