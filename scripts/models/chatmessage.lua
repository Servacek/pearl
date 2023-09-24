--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


-------------------------------------
-- [[ Contants ]]
-------------------------------------

local DEFAULT_MESSAGE_COLOUR = WHITE
local DEFAULT_SENDER_COLOUR  = SAY_COLOR

-------------------------------------
-- [[ Class Declarations ]]
-------------------------------------

--- @param content string?
--- @class ChatMessage
local ChatMessage = Class(function(self, content)
    --- @type string?
    self.content = nil

    --- @type table<string, any>? lazy loaded
    self.author = nil
    --- @type string?
    self.receiver = nil

    --- @type integer One of ChatTypes
    self.type = ChatTypes.Message

    --- @type string
    self.icon = "default"

    --- @type table<number, number>?
    self.colour = DEFAULT_MESSAGE_COLOUR

    self.whisper = false
    self.isemote = false
    self.localonly = false

    --- One of the contants starting with TEXT_FILTER_CTX_...
    --- @type integer?
    self.text_filter_context = nil

    self:SetContent(content)
end)

-------------------------------------
-- [[ Getters ]]
-------------------------------------

function ChatMessage:GetType()
    return self.type
end

function ChatMessage:GetIsWhisper()
    return self.whisper == true
end

function ChatMessage:GetIsEmote()
    return self.isemote == true
end

function ChatMessage:GetAuthor()
    return self.author
end

function ChatMessage:GetContent()
    return self.colour
end

function ChatMessage:GetColour()
    return self.colour
end

function ChatMessage:GetIsLocalOnly()
    return self.localonly == true
end

-------------------------------------
-- [[ Setters ]]
-------------------------------------
-- Always return self in these to support chaining

function ChatMessage:SetContent(content)
    self.content = content

    return self
end

function ChatMessage:SetIsWhisper(whisper)
    self.whisper = whisper

    return self
end

function ChatMessage:SetTextFilterContext(context)
    self.text_filter_context = context

    return self
end

function ChatMessage:SetType(type)
    self.type = type

    return self
end

function ChatMessage:SetIsEmote(isemote)
    self.isemote = isemote

    return self
end

function ChatMessage:SetIsLocalOnly(localonly)
    self.localonly = localonly

    return self
end

function ChatMessage:SetColour(colour)
    self.colour = colour

    return self
end

-- When this is being set the message is implicitly flagged as a DM.
function ChatMessage:SetReceiver(name)
    self.receiver = name
end

function ChatMessage:SetAuthor(name, colour, userid, netid, prefab, guid)
    self.author = {
        name = name,
        colour = colour,
        userid = userid,
        prefab = prefab,
        guid = guid,
        netid = netid,
    }

    return self
end

function ChatMessage:SetIcon(icon)
    self.icon = icon

    return self
end

-------------------------------------
-- [[ Public Methods ]]
-------------------------------------

function ChatMessage:ToTable()
    return {
        type = self.type,
        sender = self.author and self.author.name,
        sender_netid = self.author and self.author.netid,
        sender_userid = self.author and self.author.userid,
        sender_guid = self.author and self.author.guid,
        sender_prefab = self.author and self.author.prefab,
        receiver = self.receiver,
        message = self.content,
        text_filter_context = self.text_filter_context,
        localonly = self.localonly,
        m_colour = self.colour or DEFAULT_MESSAGE_COLOUR,
        s_colour = self.author and self.author.colour or DEFAULT_SENDER_COLOUR,
        icondata = self.icon,
        whisper = self.whisper,
    }
end

--- @return string? json, table data
function ChatMessage:ToJson()
    local data = self:ToTable()
    local _, jsonstr = pcall(json.encode, data)

    return jsonstr, data
end

-------------------------------------
-- [[ Return ]]
-------------------------------------

return ChatMessage
