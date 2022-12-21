

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

function string:ltake(count, init)
    return self:sub(init or 1, count)
end

-- rtake(10)
-- ffasffassafasfasf
function string:rtake(count, init)
    return self:sub(#self - count + 1, init or #self)
end

--- Converts the first letter of the given string to uppercase
--- @return string result The formatted result string
function string:capitalize()
    return self and (self:gsub("^%l", string.upper)) or self
end

function string:raw()
    return self.format("%q", self)
end
