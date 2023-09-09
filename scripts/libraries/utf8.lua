--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


-- https://gist.github.com/MikuAuahDark/124c89af9f2d4874c347

--------------------------------
-- [[ Global Localization ]]
--------------------------------

local sbyte = string.byte
local sfind = string.find
local uchar = string.utf8char

--------------------------------
-- [[ Constants ]]
--------------------------------

local ASCII_LAST    = 0x80
local ASCII_FIRST   = 0
local MAX_UTF_BYTES = 4

-- Pattern for matching all non-ascii characters
local UTF8_PATTERN  = "[\128-\255]+"

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @class utf8
local utf8 = {}

--------------------------------
-- [[ Public Member Functions ]]
--------------------------------

--- Returns whether the given character is ASCII or not.
--- @param char string|integer
function utf8.ascii(char)
    if type(char) == "number" then
        return char >= ASCII_FIRST and char <= ASCII_LAST
    end

    return sbyte(char) >= ASCII_FIRST and sbyte(char) <= ASCII_LAST
end

--- @TODO: Rethink this a bit.
-- https://github.com/kikito/utf8_validator.lua/blob/master/utf8_validator.lua
function utf8.validate(s)
    local i = 1
    while i <= #s do
        if     i == sfind(s, "[%z\1-\127]", i) then i = i + 1
        elseif i == sfind(s, "[\194-\223][\128-\191]", i) then i = i + 2
        elseif i == sfind(s, "\224[\160-\191][\128-\191]", i)
            or i == sfind(s, "[\225-\236][\128-\191][\128-\191]", i)
            or i == sfind(s, "\237[\128-\159][\128-\191]", i)
            or i == sfind(s, "[\238-\239][\128-\191][\128-\191]", i) then i = i + 3
        elseif i == sfind(s, "\240[\144-\191][\128-\191][\128-\191]", i)
            or i == sfind(s, "[\241-\243][\128-\191][\128-\191][\128-\191]", i)
            or i == sfind(s, "\244[\128-\143][\128-\191][\128-\191]", i) then i = i + 4
        else
            return false, i
        end
    end

    return true
end

function utf8.decode(char)
    local byte = sbyte(char)
    return byte and uchar(byte) or nil
end

function utf8.decode_string(s)
    if not s or #s <= 1 then
        return s
    end

    return s:gsub(UTF8_PATTERN, function(char)
        -- Should not be needed
        -- if utf8.ascii(char) then
        --     return char
        -- end

        -- If we a have a byte sequence
        if #char > 1 then
            return utf8.validate(char) and char or "?"
        end

        return utf8.decode(char) or "?"
    end)
end

function utf8.encode_string(s)
    if not s or #s <= 1 then
        return s
    end

    return s:gsub(UTF8_PATTERN, function(char)
        -- If we a have a byte sequence
        if #char > 1 then
            return utf8.validate(char) and char or "?"
        end

        return utf8.decode(char) or "?"
    end)
end

--------------------------------
-- [[ Return ]]
--------------------------------

return utf8
