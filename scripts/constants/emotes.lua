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
--- @class EMOJIS
local EMOJIS = {
    -- Game utf-8 formatted emotes accessed by name (from code)
    --- @class EMOJIS.GAME
    GAME = {
        ABIGAIL = "󰀜",
        ALCHEMY = "󰀝",
        BACKPACK = "󰀞",
        BATTLE = "󰀘",
        BEEFALO = "󰀁",
        BEEHIVE = "󰀟",
        BERRY = "󰀠",
        CARROT = "󰀡",
        CHEST = "󰀂",
        CHESTER = "󰀃",
        CROCKPOT = "󰀄",
        EYEBALL = "󰀅",
        EGG = "󰀢",
        EYEPLANT = "󰀣",
        FARM = "󰀇",
        FIREPIT = "󰀤",
        FIRE = "󰀈",
        FLEX = "󰀙",
        GHOST = "󰀉",
        GOLD = "󰀚",
        GRAVE = "󰀊",
        HAMBAT = "󰀋",
        HAMMER = "󰀌",
        HEART = "󰀍",
        HORN = "󰀥",
        HUNGER = "󰀎",
        LIGHTBULB = "󰀏",
        ARCANE = "󰀀",
        MEAT = "󰀦",
        PIG = "󰀐",
        POOP = "󰀑",
        REDGEM = "󰀒",
        REFINE = "󰀧",
        SALT = "󰀨",
        SANITY = "󰀓",
        SCIENCEMACHINE = "󰀔",
        FAKETEETH = "󰀆",
        SHADOW = "󰀩",
        SHOVEL = "󰀪",
        SKULL = "󰀕",
        WEB = "󰀗",
        THUMBSUP = "󰀫",
        TOPHAT = "󰀖",
        TORCH = "󰀛",
        TRAP = "󰀬",
        TROPHY = "󰀭",
        WAVE = "󰀮",
        WORMHOLE = "󰀯",
        PORTAL = "󰀰",
        RESURRECTION = "󰀱",

        LMB = STRINGS.LMB,
        RMB = STRINGS.RMB
    },

    --- @class EMOTES.DISCORD
    --- Converts a game utf-8 formatted emote to a discord emoji
    ---
    --- @NOTE:
    --- Discord doesn't care about emoji names in these.
    --- It only has to be at least one non-space character and contain no spaces.
    UTF_TO_DISCORD = {
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
        ["󰀰"] = "<:portal:1222646460588490834>", -- :portal:
        ["󰀱"] = "<:resurrection:1222646437670551706>", -- :resurrection:

        -- Controls
        [STRINGS.LMB] = "<a:lmb:997499438077591593>",
        [STRINGS.RMB] = "<a:rmb:997508955435700224>",
    }
}

-- Game Icon Name -> Discord Emoji
--- @class EMOJIS.GAME
EMOJIS.GAME_TO_DISCORD = {}
for name, utf in pairs(EMOJIS.GAME) do
    EMOJIS.GAME_TO_DISCORD[name] = EMOJIS.UTF_TO_DISCORD[utf]
end

do
    local _DISCORD_ID_TO_UTF = {}
    for utf, discord in pairs(EMOJIS.UTF_TO_DISCORD) do
        local discord_id = discord:match(PEARL.CONSTS.DISCORD_EMOJI_ID_PATTERN)
        _DISCORD_ID_TO_UTF[discord_id] = utf
    end

    -- Discord Emoji (Name Insensitive) -> Game UTF8 icon
    EMOJIS.DISCORD_TO_UTF = setmetatable({}, {
        __index = function(self, emoji_mention)
            if type(emoji_mention) == "string" then
                local discord_id = emoji_mention:match(PEARL.CONSTS.DISCORD_EMOJI_ID_PATTERN)
                return _DISCORD_ID_TO_UTF[discord_id]
            end

            return _DISCORD_ID_TO_UTF[emoji_mention]
        end
    })
end

--[[
    Since we have migrated the emoji menu part of the mod to a separate "Animated Emojis" mod,
    we take the mapping tables for converting utf8 strings to discord strings and vice versa
    from that mod's globally exposed tables.
--]]

function EMOJIS.EmojifyForDiscord(s)
    local animated_emojis = rawget(_G, "__MOD_ANIMATED_EMOJIS")
    local custom_utf_to_discord = animated_emojis and animated_emojis.EMOJIS
                                  and animated_emojis.EMOJIS.UTF_TO_DISCORD_STR
    return (s:gsub(PEARL.CONSTS.UTF_EMOJI_PATTERN, function(emoji)
        return PEARL.EMOJIS.UTF_TO_DISCORD[emoji]
            or (custom_utf_to_discord and custom_utf_to_discord[emoji])
            or emoji
    end))
end

function EMOJIS.EmojifyForGame(s)
    local animated_emojis = rawget(_G, "__MOD_ANIMATED_EMOJIS")
    local custom_discord_to_utf = animated_emojis and animated_emojis.EMOJIS
                                  and animated_emojis.EMOJIS.DISCORD_TO_UTF_STR

    return (s:gsub(PEARL.CONSTS.DISCORD_EMOJI_PATTERN, function(emoji)
                return PEARL.EMOJIS.DISCORD_TO_UTF[emoji]
                    or (custom_discord_to_utf and custom_discord_to_utf[emoji])
                    or emoji
            end)
            :gsub(PEARL.CONSTS.UNICODE_EMOJI_PATTERN, function(match)
                return PEARL.EMOJIS.DISCORD_TO_UTF[match] or ":UNKNOWN_EMOJI:"
            end))
end

--------------------------------
-- [[ Alias Configurations ]]
--------------------------------

PEARL.info("Loading custom emoji aliases...")

local ALIASES = PEARL.CONFIG.EMOJI_ALIASES(EMOJIS)
if type(ALIASES) == "table" then
    for alias_emoji, root_emoji in pairs(ALIASES) do
        if alias_emoji:find(PEARL.CONSTS.UNICODE_EMOJI_PATTERN) or alias_emoji:find(PEARL.CONSTS.DISCORD_EMOJI_PATTERN) then
            EMOJIS.DISCORD_TO_UTF[alias_emoji] = root_emoji
        elseif root_emoji:find(PEARL.CONSTS.DISCORD_EMOJI_PATTERN) or root_emoji:find(PEARL.CONSTS.HYBRID_EMOJI_PATTERN) then
            EMOJIS.GAME_TO_DISCORD[alias_emoji] = root_emoji
        else
            PEARL.error("Invalid emoji alias provided", alias_emoji, root_emoji)
        end
    end
end

--------------------------------
-- [[ Return ]]
--------------------------------

return EMOJIS
