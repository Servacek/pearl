--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local utf8 = PEARL.loadfile("libraries/utf8")

local json = json


function json.encode_sanitized(data)
    local success, result = pcall(json.encode_compliant, data)
    return success, success and utf8.decode_string(result) or result
end

--- @param t table
--- @param file file*
--- @return file*? file, string? data
function json.dump(t, file)
    local success, str = pcall(json.encode, t)
    if success == true then
        return file:write(str)
    end

    return file, str
end

--- @param file file*
--- @return table? result
function json.load(file)
    local _, result = pcall(json.decode, file:read("*a"))
    return result
end
