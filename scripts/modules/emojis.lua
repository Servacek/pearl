--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


require("fonthelper")

local Emoji = require("util/emoji")
local WordPredictor = require("util/wordpredictor")

local ClientEmojis = PEARL.loadfile("libraries/clientemojimanager")

--------------------------------
-- [[ Constants ]]
--------------------------------

local DELIM = PEARL.CONSTS.DELIMS.EMOJI
local PATTERN = DELIM.."([%S]+)"..DELIM

local EMOJI_USED_PATTERN = "[\243][\176][\144-\191][\128-\191]"

local DISCORD_EMOJIS = PEARL.FONTS.CUSTOM.NAMES.DISCORD_EMOJIS

--------------------------------
-- [[ Setup ]]
--------------------------------

table.insert(DEFAULT_FALLBACK_TABLE, 1, DISCORD_EMOJIS)
table.insert(DEFAULT_FALLBACK_TABLE_OUTLINE, 1, DISCORD_EMOJIS)

-- Handle duplicates
for _, data in pairs(EMOJI_ITEMS) do
    local name = data.input_name
    while PEARL.EMOJIS.DISCORD[name] ~= nil do
        name = name.."_"
    end

    PEARL.EMOJIS.DISCORD[name] = PEARL.EMOJIS.DISCORD[data.input_name]
    PEARL.EMOJIS.DISCORD[data.input_name] = nil
end

--- @TODO: Rework this for the new beta.
--- If the player already uses some mod to add icons, the icons added by the mod will be overriden.
-- PEARL.AddSimPostInit(function()
--     local apply = PEARL.GameInstParams:GetModParam("font_apply")
--     if apply == false then
--         return
--     end

--     -- Doesn't need the font to be loaded.
--     TheSim:UnloadFont(DISCORD_EMOJIS)

--     -- Make sure the font assets are loaded.
--     local Assets = {}
--     AddFontAssets(Assets, PEARL.FONTS.CUSTOM.ASSETS)
--     local FontsPrefab = Prefab(PEARL.FONTS_PREFAB, nil, Assets)
--     TheSim:UnloadPrefabs({PEARL.FONTS_PREFAB})
-- 	RegisterSinglePrefab(FontsPrefab)
-- 	TheSim:LoadPrefabs({PEARL.FONTS_PREFAB})

--     TheSim:LoadFont(PEARL.MODROOT.."fonts/discord_emojis.zip", DISCORD_EMOJIS, true)
--     for _, font in pairs(FONTS) do
--         if font.fallback and font.fallback ~= "" then
--             -- Reload the font fallbacks to apply the changes.
--             TheSim:SetupFontFallbacks(font.alias, font.fallback)
--         end
--     end

--     PEARL.GameInstParams:SetModParam("font_apply", false)
-- end)

--------------------------------
-- [[ Autocomplete ]]
--------------------------------

local function EmojifyString(s)
    return s:gsub(PATTERN, PEARL.EMOJIS.DISCORD)
end

PEARL.OverrideReturnValue(Emoji, "GetWordPredictionDictionary", function(data)
    for name, _ in pairs(PEARL.EMOJIS.DISCORD) do
        table.insert(data.words, name)
    end

    local _GetDisplayString
    _GetDisplayString = PEARL.OverrideValue(data, "GetDisplayString", function(word, ...)
        local custom_emote = PEARL.EMOJIS.DISCORD[word]
        if custom_emote then
            return custom_emote.." "..data.delim..word..data.postfix
        else
            return _GetDisplayString(word, ...)
        end
    end)

    return data
end)

local _Say
_Say = PEARL.OverrideUserdataValue("Say", function(self, message, ...)
    if type(message) == "string" then
        message = EmojifyString(message)
    end

    local needs_saving = false
    for match in message:gmatch("[\243][\176][\128-\191][\128-\191]") do
        local emoji_name = PEARL.EMOJIS.UTF_TO_NAME[match]
        if emoji_name then
            ClientEmojis:OnEmojiUsed(match, emoji_name)
            needs_saving = true
        end
    end

    if needs_saving then
        ClientEmojis:SavePersistentData()

        PEARL.EventProcessor:HandleEvent("emojis_used")
    end

    return _Say(self, message, ...)
end, TheNet)

PEARL.AddClassPostConstruct("screens/chatinputscreen", function(self)
    PEARL.AddClassFunctionPostCall("OnTextInput", function(res, self, char)
        if char ~= DELIM or res[1] ~= true then
            return
        end

        self:SetString(EmojifyString(self:GetString()))
    end, self.chat_edit, true)

    if self.chat_edit.prediction_widget then
        PEARL.AddClassFunctionPostCall("ResolvePrediction", function(res)
            local new_text = res[1]
            if new_text then
                res[1] = EmojifyString(new_text)
            end
        end, self.chat_edit.prediction_widget, true)
    end
end)
