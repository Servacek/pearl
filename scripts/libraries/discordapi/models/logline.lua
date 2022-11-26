
local PEARL = PEARL
local os, string = os, string

local MARKDOWN = require("libraries/markdown")

------------------------------------------
-- [[ Constants ]]
------------------------------------------

-- A text representation of an discord emoji, ex. '<:refresh:997496890625118250>'
-- 32 characters reserved for ID and prefix/postfix stuff
local MAX_ICON_LENGTH = PEARL.CONSTS.DISCORD.MAX_EMOJI_NAME_LENGTH + 32
local MAX_CONTENT_LENGTH = 1800
local MAX_TAG_LENGTH = 32
-- header = tag + icon
local MAX_HEADER_LENGTH = MAX_TAG_LENGTH + MAX_ICON_LENGTH
local MAX_TIMESTAMP_LENGTH = 12

local TIMESTAMP_TEMPLATE = MARKDOWN.bold(MARKDOWN.codeline("[%H:%M:%S]:"))
-- timestamp and content
local TEMPLATE = (PEARL.CONFIG.DEBUG_MODE and
    "%s ["..MARKDOWN.codeline(string.upper(PEARL.GetShardName())).."] %s" or "%s %s"
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
local LogLine = Class(function(self, content)
    self._content = nil
    self._icon = nil
    self._tag = nil

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
-- [[ Meta Methods ]]
------------------------------------------

function LogLine:__tostring()
    return "<LogLine "..self._timestamp..">"
end

------------------------------------------
-- [[ Getter Methods ]]
------------------------------------------

function LogLine:GetHeaderLength()
    return (self._tag and #self._tag + 1 or 0) + (self._icon and #self._icon + 1 or 0) + 1
end

function LogLine:GetLength()
    return MAX_TIMESTAMP_LENGTH + self:GetHeaderLength() + #self._content
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

------------------------------------------
-- [[ Setter Methods ]]
------------------------------------------

--- @TODO: The length of the content should
function LogLine:SetContent(content)
    if type(content) == "string" and #content > 0 then
        self._content = content:take(MAX_CONTENT_LENGTH)
    end

    return self
end

function LogLine:SetHeader(tag, icon)
    if type(tag) == "string" and #tag < MAX_TAG_LENGTH then
        self._tag = STRINGS.PEARL.LOGS.TAG:format(tag)
    end

    if type(icon) == "string" and #icon < MAX_ICON_LENGTH then
        self._icon = icon
    end

    return self
end

-- For long texts divided into multiple loglines
function LogLine:RemoveTimestamp()
    self._timestamp = nil

    return self
end

------------------------------------------
-- [[ Public Methods ]]
------------------------------------------

-- Returns a discord compatible string
function LogLine:Build()
    -- We do not have a header
    if not (self._icon or self._tag) then
        if PEARL.CONFIG.DEBUG_MODE then
            TEMPLATE = "%s ["..MARKDOWN.codeline(string.upper(PEARL.GetShardName())).."] %s"
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

return LogLine
