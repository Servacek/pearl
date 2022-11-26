STRINGS.PEARL_SK = {
    ----------------------------------
    -- [[ ACTIONS ]]
    ----------------------------------

    -- Prefer subftm over string.format when there are multiple versions
    EAT                     = "%s zjedol/la %s!",
    FEED                    = "%s nakŕmil/a %s s %s!",
    BURNTUP                 = "Zhorel/a %s!",
    HAMMER                  = "%s rozbil/a %s!",
    TURNOFF                 = "%s odstavil/a %s!",
    TURNON                  = "%s spustil/a %s!",

    TAKE_ITEM = {
        GENERIC     = "{doer} vzal/a {count}x {item}!",
        FROM        = "{doer} vzal/a {items} z {target}!",
    },

    KILL = {
        GENERIC     = "{doer} zabil/a {target}!",
        NEAR        = "{doer} zabil/a {target} pri {near}!",
        MONITORED   = "{doer} zabil/a {target}! Ostáva: {remaining}",
        FOLLOWER    = "{doer} zabil/a {target}! Majiteľ: {owner}",
    },

    IGNITE = {
        GENERIC     = "{doer} zapálil/a {target}!",
        NEAR        = "{doer} zapálil/a {target} pri {near}!",
    },

    CAST = {
        NEAR        = "{doer} použil/a {item} pri {near}!",
        ON          = "{doer} použil/a {item} na {target}!",
        ON_NEAR     = "{doer} použil/a {item} na {target} pri {near}!",
    },

    BUILD = {
        GENERIC     = "{doer} postavil/a {target}!",
        NEAR        = "{doer} postavil/a {target} pri {near}!",
    },

    DEPLOY = {
        GENERIC     = "{doer} položil/a {item}!",
        NEAR        = "{doer} položil/a {item} v blízkosti {near}!",
    },

    -------------------------------------------------------

    --PLAYER_COUNT            = "%s Total players: %d/%d", -- Not needed currently
    OWNER                   = "%s Majiteľ: %s",
    ITEM                    = "%dx %s",
    AND                     = "a",
    TAG                     = "[%s]",
    ANNOUNCEMENT            = "Oznam",

    INV_REPORT_TITLE        = "%s Inventár hráča %s",
    INV_REPORT_EMPTY        = string.italic("Inventár nebolo možné načítať alebo je prázdny..."),
    INV_REPORT_ITEM_RARE    = string.bold("%dx %s (\"%s\")"),
    INV_REPORT_ITEM         = string.codeline("%dx").." "..string.codeline("%s").." "..string.codeline("(\"%s\")"),

    SAY                     = string.bold("%s")..": %s",
    SAY_COMMAND             = string.bold("%s")..": "..string.codeline("/%s"),
    -- STRINGS.UI.CHATINPUTSCREEN.WHISPER_DESIGNATOR
    SAY_WHISPER             = STRINGS.UI.CHATINPUTSCREEN.WHISPER_DESIGNATOR.." "..string.bold("%s")..": "..string.italic("%s"),
    CONNECTION_CLOSE        = "Pripojenie od %s bolo prerušené -> %s",
    CONSOLE_CMD             = string.codeline("%s použil/a príkaz v konzole ->\n")..string.codeblock("%s"),
    AUTH                    = "%s autentifikované ako %s",
    NOT_WHITELISTED         = "%s nieje na zozname povolených hráčov! Prístup na server bol zamietnutý.",
    BANNED_ROOT_CLIENT      = "%s identifikovaný ako alternatívny účet blokovaeho hráča %s! Prístup na server pre tento účet bol zakázaný.",
    DISCONNECT              = "%s bol/a odpojený/á od shardu %s.",
    DISCONNECT_UNEXPECTED   = "%s bol/a neočakávane odpojený/á od shardu %s.",
    DISCONNECT_REASON       = "%s bol/a odpojený/á od shardu %s. %s",
    CAVES_STATE_UPDATE      = "Sekundárny shard Caves (%s) bol %s!",
    MIGRATING               = "%s migruje do %s.",
    WARNED                  = "%s bol/a varovaný/á za griefing!",
    SKIN_RECEIVED           = "%s získal/a %s!",
    DAY                     = "Deň %d - %s (%s °C)",
    PHASE                   = "%s %s",

    START_VOTE              = "%s spustil %s.",
    START_VOTE_ANONYMOUS    = "Bolo spustené %s.",
    STOP_VOTE               = "Hlasovanie bolo zrušené.",

    NEW_PLAYER_SPAWN        = "%s vstúpil/a do konštanty ako %s",

    RESET_COUNTDOWN_START   = "Odpočet pre automatické regenerovanie sveta bol spustený.",
    RESET_COUNTDOWN_STOP    = "Odpočet pre automatické regenerovanie sveta bol zrušený.",

    SHARD_STATE             = {
        CONNECTED           = "pripojený",
        DISCONNECTED        = "odpojený",
    },

    SEASON_PREFIX_LATE        = {
        ["spring"] = "Neskorá",
        ["summer"] = "Neskoré",
        ["autumn"] = "Neskorá",
        ["winter"] = "Neskorá",
    },

    SEASON_PREFIX_EARLY       = {
        ["spring"] = "Skorá",
        ["summer"] = "Skoré",
        ["autumn"] = "Skorá",
        ["winter"] = "Skorá",
    },

    SEASON_UNKNOWN          = "Neznáma Sezóna",

    AUTO_UPDATE_FIRST       = "Verzia servera je zastaralá, nový hráči sa nebudú môcť pripojiť. Server bude automaticky aktualizovaný o %s minút.",
    AUTO_UPDATE_FIRST_DIS   = "Verzia servera je zastaralá, nový hráči sa nebudú môcť pripojiť.",
    AUTO_UPDATE_SECOND      = "Ostáva 15 sekúnd do automatickej aktualizácie servera. Progres aktuálneho sveta bude zachovaný. Nezbudnite si aktualizovať aj vašu hru :)",
    AUTO_UPDATE_START       = "Aktualizovanie servera na verziu %s...",

    GAME_LOADED             = "Načítavanie shardu %s dokočené.",
    RESTART                 = "Reštartovanie shardu %s...",
    ROLLBACK                = "Server bude vrátený o %d záznam/y/ov späť.",
    RESET                   = "Regenerovanie sveta pre shard %s...",
    SHUTDOWN                = "Vypínanie shardu %s...",
    START                   = "Spúšťanie servera...",
    SERVER_REPORT           = string.bold("<@&%s> Server Report:\n")..string.codeblock("%s"),
    STATUS_CODE_REPORT      = "STATUS_CODE -> %d:\n%s",

    SERVER_AUTOPAUSE        = "Server bol automaticky pozastavený.",
    SERVER_PAUSE_BY         = "%s pozastavil/a server.",
    SERVER_PAUSE            = "Server bol pozastavený.",
    SERVER_UNPAUSE          = "Pozastavenie servera bolo zrušené.",
    SERVER_STARTED          = "Server bol úspešne spustený na verzii %s!",

    SIM_PAUSED              = "Simulácia bola pozastavená.",
    SIM_UNPAUSED            = "Simulácia bola obnovená.",

    EXTINGUISH              = "Ohne boli uhasené!",
    EXTINGUISH_NEAR         = "Ohne v blízkosti hráča %s boli uhasené!",

    -- Anti AFK system
    USER_ACTIVE             = "%s je späť!",
    USER_INACTIVE           = "%s je preč.",
    USER_INACTIVE_KICKED    = "%s bol/a vyhodený/á pre neaktivitu.",

    UI = {
        -- Mod blocker popup
        MODS_BLOCKED_TITLE = "Mods Blocked",
        MODS_BLOCKED_BODY  = "Some of your mods couldn't be loaded because the server doesn't allow them.",

        TIP_TOGGLE_CHAT = "Anytime you get bored with the chat, don't forget that {toggle} will toggle it for you!",
    },

    GRIEFER_WARNINGS        = {
        [1] = {
            [1] = "Oops?!",
            [2] = "Does Charlie saw that?!",
            [3] = "Wait, isn't this griefing?",
            [4] = "Maybe I should calm down a bit...",
            [5] = "My compatriots would be mad at me!",
        },

        [2] = {
            [1] = "This could end badly...",
            [2] = "I've made enough of a mess!",
            [3] = "What have I done?!",
            [4] = "I'm starting to hear some strange voices.",
            [5] = "Looks like someone is getting really mad at me!"
        },

        BAN = "There we go again...",
    },
}
