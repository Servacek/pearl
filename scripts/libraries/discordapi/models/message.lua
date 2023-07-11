--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--[[
    Represents a discord message object. Used as a dataclass which is being
    converted to a json string and sent via the REST API to discord.

    Notes:
        - MAX_CHAT_INPUT_LENGTH = 150
        - string.urf8len
        - Looks like files are not able to be sent using the default request body.
--]]


--- @type utf8
local utf8 = PEARL.loadfile("libraries/utf8")

-------------------------------------
-- [[ Global Localization ]]
-------------------------------------

local PEARL = PEARL
local table = table
local json, bit = json, bit
local pcall = pcall
local type = type

local shallowcopy = shallowcopy
local cleartable = cleartable
local iclear = table.iclear

-------------------------------------
-- [[ Constants ]]
-------------------------------------

local CROP_POSTFIX = "..."

-------------------------------------
-- [[ Class Declarations ]]
-------------------------------------

-- A message object can contain multiple log lines
--- @param content string? The content of the message
--- @class Message
local Message = Class(function(self, content)
    -- Create the table only when it's needed
    -- for embed only messages
    -- Contains the already built loglines
    --- @type table?
    self._loglines = nil

    --- @type string?
    self._content = content
    -- This table is rarely used so create it
    -- only when it's needed
    --- @type table?
    self._embeds = nil

    --- @type integer?
    self._flags = nil
    -- We don't support these yet
    --self.attachments = {}

    -- All mentions are disabled by default
    -- Posibble categories:
    --    parse,
    --    roles,
    --    users,
    -- Settings parse to false disabled the @everyone and @here ping
    -- Therefore this should be always a table.
    --- @type table<string, table>
    self._allowed_mentions = shallowcopy(self.DEFAULT_ALLOWED_MENTIONS)
end)

------------------------------------------
-- [[ Static ]]
------------------------------------------

-- Note: Discord's limit is based on characters not bytes.
-- So use utf8len to determine the actual number of characters.
Message.MAX_CONTENT_LENGTH_LIMIT        = 2000
Message.CONTENT_LENGTH_LIMIT_RESERVE    = 100
Message.CONTENT_LENGHT_LIMIT            = Message.MAX_CONTENT_LENGTH_LIMIT - Message.CONTENT_LENGTH_LIMIT_RESERVE
Message.EMBED_COUNT_LIMIT               = 10
Message.JSON_STRING                     = [[
    {
        "content": "%q",
        "embeds": "%q",
        "flags": "%q",
        "allowed_mentions:" "%q"
    }
]]
Message.MENTION_TYPES           = {
    USERS       = "users",
    ROLES       = "roles",
    EVERYONE    = "everyone", -- @everyone and @here
}

Message.FLAGS                   = {
    CROSSPOSTED	            = bit.lshift(1, 0), -- this message has been published to subscribed channels (via Channel Following)
    IS_CROSSPOST	        = bit.lshift(1, 1), -- this message originated from a message in another channel (via Channel Following)
    SUPPRESS_EMBEDS	        = bit.lshift(1, 2), -- do not include any embeds when serializing this message
    SOURCE_MESSAGE_DELETED	= bit.lshift(1, 3), -- the source message for this crosspost has been deleted (via Channel Following)
    URGENT	                = bit.lshift(1, 4), -- this message came from the urgent message system
    HAS_THREAD	            = bit.lshift(1, 5),	-- this message has an associated thread, with the same id as the message
    EPHEMERAL	            = bit.lshift(1, 6),	-- this message is only visible to the user who invoked the Interaction
    LOADING	                = bit.lshift(1, 7),	-- this message is an Interaction Response and the bot is "thinking"
}

Message.DEFAULT_ALLOWED_MENTIONS = {
    parse = {}
}

------------------------------------------
-- [[ Getters ]]
------------------------------------------

function Message:GetLength()
    if not self._loglines then
        return 0
    end

    local length = self._content and string.utf8len(self._content) or 0
    for i = 1, #self._loglines do
        length = string.utf8len(self._loglines[i])
    end

    return length
end

function Message:AcceptsEmbeds()
    return not self._embeds or #self._embeds < PEARL.CONSTS.DISCORD.MAX_EMBED_COUNT
