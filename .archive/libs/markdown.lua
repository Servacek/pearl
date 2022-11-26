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

--- Note: Currently we escape hyperlinks by escaping all '[' chars
--- Note: doesn't work for multiple hyperlinks
--local HYPERLINK_PATTERN = "%[.+%]%(.+%)"

local MARKDOWN = {
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

--------------------------------
-- [[ String Utils - Markdown ]]
--------------------------------

function string:escape(target_char)
    if not self or not target_char or string.len(target_char) ~= 1 then
        return self
    end

    local last_char
    return self:gsub("%"..target_char, function(char)
        if char and last_char ~= ESCAPE_CHAR then
            return ESCAPE_TEMPLATE:format(char)
        end

        last_char = char
    end)
end

function string:escape_markdown()
    return (self:gsub(PEARL.CONSTS.MARKDOWN_PATTERN, "\\%1"))
end

--- Checks whether the given sub-string/character is changing the markdown
--- formatting of the string. In other words, this checks if the given characters
--- are on the start and the end of the string.
--- @param o_char string The opening markdown character.
--- @param c_char string? The closing markdown character.
--- If not supplied, it uses the value of the o_char argument.
--- @return boolean result True when markdown is applied, false otherwise.
function string:applied(o_char, c_char)
    return self:startswith(o_char) and self:endswith(c_char or o_char)
end

--- Formats a string to the codeline format using the discord markdown characters
--- @return string|stringlib result The formatted string
function string:codeline()
    self = tostring(self):gsub("`", "ˋ")

    return MARKDOWN.CODE_LINE:format(self)
end

--- Formats a string to the codeblock format using the discord markdown characters
--- @return string|stringlib result The formatted string
function string:codeblock(lang_code)
    self = tostring(self):gsub("`", "ˋ")

    if type(lang_code) == "string" then
        return MARKDOWN.CODE_BLOCK_SYNTAX:format(lang_code, self)
    end

    return MARKDOWN.CODE_BLOCK:format(self)
end

--- Formats a string to the italic format using the discord markdown characters
--- @return string|stringlib result The formatted string
function string:italic()
    return MARKDOWN.ITALIC:format(self)
end

--- Formats a string to the bold format using the discord markdown characters
--- @return string|stringlib result The formatted string
function string:bold()
    return MARKDOWN.BOLD:format(self)
end

-- Do not use this with user's input
-- Note: The link parameter can be nil.
function string.hlink(str, link)
    if type(str) ~= "string" then
        return str
    end

    return MARKDOWN.HYPERLINK:format(str, tostring(link))
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

--- Note: Currently we escape hyperlinks by escaping all '[' chars
function string:escape_hlinks()
    return self:gsub("%[", "\\[")
end
