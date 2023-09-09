--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local FILE_PATH = PEARL.ROOTDIR.."data/timestamp"

local function LoadTimestamp()
    local rf, err = io.open(FILE_PATH, "r")
    if not rf or err then
        return PEARL.error(err)
    end

    local result = tonumber(rf:read())
    return rf:close() and result
end

local function SaveTimestamp(timestamp)
    local wf, err = io.open(FILE_PATH, "w")
    if not wf or err then
        return PEARL.error(err)
    end

    wf:write(tostring(timestamp))
    return wf:close()
end

local function CheckTimeUpdates()
    local timesaved = LoadTimestamp()

    local changes = false
    local timenow = os.time()
    local ctb = PEARL.TimestampToTable(timenow)
    local stb = PEARL.TimestampToTable(timesaved)

    if not stb or ctb.year ~= stb.year then
        PEARL.EventProcessor:HandleEvent("newyear", stb, ctb)
        changes = true
    end

    if not stb or ctb.month ~= stb.month then
        PEARL.EventProcessor:HandleEvent("newmonth", stb, ctb)
        changes = true
    end

    if not stb or ctb.day ~= stb.day then
        PEARL.EventProcessor:HandleEvent("newday", stb, ctb)
        changes = true
    end

    SaveTimestamp(timenow)

    PEARL.EventProcessor:HandleEvent("timeupdatedone", changes)
end

--- @TODO: Add support for servers that do not restart every day.
PEARL.AddGamePostInit(function()
    -- Make sure everything is loaded and listening!
    PEARL.WallScheduler:ExecuteInTime(1, CheckTimeUpdates)
end)
