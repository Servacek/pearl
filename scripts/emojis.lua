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

--------------------------------
-- [[ Constants ]]
--------------------------------

local DELIM = PEARL.CONSTS.DELIMS.EMOJI
local PATTERN = DELIM.."([%S]+)"..DELIM

--------------------------------
-- [[ Setup ]]
--------------------------------

local DISCORD_EMOJIS = PEARL.FONTS.CUSTOM.NAMES.DISCORD_EMOJIS

table.insert(DEFAULT_FALLBACK_TABLE, 1, DISCORD_EMOJIS)
table.insert(DEFAULT_FALLBACK_TABLE_OUTLINE, 1, DISCORD_EMOJIS)

-- Handle duplicates
for _, data in pairs(EMOJI_ITEMS) do
    local name = data.input_name
    while PEARL.EMOTES.CUSTOM_GAME[name] ~= nil do
        name = name.."_"
    end

    PEARL.EMOTES.CUSTOM_GAME[name] = PEARL.EMOTES.CUSTOM_GAME[data.input_name]
    PEARL.EMOTES.CUSTOM_GAME[data.input_name] = nil
end

--- If the player already uses some mod to add icons, the icons added by the mod will be overriden.
-- PEARL.AddSimPostInit(function()
--     -- local apply = PEARL.GameInstParams:GetModParam("font_apply")
--     -- if apply == false then
--     --     return
--     -- end

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
--     -- for _, font in pairs(FONTS) do
--     --     if font.fallback and font.fallback ~= "" then
--     --         -- Reload the font fallbacks to apply the changes.
--     --         TheSim:SetupFontFallbacks(font.alias, font.fallback)
--     --     end
--     -- end

--     --PEARL.GameInstParams:SetModParam("font_apply", false)
-- end)

--------------------------------
-- [[ Autocomplete ]]
--------------------------------

local function EmojifyString(s)
    return s:gsub(PATTERN, PEARL.EMOTES.CUSTOM_GAME)
end

PEARL.OverrideReturnValue(Emoji, "GetWordPredictionDictionary", function(data)
    for name, _ in pairs(PEARL.EMOTES.CUSTOM_GAME) do
        table.insert(data.words, name)
    end

    local _GetDisplayString
    _GetDisplayString = PEARL.OverrideValue(data, "GetDisplayString", function(word, ...)
        local custom_emote = PEARL.EMOTES.CUSTOM_GAME[word]
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

    return _Say(self, message, ...)
end, TheNet)

-- PEARL.AddClassPostConstruct("screens/chatinputscreen", function(self)
--     PEARL.AddClassFunctionPostCall("OnTextInput", function(res, self, char)
--         if char ~= DELIM or res[1] ~= true then
--             return
--         end

--         self:SetString(EmojifyString(self:GetString()))
--     end, self.chat_edit, true)

--     if self.chat_edit.prediction_widget then
--         PEARL.AddClassFunctionPostCall("ResolvePrediction", function(res)
--             local new_text = res[1]
--             if new_text then
--                 res[1] = EmojifyString(new_text)
--             end
--         end, self.chat_edit.prediction_widget, true)
--     end
-- end)
