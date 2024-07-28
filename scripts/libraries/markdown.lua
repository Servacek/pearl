--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--[[
    Wrapper for markdown syntax for strings. Supports most of the markdown supported by Discord.

    NOTES:
        - [](<url>) displays only the embed of the url.
        - Currently we escape hyperlinks by escaping all '[' chars
        - Doesn't work for multiple hyperlinks:
            -local HYPERLINK_PATTERN = "%[.+%]%(.+%)"
--]]

---------------------------
-- [[ Localization ]]
---------------------------

local type, tostring = type, tostring
local string = string

---------------------------
-- [[ Constants ]]
---------------------------

local LINK_ESCAPE_PATTERN = "<%s>"

local MENTION_PATTERN  = "<%s%s>"
local TIMESTAMP_PATTERN = "<t:%s>"
local TIMESTAMP_TYPE_PATTERN = "<t:%s:%s>"

--------------------------------
-- [[ Intialization ]]
--------------------------------

--- @static
local MARKDOWN = {
    -- Do not add backslashes before backticks
    SYMBOL_PATTERN = "[%~%*%_%>%|%[~%`%:%-%#]",
    PATTERNS = { -- We do not need to escape these
        BOLD                = "**%s**",
        ITALIC              = "*%s*",
        CODE_BLOCK          = "```%s```",
        CODE_BLOCK_SYNTAX   = "```%s\n%s```",
        CODE_LINE           = "`%s`",
        HYPERLINK           = "[%s](%s)",
        UNDERLINE           = "__%s__",
        STRYKETHROUGH       = "~~%s~~",
        QUOTE               = "> %s",
        HEADER_BIG          = "# %s",
        HEADER_MED          = "## %s",
        HEADER_SML          = "### %s",
        SPOILER             = "||%s||",
        UL_ITEM             = "- %s", -- Use this instead of the asterisk to prevent any conflicts.
        OL_ITEM             = "%d. %s",
    },

    MENTION_TYPE = {
        USER    = "@",  -- @User
        ROLE    = "@&", -- @Role
        CHANNEL = "#",  -- #Channel
    },

    TIMESTAMP_TYPE = {
        DEFAULT         = "",  -- 28 November 2018 09:01
        SHORT_TIME      = "t", -- 09:01
        LONG_TIME       = "T", -- 09:01:00
        SHORT_DATE      = "d", -- 28/11/2018
        LONG_DATE       = "D", -- 28 November 2018
        SHORT_DATE_TIME = "f", -- 28 November 2018 09:01
        LONG_DATE_TIME  = "F", -- Wednesday, 28 November 2018 09:01
        RELATIVE_TIME   = "R", -- 3 years ago
    },

    HEADER_LEVELS = {
        TINY    = -1,
        DEFAULT =  0,
        BIG     =  1,
        MEDIUM  =  2,
        SMALL   =  3,
    }
}

--------------------------------
-- [[ Functions ]]
--------------------------------

--- Escapes all known markdown symbols from the given string.
--- @param s string The string you want remove makrdown from.
--- @return string result String with escaped markdown symbols.
function MARKDOWN.escape(s)
    return (s:gsub(MARKDOWN.SYMBOL_PATTERN, "\\%1"))
end

-- https://some.host/ -> <https://some.host>
-- The result link is clickable but doesn't create the embed when posted.
-- Warning: Use only on real links, not just text!
function MARKDOWN.escape_link_embeds(link)
    return LINK_ESCAPE_PATTERN:format(link)
end

function MARKDOWN.underline(s)
    return s and MARKDOWN.PATTERNS.UNDERLINE:format(s)
end

function MARKDOWN.spoiler(s)
    return s and MARKDOWN.PATTERNS.SPOILER:format(s)
end

--- Formats a string to the codeline format using the discord markdown characters.
--- Sanitizes the string before doing so without removing any visible characters.
--- @return string result The formatted string
function MARKDOWN.codeline(s)
    return s and MARKDOWN.PATTERNS.CODE_LINE:format(tostring(s):gsub("`", "ˋ"))
end

--- @param discordid string
--- @param tp string
function MARKDOWN.mention(discordid, tp)
    return MENTION_PATTERN:format(tp, discordid)
end

--- @param timestamp string|string
--- @param tp string?
function MARKDOWN.timestamp(timestamp, tp)
    tp = tp or MARKDOWN.TIMESTAMP_TYPE.DEFAULT
    local pt = tp == MARKDOWN.TIMESTAMP_TYPE.DEFAULT and TIMESTAMP_PATTERN or TIMESTAMP_TYPE_PATTERN
    return pt:format(timestamp, tp)
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

--- @param s string
--- @return string result The formatted string
function MARKDOWN.quote(s)
    return MARKDOWN.PATTERNS.QUOTE:format(s)
end

--- Formats a string to the bold format using the discord markdown characters
--- @return string result The formatted string
function MARKDOWN.bold(s)
    return MARKDOWN.PATTERNS.BOLD:format(s)
end

function MARKDOWN.strikethrough(s)
    return MARKDOWN.PATTERNS.STRYKETHROUGH:format(s)
end

-- Do not use this with user's input
-- Note: The link parameter can be nil.
function MARKDOWN.hlink(s, link)
    if type(s) ~= "string" or type(link) ~= "string" then
        return s
    end

    return MARKDOWN.PATTERNS.HYPERLINK:format(s, link)
end

function MARKDOWN.listitem(s, indent, index)
    local pt = index and MARKDOWN.PATTERNS.OL_ITEM or MARKDOWN.PATTERNS.UL_ITEM
    return string.rep(" ", indent or 0)..pt:format(s, index);
end

function MARKDOWN.header(s, level)
    level = level or 1
    local prefix = level < 0 and "-" or ""

    -- The space here IS required!
    return prefix..string.rep("#", math.abs(level)).." "..s
end

--------------------------------
-- [[ Return ]]
--------------------------------

return MARKDOWN
