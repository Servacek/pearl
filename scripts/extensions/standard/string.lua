--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


---@diagnostic disable: param-type-mismatch

--- Some magic to prevent the diagnostics from marking custom string methods

--- @class string: stringlib
local stringlib = string
string = stringlib

-------------------------------------
-- [[ Global Localization ]]
-------------------------------------

local pairs = pairs

local rep = string.rep
local utf8upper = string.utf8upper

-------------------------------------
-- [[ Constants ]]
-------------------------------------

local BLANK_PATTERN = "^[%s%c\t\n\r]*$"

-------------------------------------
-- [[ Public Functions ]]
-------------------------------------

function string:center(count, char)
    if not count then return self end
    char = char or " "

    return rep(char, count)..self..rep(char, count)
end

--- Removes leading space characters from a string.
--- @return string result
function string:lstrip()
    return self:match("^%s*(.*)")
end

--- Remove trailling space characters from a string.
--- @return string result
function string:rstrip()
    return self:match("^(.*%S)%s*$")
end

function string:strip()
    return self:match("^%s*(.-)%s*$")
end

--- Slices a string into two parts.
--- If char is provided, it will attempt to slice the string
--- at the last possible position of the char.
--- The char won't be contained in the result.
function string:slice(pos, char)
    -- Special optimization case for short strings.
    if #self <= pos then
        return self, ""
    end

    -- Special case for start of the string.
    if pos <= 1 then
        return "", self
    end

    local lslice = self:sub(1, pos)
    if char then
        for i = #lslice, 1, -1 do
            if self:sub(i, i) == char then
                return self:sub(1, i - 1), self:sub(i + 1)
            end
        end
    end

    return lslice, self:sub(pos + 1)
end

--- Checks if string starts with the given prefix
--
--- @BYTEAWARE
--- @param prefix string The prefix we are looking for
--- @return boolean result Whether the prefix was found
function string:startswith(prefix)
    return prefix and self:utf8sub(1, prefix:len()) == prefix
end

--- Checks if string ends with the given suffix
--
--- @BYTEAWARE
--- @param suffix string The suffix we are looking for
--- @return boolean result Whether the suffix was found
function string:endswith(suffix)
    return suffix and self:utf8sub(-suffix:len()) == suffix
end

-- Replaces all known dst emoticons in a string with discord emojis
function string:emojify()
    for utf8_str, emoji in pairs(PEARL.EMOTES.MAP_DISCORD) do
        self = self:gsub(utf8_str, emoji)
    end

    return self
end

-- Returns a discord emoji string or the input string if no result was found
function string.toemoji(utf8_icon)
    return PEARL.EMOTES.MAP_DISCORD[utf8_icon] or utf8_icon
end

-- longline -> ltake(3) -> lon
--
--- @BYTEAWARE
--- @param count integer The number of characters to take from the right side of the string.
--- @param init string? The index of the character from which we should start taking.
--- @param postfix string? An additional string added after the last taken character.
---
--- @return string result The modified string.
function string:ltake(count, init, postfix)
    count = postfix and count - #postfix or count
    local r = self:utf8sub(init or 1, count)
    return postfix and count > 0 and #self > count and r..postfix or r
end

-- longline -> rtake(3) -> ine
--
--- @BYTEAWARE
--- @param count string The number of characters to take from the right side of the string.
--- @param init string? The index of the character from which we should start taking.
--- @param prefix string? An additional string added before the first taken character.
---
--- @return string result The modified string.
function string:rtake(count, init, prefix)
    local r = self:utf8sub(#self - count + 1, init or #self)
    return prefix and count > 0 and #self > count and prefix..r or r
end

--- Converts the first letter of the given string to uppercase
--- @return string result The formatted result string
function string:capitalize()
    return self and (self:gsub("^%l", utf8upper)) or self
end

function string:count(word)
    local count = 0

    --- @type integer?
    local startPos = 0
    while startPos do
        startPos = self:find(word, startPos + 1, true)
        if startPos then
            count = count + 1
        end
    end

    return count
end

function string:escape(char)
    return self:gsub(char, "\\%1")
end

function string:raw()
    return self.format("%q", self)
end

function string:empty()
    return #self == 0
end

function string:blank()
    return self:empty() or self:find(BLANK_PATTERN) ~= nil
end

--- If name is a table, all formattings in that table will be applied.
--- Otherwise, if it's a string then a only specific formatting with that name
--- will be replaced with the value string provided.
---
--- @KnownErrors: Invalid replacement value:
---  - This is thrown when the replacement table contains other subtables as replacements,
---
--- @param self string
--- @param name table<string, any>|string
--- @param value string?
function string:nformat(name, value)
    if type(name) == "table" then
        return (self:gsub("{([^}]+)}", name))
    end

    if name == nil or value == nil then
        return self
    end

    return self:gsub("{"..name.."}", value, 1)
end


function string:iformat(index, value, pattern)
    pattern = pattern or "%s"

    local count = 0
    return (self:gsub("%"..pattern, function()
        count = count + 1

        if count == index then
            return value
        end
    end))
end
