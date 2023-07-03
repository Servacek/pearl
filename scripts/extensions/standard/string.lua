--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]




-------------------------------------
-- [[ Global Localization ]]
-------------------------------------

local pairs = pairs

local rep = string.rep
local upper = string.utf8upper
local utf8char = string.utf8char
local sbyte = string.byte

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
    return suffix and suffix:utf8sub(-suffix:len()) == suffix
end

-- Replaces all known dst emoticons in a string with discord emojis
function string.emojify(str)
    for utf8_str, emoji in pairs(PEARL.EMOTES.DISCORD) do
        str = str:gsub(utf8_str, emoji)
    end

    return str
end

-- Returns a discord emoji string or the input string if no result was found
function string.to_emoji(utf8_icon)
    return PEARL.EMOTES.DISCORD[utf8_icon] or utf8_icon
end

-- longline -> ltake(3) -> lon
--
--- @BYTEAWARE
--- @param count number The number of characters to take from the right side of the string.
--- @param init number? The index of the character from which we should start taking.
--- @param postfix string? An additional string added after the last taken character.
---
--- @return string result The modified string.
function string:ltake(count, init, postfix)
    local r = self:utf8sub(init or 1, count)
    return postfix and count > 0 and #self > count and r..postfix or r
end

-- longline -> rtake(3) -> ine
--
--- @BYTEAWARE
--- @param count number The number of characters to take from the right side of the string.
--- @param init number? The index of the character from which we should start taking.
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
    return self and (self:gsub("^%l", upper)) or self
end

function string:count(word)
    local count = 0
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

-- -- https://github.com/kikito/utf8_validator.lua/blob/master/utf8_validator.lua
-- local find = string.find
-- local function utf8validate(s)
--     while i <= len do
--     if     i == find(s, "[%z\1-\127]", i) then
--         i = i + 1
--     elseif i == find(s, "[\194-\223][\128-\191]", i) then i = i + 2
--     elseif i == find(s,        "\224[\160-\191][\128-\191]", i)
--         or i == find(s, "[\225-\236][\128-\191][\128-\191]", i)
--         or i == find(s,        "\237[\128-\159][\128-\191]", i)
--         or i == find(s, "[\238-\239][\128-\191][\128-\191]", i) then i = i + 3
--     elseif i == find(s,        "\240[\144-\191][\128-\191][\128-\191]", i)
--         or i == find(s, "[\241-\243][\128-\191][\128-\191][\128-\191]", i)
--         or i == find(s,        "\244[\128-\143][\128-\191][\128-\191]", i) then i = i + 4
--     else
--         return false, i
--     end
--     end

--   return true
-- end

-- --- @TODO: Filter out invalid byte sequences!
-- function string:utf8decode()
--     return self:gsub("[\128-\255]+", function(h)
--         -- If we a have a byte sequence
--         if #h > 1 then
--             if not utf8validate(h) then
--                 return "?"
--             end

--             return h
--         end

--         local byte = sbyte(h)
--         return byte and utf8char(byte) or "?"
--     end)
-- end

function string:raw()
    return self.format("%q", self)
end
