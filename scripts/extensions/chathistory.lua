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

local ChatTypes = ChatTypes
local ChatHistory = ChatHistory
local ChatTypesCount = GetTableSize(ChatTypes)

ChatTypes.DiscordMessage = ChatTypesCount + 1

---------------------------
-- [[ Event Handlers ]]
---------------------------

local function OnChatMessageAdded(message)
    for fn in pairs(ChatHistory.listeners) do
        fn(message)
    end

    if message.type == ChatTypes.Announcement then
        PEARL.EventProcessor:HandleEvent("chat_announcement", message.message, message.m_colour, message.icondata)
    elseif message.type == ChatTypes.SystemMessage then
        PEARL.EventProcessor:HandleEvent("chat_system_message", message.message)
    else
        PEARL.EventProcessor:HandleEvent("chat_message",
            message.sender_guid, message.sender_prefab, message.sender,
            message.message, message.whisper, message.icondata, message.receiver
        )
    end
end

---------------------------
-- [[ Public Methods ]]
---------------------------

--- @param message table<string, any>
function ChatHistory:AddChatMessage(message)
    if type(message.message) ~= "string" then
        return PEARL.error("Attempted to add an invalid chat message!", message.message)
    end

    PEARL.info(string.format("[Say] %s > %s: %s", tostring(message.sender or "UNKNOWN"), message.receiver or "ALL", message.message))

    if not TheNet:IsDedicated() then
        if message.receiver then
            message.sender = STRINGS.PEARL.UI.DM_DESIGNATOR.." "..tostring(message.sender)
        elseif message.whisper then
            message.sender = STRINGS.UI.CHATINPUTSCREEN.WHISPER_DESIGNATOR.." "..tostring(message.sender)
        end
    end

    -- We store local messages on server but we do not return them when requested.
    if self.request_history_start then
        self.request_history_start = self.request_history_start + 1
        if self.request_history_start >= self.MAX_CHAT_HISTORY then
            self.request_history_start = nil
        end
    end

    self.history_start = (self.history_start % self.MAX_CHAT_HISTORY) + 1
    self.max_chat_history_plus_one = self.history[self.history_start]
    self.history[self.history_start] = message

    OnChatMessageAdded(message)

    return message
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

-- Fallback case for invalid announcement types.
local mt = getmetatable(ANNOUNCEMENT_ICONS) or {}
mt.__index = function(self, name)
    return rawget(ANNOUNCEMENT_ICONS, name) or rawget(ANNOUNCEMENT_ICONS, "default")
end

setmetatable(ANNOUNCEMENT_ICONS, mt)

---------------------------
-- [[ Setup ]]
---------------------------

-- No assets on the server
if TheNet:GetIsClient() then
    for _, name in pairs(PEARL.CONSTS.PROFILE_FLAIRS) do
        AddCustomProfileFlair(
            name, PEARL.ASSETS.PROFILE_FLAIRS.ATLAS, name..".tex"
        )
    end
end
