--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local Emoji = require("util/emoji")

--------------------------------
-- [[ Constants ]]
--------------------------------

local FONT_ASSET_PATH = PEARL.MODROOT.."fonts/%s.zip"
local ANIM_ASSET_PATH = PEARL.MODROOT.."anim/%s.zip"

local CUSTOM_EMOJI_FONTS = {}
local FONT_FALLBACK_TABLES = {
    DEFAULT_FALLBACK_TABLE,
    DEFAULT_FALLBACK_TABLE_OUTLINE
}

--------------------------------
-- [[ Assets ]]
--------------------------------

for pack_name, enabled in pairs(PEARL.CONFIG.CUSTOM_EMOJI_PACKS) do
    if enabled == true then
        local filepath = FONT_ASSET_PATH:format(pack_name)
        local font_table = {filename = filepath, alias = pack_name, disable_color = true}

        table.insert(CUSTOM_EMOJI_FONTS, font_table)
        table.insert(GLOBAL.FONTS, font_table)

        table.insert(PEARL.ENV.Assets, Asset("FONT", filepath))

        if PEARL.EMOJIS.IsEmojiPackAnimated(pack_name) then
            for emoji_name, _ in pairs(PEARL.EMOJIS.PACK_CHAR_MAP[pack_name]) do
                table.insert(PEARL.ENV.Assets, Asset("ANIM", ANIM_ASSET_PATH:format(emoji_name)))
            end
        end
    end
end

--------------------------------
-- [[ Autocomplete ]]
--------------------------------

--- TODO: Modify the EMOJI_ITEMS table directly?
--- This would require to modify the TheInventory which is kinda... meh
PEARL.OverrideReturnValue(Emoji, "GetWordPredictionDictionary", function(data)
    for _, char_map in pairs(PEARL.EMOJIS.PACK_CHAR_MAP) do
        table.join(data.words, table.keys(char_map))
    end

    local _GetDisplayString
    _GetDisplayString = PEARL.OverrideValue(data, "GetDisplayString", function(word, ...)
        local custom_emote = PEARL.EMOJIS.ALL[word]
        if custom_emote then
            return custom_emote.." "..data.delim..word..data.postfix
        else
            return _GetDisplayString(word, ...)
        end
    end)

    return data
end)

--------------------------------
-- [[ Setup ]]
--------------------------------

PEARL.AddSimPostInit(function()
    for _, font_table in ipairs(CUSTOM_EMOJI_FONTS) do
        for _, fallback_table in ipairs(FONT_FALLBACK_TABLES) do
            --- Insert only right before the fonts are loaded so the fallbacks cannot be used unloaded.
            table.insert(fallback_table, 1, font_table.alias)
        end
    end

    --- Reload all fonts to apply the changes.
    --- @TROUBLESHOOTING:
    --- Possible causes of a crash:
    --- - Assets for the provided fonts are not loaded.
    LoadFonts()
end)
