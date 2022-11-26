--[[
    Additional utility functions to the standard libraries.

    NOTES:
        - [](<url>) displays only the embed of the url.
--]]


local PEARL = PEARL
local string = string

---------------------------
-- [[ Constants ]]
---------------------------

local ESCAPE_CHAR = "\\"
local ESCAPE_TEMPLATE = ESCAPE_CHAR.."%s"

local URL_PATTERN = "https?%:%/%/"..string.rep(
    "[%w%d%.%/%#]", 2
).."+"

--- Note: Currently we escape hyperlinks by escaping all '[' chars
--- @TODO doesn't work for multiple hyperlinks
local HYPERLINK_PATTERN = "%[.*%]%(.*%)"

--------------------------------
-- [[ String Utils ]]
--------------------------------

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

function string:take(count, init)
    return self:sub(init or 1, count)
end

function string:rtake(count, init)
    return self:sub(count, #self - init)
end

--- Converts the first letter of the given string to uppercase
--- @return string result The formatted result string
function string:capitalize()
    return self and (self:gsub("^%l", string.upper)) or self
end

---------------------------
-- [[ Table Utils ]]
---------------------------

function table:filter(checkfn)
    local result = {}
    for k, v in pairs(self) do
        if checkfn(k, v) then
            result[k] = v
        end
    end

    return result
end

function table:check(checkfn)
    for k, v in pairs(self) do
        if checkfn(k, v) then
            return true
        end
    end

    return false
end

---------------------------
-- [[ Math Utils ]]
---------------------------

function math.round(num, dp)
    local mult = 10^(dp or 0)

    return math.floor((num * mult) + 0.5) / mult
end
