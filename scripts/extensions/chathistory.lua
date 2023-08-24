--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


require("chathistory")

--- @type ChatHistoryManager
local ChatTypes = ChatTypes
local ChatHistory = ChatHistory
local ChatTypesCount = GetTableSize(ChatTypes)

ChatTypes.DiscordMessage = ChatTypesCount + 1

---------------------------
-- [[ Constats ]]
---------------------------

local DEFAULT_CHAT_MESSAGE_COLOR = WHITE

---------------------------
-- [[ Public Methods ]]
---------------------------

function ChatHistory:GetColourForMessage(s_colour, m_colour)
    s_colour = type(s_colour) == "number" and {PEARL.DecimalToPercent(s_colour)} or s_colour
    m_colour = type(m_colour) == "number" and {PEARL.DecimalToPercent(m_colour)} or m_colour

    s_colour = s_colour or DEFAULT_CHAT_MESSAGE_COLOR
    s_colour.message = m_colour

    return s_colour
end

---------------------------
-- [[ UI ]]
---------------------------

local CustomProfileFlairs = {}

local function AddCustomProfileFlair(name, atlas, tex)
    CustomProfileFlairs[name] = {
        atlas = atlas,
        tex = tex,
    }
end

local function GetCustomFlaireAtlasAndTex(name)
    local flaire = CustomProfileFlairs[name]
    return (flaire and flaire.atlas), (flaire and flaire.tex)
end

local _GetProfileFlairAtlasAndTex
_GetProfileFlairAtlasAndTex = PEARL.OverrideValue(_G, "GetProfileFlairAtlasAndTex", function(item_key)
    local atlas, tex = GetCustomFlaireAtlasAndTex(item_key)
    if atlas and tex then
        return atlas, tex
    end

    return _GetProfileFlairAtlasAndTex(item_key)
end)

---------------------------
-- [[ Overrides ]]
---------------------------

--- Add support for changing the colour of the text.
PEARL.OverrideReturnValue(ChatHistory, "GenerateChatMessage", function(chat_message, self, type, sender_userid, sender_netid, sender_name, message, colour)
    chat_message.m_colour = colour and colour.message or chat_message.m_colour or SAY_COLOR

    return chat_message
end, true)

-- Fallback case for invalid announcement types.
local mt = getmetatable(ANNOUNCEMENT_ICONS) or {}
mt.__index = function(self, name)
    return rawget(ANNOUNCEMENT_ICONS, name) or rawget(ANNOUNCEMENT_ICONS, "default")
end

setmetatable(ANNOUNCEMENT_ICONS, mt)

---------------------------
-- [[ Setup ]]
---------------------------

AddCustomProfileFlair("dft_discord", "images/dft_flairs.xml", "dft_discord.tex")
