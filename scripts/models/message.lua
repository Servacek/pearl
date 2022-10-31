require("metaclass")

local SUB = SUB
local CONTENT_LENGHT_LIMIT = SUB.CONSTANTS.CONTENT_LENGHT_LIMIT
local EMBED_COUNT_LIMIT = SUB.CONSTANTS.EMBED_COUNT_LIMIT

------------------------------------------

-- Userdata object which represents a discord message
local Message = MetaClass(function(self, str, icon)
    self.strings_lenght = 0
    self.strings = {}
    self.embeds = {}
    self.allowed_mentions = { -- All mentions are disabled by default
        parse={},
        roles={},
        users={},
    }

    -- The original content
    self:SetString(str, icon)
end)

------------------------------------------
-- [[ Meta Methods ]]
------------------------------------------

function Message:__len()
    return self.strings_lenght
end

------------------------------------------

function Message:AddString(str)
    if str and #str > 0 then
        self.strings[#self.strings + 1] = str
        self.strings_lenght = self.strings_lenght + #str
    end
end

function Message:AddEmbed(embed)
    if embed ~= nil then
        self.embeds[#self.embeds + 1] = embed
    end
end

function Message:SetString(str, icon)
    if str and #str > 0 then
        if icon then
            str = icon.." "..str
        end

        self:AddString(string.timestampize(str))
    end
end

function Message:CanMerge(message)
    return message ~= nil and message:IsValid() and (#self + #message) < CONTENT_LENGHT_LIMIT
    and (#self.embeds + #message.embeds) <= EMBED_COUNT_LIMIT
end

function Message:Concatenate(message)
    if not self:CanMerge(message) then
        return
    end

    if message:HasContent() then
        for i = 1, #message.strings do
            self:AddString(message.strings[i])
        end
    end

    if message:HasEmbed() then
        self.embeds = ConcatArrays(self.embeds, message.embeds)
    end
end

function Message:HasContent()
    return self.strings_lenght ~= nil and self.strings_lenght > 0
end

function Message:HasEmbed()
    return self.embeds ~= nil and #self.embeds > 0
end

function Message:ToString()
    return table.concat(self.strings, "\n")
end

function Message:ToTable()
    return {
        content = self:ToString(),
        embeds = self.embeds,
        allowed_mentions = self.allowed_mentions,
    }
end

--- Converts the self message object to an json string.
--- @return success boolean true on success otherwise false
--- @return result any the json result on success otherwise the error message
function Message:ToJson()
    return pcall(json.encode_compliant, self:ToTable())
end

function Message:IsValid()
    return (self:HasContent() or self:HasEmbed())
    and #self < CONTENT_LENGHT_LIMIT and #self.embeds <= EMBED_COUNT_LIMIT
end

--------------------------

function Message:AllowMentionsForType(mention_type)
    table.insert(self.allowed_mentions.parse, mention_type)
end

function Message:AllowMentionsForRoles(role_ids)
    ConcatArrays(self.allowed_mentions.roles, role_ids)
end

function Message:AllowMentionsForUsers(user_ids)
    ConcatArrays(self.allowed_mentions.users, user_ids)
end

--------------------------

Message.MENTION_TYPES = {
    USERS       = "users",
    ROLES       = "roles",
    EVERYONE    = "everyone",
}

return Message