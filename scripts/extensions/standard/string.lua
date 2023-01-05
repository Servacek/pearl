--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.
    
    Copyright (c) 2023 Fi7iP
    All rights reserved.
    
    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



function string:center(count, char)
    if not count then return self end
    char = char or " "

    return string.rep(char, count)..self..string.rep(char, count)
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
--- @param prefix string The prefix we are looking for
--- @return boolean result Whether the prefix was found
function string:startswith(prefix)
    return prefix and self:sub(1, prefix:len()) == prefix
end

--- Checks if string ends with the given suffix
--- @param suffix string The suffix we are looking for
--- @return boolean result Whether the suffix was found
function string:endswith(suffix)
    return suffix and suffix:sub(-suffix:len()) == suffix
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
--- @param count number The number of characters to take from the right side of the string.
--- @param init number? The index of the character from which we should start taking.
--- @param postfix string? An additional string added after the last taken character.
---
--- @return string result The modified string.
function string:ltake(count, init, postfix)
    local r = self:sub(init or 1, count)
    return postfix and count > 0 and #self > count and r..postfix or r
end

-- longline -> rtake(3) -> ine
--- @param count number The number of characters to take from the right side of the string.
--- @param init number? The index of the character from which we should start taking.
--- @param prefix string? An additional string added before the first taken character.
---
--- @return string result The modified string.
function string:rtake(count, init, prefix)
    local r = self:sub(#self - count + 1, init or #self)
    return prefix and count > 0 and #self > count and prefix..r or r
end

--- Converts the first letter of the given string to uppercase
--- @return string result The formatted result string
function string:capitalize()
    return self and (self:gsub("^%l", string.upper)) or self
end

function string:raw()
    return self.format("%q", self)
end
