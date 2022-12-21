
local MARKDOWN = require("libraries/markdown")

------------------------------------
-- Mod Specific Strings
--- @TODO Solve the problem with markdown in strings.
STRINGS.PEARL = {
    ACTIONS     = {
        -- Prefer subftm over string.format when there are multiple versions
        EAT                     = "%s ate %s!",
        FEED                    = "%s feed %s with %s!",
        BURNTUP                 = "%s burnt up!",
        HAMMER                  = "%s destroyed %s!",
        TURNOFF                 = "%s turned off %s!",
        TURNON                  = "%s turned on %s!",

        TAKE_ITEM = {
            GENERIC     = "{doer} took {item}!",
            FROM        = "{doer} took {items} from {target}!",
        },

        KILL = {
            GENERIC     = "{doer} killed {target}!",
            NEAR        = "{doer} killed {target} near {near}!",
            MONITORED   = "{doer} killed {target}! Remaining: {remaining}",
            FOLLOWER    = "{doer} killed {target}! Owner: {owner}",
            BOSS        = "{doer} defeated {target}!"
        },

        IGNITE = {
            GENERIC     = "{doer} lit {target}!",
            NEAR        = "{doer} lit {target} near {near}!",
        },

        CAST = {
            NEAR        = "{doer} used {item} near {near}!",
            ON          = "{doer} used {item} on {target}!",
            ON_NEAR     = "{doer} used {item} on {target} near {near}!",
        },

        BUILD = {
            GENERIC     = "{doer} built {target}!",
            NEAR        = "{doer} built {target} near {near}!",
        },

        DEPLOY = {
            GENERIC     = "{doer} placed {item}!",
            NEAR        = "{doer} placed {item} near {near}!",
        },
    },

    LOGS        = {
        --PLAYER_COUNT            = "%s Total players: %d/%d", -- Not needed currently
        OWNER                   = "%s Owner: %s",
        ITEM                    = "%dx %s",
        AND                     = "%s and %s",
        TAG                     = "[%s]",
        ANNOUNCEMENT            = "Announcement",

        INV_REPORT_TITLE        = "%s %s's Inventory",
        INV_REPORT_EMPTY        = "*Loading failed or the inventory is empty.*",
        INV_REPORT_ITEM_RARE    = "**%dx %s (\"%s\")**",
        INV_REPORT_ITEM         = MARKDOWN.codeline("%dx").." "..MARKDOWN.codeline("%s").." "..MARKDOWN.codeline("(\"%s\")"),

        SAY                     = MARKDOWN.bold("%s")..": %s",
        SAY_COMMAND             = MARKDOWN.bold("%s")..": "..MARKDOWN.codeline("/%s"),
        -- STRINGS.UI.CHATINPUTSCREEN.WHISPER_DESIGNATOR
        SAY_WHISPER             = STRINGS.UI.CHATINPUTSCREEN.WHISPER_DESIGNATOR.." "..MARKDOWN.bold("%s")..": "..MARKDOWN.italic("%s"),
        CONNECTION_CLOSE        = "Connection for %s was closed -> %s",
        CONSOLE_CMD             = "%s executed remote command:\n```lua\n%s```",
        AUTH                    = "%s authenticated as %s",
        --- @TODO Rework these to use CONNECTION_CLOSE with a custom reason instead
        --NOT_WHITELISTED         = "%s nieje na zozname povolených hráčov! Prístup na server bol zamietnutý.",
        --BANNED_ROOT_CLIENT      = "%s identifikovaný ako alternatívny účet blokovaného hráča %s! Prístup na server pre tento účet bol zakázaný.",
        DISCONNECT              = "%s was disconnected from shard %s.",
        DISCONNECT_UNEXPECTED   = "%s was unexpectedly disconnected from shard %s.",
        DISCONNECT_REASON       = "%s was disconnected from shard %s. %s",
        CAVES_STATE_UPDATE      = "Secondary shard Caves has been %s.",
        MIGRATING               = "%s migruje do %s.",
        WARNED                  = "%s was warned for griefing!",
        SKIN_RECEIVED           = "%s received %s!",
        DAY                     = "Day %d - %s (%s °C)",
        PHASE                   = "%s",

        START_VOTE              = "%s started %s.",
        START_VOTE_ANONYMOUS    = "%s started.",
        STOP_VOTE               = "The vote was stopped.",

        NEW_PLAYER_SPAWN        = "%s entered the constant as %s",

        RESET_COUNTDOWN_START   = "World reset countdown has started!",
        RESET_COUNTDOWN_STOP    = "World reset countdown has stopped.",

        AUTO_UPDATE_FIRST       = "Server's version is outdated, new players aren't able to connect. It will be automatically updated in %s seconds.",
        AUTO_UPDATE_FIRST_DIS   = "Server's version is outdated, new players aren't able to connect.",
        AUTO_UPDATE_SECOND      = "Server will be automatically updated in 15 seconds. All your current progress will remain untouched. Don't forget to update your game as well :)",
        AUTO_UPDATE_START       = "Updating the server to version %s...",

        GAME_LOADED             = "Shard %s was loaded.",
        RESTART                 = "Rastarting the server...",
        ROLLBACK                = "Rolling server %d snapshots back!",
        RESET                   = "Regenerating the world on %s.",
        SHUTDOWN                = "Shutting down %s...",
        START                   = "Starting the server...",
        SERVER_REPORT           = MARKDOWN.bold("<@&%s> Server Report:\n")..MARKDOWN.codeblock("%s"),
        STATUS_CODE_REPORT      = "STATUS_CODE -> %d:\n%s",

        SERVER_AUTOPAUSE        = "Server was autopaused.",
        SERVER_PAUSE_BY         = "Server was paused by %s.",
        SERVER_PAUSE            = "Server was paused.",
        SERVER_UNPAUSE          = "Server was unpaused.",
        SERVER_STARTED          = "Server successfully started on version %s!",

        SIM_PAUSED              = "Simulation was paused.",
        SIM_UNPAUSED            = "Simulation was unpaused.",

        EXTINGUISH              = "Fires were extinguished!",
        EXTINGUISH_NEAR         = "Fire near %s were extinguished!",
        EXTINGUISH_ALL          = "%s extinguished fires near all players!",

        REPAIR                  = "Burnt structures were restored!",
        REPAIR_NEAR             = "Burnt structures near %s were restored!",
        REPAIR_ALL              = "%s restored burnt structures near all players!",

        -- Anti AFK system
        USER_ACTIVE             = "%s came back!",
        USER_INACTIVE           = "%s went away...",
        USER_INACTIVE_KICKED    = "%s was kicked for inactivity.",

        STARTUP_EMBED_THUMBNAIL_URL = "https://cdn.discordapp.com/attachments/662636816091971604/1038563863282581584/dedicated.png",
        STARTUP_EMBED_TITLE     = "Server Launched",
        STARTUP_EMBED_FIELD_NAMES = {
            PLATFORM    = "Plaform",
            GAME_V      = "Game Version",
            MOD_V       = "Mod Version",
            SEED        = "World Seed",
            PLAYSTYLE   = "Playstyle",
        },
    },

    SHARD_STATE             = {
        CONNECTED           = "connected",
        DISCONNECTED        = "disconnected",
    },

    SEASON_PREFIX_LATE        = {
        ["spring"] = "Late",
        ["summer"] = "Late",
        ["autumn"] = "Late",
        ["winter"] = "Late",
    },

    SEASON_PREFIX_EARLY       = {
        ["spring"] = "Early",
        ["summer"] = "Early",
        ["autumn"] = "Early",
        ["winter"] = "Early",
    },

    SEASON_UNKNOWN          = "Unknown Season",

    UI = {
        -- Mod blocker popup
        MODS_BLOCKED_TITLE = "Mods Blocked",
        MODS_BLOCKED_BODY  = "Some of the mods you are using were blocked by the server.",

        TIP_TOGGLE_CHAT = "Anytime you get bored with the chat, don't forget that {toggle} will toggle it for you!",

        BUILTINCOMMANDS = {
            FIRE = {
                PRETTYNAME = "Extinguish Fires",
                DESC       = "When a nasty griefer appears, this can safe your base from fire!",
            },

            REPAIR = {
                PRETTYNAME = "Repair Structures",
                DESC       = "Brings back structures that were engulfed in fire.",
            },

            UNBAN = {
                PRETTYNAME = "Unban",
                DESC       = "Removes the given player from the blocklist. Accepts both, Klei ID and Steam ID as player_id argument.",

                ON_SUCCESS  = "ID %s bolo úspešne odstránené zo zoznamu blokovaných hráčov!\nHráč s týmto ID sa môže znova pripojiť na server.",
                ON_NOTFOUND = "Zadané ID nieje na zozname...",
            },

            INV = {
                PRETTYNAME = "Display Inventory",
                DESC       = "Displays player's inventory on discord.",

                ON_SUCCESS  = "Inventár hráča bol odoslaný na discord.",
                ON_NOTFOUND = "Inventár zadaného hráča je prázdny alebo neexistuje...",
            },

            INV_FIND = {
                PRETTYNAME = "Find Inventory",
                DESC       = "Searches for inventory containing specified item.",
            },

            WHITELIST_ADD = {
                PRETTYNAME = "Add to whitelist",
                DESC       = "Whitelists the given player id.",

                ON_ALREADY_WHITELISTED = "Zadané ID už na zozname je.",
                ON_SUCCESS = "Bol povolený prístup na tento server pre hráča s ID %s.",
                ON_FAILURE = "Nebolo možné uložiť zmeny...",
                ON_BANNED = "Zadané ID je na zozname blokovaných.",
                ON_DISABLED = "Whitelist je aktuálne vypnutý.",
            },

            WHITELIST_REMOVE = {
                PRETTYNAME = "Remove from whitelist",
                DESC       = "Attempts to remove the given player id from the whitelist.",

                ON_SUCCESS = "ID odstránené zo zoznamu.",
                ON_DISABLED = "Whitelist je aktuálne vypnutý.",
                ON_FAILURE = "Nebolo možné uložiť zmeny...",
                ON_NOTFOUND = "Zadané ID nieje na zozname."
            },
        },

        DISCORD_BUTTON_HOVER = "View Discord",

        INTRO_POPUP_BUTTON_CONTINUE = "Continue",
        AGREEMENT_SCREEN_BUTTON_FINISH = "Finish",
        AGREEMENT_SCREEN_BUTTON_AGREE = "I agree",
        AGREEMENT_SCREEN_BUTTON_DISAGREE = "I disagree",
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

------------------------------------
-- Custom Disconnection Popups

PEARL.AddNetworkDisconnectPopupStrings("ID_DST_USER_INACTIVE",
    "Disconnected",
    "You have been disconnected from the server for long inactivity.\nFeel free to reconnect when you get back."
)

PEARL.AddNetworkDisconnectPopupStrings("ID_DST_USER_NOT_ALLOWED",
    "Not Whitelisted",
    "This server currently uses a whitelist you are not on."
)

PEARL.AddNetworkDisconnectPopupStrings("ID_DST_MODS_PROHIBITED",
    "Disconnected",
    "You are using mods that are not allowed on this server.\nPlease disable them and try again."
)

PEARL.AddNetworkDisconnectPopupStrings("ID_DST_LOCALE_BLOCKED",
    "Community Server",
    "This server currently only allows connections\nfrom the Czech Republic and Slovakia."
)
