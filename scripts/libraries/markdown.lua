--[[
    Additional utility functions to the standard libraries.

    NOTES:
        - [](<url>) displays only the embed of the url.
--]]

---------------------------
-- [[ Constants ]]
---------------------------

--- Note: Currently we escape hyperlinks by escaping all '[' chars
--- Note: doesn't work for multiple hyperlinks
--local HYPERLINK_PATTERN = "%[.+%]%(.+%)"

--------------------------------
-- [[ Initialization ]]
--------------------------------

local MARKDOWN = {
    -- Do not add backslashes before backticks
    SYMBOL_PATTERN = "[%~%*%_%>%|%[~%`%:]",
    PATTERNS = {
        BOLD                = "**%s**",
        ITALIC              = "*%s*",
        CODE_BLOCK          = "```%s```",
        CODE_BLOCK_SYNTAX   = "```%s\n%s```",
        CODE_LINE           = "`%s`",
        HYPERLINK           = "[%s](%s)",
        UNDERLINE           = "__%s__",
        STRYKETHROUGH       = "~~%s~~",
        QUOTE               = ">%s",
    }
}

--------------------------------
-- [[ Functions ]]
--------------------------------

--- @deprecated
-- function string:escape(target_char)
--     if not self or not target_char or string.len(target_char) ~= 1 then
--         return self
--     end

--     local last_char
--     return self:gsub("%"..target_char, function(char)
--         if char and last_char ~= ESCAPE_CHAR then
--             return ESCAPE_TEMPLATE:format(char)
--         end

--         last_char = char
--     end)
-- end

--- Escapes all known markdown symbols from the given string.
--- @param s string The string you want remove makrdown from.
--- @return string result String with escaped markdown symbols.
function MARKDOWN.escape(s)
    return (s:gsub(MARKDOWN.SYMBOL_PATTERN, "\\%1"))
end

-- https://some.host/ -> https\://some.host
-- Warning: This link is not clickable anymore! Only if used in a hyperlink
function MARKDOWN.escape_link_embeds(s)
    return s:gsub(":", "\\%1")
end

--- @deprecated
--- Checks whether the given sub-string/character is changing the markdown
--- formatting of the string. In other words, this checks if the given characters
--- are on the start and the end of the string.
--- @param o_char string The opening markdown character.
--- @param c_char string? The closing markdown character.
--- If not supplied, it uses the value of the o_char argument.
--- @return boolean result True when markdown is applied, false otherwise.
-- function MARKDOWN.applied(o_char, c_char)
--     return self:startswith(o_char) and self:endswith(c_char or o_char)
-- end

--- Formats a string to the codeline format using the discord markdown characters
--- @return string|stringlib result The formatted string
function MARKDOWN.codeline(s)
    s = tostring(s):gsub("`", "ˋ")

    return MARKDOWN.PATTERNS.CODE_LINE:format(s)
end

--- Formats a string to the codeblock format using the discord markdown characters
--- @return string result The formatted string
function MARKDOWN.codeblock(s, lang_code)
    s = tostring(s):gsub("`", "ˋ")

    if type(lang_code) == "string" then
        return MARKDOWN.PATTERNS.CODE_BLOCK_SYNTAX:format(lang_code, s)
    end

    return MARKDOWN.PATTERNS.CODE_BLOCK:format(s)
end

--- Formats a string to the italic format using the discord markdown characters
--- @return string result The formatted string
function MARKDOWN.italic(s)
    return MARKDOWN.PATTERNS.ITALIC:format(s)
end

--- Formats a string to the bold format using the discord markdown characters
--- @return string result The formatted string
function MARKDOWN.bold(s)
    return MARKDOWN.PATTERNS.BOLD:format(s)
end

-- Do not use this with user's input
-- Note: The link parameter can be nil.
function MARKDOWN.hlink(s, link)
    if type(s) ~= "string" then
        return s
    end

    return MARKDOWN.PATTERNS.HYPERLINK:format(s, tostring(link))
end

--- @deprecated Use SUPPRESS_EMBEDS flag instead
-- Prevents the given link from creating an embed when posted
-- function string:noembed()
--     return string.format("<%s>", self)
-- end

--- @deprecated Use SUPPRESS_EMBEDS flag instead
-- Escapes all markdowned links in the given string, so they do not create
-- an embed when posted.
-- Note: Currently we escape links by escaping all ':' chars
-- function string:escape_links()
--     return self:gsub(URL_PATTERN, "<%1>")
-- end

--- @deprecated
--- Note: Currently we escape hyperlinks by escaping all '[' chars
-- function string:escape_hlinks()
--     return self:gsub("%[", "\\[")
-- end

return MARKDOWN
