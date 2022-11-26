--[[
    Represents a discord message object. Used as a dataclass which is being
    converted to a json string and sent via the REST API to discord.

    Notes:
        - MAX_CHAT_INPUT_LENGTH = 150
        - string.urf8len -> returns the
--]]

local PEARL = PEARL
local table = table
local json, bit = json, bit
local pcall = pcall

-- Userdata object which represents a discord message
-- A message object can contain multiple log lines
--- @param content string? The content of the initial logline
local Message = Class(function(self, content)
    -- Create the table only when it's needed
    -- for embed only messages
    -- Contains the already built loglines
    --- @type table?
    self._loglines = nil

    self._content = nil
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
    self._allowed_mentions = {parse = false}

    -- --- @type function?
    -- self._postconstructfn = nil
    -- self._postconstructfn_args = nil

    if content then
        self:AddLogLine(content)
    end
end)

------------------------------------------
-- [[ Constants ]]
------------------------------------------

Message.CONTENT_LENGHT_LIMIT    = 2000
Message.EMBED_COUNT_LIMIT       = 10
Message.JSON_STRING             = [[
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
    EVERYONE    = "everyone",
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

------------------------------------------
-- [[ Getters ]]
------------------------------------------

function Message:GetLength()
    if not self._loglines then
        return 0
    end

    local length = 0
    for _, logline in ipairs(self._loglines) do
        length = #logline
    end

    return length
end

function Message:AcceptsLogLines()
    return not self._loglines or #self._loglines < PEARL.CONSTS.DISCORD.MAX_LOGLINE_COUNT
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

function Message:GetContent()
    return self:HasLogLines() and table.concat(self._loglines, "\n")
    or self._content
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
    if not (embed and self:AcceptsEmbeds()) then
        return
    end

    if not self._embeds then
        self._embeds = {}
    end

    self._embeds[#self._embeds + 1] = embed

    return self
end

--- @param logline LogLine The logline to be added.
--- @return Message? self Return self on success, nil on error.
function Message:AddLogLine(logline)
    if not (logline and self:AcceptsLogLines() and not self._content) then
        return
    end

    -- Verify, that by adding the logline we will not exceed the content length limit.
    if (self:GetLength() + logline:GetLength()) > Message.CONTENT_LENGHT_LIMIT - 100 then
        return
    end

    if not self._loglines then
        self._loglines = {}
    end

    self._loglines[#self._loglines + 1] = logline:Build()

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

--- @NOTE Do not allow changing the mention type
-- function Message:AllowMentionsForType(mention_type)
--     if not self.allowed_mentions then
--         self.allowed_mentions = {}
--     end

--     if not self.allowed_mentions.parse then
--         self.allowed_mentions.parse = {}
--     end

--     table.insert(self.allowed_mentions.parse, mention_type)

--     return self
-- end

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

function Message:SetPostConstructFn(fn, ...)
    self._postconstructfn = fn
    self._postconstructfn_args = ...

    return self
end

------------------------------------------
-- [[ Public Methods ]]
------------------------------------------

function Message:ToTable()
    return {
        content = self:GetContent(),
        embeds = self._embeds,
        flags = self._flags,
        -- Always disable everyone ping
        allowed_mentions = self._allowed_mentions,
    }
end

--- Converts the self message object to an json string.
--- @return boolean success true on success otherwise false
--- @return any result the json result on success otherwise the error message
function Message:ToJson()
    -- Use encode_compliant for discord compatible json strings
    return pcall(json.encode_compliant, self:ToTable())
end

function Message:Construct(force)
    if not self._postconstructfn then
        return PEARL.error("Message", "_postconstructfn is a nil value!")
    end

    self._postconstructfn(self, force, self._postconstructfn_args)
end

-- Allows reuse of the message object (when used as a buffer)
function Message:Clear()
    cleartable(self._loglines)
    cleartable(self._embeds)
    cleartable(self._allowed_mentions)

    self._flags = nil
    self._allowed_mentions.parse = false
end

return Message
