--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

require("emoji_items")

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

    ANIMATED = {
        DISCORD = {
            --- @AUTOGENERATE CONTENT START ANIMATED_DISCORD_NAME_TO_UTF8
            ["Huh"] = "󰃕",
            ["Jam"] = "󰃖",
            ["PepeKek"] = "󰃗",
            ["PepeLaughs"] = "󰃘",
            ["PoggiesFast"] = "󰃙",
            ["TeaTime"] = "󰃚",
            ["aware"] = "󰃛",
            ["bongocat"] = "󰃜",
            ["burn"] = "󰃝",
            ["clap"] = "󰃞",
            ["eyes"] = "󰃟",
            ["peepoHey"] = "󰃠",
            ["tumtum"] = "󰃡",
            ["vibing_cat"] = "󰃢",
            --- @AUTOGENERATE CONTENT END ANIMATED_DISCORD_NAME_TO_UTF8
        },
    },

    DISCORD = { -- These are not used in code so the lowered down version is enough.
        --- @AUTOGENERATE CONTENT START DISCORD_NAME_TO_UTF8
        ["Clueless"] = "󰂠",
        ["D_"] = "󰂡",
        ["ICANT"] = "󰂢",
        ["anojdgurl"] = "󰂣",
        ["cat_angry"] = "󰂤",
        ["catto"] = "󰂥",
        ["conceited_reaction"] = "󰂦",
        ["cz"] = "󰂧",
        ["doge"] = "󰂨",
        ["doge_kek"] = "󰂩",
        ["doublefacepalm"] = "󰂪",
        ["facepalm"] = "󰂫",
        ["free_real_estate"] = "󰂬",
        ["gooddoggo"] = "󰂭",
        ["harold"] = "󰂮",
        ["heh"] = "󰂯",
        ["kekleo"] = "󰂰",
        ["kekw"] = "󰂱",
        ["krtek_ewww"] = "󰂲",
        ["lulw"] = "󰂳",
        ["noice"] = "󰂴",
        ["omegalul"] = "󰂵",
        ["peepoBlanket"] = "󰂶",
        ["peepoEgoUp"] = "󰂷",
        ["peepoHappy"] = "󰂸",
        ["risitas"] = "󰂹",
        ["sir"] = "󰂺",
        ["sk"] = "󰂻",
        ["skill_issue"] = "󰂼",
        ["stare"] = "󰂽",
        ["takjo"] = "󰂾",
        ["webber_damage"] = "󰂿",
        ["wes_annoyed"] = "󰃀",
        ["wesluv"] = "󰃁",
        ["whaskaBACK"] = "󰃂",
        ["whaskaBIGBRAIN"] = "󰃃",
        ["whaskaCELO"] = "󰃄",
        ["whaskaHI"] = "󰃅",
        ["whaskaHYPE"] = "󰃆",
        ["whaskaJAM"] = "󰃇",
        ["whaskaLOVE"] = "󰃈",
        ["whaskaLUL"] = "󰃉",
        ["whaskaLURK"] = "󰃊",
        ["whaskaRIP"] = "󰃋",
        ["whaskaSAD"] = "󰃌",
        ["whaskaSELLOUT"] = "󰃍",
        ["whaskaTUMTUM"] = "󰃎",
        ["wigfrid_ping"] = "󰃏",
        ["willowkys"] = "󰃐",
        ["wilson_thong"] = "󰃑",
        ["wilson_why"] = "󰃒",
        ["wormwood_fire"] = "󰃓",
        ["yeah"] = "󰃔",
        --- @AUTOGENERATE CONTENT END DISCORD_NAME_TO_UTF8
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

        -- Custom (automatically generated by my scripts)
        --- @AUTOGENERATE CONTENT START UTF8_TO_DISCORD
        ["󰂰"] = "<:kekleo:830091874122596386>", -- :kekleo:
        ["󰂫"] = "<:facepalm:765931848030355487>", -- :facepalm:
        ["󰂦"] = "<:conceited_reaction:803675137676673055>", -- :conceited_reaction:
        ["󰂬"] = "<:free_real_estate:777850333963616277>", -- :free_real_estate:
        ["󰃏"] = "<:wigfrid_ping:686155662304346112>", -- :wigfrid_ping:
        ["󰂣"] = "<:anojdgurl:726378051012919326>", -- :anojdgurl:
        ["󰂪"] = "<:doublefacepalm:826807100172271707>", -- :doublefacepalm:
        ["󰂹"] = "<:risitas:797532692731789362>", -- :risitas:
        ["󰃀"] = "<:wes_annoyed:685925681397366787>", -- :wes_annoyed:
        ["󰃁"] = "<:wesluv:797532778463756309>", -- :wesluv:
        ["󰃐"] = "<:willowkys:797528101792776192>", -- :willowkys:
        ["󰂽"] = "<:stare:872544999726776391>", -- :stare:
        ["󰂼"] = "<:skill_issue:1216792672891834558>", -- :skill_issue:
        ["󰃔"] = "<:yeah:824195462264651788>", -- :yeah:
        ["󰃓"] = "<:wormwood_fire:1222665874910085171>", -- :wormwood_fire:
        ["󰂥"] = "<:catto:765936051905888317>", -- :catto:
        ["󰂤"] = "<:cat_angry:765940080568827914>", -- :cat_angry:
        ["󰂾"] = "<:takjo:779345130112286730>", -- :takjo:
        ["󰃒"] = "<:wilson_why:685925800448753672>", -- :wilson_why:
        ["󰃑"] = "<:wilson_thong:685926128514629667>", -- :wilson_thong:
        ["󰂭"] = "<:gooddoggo:830090455395074068>", -- :gooddoggo:
        ["󰂯"] = "<:heh:803360836025450506>", -- :heh:
        ["󰂿"] = "<:webber_damage:686144348110323767>", -- :webber_damage:
        ["󰂲"] = "<:krtek_ewww:802953092634378330>", -- :krtek_ewww:
        ["󰂮"] = "<:harold:709677100814303264>", -- :harold:
        ["󰂱"] = "<:kekw:729622110183358515>", -- :kekw:
        ["󰂨"] = "<:doge:765929919703679010>", -- :doge:
        ["󰂩"] = "<:doge_kek:709677492939784193>", -- :doge_kek:
        ["󰂴"] = "<:noice:779689296902094889>", -- :noice:
        ["󰂻"] = "<:sk:1208462378321317960>", -- :sk:
        ["󰂧"] = "<:cz:1208462259261808730>", -- :cz:
        ["󰂺"] = "<:sir:798150463315771412>", -- :sir:
        ["󰂵"] = "<:omegalul:693619803708981341>", -- :omegalul:
        ["󰃈"] = "<:whaskaLOVE:1141066020396736562>", -- :whaskaLOVE:
        ["󰃂"] = "<:whaskaBACK:1141065996640202802>", -- :whaskaBACK:
        ["󰃃"] = "<:whaskaBIGBRAIN:1141066000779980830>", -- :whaskaBIGBRAIN:
        ["󰃆"] = "<:whaskaHYPE:1141066016139526304>", -- :whaskaHYPE:
        ["󰃇"] = "<:whaskaJAM:1141066040428744815>", -- :whaskaJAM:
        ["󰃌"] = "<:whaskaSAD:1141066004324159570>", -- :whaskaSAD:
        ["󰃍"] = "<:whaskaSELLOUT:1141066035945021451>", -- :whaskaSELLOUT:
        ["󰃋"] = "<:whaskaRIP:1141066008103239750>", -- :whaskaRIP:
        ["󰃉"] = "<:whaskaLUL:1141066024746233988>", -- :whaskaLUL:
        ["󰃊"] = "<:whaskaLURK:1141066030681165864>", -- :whaskaLURK:
        ["󰃅"] = "<:whaskaHI:1141066012297535559>", -- :whaskaHI:
        ["󰂢"] = "<:ICANT:1084938163513983041>", -- :ICANT:
        ["󰃎"] = "<:whaskaTUMTUM:1141066051472330792>", -- :whaskaTUMTUM:
        ["󰂸"] = "<:peepoHappy:874748262819721287>", -- :peepoHappy:
        ["󰂶"] = "<:peepoBlanket:887641852189225000>", -- :peepoBlanket:
        ["󰂷"] = "<:peepoEgoUp:950920683456716850>", -- :peepoEgoUp:
        ["󰃄"] = "<:whaskaCELO:1222905393571696721>", -- :whaskaCELO:
        ["󰂳"] = "<:lulw:721771709119725638>", -- :lulw:
        ["󰂡"] = "<:D_:799323543216062474>", -- :D_:
        ["󰂠"] = "<:Clueless:998708758425378846>", -- :Clueless:
        -- Animated Emojis
        ["󰃢"] = "<a:vibing_cat:779688822401138688>", -- :vibing_cat:
        ["󰃘"] = "<a:PepeLaughs:759962864127180812>", -- :PepeLaughs:
        ["󰃕"] = "<a:Huh:813330918316048414>", -- :Huh:
        ["󰃡"] = "<a:tumtum:871808235068354611>", -- :tumtum:
        ["󰃝"] = "<a:burn:724400307529842740>", -- :burn:
        ["󰃙"] = "<a:PoggiesFast:815524206791360533>", -- :PoggiesFast:
        ["󰃠"] = "<a:peepoHey:932222156677464094>", -- :peepoHey:
        ["󰃖"] = "<a:Jam:797579041875034144>", -- :Jam:
        ["󰃗"] = "<a:PepeKek:690414482911920218>", -- :PepeKek:
        ["󰃛"] = "<a:aware:932052586377392178>", -- :aware:
        ["󰃞"] = "<a:clap:890633018497171547>", -- :clap:
        ["󰃟"] = "<a:eyes:425228613915508736>", -- :eyes:
        ["󰃚"] = "<a:TeaTime:872170648183648267>", -- :TeaTime:
        ["󰃜"] = "<a:bongocat:779690867706953758>", -- :bongocat:
        --- @AUTOGENERATE CONTENT END UTF8_TO_DISCORD
    }
}

