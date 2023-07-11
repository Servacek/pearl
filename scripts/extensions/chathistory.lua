--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--- @type ChatHistoryManager
local ChatTypes = ChatTypes
local ChatTypesCount = GetTableSize(ChatTypes)

ChatTypes.DiscordMessage = ChatTypesCount + 1

--- Add support for changing the colour of the text.
PEARL.OverrideReturnValue(ChatHistory, "GenerateChatMessage", function(chat_message, type, sender_userid, sender_netid, sender_name, message, colour)
    chat_message.m_colour = colour and colour.message or chat_message.m_colour or SAY_COLOR

    return chat_message
end, true)

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
-- [[ Setup ]]
---------------------------

AddCustomProfileFlair("dft_discord", "images/dft_flairs.xml", "dft_discord.tex")
