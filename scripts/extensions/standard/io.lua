--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
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

function io.empty(fp)
    local empty
    local f = io.open(fp, "r")
    if f then
        empty = f:read("*a") == ""
        f:close()
    end

    return empty
end

-- True when the file didn't exist and was successfully created
-- or when the file already existed. Otherwise false.
function io.ensure(fp, init_txt)
    return io.exists(fp) or io.create(fp, init_txt)
end

function io.noext(fp)
    return fp:match("(.+)%..+") or fp
end

--- Provide the extension with a prefix dot for more precise matching.
function io.extensure(fp, ext)
    if fp:utf8sub(-ext:len()) ~= ext then
        return fp..ext
    end

    return fp
end

--- Returns a UNIX timestamp representing the last modification time of the specified file.
--- @return integer?
function io.fmtime(fp)
    -- 64bit representation of the last update timestamp in hexdecimal format.
    --- @type string
    local hex = TheSim:GetFileModificationTime(fp)
    if type(hex) ~= "string" then
        return
    end

    if PEARL.X32 and hex then
        -- If more characters are needed at some point,
        -- it will overflow on the 32 bit system anyway.
        hex = hex:rtake(8)
    end

    return tonumber(hex, 16)
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
