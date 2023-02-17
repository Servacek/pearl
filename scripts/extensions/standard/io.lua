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

function io.create(fp)
    local f = io.open(fp, "w")
    return f and f:close()
end

function io.line(fp)
    local f = io.open(fp, "r")
    local line = f and f:read("*l")
    return f and f:close() and line or ""
end

function io.ensure(fp)
    return io.exists(fp) or io.create(fp)
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
