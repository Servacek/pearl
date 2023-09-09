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
    -- Game utf-8 formatted emotes accessed by name
    GAME = {
        ABIGAIL         = "󰀜",
        ALCHEMY		    = "󰀝",
        BACKPACK		= "󰀞",
        BATTLE		    = "󰀘",
        BEEFALO		    = "󰀁",
        BEEHIVE		    = "󰀟",
        BERRY			= "󰀠",
        CARROT		    = "󰀡",
        CHEST			= "󰀂",
        CHESTER		    = "󰀃",
        CROCKPOT	   	= "󰀄",
        EYEBALL		    = "󰀅",
        EGG			    = "󰀢",
        EYEPLANT		= "󰀣",
        FARM			= "󰀇",
        FIREPIT		    = "󰀤",
        FIRE			= "󰀈",
        FLEX			= "󰀙",
        GHOST			= "󰀉",
        GOLD			= "󰀚",
        GRAVE			= "󰀊",
        HAMBAT		    = "󰀋",
        HAMMER		    = "󰀌",
        HEART			= "󰀍",
        HORN			= "󰀥",
        HUNGER		    = "󰀎",
        LIGHTBULB		= "󰀏",
        ARCANE		    = "󰀀",
        MEAT			= "󰀦",
        PIG			    = "󰀐",
        POOP			= "󰀑",
        REDGEM		    = "󰀒",
        REFINE		    = "󰀧",
        SALT			= "󰀨",
        SANITY		    = "󰀓",
        SCIENCEMACHINE	= "󰀔",
        FAKETEETH		= "󰀆",
        SHADOW		    = "󰀩",
        SHOVEL		    = "󰀪",
        SKULL			= "󰀕",
        WEB			    = "󰀗",
        THUMBSUP		= "󰀫",
        TOPHAT		    = "󰀖",
        TORCH			= "󰀛",
        TRAP			= "󰀬",
        TROPHY		    = "󰀭",
        WAVE			= "󰀮",
        WORMHOLE		= "󰀯",

        -- Status announcements mod
        LMB             = "",
    },

    -- Converts a game utf-8 formatted emote to a discord emoji
    DISCORD = {
        ["󰀜"] = "<a:abigail:997498948161900584>", -- :abigail:
        ["󰀝"] = "<a:alchemy:997498961675960470>", -- :alchemy:
        ["󰀞"] = "<a:backpack:997498991094800510>", -- :backpack:
        ["󰀘"] = "<a:battle:997499007595192442>", -- :battle:
        ["󰀁"] = "<a:beefalo:997499021801312338>", -- :beefalo:
        ["󰀟"] = "<a:beehive:997499036401676298>", -- :beehive:
        ["󰀠"] = "<a:berry:997499052113526846>", -- :berry:
        ["󰀡"] = "<a:carrot:997499067099779073>", -- :carrot:
        ["󰀂"] = "<a:chest:997499374949122168>", -- :chest:
        ["󰀃"] = "<a:chester:997499403155804170>", -- :chester:
        ["󰀄"] = "<a:crockpot:997499081217810504>", -- :crockpot:
        ["󰀅"] = "<a:eyeball:997499144962842704>", -- :eyeball:
        ["󰀢"] = "<a:egg:997499097655279646>", -- :egg:
        ["󰀣"] = "<a:eyeplant:997499160968302615>", -- :eyeplant:
        ["󰀇"] = "<a:farm:997499195999125564>", -- :farm:
        ["󰀤"] = "<a:firepit:997499224965005413>", -- :firepit:
        ["󰀈"] = "<a:fire:997499211568381982>", -- :fire:
        ["󰀙"] = "<a:flex:997499239577948210>", -- :flex:
        ["󰀉"] = "<a:ghost:997499254065090701>", -- :ghost:
        ["󰀚"] = "<a:gold:997499267763671100>", -- :gold:
        ["󰀊"] = "<a:grave:997499282447933470>", -- :grave:
        ["󰀋"] = "<a:hambat:997499296385597572>", -- :hambat:
        ["󰀌"] = "<a:hammer:997499313045377084>", -- :hammer:
        ["󰀍"] = "<a:heart:997499329021489162>", -- :heart:
        ["󰀥"] = "<a:horn:997499344326504528>", -- :horn:
        ["󰀎"] = "<a:hunger:997499359082057768>", -- :hunger:
        ["󰀏"] = "<a:lightbulb:997509014852222986>", -- :lightbulb:
        ["󰀀"] = "<a:arcane:997498975110312058>", -- :arcane:
        ["󰀦"] = "<a:meat:997508811977916517>", -- :meat:
        ["󰀐"] = "<a:pig:997508861382627448>", -- :pig:
        ["󰀑"] = "<a:poop:997508890604347452>", -- :poop:
        ["󰀒"] = "<a:redgem:997508909541638204>", -- :redgem:
        ["󰀧"] = "<a:refine:997508939254091898>", -- :refine:
        ["󰀨"] = "<a:salt:997509143936114718>", -- :salt:
        ["󰀓"] = "<a:sanity:997509161904525342>", -- :sanity:
        ["󰀔"] = "<a:sciencemachine:997509200311758948>", -- :sciencemachine:
        ["󰀆"] = "<a:faketeeth:997499178378858606>", -- :faketeeth:
        ["󰀩"] = "<a:shadow:997509220754784366>", -- :shadow:
        ["󰀪"] = "<a:shovel:997509241013280768>", -- :shovel:
        ["󰀕"] = "<a:skull:997509305978867742>", -- :skull:
        ["󰀗"] = "<a:web:997509261343072266>", -- :web:
        ["󰀫"] = "<a:thumbsup:997511199971356732>", -- :thumbsup:
        ["󰀖"] = "<a:tophat:997509321762033754>", -- :tophat:
        ["󰀛"] = "<a:torch:997509339285823611>", -- :torch:
        ["󰀬"] = "<a:trap:997509380763299920>", -- :trap:
        ["󰀭"] = "<a:trophy:997509395309150238>", -- :trophy:
        ["󰀮"] = "<a:wave:997511183085097050>", -- :wave:
        ["󰀯"] = "<a:wormhole:997509414636507156>", -- :wormhole:

        -- These are internal but can still be used in the chat using the UTF8 codes.
        -- Or in messages sent from discord.
        ["󰀰"] = "<:endless:1093462962397794314>",
        ["󰀱"] = "<:touchstone:1134905297278877766>",

        -- Status announcements mod
        [""] = "<a:lmb:997499438077591593>",
        --["TODO?"] = "<a:rmb:997508955435700224>", -- right mouse click
    },
}
