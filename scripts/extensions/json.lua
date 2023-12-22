--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local utf8 = PEARL.loadfile("libraries/utf8")

--- @type JSON
json = json

--- @class JSON
local json = json


function json.encode_sanitized(data)
    local success, result = pcall(json.encode_compliant, data)
    return success, success and utf8.decode_string(result) or result
end

--- Dumps the provided table to the file at the provided path as JSON encoded string.
--- Use load in order to load this file back into a Lua table.
--- @param t table
--- @param filepath string
--- @return file*? file, string? data
function json.dump(t, filepath)
    local wf, errmsg = io.open(filepath, "w")
    if not wf then
        PEARL.error("Failed to open JSON file at", filepath, errmsg)
        return
    end

    local success, str = pcall(json.encode, t)
    if success ~= true or type(str) ~= "string" then
        PEARL.error("Failed to encode the provided JSON data.", str)
    else
        wf:write(str)
    end

    wf:close()
end

--- Inverse operation to json.dump. Attempts to load the JSON data from the specified file
--- and decode them back into a Lua table.
--- @param filepath string
--- @return table? result, string? errmsg
function json.load(filepath)
    local rf, errmsg = io.open(filepath, "r")
    if not rf then
        PEARL.error("Failed to open JSON file at", filepath, errmsg)
        return
    end

    local str = rf:read("*a")
    local success, t = pcall(json.decode, str)
    if success ~= true or type(t) ~= "table" then
        return nil, t
    end

    return t
end
