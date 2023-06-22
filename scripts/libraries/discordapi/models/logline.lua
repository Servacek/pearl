--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local os, string = os, string

local MARKDOWN = PEARL.loadfile("libraries/markdown")

------------------------------------------
-- [[ Constants ]]
------------------------------------------

-- A text representation of an discord emoji, ex. '<:refresh:997496890625118250>'
-- 32 characters reserved for ID and prefix/postfix stuff
-- Note: Icons contain only ASCII characters. So 1 character == 1 byte.
local MAX_ICON_LENGTH = PEARL.CONSTS.DISCORD.MAX_EMOJI_NAME_LENGTH + 32
local MAX_CONTENT_LENGTH = 1800
local MAX_TAG_LENGTH = 32
-- header = tag + icon
local MAX_HEADER_LENGTH = MAX_TAG_LENGTH + MAX_ICON_LENGTH
local MAX_TIMESTAMP_LENGTH = 12

local TIMESTAMP_TEMPLATE = MARKDOWN.codeline("[%H:%M:%S]:")
-- timestamp and content
local TEMPLATE = (PEARL.CONFIG.DEBUG_MODE and
    "%s ["..MARKDOWN.codeline(string.upper(PEARL.GetShardFancyName())).."] %s" or "%s %s"
)
-- timestamp, (icon OR tag) and content
local TEMPLATE_HEADER_HALF = TEMPLATE.." %s"
-- timestamp, header (icon AND tag) and content
-- Note: Tag should be always before icon
local TEMPLATE_HEADER_FULL = TEMPLATE.." %s %s"

------------------------------------------
-- [[ Definition ]]
------------------------------------------

-- The content parameter should be required for initiliazation
--- @class LogLine
local LogLine = Class(function(self, content)
    self._content = nil
    self._icon = nil
    self._tag = nil
    self._size = self.SIZES.DEFAULT

    -- Timestamp should refer to the creation time of this object
    -- This should not change.
    self._timestamp = os.time()
    self._is_long = false

    --assert(type(self._content) == "string", "Attempted to create a LogLine instance without suppling a valid content.")

    if content then
        self:SetContent(content)
    end
end)

------------------------------------------
-- [[ Contants ]]
------------------------------------------

LogLine.SIZES = {
    DEFAULT = 0,
    BIG     = 1,
    MEDIUM  = 2,
    SMALL   = 3,
}

------------------------------------------
-- [[ Meta Methods ]]
------------------------------------------

function LogLine:__tostring()
    return "<LogLine "..self._timestamp..">"
end

------------------------------------------
-- [[ Getter Methods ]]
------------------------------------------

function LogLine:GetHeaderLength()
    return (self._tag and string.utf8len(self._tag) + 1 or 0) + (self._icon and #self._icon + 1 or 0) + 1
end

function LogLine:GetLength()
    return MAX_TIMESTAMP_LENGTH + self:GetHeaderLength() + string.utf8len(self._content)
end

function LogLine:GetReadableTimestamp()
    if not self._timestamp then
        return ""
    end

    return os.date(TIMESTAMP_TEMPLATE, self._timestamp)
end

function LogLine:GetContent()
    return self._content
end

function LogLine:GetTag()
    return self._tag
end

function LogLine:GetIcon()
    return self._icon
end

function LogLine:GetSize()
    return self._size
end

------------------------------------------
-- [[ Setter Methods ]]
------------------------------------------

function LogLine:SetSize(size)
    self._size = size

    return self
end

function LogLine:SetContent(content)
    if type(content) == "string" and #content > 0 then
        self._content = content
    end

    return self
end

function LogLine:SetTag(tag)
    if type(tag) == "string" then
        self._tag = STRINGS.PEARL.LOGS.TAG:format(tag:ltake(MAX_TAG_LENGTH, nil, "..."))
    end

    return self
end

function LogLine:SetIcon(icon)
    if type(icon) == "string" and #icon < MAX_ICON_LENGTH then
        self._icon = icon
    end

    return self
end

function LogLine:SetHeader(tag, icon)
    self:SetTag(tag)
    self:SetIcon(icon)

    return self
end

-- For long texts divided into multiple loglines
function LogLine:RemoveTimestamp()
    self._timestamp = nil

    return self
end

------------------------------------------
-- [[ Private Methods ]]
------------------------------------------

function LogLine:_BuildString()
    -- We do not have a header
    if not (self._icon or self._tag) then
        if PEARL.CONFIG.DEBUG_MODE then
            TEMPLATE = "%s ["..MARKDOWN.codeline(string.utf8upper(PEARL.GetShardFancyName())).."] %s"
        end

        return TEMPLATE:format(
            self:GetReadableTimestamp(), self._content
        )
    end

    if not (self._icon and self._tag) then
        return TEMPLATE_HEADER_HALF:format(
            self:GetReadableTimestamp(), (self._tag or self._icon), self._content
        )
    end

    return TEMPLATE_HEADER_FULL:format(
        -- tag should be always first
        self:GetReadableTimestamp(), self._tag, self._icon, self._content
    )
end

------------------------------------------
-- [[ Public Methods ]]
------------------------------------------

-- Returns a discord compatible string
function LogLine:Build()
    local str = self:_BuildString()
    if self._size <= self.SIZES.DEFAULT then
        return str
    end

    return MARKDOWN.header(str, self._size)
end

------------------------------------------
-- [[ Return ]]
------------------------------------------

return LogLine