--- @enum EMOJIS.PACK_TYPE
EMOJIS.PACK_TYPE = {
    CLASSIC = "CLASSIC",
    ANIMATED = "ANIMATED"
}

EMOJIS.PACKS = {
    DISCORD = {
        [EMOJIS.PACK_TYPE.ANIMATED] = "discord_emojis_animated",
        [EMOJIS.PACK_TYPE.CLASSIC]  = "discord_emojis",
    },
}

EMOJIS.PACK_CHAR_MAP = {
    [EMOJIS.PACKS.DISCORD[EMOJIS.PACK_TYPE.ANIMATED]] = EMOJIS.ANIMATED.DISCORD,
    [EMOJIS.PACKS.DISCORD[EMOJIS.PACK_TYPE.CLASSIC]] = EMOJIS.DISCORD,
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

EMOJIS.VANILLA = {}
EMOJIS.INPUTNAME_TO_ID = {}
EMOJIS.VANILLA_ITEMS = EMOJI_ITEMS -- This should be the untouched version from emoji_items.lua
for emoji_id, emojis in pairs(EMOJIS.VANILLA_ITEMS) do
    EMOJIS.VANILLA[emoji_id] = emojis.data.utf8_str
    EMOJIS.INPUTNAME_TO_ID[emojis.input_name] = emoji_id
end

EMOJIS.ALL = MergeMaps(EMOJIS.VANILLA, EMOJIS.DISCORD, EMOJIS.ANIMATED.DISCORD)

EMOJIS.DATA = PEARL.loadfile("constants/generated/emoji_data", nil, nil, function(...)
    PEARL.error(...)
end) or {}

EMOJIS.UTF_TO_NAME = {}
for name, utf in pairs(EMOJIS.ALL) do
    EMOJIS.UTF_TO_NAME[utf] = name
end

--- @param emoji_id string
--- @param userid string? Defaults to TheNet:GetUserID()
--- @return boolean
function EMOJIS.IsEmojiOwnedBy(emoji_id, userid)
    if not EMOJIS.IsEmojiVanilla(emoji_id) then
        return true -- For custom emojis we do not have any ownership logic yet.
    end

    if emoji_id ~= nil then
        userid = userid or TheNet:GetUserID()
        if TheWorld ~= nil and userid ~= nil and TheWorld.ismastersim then
            return TheInventory:CheckClientOwnership(userid, emoji_id)
        elseif userid == TheNet:GetUserID() then
            return TheInventory:CheckOwnership(emoji_id)
        end
    end

    return false
end

function EMOJIS.IsEmojiAnimated(emoji_id)
    return emoji_id and io.exists(MODROOT.."/anim/"..emoji_id..".zip") == true
end

function EMOJIS.EmojifyForDiscord(s)
    return (s:gsub(PEARL.CONSTS.UTF_EMOJI_PATTERN, PEARL.EMOJIS.UTF_TO_DISCORD))
end

--- Converts emoji names (e. g. ":salt:") in a string to their corresponding utf8 emoji characters.
function EMOJIS.EmojifyGameString(s)
    return s:gsub(PEARL.CONSTS.GAME_EMOJI_ALIAS_MATCH, function(char)
        return PEARL.EMOJIS.DISCORD[char] or PEARL.EMOJIS.ANIMATED.DISCORD[char]
    end)
end

function EMOJIS.EmojifyForGame(s)
    return (s:gsub(PEARL.CONSTS.DISCORD_EMOJI_PATTERN, PEARL.EMOJIS.DISCORD_TO_UTF)
            :gsub(PEARL.CONSTS.UNICODE_EMOJI_PATTERN, function(match)
                return PEARL.EMOJIS.DISCORD_TO_UTF[match] or ":UNKNOWN_EMOJI:"
            end))
end

function EMOJIS.GetPackForEmoji(emoji_id)
    for pack_name, char_map in pairs(EMOJIS.PACK_CHAR_MAP) do
        if EMOJIS.IsEmojiPackAvailable(pack_name) and char_map[emoji_id] ~= nil then
            return pack_name
        end
    end
end

function EMOJIS.IsEmojiVanilla(emoji_id)
    return EMOJIS.VANILLA[emoji_id] ~= nil
end

function EMOJIS.IsEmojiPackAvailable(pack_name)
    return PEARL.CONFIG.CUSTOM_EMOJI_PACKS[pack_name] == true
end

function EMOJIS.IsEmojiAvailable(emoji_id)
    local emoji_data = PEARL.EMOJIS.DATA[emoji_id]
    return emoji_data ~= nil and emoji_data.available ~= false
    and EMOJIS.UTF_TO_NAME[emoji_data.utf8_str] ~= nil and (
        EMOJIS.GetPackForEmoji(emoji_id) ~= nil or EMOJIS.IsEmojiVanilla(emoji_id)
    )
end

function EMOJIS.IsEmojiPackAnimated(pack_name)
    for _, category in pairs(EMOJIS.PACKS) do
        if category[EMOJIS.PACK_TYPE.ANIMATED] == pack_name then
            return true
        end
    end

    return false
end

function EMOJIS.IsAnyAnimatedEmojiPackEnabled()
    for _, category in pairs(EMOJIS.PACKS) do
        for pack_type, pack_name in pairs(category) do
            if pack_type == EMOJIS.PACK_TYPE.ANIMATED and EMOJIS.IsEmojiPackAvailable(pack_name) then
                return true
            end
        end
    end

    return false
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
