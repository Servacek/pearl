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
            ["5770pepecheers"] = "󰄃",
            ["ClaudyTumTum"] = "󰄄",
            ["DinkDonk"] = "󰄅",
            ["Huh"] = "󰄆",
            ["Jam"] = "󰄇",
            ["PepeKek"] = "󰄈",
            ["PepeLaughs"] = "󰄉",
            ["PoggiesFast"] = "󰄊",
            ["SadgeCry"] = "󰄋",
            ["TeaTime"] = "󰄌",
            ["Tiktok"] = "󰄍",
            ["aware"] = "󰄎",
            ["blobcathug"] = "󰄏",
            ["bongocat"] = "󰄐",
            ["burn"] = "󰄑",
            ["charmander_dancing"] = "󰄒",
            ["clap"] = "󰄓",
            ["eyes"] = "󰄔",
            ["jolteon"] = "󰄕",
            ["peepoHey"] = "󰄖",
            ["peepoukr"] = "󰄗",
            ["petTheCloudy"] = "󰄘",
            ["rohliktumtum"] = "󰄙",
            ["thisisfine"] = "󰄚",
            ["tumtum"] = "󰄛",
            ["vibing_cat"] = "󰄜",
            --- @AUTOGENERATE CONTENT END ANIMATED_DISCORD_NAME_TO_UTF8
        },
    },

    DISCORD = { -- These are not used in code so the lowered down version is enough.
        --- @AUTOGENERATE CONTENT START DISCORD_NAME_TO_UTF8
        ["Clueless"] = "󰂠",
        ["D_"] = "󰂡",
        ["HYPERS"] = "󰂢",
        ["ICANT"] = "󰂣",
        ["Instagram"] = "󰂤",
        ["KEKW"] = "󰂥",
        ["MonkaKristus"] = "󰂦",
        ["PauseChamp"] = "󰂧",
        ["PepeLaugh"] = "󰂨",
        ["Pog"] = "󰂩",
        ["Sir"] = "󰂪",
        ["WX_78"] = "󰂫",
        ["Walter"] = "󰂬",
        ["Warly"] = "󰂭",
        ["Webber"] = "󰂮",
        ["Wendy"] = "󰂯",
        ["Wes"] = "󰂰",
        ["Wickerbottom"] = "󰂱",
        ["Wigfrid"] = "󰂲",
        ["Wilson"] = "󰂳",
        ["Winona"] = "󰂴",
        ["Wolfgang"] = "󰂵",
        ["Woodie"] = "󰂶",
        ["Wormwood"] = "󰂷",
        ["Wortox"] = "󰂸",
        ["Wurt"] = "󰂹",
        ["anojdgurl"] = "󰂺",
        ["cat_angry"] = "󰂻",
        ["catto"] = "󰂼",
        ["conceited_reaction"] = "󰂽",
        ["coolpepe"] = "󰂾",
        ["copium"] = "󰂿",
        ["cz"] = "󰃀",
        ["doge"] = "󰃁",
        ["doge_kek"] = "󰃂",
        ["doublefacepalm"] = "󰃃",
        ["ds_Maxwell"] = "󰃄",
        ["ds_Willow"] = "󰃅",
        ["ds_free_real_estate"] = "󰃆",
        ["ds_noice"] = "󰃇",
        ["ds_takjo"] = "󰃈",
        ["ds_watching"] = "󰃉",
        ["ds_webber_damage"] = "󰃊",
        ["ds_wes_annoyed"] = "󰃋",
        ["ds_wesluv"] = "󰃌",
        ["ds_wigfrid_ping"] = "󰃍",
        ["ds_willowkys"] = "󰃎",
        ["ds_wilson_thong"] = "󰃏",
        ["ds_wilson_why"] = "󰃐",
        ["facepalm"] = "󰃑",
        ["feelsHangMan"] = "󰃒",
        ["gooddoggo"] = "󰃓",
        ["harold"] = "󰃔",
        ["heh"] = "󰃕",
        ["kappa"] = "󰃖",
        ["kekleo"] = "󰃗",
        ["krtek_ewww"] = "󰃘",
        ["lul"] = "󰃙",
        ["madge"] = "󰃚",
        ["monkaChrist"] = "󰃛",
        ["monkaHmm"] = "󰃜",
        ["monkaMEGA"] = "󰃝",
        ["monkaS"] = "󰃞",
        ["monkaStop"] = "󰃟",
        ["nailsing"] = "󰃠",
        ["notlikethis"] = "󰃡",
        ["okayge"] = "󰃢",
        ["omegalul"] = "󰃣",
        ["pea"] = "󰃤",
        ["peepoEgoUp"] = "󰃥",
        ["peepoblanket"] = "󰃦",
        ["peepolove"] = "󰃧",
        ["peepothink"] = "󰃨",
        ["pepeHands"] = "󰃩",
        ["pepecool"] = "󰃪",
        ["planetHug"] = "󰃫",
        ["risitas"] = "󰃬",
        ["sadge"] = "󰃭",
        ["sk"] = "󰃮",
        ["skill_issue"] = "󰃯",
        ["stare"] = "󰃰",
        ["twitch"] = "󰃱",
        ["wanda"] = "󰃲",
        ["whaskaBACK"] = "󰃳",
        ["whaskaBIGBRAIN"] = "󰃴",
        ["whaskaCELO"] = "󰃵",
        ["whaskaHI"] = "󰃶",
        ["whaskaHYPE"] = "󰃷",
        ["whaskaJAM"] = "󰃸",
        ["whaskaLOVE"] = "󰃹",
        ["whaskaLUL"] = "󰃺",
        ["whaskaLURK"] = "󰃻",
        ["whaskaRIP"] = "󰃼",
        ["whaskaSAD"] = "󰃽",
        ["whaskaSELLOUT"] = "󰃾",
        ["whaskaTUMTUM"] = "󰃿",
        ["xdd"] = "󰄀",
        ["yeah"] = "󰄁",
        ["youtube"] = "󰄂",
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
        ["󰂫"] = "<:WX_78:700037741915799688>", -- :WX_78:
        ["󰃇"] = "<:ds_noice:779689296902094889>", -- :ds_noice:
        ["󰃅"] = "<:ds_Willow:700037117220487228>", -- :ds_Willow:
        ["󰃯"] = "<:skill_issue:1216792672891834558>", -- :skill_issue:
        ["󰃴"] = "<:whaskaBIGBRAIN:1320810664813400105>", -- :whaskaBIGBRAIN:
        ["󰃸"] = "<:whaskaJAM:1320810671859962058>", -- :whaskaJAM:
        ["󰂨"] = "<:PepeLaugh:928727675760181258>", -- :PepeLaugh:
        ["󰃈"] = "<:ds_takjo:779345130112286730>", -- :ds_takjo:
        ["󰃼"] = "<:whaskaRIP:1320810681871892591>", -- :whaskaRIP:
        ["󰃐"] = "<:ds_wilson_why:685925800448753672>", -- :ds_wilson_why:
        ["󰂮"] = "<:Webber:700036289822457947>", -- :Webber:
        ["󰃞"] = "<:monkaS:928727675693043782>", -- :monkaS:
        ["󰂢"] = "<:HYPERS:1118210148557656204>", -- :HYPERS:
        ["󰄁"] = "<:yeah:824195462264651788>", -- :yeah:
        ["󰂴"] = "<:Winona:700037278533156895>", -- :Winona:
        ["󰃦"] = "<:peepoblanket:799323742563729449>", -- :peepoblanket:
        ["󰂱"] = "<:Wickerbottom:700036552067252378>", -- :Wickerbottom:
        ["󰂼"] = "<:catto:765936051905888317>", -- :catto:
        ["󰃢"] = "<:okayge:928730454633381918>", -- :okayge:
        ["󰃿"] = "<:whaskaTUMTUM:1320810694601347083>", -- :whaskaTUMTUM:
        ["󰃉"] = "<:ds_watching:768799989060861952>", -- :ds_watching:
        ["󰂩"] = "<:Pog:1084574485031702629>", -- :Pog:
        ["󰃘"] = "<:krtek_ewww:802953092634378330>", -- :krtek_ewww:
        ["󰂺"] = "<:anojdgurl:726378051012919326>", -- :anojdgurl:
        ["󰃎"] = "<:ds_willowkys:797528101792776192>", -- :ds_willowkys:
        ["󰂥"] = "<:KEKW:729622110183358515>", -- :KEKW:
        ["󰃛"] = "<:monkaChrist:799323679933595688>", -- :monkaChrist:
        ["󰃌"] = "<:ds_wesluv:797532778463756309>", -- :ds_wesluv:
        ["󰃭"] = "<:sadge:928819517176578060>", -- :sadge:
        ["󰃔"] = "<:harold:709677100814303264>", -- :harold:
        ["󰃾"] = "<:whaskaSELLOUT:1320810678608593007>", -- :whaskaSELLOUT:
        ["󰂽"] = "<:conceited_reaction:803675137676673055>", -- :conceited_reaction:
        ["󰃄"] = "<:ds_Maxwell:700036190392418394>", -- :ds_Maxwell:
        ["󰂲"] = "<:Wigfrid:700036639040208957>", -- :Wigfrid:
        ["󰂯"] = "<:Wendy:700036336962502717>", -- :Wendy:
        ["󰃽"] = "<:whaskaSAD:1320810675206881372>", -- :whaskaSAD:
        ["󰃕"] = "<:heh:803360836025450506>", -- :heh:
        ["󰂡"] = "<:D_:799323543216062474>", -- :D_:
        ["󰂣"] = "<:ICANT:1084938163513983041>", -- :ICANT:
        ["󰃰"] = "<:stare:872544999726776391>", -- :stare:
        ["󰃬"] = "<:risitas:797532692731789362>", -- :risitas:
        ["󰃠"] = "<:nailsing:1148965547078324224>", -- :nailsing:
        ["󰃁"] = "<:doge:765929919703679010>", -- :doge:
        ["󰃮"] = "<:sk:1208462378321317960>", -- :sk:
        ["󰃲"] = "<:wanda:885865311105089536>", -- :wanda:
        ["󰃝"] = "<:monkaMEGA:799323692940787772>", -- :monkaMEGA:
        ["󰄂"] = "<:youtube:805085904158720020>", -- :youtube:
        ["󰃪"] = "<:pepecool:928727675592388679>", -- :pepecool:
        ["󰃻"] = "<:whaskaLURK:1320810688293376012>", -- :whaskaLURK:
        ["󰃚"] = "<:madge:928730454679490571>", -- :madge:
        ["󰃳"] = "<:whaskaBACK:1320810661554683914>", -- :whaskaBACK:
        ["󰂹"] = "<:Wurt:700037704427110471>", -- :Wurt:
        ["󰂶"] = "<:Woodie:700037430442590359>", -- :Woodie:
        ["󰂪"] = "<:Sir:798150463315771412>", -- :Sir:
        ["󰂦"] = "<:MonkaKristus:791395487995133952>", -- :MonkaKristus:
        ["󰃫"] = "<:planetHug:928822223987421205>", -- :planetHug:
        ["󰂠"] = "<:Clueless:1320837537996079156>", -- :Clueless:
        ["󰃵"] = "<:whaskaCELO:1222905393571696721>", -- :whaskaCELO:
        ["󰃂"] = "<:doge_kek:709677492939784193>", -- :doge_kek:
        ["󰃶"] = "<:whaskaHI:1320810691426517002>", -- :whaskaHI:
        ["󰃥"] = "<:peepoEgoUp:950920683456716850>", -- :peepoEgoUp:
        ["󰃊"] = "<:ds_webber_damage:686144348110323767>", -- :ds_webber_damage:
        ["󰂷"] = "<:Wormwood:700037502869831721>", -- :Wormwood:
        ["󰃗"] = "<:kekleo:830091874122596386>", -- :kekleo:
        ["󰃣"] = "<:omegalul:984385807026647040>", -- :omegalul:
        ["󰃙"] = "<:lul:799323633704108082>", -- :lul:
        ["󰂾"] = "<:coolpepe:928727676762595378>", -- :coolpepe:
        ["󰃒"] = "<:feelsHangMan:928727675789520966>", -- :feelsHangMan:
        ["󰃋"] = "<:ds_wes_annoyed:685925681397366787>", -- :ds_wes_annoyed:
        ["󰃍"] = "<:ds_wigfrid_ping:686155662304346112>", -- :ds_wigfrid_ping:
        ["󰃑"] = "<:facepalm:765931848030355487>", -- :facepalm:
        ["󰃏"] = "<:ds_wilson_thong:685926128514629667>", -- :ds_wilson_thong:
        ["󰂰"] = "<:Wes:700036508572188693>", -- :Wes:
        ["󰃜"] = "<:monkaHmm:799323660132941884>", -- :monkaHmm:
        ["󰃟"] = "<:monkaStop:799323721054945370>", -- :monkaStop:
        ["󰂤"] = "<:Instagram:803241248772587530>", -- :Instagram:
        ["󰂿"] = "<:copium:928727676041175160>", -- :copium:
        ["󰂳"] = "<:Wilson:700037170785681479>", -- :Wilson:
        ["󰂻"] = "<:cat_angry:765940080568827914>", -- :cat_angry:
        ["󰃨"] = "<:peepothink:799323809018019890>", -- :peepothink:
        ["󰂬"] = "<:Walter:722146045735469187>", -- :Walter:
        ["󰂧"] = "<:PauseChamp:1103419473848979496>", -- :PauseChamp:
        ["󰂵"] = "<:Wolfgang:700037355213684827>", -- :Wolfgang:
        ["󰃡"] = "<:notlikethis:799323730799099945>", -- :notlikethis:
        ["󰃃"] = "<:doublefacepalm:826807100172271707>", -- :doublefacepalm:
        ["󰃷"] = "<:whaskaHYPE:1320810668034752683>", -- :whaskaHYPE:
        ["󰃱"] = "<:twitch:803241054278385674>", -- :twitch:
        ["󰃆"] = "<:ds_free_real_estate:777850333963616277>", -- :ds_free_real_estate:
        ["󰃺"] = "<:whaskaLUL:1320810685097054270>", -- :whaskaLUL:
        ["󰂸"] = "<:Wortox:700035257780666409>", -- :Wortox:
        ["󰃹"] = "<:whaskaLOVE:1320810658731790409>", -- :whaskaLOVE:
        ["󰃖"] = "<:kappa:799323609641779260>", -- :kappa:
        ["󰃧"] = "<:peepolove:799323769268731956>", -- :peepolove:
        ["󰃩"] = "<:pepeHands:799323795755499530>", -- :pepeHands:
        ["󰃓"] = "<:gooddoggo:830090455395074068>", -- :gooddoggo:
        ["󰃤"] = "<:pea:1064606686402318379>", -- :pea:
        ["󰄀"] = "<:xdd:1118216094507860010>", -- :xdd:
        ["󰃀"] = "<:cz:1208462259261808730>", -- :cz:
        ["󰂭"] = "<:Warly:700036121039732757>", -- :Warly:

        -- Animated Emojis
        ["󰄋"] = "<a:SadgeCry:928819814426890320>", -- :SadgeCry:
        ["󰄐"] = "<a:bongocat:1320874535179780166>", -- :bongocat:
        ["󰄖"] = "<a:peepoHey:1320811967249907712>", -- :peepoHey:
        ["󰄄"] = "<a:ClaudyTumTum:934106040880996452>", -- :ClaudyTumTum:
        ["󰄛"] = "<a:tumtum:1320812105435447296>", -- :tumtum:
        ["󰄓"] = "<a:clap:1320811816577925181>", -- :clap:
        ["󰄚"] = "<a:thisisfine:905418828362706964>", -- :thisisfine:
        ["󰄊"] = "<a:PoggiesFast:1320812053019103324>", -- :PoggiesFast:
        ["󰄑"] = "<a:burn:1320811793685417995>", -- :burn:
        ["󰄕"] = "<a:jolteon:928729879833378816>", -- :jolteon:
        ["󰄉"] = "<a:PepeLaughs:1320812021054443550>", -- :PepeLaughs:
        ["󰄇"] = "<a:Jam:1320811940158771281>", -- :Jam:
        ["󰄎"] = "<a:aware:1320811719030870117>", -- :aware:
        ["󰄅"] = "<a:DinkDonk:928820020618874961>", -- :DinkDonk:
        ["󰄍"] = "<a:Tiktok:808745253770231838>", -- :Tiktok:
        ["󰄒"] = "<a:charmander_dancing:928729765689573426>", -- :charmander_dancing:
        ["󰄘"] = "<a:petTheCloudy:928825899976106034>", -- :petTheCloudy:
        ["󰄈"] = "<a:PepeKek:1320811991530471535>", -- :PepeKek:
        ["󰄃"] = "<a:5770pepecheers:928727675969888256>", -- :5770pepecheers:
        ["󰄌"] = "<a:TeaTime:1320812081007689738>", -- :TeaTime:
        ["󰄗"] = "<a:peepoukr:946463001370828871>", -- :peepoukr:
        ["󰄔"] = "<a:eyes:1320811840657297470>", -- :eyes:
        ["󰄜"] = "<a:vibing_cat:1320812141783285880>", -- :vibing_cat:
        ["󰄏"] = "<a:blobcathug:928728971284193280>", -- :blobcathug:
        ["󰄙"] = "<a:rohliktumtum:970740009755902002>", -- :rohliktumtum:
        ["󰄆"] = "<a:Huh:1320811874325102653>", -- :Huh:
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