end

function Message:HasLogLines()
    return self._loglines ~= nil and #self._loglines > 0
end

function Message:HasEmbed()
    return self._embeds ~= nil and #self._embeds > 0
end

function Message:HasContent()
    -- Maybe just blank characters are not counted as a content?
    return self._content ~= nil and #self._content > 0
end

function Message:GetFreeCharCount()
    return Message.CONTENT_LENGHT_LIMIT - self:GetLength()
end

function Message:GetContent()
    return self:HasLogLines() and table.concat(self._loglines, "\n")
    or self._content
end

-- A Message is valid if it has at least one of the main attributes:
-- - Content
-- - File
-- - Embed
function Message:IsValid()
    return self:HasLogLines() or self:HasContent() or self:HasEmbed()
end

function Message:GetEmbed(index)
    return self._embeds and self._embeds[index]
end

------------------------------------------
-- [[ Setters ]]
------------------------------------------

function Message:SetContent(content)
    self._content = content

    return self
end

--- @param embed Embed The logline to be added.
--- @return Message? self Return self on success, nil on error.
function Message:AddEmbed(embed)
    if not self:AcceptsEmbeds() then
        return PEARL.error("Attempted to add more than", PEARL.CONSTS.DISCORD.MAX_EMBED_COUNT, "embeds to a message.")
    end

    if not self._embeds then
        self._embeds = {} -- Leave allocation on lua for small messages.
    end

    self._embeds[#self._embeds + 1] = embed

    return self
end

--- @param logline LogLine The logline to be added.
--- @return Message? self Return self on success, nil on error.
function Message:AddLogLine(logline)
    if not self._loglines then
        self._loglines = {} -- Leave allocation on lua for small messages.
    end

    self._loglines[#self._loglines + 1] = logline
        :Build()
        :ltake(self:GetFreeCharCount(), nil, CROP_POSTFIX)

    return self
end

function Message:AddFlag(flag)
    if not self._flags then
        self._flags = flag
    else
        self._flags = bit.bor(self._flags, flag)
    end

    return self
end

--- @NOTE: Careful here.
function Message:SetAllowedMentionTypes(mention_types)
    if type(self._allowed_mentions) ~= "table" then
        self._allowed_mentions = {}
    end

    self._allowed_mentions.parse = mention_types

    return self
end

function Message:AllowMentionsForRole(roleid)
    if not self._allowed_mentions then
        self._allowed_mentions = {}
    end

    if not self._allowed_mentions.roles then
        self._allowed_mentions.roles = {roleid}
        return self
    end

    if #self._allowed_mentions.roles <= PEARL.CONSTS.DISCORD.MAX_ROLE_MENTIONS then
        table.insert(self._allowed_mentions.roles, tostring(roleid))
    end

    return self
end

function Message:AllowMentionsForUser(userid)
    if not self._allowed_mentions then
        self._allowed_mentions = {}
    end

    if not self._allowed_mentions.users then
        self._allowed_mentions.users = {userid}
        return self
    end

    if #self._allowed_mentions.users <= PEARL.CONSTS.DISCORD.MAX_USER_MENTIONS then
        table.insert(self._allowed_mentions.users, tostring(userid))
    end

    return self
end

function Message:ClearAllowedMentions()
    local parse = self._allowed_mentions and self._allowed_mentions.parse
    cleartable(self._allowed_mentions)

    self._allowed_mentions.parse = parse and iclear(parse) or {}
end

------------------------------------------
-- [[ Public Methods ]]
------------------------------------------

function Message:ToTable()
    -- Send as few data here as possible since for every
    -- character we need to send one byte of data.
    return {
        content = self:GetContent(),
        embeds = not table.empty(self._embeds) and self._embeds or nil,
        flags = self._flags,
        allowed_mentions = not table.empty(self._allowed_mentions) and self._allowed_mentions or nil,
    }
end

--- Converts the self message object to an json string.
--- @return boolean success true on success otherwise false
--- @return any result the json result on success otherwise the error message
function Message:ToJson()
    local success, result = pcall(json.encode_compliant, self:ToTable())
    return success, success and utf8.decode_string(result) or result
end

------------------------------------------
-- [[ Return ]]
------------------------------------------

return Message
