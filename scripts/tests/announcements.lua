--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local Message = PEARL.loadfile("libraries/discordapi/models/message")


local tests = {}

function tests.skin_announce_test()
    local skins = {
        "legs_wickerbottom_yule",
        "legs_swing_pants_navy_midnight",
        "kitten_black",
        "hand_winona_pirate",
        "emoji_tophat",
        "emote_dance_step",
        "cane_candycane",
        "profileflair_anchor_nautical",
        "mysterybox_ice_4",
    }

    for _, skin in ipairs(skins) do
        d_test_skins_announce(skin)
    end
end

function tests.logger()

end

function tests.mentions()
    PEARL.DiscordLogger:LogStringRaw("@everyone MENTION OFF BY DEFAULT", nil, true)
    PEARL.DiscordLogger:GetBufferedMessage():SetAllowedMentionTypes({
        Message.MENTION_TYPES.EVERYONE
    })
    PEARL.DiscordLogger:LogStringRaw("@everyone MENTION ON", nil, true)
    PEARL.DiscordLogger:LogStringRaw("@everyone MENTION OFF", nil, true)
        PEARL.DiscordLogger:GetBufferedMessage():SetAllowedMentionTypes({
        Message.MENTION_TYPES.EVERYONE
    })
    PEARL.DiscordLogger:LogStringRaw("@everyone MENTION ON", nil, true)
end

return tests
