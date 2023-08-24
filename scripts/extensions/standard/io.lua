--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]




function io.exists(fp)
    local f = io.open(fp, "r")
    return f and f:close() ~= nil or false
end

function io.create(fp, init_txt)
    local f = io.open(fp, "w")
    if f ~= nil then
        if init_txt ~= nil then
            f:write(tostring(init_txt))
        end

        return f:close()
    end
end

function io.line(fp)
    local f = io.open(fp, "r")
    local line = f and f:read("*l")
    return f and f:close() and line or ""
end

function io.ensure(fp, init_txt)
    return not io.exists(fp) and io.create(fp, init_txt)
end

function io.strippedlines(...)
    local slines = {}
    for line in io.lines(...) do
        local sline = line:strip()
        if sline ~= "" then
            slines[#slines+1] = sline
        end
    end

    return slines
end

-- Removing this for now since it crashes the server without error.
---@diagnostic disable-next-line: duplicate-set-field
io.flush = function()
    print("ERROR: io.flush not supported")
end

io.seek = function()
    print("ERROR: io.seek not supported")
end
