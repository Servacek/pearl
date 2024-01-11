--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



-- Note: Webhooks and bots in general can use external emojis even from servers they are not in.
-- So these icons should work on all discord servers.

--------------------------------
-- [[ Constants ]]
--------------------------------

local DISCORD_EMOJI_PATTERN = "^<a?:%S+:%d+>$"

-- First 3 bytes of the emoji are the same always.
-- The last one is from range 156-255
-- This is true only for original game emojis.
local GAME_EMOTE_PATTERN    = "^\243\176\128[\156-\255]$"

--------------------------------
-- [[ Class Delcaration ]]
--------------------------------

--- @class ICONS
local ICONS = {
    X = "<:x_:999294448045408277>",
    CHECK = "<:check:999294412972625940>",
    PING = "<:connection:1064114008698916864>",
    STEAM = "<:steam:1076608091656814643>",
    LOCAL = "<:local:1076609330905878588>",
    ARROW_UP = "<:arrowsmallup:1190665482068561930>",
    ARROW_DOWN = "<:arrowsmalldown:1190665466352513106>",
    LIGHTNING = "<:lightning:1166029673076105276>",
    SYNC   = "<:connect:1166026349157302332>",
    UNSYNC = "<:disconnect:1030926979463135313>",

    ONLINE = ":green_circle:",
    OFFLINE = ":red_circle:",

    AFK   = "<:avatar_afk:1191784868347121714>",
    ADMIN = "<:avatar_admin:1191784852341661696>",

    PLAYER_PREFABS = {
        ["walter"] =             "<:avatar_walter:1152542346253180938>",
        ["wagstaff"] =           "<:avatar_wagstaff_npc:1152542386342334525>",
        ["warly"] =              "<:avatar_warly:1152542415966703686>",
        ["waxwell"] =            "<:avatar_waxwell:1152542452444581898>",
        ["wathgrithr"] =         "<:avatar_wathgrithr:1152542482589024358>",
        ["webber"] =             "<:avatar_webber:1152542502553931826>",
        ["wendy"] =              "<:avatar_wendy:1152542517972185140>",
        ["wes"] =                "<:avatar_wes:1152542532333481985>",
        ["wickerbottom"] =       "<:avatar_wickerbottom:1152542545377763338>",
        ["willow"] =             "<:avatar_willow:1152542561228038185>",
        ["wilson"] =             "<:avatar_wilson:1152542583810170981>",
        ["winona"] =             "<:avatar_winona:1152542602768437278>",
        ["wolfgang"] =           "<:avatar_wolfgang:1152542617976983602>",
        ["wonkey"] =             "<:avatar_wonkey:1152542634703851550>",
        ["woodie"] =             "<:avatar_woodie:1152542652437368933>",
        ["wormwood"] =           "<:avatar_wormwood:1152542674642010153>",
        ["wortox"] =             "<:avatar_wortox:1152542700676055050>",
        ["wx78"] =               "<:avatar_wx78:1152542719483330640>",
        ["wurt"] =               "<:avatar_wurt:1152542745215381525>",
        ["wanda"] =              "<:avatar_wanda:1152565827904745562>",

        ---------------------------------------------------------
        -- Support for mods that add characters from the DLCS
        -- like Tropical Experience, etc...

        -- Shipwrecked
        wilbur =            "<:wilbur:988081746975272980>",
        woodlegs =          "<:woodlegs:988081763236585522>",

        -- Hamlet
        wilba =             "<:wilba:988081734933434368>",
        wheeler =           "<:wheeler:988081715325059083>",

        -- Server
        ["server"] =        "<:dedicated:1001104949524041788>",

        -- Ghost Prefabs
        ["ghost_wilson"]        = "<:ghost_wilson:1150182509926174740>",
        ["ghost_winona"]        = "<:ghost_winona:1150182524098728068>",
        ["ghost_wolfgang"]      = "<:ghost_wolfgang:1150182536794886175>",
        ["ghost_wonkey"]        = "<:ghost_wonkey:1150182549918863420>",
        ["ghost_woodie"]        = "<:ghost_woodie:1150182563378372789>",
        ["ghost_woodie_1"]      = "<:ghost_woodie_1:1150182576544292875>",
        ["ghost_woodie_2"]      = "<:ghost_woodie_2:1150182622572593234>",
        ["ghost_woodie_3"]      = "<:ghost_woodie_3:1150182637646917793>",
        ["ghost_wickerbottom"]  = "<:ghost_wickerbottom:1150182661273436252>",
        ["ghost_wes"]           = "<:ghost_wes:1150182678679789661>",
        ["ghost_wendy"]         = "<:ghost_wendy:1150182697654829067>",
        ["ghost_webber"]        = "<:ghost_webber:1150182722627702836>",
        ["ghost_waxwell"]       = "<:ghost_waxwell:1150182740889718905>",
        ["ghost_wathgrithr"]    = "<:ghost_wathgrithr:1150182759030075392>",
        ["ghost_warly"]         = "<:ghost_warly:1150182774750314678>",
        ["ghost_wanda"]         = "<:ghost_wanda:1150182789849821185>",
        ["ghost_walter"]        = "<:ghost_walter:1150182815477010513>",
        ["ghost_willow"]        = "<:ghost_willow:1150182832178737212>",
        ["ghost_wormwood"]      = "<:ghost_wormwood:1151208430586044466>",
        ["ghost_wortox"]        = "<:ghost_wortox:1151208508566544425>",
        ["ghost_wurt"]          = "<:ghost_wurt:1151208540871082034>",
        ["ghost_wx78"]          = "<:ghost_wx78:1151208576010948619>",

        -- State Prefabs
        ["woodie_1"]            = "<:woodie_1:1151231449664589894>",
        ["woodie_2"]            = "<:woodie_2:1151231475216302141>",
        ["woodie_3"]            = "<:woodie_3:1151231500335984723>",
        ["wormwood_1"]          = "<:wormwood_1:1151231540425146460>",
        ["wormwood_2"]          = "<:wormwood_2:1151231563380555818>",
        ["wormwood_3"]          = "<:wormwood_3:1151231594078666792>",

        -- Fallbacks
        ["unknown"]             = "<:unknown:1151231676891005070>",
        ["ghost_unknown"]       = "<:ghost_unknown:1150182868279099432>",
        [""]                    = "<:unknown:990652780496695406>",
        ["ghost_"]              = "<:ghost_unknown:1150182868279099432>",
    },

    LEADERBOARD_PLACES = {
        [1] = "<:1st:1129353293357912105>",
        [2] = "<:2nd:1129353938848723065>",
        [3] = "<:3rd:1129348645741924358>",
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
        UNBAN               = "<:unban:1138547740410908824>",
    },

    PLAYER_VANITY = {
        [PEARL.CONSTS.PROFILE_FLAIRS.DISCORD] = "<:discord:1135176871655522374>",
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

        ["ignite"]=     PEARL.EMOTES.MAP_DISCORD[PEARL.EMOTES.GAME.TORCH],
        ["burn"]=       PEARL.EMOTES.MAP_DISCORD[PEARL.EMOTES.GAME.FIRE],
        ["take"]=       PEARL.EMOTES.MAP_DISCORD[PEARL.EMOTES.GAME.BACKPACK],
        ["swallow"]=    PEARL.EMOTES.MAP_DISCORD[PEARL.EMOTES.GAME.FAKETEETH],
        ["kill"]=       PEARL.EMOTES.MAP_DISCORD[PEARL.EMOTES.GAME.HAMBAT],
        ["murder"]=     PEARL.EMOTES.MAP_DISCORD[PEARL.EMOTES.GAME.CHESTER],
        ["hammer"]=     PEARL.EMOTES.MAP_DISCORD[PEARL.EMOTES.GAME.HAMMER],
        ["defeat"]=     PEARL.EMOTES.MAP_DISCORD[PEARL.EMOTES.GAME.TROPHY],
        ["deploy"]=     PEARL.EMOTES.MAP_DISCORD[PEARL.EMOTES.GAME.EYEPLANT],
        ["welcome"]=    PEARL.EMOTES.MAP_DISCORD[PEARL.EMOTES.GAME.WAVE],
        ["read"]=       "<:pravidla:1152668369544286268>",

        ["extinguish"]= "<:extinguish:1133083578381643818>",
        ["build"]=      "<:build:1133086015146438686>",
        ["craft"]=      PEARL.EMOTES.MAP_DISCORD[PEARL.EMOTES.GAME.SCIENCEMACHINE],
        --["dig"]=        PEARL.EMOTES.MAP_DISCORD[PEARL.EMOTES.GAME.SHOVEL],
        ["plant"]=      PEARL.EMOTES.MAP_DISCORD[PEARL.EMOTES.GAME.BERRY],
        ["give"]=       PEARL.EMOTES.MAP_DISCORD[PEARL.EMOTES.GAME.PIG],
        ["sleep"]=      "<:tent:1133091346371072040>",
        ["chop"]=       "<:axe:1133094231972515910>",
        ["eat"]=        PEARL.EMOTES.MAP_DISCORD[PEARL.EMOTES.GAME.HUNGER],
        ["propagator"]= PEARL.EMOTES.MAP_DISCORD[PEARL.EMOTES.GAME.FIREPIT],
        ["fertilize"]=  PEARL.EMOTES.MAP_DISCORD[PEARL.EMOTES.GAME.POOP],
        ["waste"]=      PEARL.EMOTES.DISCORD.WORMHOLE,
        ["cook"]=       PEARL.EMOTES.DISCORD.CROCKPOT,
        ["heal"]=       PEARL.EMOTES.DISCORD.HEART,
        ["sew"]=        "<:sewing_kit:1170438166168215652>",
        ["mine"]=       "<:mine:1189591897673576579>",
        ["play"]=       "<:play:1189612902282428486>",
        ["activate"]=   PEARL.EMOTES.DISCORD.LIGHTBULB,
        ["teach"]=      PEARL.EMOTES.DISCORD.SANITY,
        ["extinct"]=    PEARL.EMOTES.DISCORD.BEEFALO,
        ["catch"]=      "<:catch:1195066050442694726>",
        ["broke"]=      "<:broke:1195062001488105613>",
    },
}

ICONS.TYPE = {
    UNKNOWN = 0,
    DISCORD = 1,
    INGAME  = 2,
}

--------------------------------
-- [[ Public ]]
--------------------------------

--- @param icon string
--- @return integer ICONS.TYPE
function ICONS.GetType(icon)
    if icon:match(DISCORD_EMOJI_PATTERN) then
        return ICONS.TYPE.DISCORD
    end

    if icon:match(GAME_EMOTE_PATTERN) or PEARL.EMOTES.MAP_DISCORD[icon] ~= nil then
        return ICONS.TYPE.INGAME
    end

    return ICONS.TYPE.UNKNOWN
end

--------------------------------
-- [[ Inventory Icons ]]
--------------------------------

if TheNet:GetIsServer() and PEARL.CONFIG.INVENTORY_ICONS then
    ICONS.INVENTORY = json.load(PEARL.MODROOT.."/data/inventory_icons.json")
end

ICONS.INVENTORY = type(ICONS.INVENTORY) == "table" and ICONS.INVENTORY or {}

--------------------------------
-- [[ Return ]]
--------------------------------

return ICONS
