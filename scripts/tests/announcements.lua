
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
    }

    for _, skin in ipairs(skins) do
        d_test_skins_announce(skin)
    end
end

function tests.logger()

end

return tests
