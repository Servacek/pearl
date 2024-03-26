--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]] -- Note: Webhooks and bots in general can use external emojis even from servers they are not in.
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

        LMB = STRINGS.LMB,
        RMB = STRINGS.RMB
    },

    DISCORD = { -- These are not used in code so the lowered down version is enough.
        ["anojdgurl"] = "󰂡",
        ["cat_angry"] = "󰂢",
        ["catto"] = "󰂣",
        ["conceited_reaction"] = "󰂤",
        ["cz"] = "󰂥",
        ["doge"] = "󰂦",
        ["doge_kek"] = "󰂧",
        ["doublefacepalm"] = "󰂨",
        ["noice"] = "󰂩",
        ["facepalm"] = "󰂪",
        ["free_real_estate"] = "󰂫",
        ["gooddoggo"] = "󰂬",
        ["harold"] = "󰂭",
        ["heh"] = "󰂮",
        ["kekleo"] = "󰂯",
        ["kekw"] = "󰂰",
        ["krtek_ewww"] = "󰂱",
        ["risitas"] = "󰂲",
        ["sir"] = "󰃀",
        ["sk"] = "󰂳",
        ["skill_issue"] = "󰂴",
        ["stare"] = "󰂵",
        ["takjo"] = "󰂶",
        ["webber_damage"] = "󰂷",
        ["wes_annoyed"] = "󰂸",
        ["wesluv"] = "󰂹",
        ["wigfrid_ping"] = "󰂺",
        ["willowkys"] = "󰂻",
        ["wilson_thong"] = "󰂼",
        ["wilson_why"] = "󰂽",
        ["wormwood_fire"] = "󰂾",
        ["yeah"] = "󰂿"

        -- Revelaing internal icons
        -- Looks like even this requires the fonts.
        -- ["touchstone"] = "󰀱",
        -- ["portal"] = "󰀰"
    },

    --- @class EMOTES.DISCORD
    -- Converts a game utf-8 formatted emote to a discord emoji
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

        -- These are internal but can still be used in the chat using the UTF8 codes.
        -- Or in messages sent from discord.
        ["󰀰"] = "<:endless:1093462962397794314>",
        ["󰀱"] = "<:touchstone:1134905297278877766>",

        -- Controls
        [STRINGS.LMB] = "<a:lmb:997499438077591593>",
        [STRINGS.RMB] = "<:rmb:999294664458895473>",

        -- Custom
        ["󰂰"] = "<:KEKW:729622110183358515>",
        ["󰂦"] = "<:doge:765929919703679010>",
        ["󰂧"] = "<:doge_kek:709677492939784193>",
        ["󰂯"] = "<:kekleo:830091874122596386>",
        ["󰂤"] = "<:conceited_reaction:803675137676673055>",
        ["󰂫"] = "<:ds_free_real_estate:777850333963616277>",
        ["󰂺"] = "<:ds_wigfrid_ping:686155662304346112>",
        ["󰂡"] = "<:anojdgurl:726378051012919326>",
        ["󰂨"] = "<:doublefacepalm:826807100172271707>",
        ["󰂲"] = "<:risitas:797532692731789362>",
        ["󰂸"] = "<:ds_wes_annoyed:685925681397366787>",
        ["󰂹"] = "<:ds_wesluv:797532778463756309>",
        ["󰂻"] = "<:ds_willowkys:797528101792776192>",
        ["󰂵"] = "<:stare:872544999726776391>",
        ["󰂴"] = "<:skill_issue:1216792672891834558>",
        ["󰂿"] = "<:yeah:824195462264651788>",
        ["󰂾"] = "<:wormwoodFire:989498400443617310>",
        ["󰂣"] = "<:catto:765936051905888317>",
        ["󰂢"] = "<:cat_angry:765940080568827914>",
        ["󰂶"] = "<:ds_takjo:779345130112286730>",
        ["󰂽"] = "<:ds_wilson_why:685925800448753672>",
        ["󰂼"] = "<:ds_wilson_thong:685926128514629667>",
        ["󰂬"] = "<:gooddoggo:830090455395074068>",
        ["󰂮"] = "<:heh:803360836025450506>",
        ["󰂷"] = "<:ds_webber_damage:686144348110323767>",
        ["󰂱"] = "<:krtek_ewww:802953092634378330>",
        ["󰂭"] = "<:harold:709677100814303264>",
        ["󰃀"] = "<:Sir:798150463315771412>",
        ["󰂩"] = "<:ds_noice:779689296902094889>",
        ["󰂳"] = ":flag_sk:",
        ["󰂥"] = ":flag_cz:",
    }
}

-- Game Icon Name -> Discord Emoji
--- @class EMOJIS.GAME
EMOJIS.GAME_TO_DISCORD = {}
for name, utf in pairs(EMOJIS.GAME) do
    EMOJIS.GAME_TO_DISCORD[name] = EMOJIS.UTF_TO_DISCORD[utf]
end

EMOJIS.DISCORD_TO_UTF = {}
for utf, discord in pairs(EMOJIS.UTF_TO_DISCORD) do
    EMOJIS.DISCORD_TO_UTF[discord] = utf
end

EMOJIS.GAME_LOWERED = {}
for name, utf in pairs(EMOJIS.GAME) do
    EMOJIS.GAME_LOWERED[name:lower()] = utf
end

EMOJIS.ALL = MergeMaps(EMOJIS.GAME_LOWERED, EMOJIS.DISCORD)

EMOJIS.UTF_TO_NAME = {}
for name, utf in pairs(EMOJIS.ALL) do
    EMOJIS.UTF_TO_NAME[utf] = name
end

function EMOJIS.GetOwnedVanillaEmojis(userid)
    local has_ownership = nil
    if TheWorld ~= nil and userid ~= nil and TheWorld.ismastersim then
        has_ownership = function(item_type)
            return TheInventory:CheckClientOwnership(userid, item_type)
        end
    elseif userid == TheNet:GetUserID() then
        has_ownership = function(item_type)
            return TheInventory:CheckOwnership(item_type)
        end
    else
        return {}
    end

    local emojis_map = {}
    for item_type, emojis in pairs(EMOJI_ITEMS) do
        if has_ownership(item_type) then
            emojis_map[emojis.input_name] = emojis.data.utf8_str
        end
    end

    return emojis_map
end

function EMOJIS.EmojifyForDiscord(s)
    return s:gsub(PEARL.CONSTS.UTF_EMOJI_PATTERN, PEARL.EMOJIS.UTF_TO_DISCORD)
end

function EMOJIS.EmojifyForGame(s)
    return s:gsub(PEARL.CONSTS.DISCORD_EMOJI_PATTERN, PEARL.EMOJIS.DISCORD_TO_UTF)
            :gsub(PEARL.CONSTS.UNICODE_EMOJI_PATTERN, function(match)
                return PEARL.EMOJIS.DISCORD_TO_UTF[match] or ":UNKNOWN_EMOJI:"
            end)
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
