--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



-- Note: Webhooks and bots in general can use external emojis even from servers they are not in.
-- So these icons should work on all discord servers.

return {
    X = "<:x_:1063767987456315472>",
    CHECK = "<:check:998561107776122900>",
    PING = "<:connection:1064114008698916864>",
    ENABLED = "<:enabled:1071821645427261450>",
    DISABLED = "<:disabled:1071821625470746686>",
    STEAM = "<:steam:1076608091656814643>",
    LOCAL = "<:local:1076609330905878588>",
    GAINS = "<:arrow_up_green:1130590082349400084>",

    PLAYER_PREFABS = {
        -- DST
        wilson =            "<:Wilson:700037170785681479>",
        willow =            "<:Willow:700037117220487228>",
        wolfgang =          "<:Wolfgang:700037355213684827>",
        wendy =             "<:Wendy:700036336962502717>",
        wx78 =              "<:WX_78:700037741915799688>",
        wickerbottom =      "<:Wickerbottom:700036552067252378>",
        woodie =            "<:Woodie:700037430442590359>",
        wes =               "<:Wes:700036508572188693>",
        waxwell =           "<:Maxwell:700036190392418394>",
        wathgrithr =        "<:Wigfrid:700036639040208957>",
        webber =            "<:Webber:700036289822457947>",
        winona =            "<:Winona:700037278533156895>",
        wortox =            "<:Wortox:700035257780666409>",
        warly =             "<:Warly:700036121039732757>",
        wormwood =          "<:Wormwood:700037502869831721>",
        wurt =              "<:Wurt:700037704427110471>",
        walter =            "<:Walter:722146045735469187>",
        wanda =             "<:wanda:885865311105089536>",

        wonkey =            "<:wonkey:988082378541002802>",

        ---------------------------------------------------------
        -- Support for mods that add characters from the DLCS
        -- like Tropical Experience, etc...

        -- Shipwrecked
        wilbur =            "<:wilbur:988081746975272980>",
        woodlegs =          "<:woodlegs:988081763236585522>",

        -- Hamlet
        wagstaff =          "<:wagstaff:988082475727220786>",
        wilba =             "<:wilba:988081734933434368>",
        wheeler =           "<:wheeler:988081715325059083>",

        -- Unknown character
        [""] =              "<:unknown:990652780496695406>",
        unknown =           "<:unknown:990652780496695406>",

        -- Server
        ["server"] =        "<:dedicated:1001104949524041788>",
    },

    LEADERBOARD_PLACES = {
        [1] = "<:1st:1129353293357912105>",
        [2] = "<:2nd:1129353938848723065>",
        [3] = "<:3place:1129348645741924358>",
    },

    PRECIPITATION = {
        ["none"]=           ":sunny:",
        ["rain"]=           ":cloud_rain:",
        ["snow"]=           ":cloud_snow:",
    },

    MOONPHASES = {
        WANNING = {
            ["new"]=            "<:new:1076473832963068017>", --"🌕︎",
            ["quarter"]=        "<:wanning_quarter:1076473860427350097>", --"🌔︎",
            ["half"]=           "<:wanning_half:1076473846959456356>", --"🌓︎",
            ["threequarter"]=   "<:wanning_threequarter:1076473873681358869>", --"🌒︎",
            ["full"]=           "<:full:1076473817087610900>", --"🌑︎",
        },
        WAXING = {
            ["new"]=            "<:new:1076473832963068017>", --"🌕︎",
            ["quarter"]=        "<:waxing_quarter:1076473913174917150>", --"🌖︎",
            ["half"]=           "<:waxing_half:1076473898494869504>", --"🌗︎",
            ["threequarter"]=   "<:waxing_threequarter:1076473928710623364>", --"🌘︎",
            ["full"]=           "<:full:1076473817087610900>", --"🌑︎",
        },
    },

    SERVER_STATE = {
        START       = "<:check:998561107776122900>",
        STOP        = "<:save:998561362710110328>",
        CRASH       = "<:warn:1076451075126734878>",
        PAUSE       = "<:pause:998561335463907459>",
        --RESUME      = "▶️",
        ROLLBACK    = "<:rollback:998561230799253614>",
        SAVE        = "<:save:1071499100752711801>",
        RESTART     = "<:refresh:997496890625118250>",
        CMD_RECV    = "<:clip:1071796523140120577>",
    },

    PLAYER_STATE = {
        CMD_SEND            = "<:clip:1071796523140120577>",
        AUTH                = "<:auth:997498156617056341>",
        CAVE_ENTER          = "<:cave_enter:998568774519230494>",
        CAVE_LEAVE          = "<:cave_leave:998568758647988244>",
        FORCE_DISCONNECTED  = "<:disconnect:1030926979463135313>",
        DROP_ITEMS          = "<:drop:1096807866167480401>",
    },

    SIM_STATE = {
        REGENERATE              = "<:sim:998561317164163172>",
        REGENERATE_COUNT_DOWN   = "<:clock:1060193937379299518>",

        --- @deprecated
        PAUSE       = "<:sim:998561317164163172>",
        RESUME      = "<:sim:998561317164163172>",
    },

    ANNOUNCEMENTS = {
        -- Built in announcements
        ["default"]=            "<:announcement:997492667422351360>",
        ["join_game"]=          "<:join_game:997495868343193650>",
        ["leave_game"]=         "<:leave:1017873541556875264>",
        ["vote"]=               "<:vote:997496719170347090>",
        ["dice_roll"]=          "<:dice_roll:997498033493250168>",
        ["death"]=              "<:death:997497223111790762>",
        ["resurrect"]=          "<:resurrect:997498050178195506>",
        ["kicked_from_game"]=   "<:kicked_from_game:997496806093111416>",
        ["banned_from_game"]=   "<:banned_from_game:997492654914949151>",
        ["mod"]=                "<:mod:997496789735329803>",
        ["skin"]=               "<:skin:997496735754637333>",
        ["item_drop"]=          "<:skin:997496735754637333>",
        ["afk_start"]=          "<:afk_start:997473616604184686>",
        ["afk_stop"]=           "<:afk_stop:997473583410450492>",

        ["ignite"]=     PEARL.EMOTES.DISCORD[PEARL.EMOTES.GAME.TORCH],
        ["burn"]=       PEARL.EMOTES.DISCORD[PEARL.EMOTES.GAME.FIRE],
        ["take"]=       PEARL.EMOTES.DISCORD[PEARL.EMOTES.GAME.BACKPACK],
        ["eat"]=        PEARL.EMOTES.DISCORD[PEARL.EMOTES.GAME.FAKETEETH],
        ["kill"]=       PEARL.EMOTES.DISCORD[PEARL.EMOTES.GAME.HAMBAT],
        ["hammer"]=     PEARL.EMOTES.DISCORD[PEARL.EMOTES.GAME.HAMMER],
        ["defeat"]=     PEARL.EMOTES.DISCORD[PEARL.EMOTES.GAME.TROPHY],
        ["deploy"]=     PEARL.EMOTES.DISCORD[PEARL.EMOTES.GAME.EYEPLANT],
        ["welcome"]=    PEARL.EMOTES.DISCORD[PEARL.EMOTES.GAME.WAVE]
    },
}
