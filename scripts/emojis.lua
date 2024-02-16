--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local Emoji = require("util/emoji")

-- local DISCORD_EMOJIS = "discord_emojis"
-- local DISCORD_EMOJIS_PACKAGE = PEARL.ENV.MODROOT.."fonts/discord_emojis.zip"

-- local TWEMOJI = "twemoji"

-- table.insert(DEFAULT_FALLBACK_TABLE, 1, TWEMOJI)
-- table.insert(DEFAULT_FALLBACK_TABLE_OUTLINE, 1, TWEMOJI)
-- table.insert(FONTS, { filename = PEARL.ENV.MODROOT.."fonts/twemoji.zip", alias = TWEMOJI, disable_color = true })
-- table.insert(DEFAULT_FALLBACK_TABLE, 1, DISCORD_EMOJIS)
-- table.insert(DEFAULT_FALLBACK_TABLE_OUTLINE, 1, DISCORD_EMOJIS)
-- table.insert(FONTS, { filename = DISCORD_EMOJIS_PACKAGE, alias = DISCORD_EMOJIS, disable_color = true })

PEARL.OverrideReturnValue(Emoji, "GetWordPredictionDictionary", function(data)
    for name, _ in pairs(PEARL.EMOTES.CUSTOM_GAME) do
        table.insert(data.words, name)
    end

    PEARL.OverrideValue(data, "GetDisplayString", function(word)
        local emote = PEARL.EMOTES.CUSTOM_GAME[word]
        return emote and (emote.." "..data.delim..word..data.postfix) or word
    end)

    return data
end)
