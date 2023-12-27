--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


-------------------------------------
-- [[ Constants ]]
-------------------------------------

local FILE_PATH = PEARL.ROOTDIR.."data/timestamp"

local UPDATE_FREQUENCY = 1

-------------------------------------
-- [[ Local Functions ]]
-------------------------------------

local function LoadTimestamp()
    PEARL.debug("LoadTimestamp")

    if io.ensure(FILE_PATH) then
        return
    end

    local rf, err = io.open(FILE_PATH, "r")
    if not rf or err then
        return PEARL.error(err)
    end

    local result = tonumber(rf:read())
    return rf:close() and result or nil
end

local function SaveTimestamp(timestamp)
    PEARL.debug("SaveTimestamp", timestamp)

    local wf, err = io.open(FILE_PATH, "w")
    if not wf or err then
        return PEARL.error(err)
    end

    wf:write(tostring(timestamp))
    return wf:close()
end

-- Returns true when the current timestamp differs from
-- the saved one in years, days, or months.
local function CheckForTimeChanges(timenow, timesaved)
    local changes = false
    local ctb = PEARL.TimestampToTable(timenow)
    local stb = PEARL.TimestampToTable(timesaved)
    if not stb or not ctb then
        return changes
    end

    -- Years are always unique so start with them.
    if changes or ctb.year ~= stb.year then
        PEARL.debug("NEW YEAR", ctb.year)
        PEARL.EventProcessor:HandleEvent("newyear", stb, ctb)
        changes = true
    end

    -- After the year has changed we have guaranteed to have a new month
    -- even when the month numbers are equal.
    if changes or ctb.month ~= stb.month then
        PEARL.debug("NEW MONTH", ctb.month)

        PEARL.EventProcessor:HandleEvent("newmonth", stb, ctb)
        changes = true
    end

    if changes or ctb.day ~= stb.day then
        PEARL.debug("NEW DAY", ctb.day)

        PEARL.EventProcessor:HandleEvent("newday", stb, ctb)
        changes = true
    end

    return changes
end

local function OnUpdate()
    local timenow = os.time()
    local timesaved = LoadTimestamp()
    local changes = true
    if timesaved ~= nil then
        changes = CheckForTimeChanges(timenow, timesaved)
    end

    if changes == true then
        SaveTimestamp(timenow)

        --- @TODO: Verify if this is really needed.
        PEARL.EventProcessor:HandleEvent("timeupdatedone")
    end
end

-------------------------------------
-- [[ Setup ]]
-------------------------------------

--- @TODO: Add support for servers that do not restart every day.
PEARL.AddGamePostInit(function()
    -- Make sure everything is loaded and listening!
    PEARL.WallScheduler:ExecuteInTime(UPDATE_FREQUENCY, OnUpdate)
end)
