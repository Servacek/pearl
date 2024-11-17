--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--[[
    Markdown Policy:
        - Use markdown as little as possible in the strings themselves to keep flexibility.
          (When markdown is used the string becomes unusable outside discord)
        - When markdown has to be used, there is no point in using the library
          since we have to rewrite them in all the translation files anyway.
--]]

-- Note: Prefer %s over %d because sometimes we want to format
-- the number variables as a codeline.

local MARKDOWN = PEARL.loadfile("libs/markdown")

------------------------------------
-- Mod Specific Strings
local STRINGS = {
    ACTIONS     = {
        -- Prefer subftm over string.format when there are multiple versions
        -- Here we use the following order:
        -- 1. The Doer's Display Name
        -- 2. Target Name(s)
        -- 3. Name of the Tool/Item used for the action
        -- The number of parameters can be bigger than needed but not smaller.
        -- We can keep non-stackable actions in this format...
        ACTIVATE                = "%s activated %s!",

        -- Here we do not care about the order at all.
        -- Also not matching every field will not crash.
        TAKE_ITEM = {
            GENERIC     = "{doer} took {target}!",
            FROM        = "{doer} took {target} from {source}!",
            WITH        = "{doer} took {source} with {target}!"
        },

        FEED = {
            GENERIC     = "{doer} feed {target}.",
            WITH        = "{doer} feed {target} with {tool}.",
        },

        DRIED = {
            GENERIC     = "{doer} dried {item}.",
            ON          = "{doer} dried {item} on {target}.",
        },

        EAT = {
            GENERIC     = "{target} has been eaten.",
            DOER        = "{doer} ate {target}.",
            FULL        = "{doer} overeated with {target}."
        },

        HEAL = {
            GENERIC     = "{doer} healed.",
            USING       = "{doer} healed using {tool}.",
            TARGET      = "{doer} healed {target} using {tool}.",
        },

        WOREOUT = {
            GENERIC     = "{target} broke due to low durability.",
            DOER        = "{doer} worn out {target}.",
        },

        CATCH = {
            GENERIC     = "{target} was catched.",
            DOER        = "{doer} catched {target}.",
            DOER_WITH   = "{doer} catched {target} with {tool}.",
        },

        CONSTRUCT = {
            GENERIC     = "{doer} constructed {target}.",
            QUEST       = "{doer} completed quest from {target}.",
        },

        SEW = {
            GENERIC     = "{doer} sewn {target}.",
            USING       = "{doer} sewn {target} using {tool}."
        },

        READ = {
            GENERIC     = "{doer} read {target}.",
            NEAR        = "{doer} read {target} near {near}!",
        },

        WAX = {
            GENERIC     = "{doer} waxed {target}.",
            WITH        = "{doer} waxed {target} with {tool}.",
        },

        UPGRADE = {
            GENERIC     = "{doer} upgraded {target}.",
            WITH        = "{doer} upgraded {target} with {tool}.",
        },

        TEACH = {
            GENERIC     = "{doer} learnt {target}.",
        },

        COOK = {
            GENERIC     = "{doer} cooked {target}.",
            ON          = "{doer} cooked {target} on {tool}.",
            IN          = "{doer} cooked {target} in {tool}.",
        },

        EXTINGUISH = {
            GENERIC     = "{doer} extinguished {target}.",
            WITH        = "{doer} extinguished {target} using {tool}.",
        },

        KILL = {
            GENERIC     = "{doer} killed {target}!",
            STRUCTURE   = "{doer} destroyed {target}!",
            NEAR        = "{doer} killed {target} near {near}!",
            REMAINING   = "{doer} killed {target}! Remaining: {remaining}",
            LAST        = "{doer} killed the last {target}!",
            FOLLOWER    = "{doer} killed {target}! Owner: {owner}",
            BOSS        = "{doer} defeated {target}!",
            BOSS_DOERS  = "{doer} defeated {target}!",
            NODOER      = "{target} was killed!",
            NODOERNEAR  = "{target} was killed near {near}!"
        },

        CHOP = {
            GENERIC     = "{doer} chopped down {target}.",
        },

        IGNITE = {
            GENERIC     = "{doer} lit {target}!",
            NEAR        = "{doer} lit {target} near {near}!",
        },

        CAST = {
            GENERIC     = "{doer} used {item}!",
            NEAR        = "{doer} used {item} near {near}!",
            ON          = "{doer} used {item} on {target}!",
            ON_OWNERED  = "{doer} used {item} on {target}! Owner: {owner}",
            ON_NEAR     = "{doer} used {item} on {target} near {near}!",
            ON_OWN_NEAR = "{doer} used {item} on {target} near {near}! Owner: {owner}"
        },

        BUILD = {
            GENERIC     = "{doer} built {target}.",
            NEAR        = "{doer} built {target} near {near}.",
        },

        GIVE = {
            GENERIC     = "{doer} gave {tool} to {target}.",
        },

        SLEEP = {
            GENERIC     = "{doer} slept in {target}."
        },

        DEPLOY = {
            GENERIC     = "{doer} placed {item}!",
            NEAR        = "{doer} placed {item} near {near}!",
        },

        PLANT = {
            GENERIC     = "{doer} planted {target}.",
            IN          = "{doer} planted {target} in {source}.",
        },

        FERTILIZE = {
            GENERIC     = "{doer} fertilized {target}.",
            FIELD       = "{doer} fertilized the field.",
            WITH        = "{doer} fertilized {target} with {item}.",
            FIELD_WITH  = "{doer} fertilized the field with {item}."
        },

        DIG = {
            GENERIC     = "{doer} dug up {target}.",
        },

        ADDFUEL = {
            GENERIC     = "{doer} added {target} to {source}.",
            NEAR        = "{doer} added {target} to {source} near {near}!",
            WASTE       = "{doer} wasted {target} to {source}!",
        },

        CRAFT = {
            GENERIC     = "{doer} constructed {target}."
        },

        DESTROY = {
            GENERIC     = "{doer} destroyed {target}.",
            IN          = "{doer} destroyed {target} in {source}."
        },

        BURNTUP = {
            GENERIC     = "{target} burnt up!",
            OWNED       = "{target} burnt up! Owner: {owner}"
        },

        HAMMER = {
            GENERIC     = "{doer} hammered down {target}!",
            OWNED       = "{doer} hammered down {target}! Owner: {owner}"
        },

        PLAY = {
            GENERIC     = "{doer} played on {target}!",
        },

        MINE = {
            GENERIC     = "{doer} mined {target}!",
        },

        USED = {
            GENERIC     = "{doer} used {item}!",
            ON          = "{doer} used {item} on {target}!",
        },
    },

    SHARDS = {
        MASTER      = "Master",
        SECONDARY   = "Caves",
        UNKNOWN     = "Unknown",
    },

    EMBEDS = {
        PLAYERS = {
            SHARD_NAME = "%s (%s)",
            TITLE = "Player List",
            THMB_URL = "https://cdn.discordapp.com/attachments/1066442901380403333/1187075388187357294/player.png",
            AUTHOR_ICON_URL = "https://cdn.discordapp.com/attachments/1066442901380403333/1066442981353201854/dedicated.png",
            EMPTY = "Nobody is playing..."
        },

        SERVER = {
            THMB_URL = "https://cdn.discordapp.com/attachments/1066442901380403333/1066442981353201854/dedicated.png",
            BOOT = "Server Launched",
            TITLE = "Server Properties",
            FOOTER = "Session: %s • Snapshot: #%s",
            FD_NAMES = {
                PLATFORM    = "Plaform",
                GAME_V      = "Game Version",
                MOD_V       = "Mod Version",
                SEED        = "World Seed",
                PLAYSTYLE   = "Playstyle",
                EVENT       = "Event",
                RUN_TIME    = "Run Time",
            },
        },

        WORLD = {
            TITLE = "%s World Properties",
            REGENERATED = "Shard `%s` Regenerated",
            THMB_URL = "https://cdn.discordapp.com/attachments/1066442901380403333/1066443002630918236/world.png",
            AUTHOR_ICON_URL = "https://cdn.discordapp.com/attachments/1066442901380403333/1066442981353201854/dedicated.png",
            DESC_TITLE = "**World Setting Overrides**",
            SETPIECE_SUBTITLE = "Set Pieces",
            OTHER = "+%d other change(s)",
            FD_NAMES = {
                SEED            = "World Seed",
                SESSION_ID      = "Session ID",
                SNAPSHOT_ID     = "Snapshot ID",
                SAVE_VERSION    = "Save Version",
                GEN_VERSION     = "Generator Version",
                REED_TRAP       = "Reed Trap",
                WALRUS_CAMPS    = "Walrus Camps",
            },
        },

        LEADERBOARD = {
            TITLE_ABS = "Total Leaderboard",
            TITLE_CUR = "Month Leaderboard",
            TITLE_ARCHIVED = "Archived",

            FD_NAMES = {
                INDEX_COL   = "#",
                NAME_COL    = "Name",
                REP_COL     = "Reputation",
                MONTH       = "Month",
                CREATED     = "Data From",
                DAY_PLAYER  = "Player of the Day",
            },

            FD_VALUES = {
                MONTH = "%s %s",
            },

            THMB_ABS_URL = "https://cdn.discordapp.com/attachments/1066442901380403333/1129005246027419648/trophy-big.png",
            THMB_CUR_URL = "https://cdn.discordapp.com/attachments/1066442901380403333/1127332501858291732/daychanges.png",

            NOT_ENOUGH_DATA = "Not enough data",
            NO_LEADERBOARDS = "No leaderboards active",
        },

        INV = {
            TITLE = "%s's Inventory",
            INVENTORY = MARKDOWN.bold("Inventory"),
            INVENTORY_EMPTY = MARKDOWN.italic("*Inventory Empty*"),
            SURVIVED = "`%s/%s`",
            THMB_URL = "https://cdn.discordapp.com/attachments/1066442901380403333/1196480952105439302/backpack.png?ex=65b7c8b8&is=65a553b8&hm=ed2083f11b69c8dff56e33f1fecd056fdb47a6cbc027fcd7a5bce1f712a83ef0&",
            FD_NAMES = {
                SURVIVED        = "Days Survived",
                SUSPICIOUSNESS  = "Suspiciousness",
            },
        },

        SKIN = {
            TITLE = "%s %s received %s!",
            MARKETABLE_NOTE = "View in the Steam Market",
            FD_NAMES = {
                TYPE = "Reskins",
                COLLECTION = "Collection",
                RARITY = "Rarity",
            }
        },

        MODS = {
            LOC_MODS = "Local Mods",
            PUB_MODS = "Steam Workshop Mods",
            TITLE = "%s's Enabled Mods",
            THMB_URL = "https://cdn.discordapp.com/attachments/1066442901380403333/1093953980482211862/wrench.png",
            FOOTER = "%s/%s",
            ALLOWLIST = "Allowlist is enabled.",
            UNKNOWN_MOD = "Unknown Mod",
        },

        PROFILE = {
            -- Prefab + Username
            TITLE = "# %s %s",
            FOOTER = "Klei ID: %s • Steam ID: %s",
            PLAYING = "Playing Now!",
            UNKNOWN = "No Information",
            PRIVATE = "Profile is set as private, therefore some data may be inaccurate or not provided.",
            NOT_SETUPED = "User has not set their community profile yet.",
            SYSTEM_BAN = "System Ban",
            UNKNOWN_AUTHOR = "Unknown",
            MOD_NOTE = "**Staff Note**\n```%s```",
            NO_REASON  = "No Reason Provided",
            FOOTER_ICON = "https://cdn.discordapp.com/attachments/1066442901380403333/1190652981864042556/authentication.png",
            ACTIVE_BAN_TAG = "[Active]",
            BAN_END = "`To:` %s",
            FD_NAMES = { -- Max 25 fields!
                PLAYED          = "Total Days Played/Survived",
                REP             = "Reputation",
                JOINED          = "Joined At",
                LOCALE          = "Locale",
                SEEN            = "Last Time Seen",
                DISCORD         = "Discord",
                GAMEPLAYTIME    = "Game Play Time",
                DEATHS          = "Deaths Count",
                STEAMCREATED    = "Steam Member Since",
                LAST_BAN        = "Last Ban",
                ALT_ACCOUNT     = "Alternative Account",
                LAST_SESSION    = "Last Session",
            },
            FD_VALUES = {
                LAST_BAN        = "> `Author:` %s\n> `From:` %s\n> `Reason:` %s",
                LAST_SESSION    = "`%s`\n> Day: `%s`\n> Snapshot: `%s`"
            }
        },
    },

    REPORTS     = {
        NO_STACKTRACE = "No Traceback",
        MISSING_NAME = "Entity `%s` has no standardized name!",
        INVALID_RPC   = "Received invalid RPC on shard `%s` from client `%s`:```lua\n%s```",
        USERID_UNKNOWN = "<UNKNOWN>"
    },

    FILES = {
        MOUNTABLE_SCRIPTS = [[
-- File for executing your custom Lua on the clients and server without
-- the need to update any software uploaded to the Steam Workshop.
--
-- Feel free to remove the "KLEI     1" prefix from the start of this file
-- in case it is provided.


-- Execute code that is common for both sides here.

if PEARL.CLIENT_SIDE then
    -- Execute client-side stuff here
else
    -- Execute server-side stuff here
end
        ]]
    },

    LOGS        = {
        --PLAYER_COUNT            = "%s Total players: %d/%d", -- Not needed currently
        OWNER                   = "%s Owner: %s",
        ITEM                    = "%dx %s",
        AND                     = "%s and %s",
        TAG                     = "[%s]",
        ANNOUNCEMENT            = "Announcement",
        UNKNOWN                 = "Unknown",
        NONE_EVENT              = "No Event",

        HOUNDS                  = "Hounds",
        DEPTH_WORMS             = "Depth Worms",

        INV_REPORT_TITLE        = "%s %s's Inventory",
        INV_REPORT_EMPTY        = "*Loading failed or the inventory is empty.*",
        INV_REPORT_ITEM_RARE    = "**%dx\t%s (\"%s\")**",
        INV_REPORT_ITEM         = MARKDOWN.codeline("%dx").."\t%s\t\t\t\t"..MARKDOWN.codeline("%s"),
        INV_REPORT_DROPPED      = "Player's inventory was dropped before despawning.",
        INV_RARE_ITEMS_DROPPED  = "Rare items were dropped from player's inventory before despawning.",

        PERMISSIVE_MODE_WARNING = "Permissive mode is turned on! Reputation and penalization systems disabled.",
        WAVE_WARNING            = "%s are comming!",

        STEAM_BANNED_FRIENDS    = "User %s has %d/%d friends currently banned on this server.",
        STEAM_LOCALE_MISMATCH   = "Mismatch between the IP locale (`%s`) and the locale set on Steam Profile (`%s`) for user %s.\nMaybe they are using a VPN?",

        PLAYER_ON_EXT_BANLIST   = "The player %s is banned on the external banlist. Keep an eye on them.",

        SAY                     = MARKDOWN.bold("%s")..": %s",
        SAY_COMMAND             = MARKDOWN.bold("%s")..": "..MARKDOWN.codeline("/%s"),
        SAY_WHISPER             = STRINGS.UI.CHATINPUTSCREEN.WHISPER_DESIGNATOR.." "..MARKDOWN.bold("%s")..": "..MARKDOWN.italic("%s"),
        SAY_DM                  = "[DM] "..MARKDOWN.bold("%s").." > "..MARKDOWN.bold("%s")..": "..MARKDOWN.italic("%s"),
        CONNECTION_CLOSE        = "Connection for %s was closed -> %s",
        CONSOLE_CMD             = "`%s executed remote command:`\n```lua\n%s```",
        AUTH                    = "%s authenticated as %s",
        DISCONNECT_GENERIC      = "%s was disconnected from shard %s.",
        DISCONNECT              = "%s was disconnected from shard %s as %s.",
        DISCONNECT_UNEXPECTED   = "%s was unexpectedly disconnected from shard %s as %s. %s",
        DISCONNECT_REASON       = "%s was disconnected from shard %s as %s. %s",
        CONNECTED_TO_SHARD      = "%s was connected to shard %s as %s.",
        OFFLINE_CLIENT_BANNED   = "%s was added to the banlist!",
        CLIENT_UNBANNED         = "%s was removed from the banlist!",
        CAVES_STATE_UPDATE      = "Secondary shard Caves has been %s.",
        LOCALIZATION_TIMEOUT    = "Localization process for client %s has timed out!",
        MIGRATING               = "%s is migrating to shard %s.",
        WARNED                  = "%s was warned for griefing!",
        PLAYER_RENAMED          = "%s was renamed from %s to %s.",
        STAFF_CALLED            = "Admins and server moderators were notified.",
        SKIN_RECEIVED           = "%s received %s!",
        QUAKE_START             = "An earthquake has started!",
        QUAKE_END               = "The earthquake has ended!",
        LIGHTNING_STRIKE        = "Lightning stuck near %s!",
        --DAY                     = "Day %d - %s (%s °C) - %d/%d Players",
        DAY                     = "Day %d - %s (%s °C)",
        PHASE                   = "%s",

        SPAWN                   = "Spawning %s in shard %s",
        SPAWN_AT                = "Spawning %s in shard %s at X: %2.2f Y: %2.2f Z: %2.2f",
        SPAWN_AT_BASE_NEAR      = "Player %s was spawned at the base near %s",

        PRECIPITATION_START     = "It started %s!",
        PRECIPITATION_STOP      = "It stopped %s.",

        START_VOTE              = "%s started %s.",
        START_VOTE_ANONYMOUS    = "%s started.",
        STOP_VOTE               = "The vote was stopped.",

        NEW_PLAYER_SPAWN        = "%s entered the constant as %s!",
        PLAYER_DESPAWN          = "%s left the constant as %s.",

        RESET_COUNTDOWN_START   = "World reset countdown has started! The server will be regenerated in %s seconds.",
        RESET_COUNTDOWN_STOP    = "World reset countdown has stopped.",

        MOD_INIT                = "The system has been initialized. Loading the server...",
        MOD_BACKUP_INIT         = "The system backup has been initialized. Loading the server...",
        SHARD_LOADED_MASTER     = "Shard `%s` was loaded.",
        SHARD_LOADED_SECONDARY  = "Shard `%s` was loaded. Connecting to shard `%s`...",

        AUTO_UPDATE_FIRST       = "Server's version is outdated, new players aren't able to connect.\nIt will be automatically updated in %s minute(s).",
        AUTO_UPDATE_FIRST_DIS   = "Server's version is outdated, new players aren't able to connect.",
        AUTO_UPDATE_SECOND      = "Server will be automatically updated in 15 seconds.\nAll your progress will remain untouched. Don't forget to update your game as well :)",
        AUTO_UPDATE_START       = "Updating the server to version %s...",

        GAME_LOADED             = "Shard %s was loaded.",
        RESTART                 = "Restarting shard `%s`...",
        ROLLBACK                = "Rolling server %s snapshot(s) back!",
        ROLLBACK_AFTER          = "Rolling server %s snapshot(s) back in %s second(s)!",
        DAYSBACK                = "Rolling server back to day %s!",
        DAYSBACK_AFTER          = "Rolling server back to day %s in %s second(s)!",
        DAYSBACK_COUNT          = "Rolling server %s day(s) back!",
        DAYSBACK_COUNT_AFTER    = "Rolling server %s day(s) back in %s second(s)!",
        SAVE                    = "Saving world on shard %s as snapshot %s...",
        AUTO_SAVE               = "Auto-Saving world on shard %s as snapshot %s...",
        RESET                   = "Regenerating the world on %s.",
        SHUTDOWN                = "Shutting down %s...",
        SHUTDOWN_ERROR          = "Shard %s has crashed!",
        START                   = "Starting the server...",
        SERVER_REPORT           = MARKDOWN.bold("<@&%s> Server Report:\n")..MARKDOWN.codeblock("%s"),
        STATUS_CODE_REPORT      = "STATUS_CODE -> %d:\n%s",

        HIGH_PING               = "**High latency (`%d ms`) was reported from client `%s`. Region: `%s`**",
        LOW_PERFORMANCE         = "Received bad server performance reports.",

        SERVER_AUTOPAUSE        = "Server was autopaused.",
        SERVER_PAUSE_BY         = "Server was paused by %s.",
        SERVER_PAUSE            = "Server was paused.",
        SERVER_UNPAUSE          = "Server was unpaused.",
        SERVER_UNPAUSE_BY       = "Server was unpaused by %s.",
        SERVER_STARTED          = "Server successfully started on version %s!",

        SIM_PAUSED              = "Simulation was paused.",
        SIM_UNPAUSED            = "Simulation was unpaused.",

        LAST_CRASH_LOG_FETCHED  = "**Last uncatched crash log for player (`%s`) %s:**",
        LOST_CONNECTION         = "> %s\nNext time this user joins the game, attempts will be made to fetch the crash logs.",

        -- We assume that catched exceptions are always caused by us.
        EXC_CATCHED_SERVER      = "**Catched exception**\n%s",
        EXC_CATCHED_SHARD       = "**Catched exception on shard %s**\n%s",
        EXC_CATCHED_CLIENT      = "**Catched exception on client (%s) %s**\n%s",

        EXC_SERVER              = "**Uncatched exception**\n%s",
        EXC_SHARD               = "**Uncatched exception on shard %s**\n%s",
        EXC_CLIENT              = "**Uncatched exception on client (%s) %s**\n%s",

        EXC_SELF_SERVER         = "**Caused uncatched exception**\n%s",
        EXC_SELF_SHARD          = "**Caused uncatched exception on shard %s**\n%s",
        EXC_SELF_CLIENT         = "**Caused uncatched exception on client (%s) %s**\n%s",

        EXC_MOD_SERVER          = "**Mod %s caused uncatched exception**\n%s",
        EXC_MOD_SHARD           = "**Mod %s caused uncatched exception on shard %s**\n%s",
        EXC_MOD_CLIENT          = "**Mod %s caused uncatched exception on client (%s) %s**\n%s",

        EXC_ENABLED_MODS        = "Enabled Mods (%s):\n%s",

        AFFLICTER_MOD_DISABLED  = "The crashed mod was disabled.",
        HTTP_ERROR              = "HTTP Error status code on shard %s:\n%s",

        INVALIDRPC              = "Received invalid RPC %s from client %s!",

        EXTINGUISH              = "Fires ({count}) were extinguished!",
        EXTINGUISH_DOER         = "{doer} extinguished {count} fires!",
        EXTINGUISH_NEAR         = "Fires ({count}) near {target} were extinguished!",
        EXTINGUISH_DOER_NEAR    = "{doer} extinguished fires ({count}) near {target}!",
        EXTINGUISH_ALL          = "All ({count}) were extinguished!",
        EXTINGUISH_DOER_ALL     = "{doer} extinguished all ({count}) fires!",

        REPAIR                  = "Burnt structures ({count}) were restored!",
        REPAIR_DOER             = "{doer} restored ({count}) burnt structure(s)!",
        REPAIR_NEAR             = "Burnt structures ({count}) near {target} were restored!",
        REPAIR_DOER_NEAR        = "{doer} restored {count} burnt structures near {target}!",
        REPAIR_ALL              = "All ({count}) burnt structures were restored!",
        REPAIR_DOER_ALL         = "{doer} restored all ({count}) burnt structure(s)!",

        PROXY_SERVER_STARTED    = "Proxy server has successfully started!",
        PROXY_SERVER_STOPPED    = "Stopping the proxy server...",
        PROXY_SERVER_UNREACH    = "Proxy server seems to be unreachable.",
        PROXY_SERVER_RESTARTED  = "Restarting the proxy server...",
        PROXY_SERVER_ERROR      = "Internal proxy server error.",

        PROXY_MESSAGE_FAILED    = "There was an error processing the message!",

        PROXY_COMMAND_FAILED    = "There was an error processing the command!",
        PROXY_COMMAND_FAILED_N  = "There was an error processing command \"%s\"!",

        -- Anti AFK system
        USER_ACTIVE             = "%s came back!",
        USER_INACTIVE           = "%s went away...",
        USER_INACTIVE_KICKED    = "%s was kicked for inactivity.",

        SEARCH_RESULTS_FOR      = "Search results for `%s` (`%d`):",

        PLAYER_REPORT           = "%s [@here] `%s` %s **%s**: %s",
        PLAYER_REPORT_EMPTY     = "%s [@here] `%s` %s **%s**",
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

    PRECIPITATION_NAMES = {
        ["rain"]        = "raining",
        ["snow"]        = "snowing",
        ["frograin"]    = "raining frogs",
        ["lunarhail"]   = "the Lunar Hail",
        ["none"]        = "no precipitation",
    },

    DATE_FORMAT = "%s. of %s %s",
    HM_TIME_FORMAT = "%dh %dm",
    FULL_MONTH_NAME = "%s %s", -- First is fancy month name and then the year number
    PROPORTION = "%s/%s",
    POSITION = "%s.",

    TAG_PREFIXES = {
        ["burnt"] = "burnt",
    },

    MONTHS = {
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December",
    },

    -- Create a copy of the game's seasons so we do not modify the actual table when translating
    -- THESE translations should NOT display on the client.
    SEASONS = shallowcopy(STRINGS.UI.SERVERLISTINGSCREEN.SEASONS),
    PHASES  = shallowcopy(STRINGS.UI.SERVERLISTINGSCREEN.PHASES),

    SEASON_UNKNOWN          = "Unknown Season",

    COMMAND_RESPONSES = {
        INVALID = "Invalid command provided!",
    },

    UI = {
        LAST_CRASH_POPUP = {
            TITLE = "Unexpected Shutdown",
            BODY_UNCATCHED = "Looks like your game didn't shutdown clearly last time.\nIf this wasn't intended, you may want to report this issue to the server admins.",
            BODY_CATCHED = "Looks like your game didn't shutdown clearly last time.\nLogs were sent to the server admins and will be reviewed.",
            CONTINUE = "Continue",
        },

        DEFAULT_POPUP_TITLE = "Notification",

        CLIENTERROR_DETAIL_SELF = "The error was reported to the server owner.\nWe will make sure to take a look into it!",
        CLIENTERROR_DETAIL = "The error was reported to the server owner.",

        CONSOLE_DISABLED = "Disabled :)",


        EMOJI_MENU = {
            NO_EMOJIS_FOUND = "No emojis match your search", -- from discord

            FAVORITE_BUTTON_HOVER = "Favourite",
            UNFAVORITE_BUTTON_HOVER = "Unfavourite",

            OPEN_BUTTON_HOVER = "View Emojis\n(%s)",
            CLEAR_BUTTON_HOVER = "Clear\n(%s)",

            SEARCH = "Search",
            NEW = "New!",
        },

        SCRIPTERRORWIDGET = {
            QUIT = "Exit Game",
            BACK = "Back to Menu",
            REJOIN = "Continue",
            RELOAD = "Reload Save",
            DISABLE_MODS = "Disable Mods",
        },

        OPTION_CHOICES = {
            LEADERBOARD = {
                MONTHLY = "Monthly", ABSOLUTE = "Absolute"
            },
            YES_NO = {
                YES = "Yes", NO = "No",
            }
        },

        EMOJI_CATEGORIES = {
            FAVORITES = "Favourites",
            FREQUENTLY_USED = "Frequently Used",

            DISCORD = "Discord",
            VANILLA = "Vanilla",
        },

        STATIC_BAN_REASONS = {
            NONE = "Reason not specified.",
            AUTO = "Auto-Banned for repeated violation of the rules.",
            ALT  = "Auto-Banned for attempting to bypass a ban using an alternative account.",
        },

        PROXY_SERVER = {
            STATE_LABEL         = "Proxy Server:",

            STATES = {
                UNREACHABLE     = "Unreachable",
                ONLINE          = "Online",
                OFFLINE         = "Offline",
                STARTING        = "Starting",
                UNKNOWN         = "Unknown State",
            }
        },

        ALLOWED = "Allowed",
        BLOCKED = "Blocked",

        POTM_ANNOUNCEMENT = "Best player of the month {month} is {leader}! New month begins today!",
        POTM_AGAIN_ANNOUNCEMENT = "Best player of the month {month} is again {leader}! New month begins today!",
        POTM_MULTIPLE_ANNOUNCEMENT = "Best player of the month {month} is for the {times}. time {leader}! New month begins today!",
        MONTHLY_LEADERBOARD_RESET = "The monthly leaderboard was reset!",

        EMPTY_SERVER_POPUP = {
            TITLE = "The Server is Empty! For now...",
            BODY_DISCORD = "You are alone here but surviving is much more fun in multiple people!\nDo not hesitate to invite your friends or visit our Discod community\nto find some people to play with!",
            BODY = "You are alone here but surviving is much more fun in multiple people!\nDo not hesitate to invite your friends!",
            VISIT_DISCORD_BUTTON = "Visit our Discord",
            CONTINUE = "Continue",
        },

        -- Mod blocker popup
        MODS_BLOCKED_TITLE = "Mods Disabled",
        MODS_BLOCKED_ALL_TITLE = "All Mods Blocked",
        MODS_BLOCKED_BODY  = "Some of the mods you are using were blocked by the server.",
        MODS_BLOCKED_ALL_BODY = "All of your mods were blocked by the server.",

        WHISPER_WARN_TEXT = "Messages sent in the Whisper Mode will be only visible to nearby players. Use %s in order to display your message for everyone.",

        DM_DESIGNATOR = "[DM]",

        BACKUP_TAG    = "[Backup]",

        LOADING_VERIFICATION = "Verifying connection...",
        LOADING_ERROR = "Maybe it didn't work that well at the end...",
        CONNECTION_FAILED = "Connection failed...",

        PARAM_DESCRIPTIONS = {
            ["player"] = "Identifier of the target player.",
            ["shard"]  = "Identifier of the target shard.",
            ["prefab"] = "Prefab code of the target entitiy.",

            ["note"]   = "The note text to save for the player."
        },

        CMD_ERRORS = {
            MISSING_BINDING = "In order to use this command you need to pair your account! Lern more at:\n%s",
            EXECUTION = "Error while executing the command!",
            NO_LHOOK = "Logging webhook is disabled! Enable 'LHOOK' in modoverrides.lua.",
            NO_RHOOK = "Report webhook is disabled! Enable 'RHOOK' in modoverrides.lua.",
            NO_SNAPSHOT_FOUND = "Couldn't find any snaphots for day %d.",
            FAILED_SNAPHOTS_LOAD = "Failed to load the snapshots for this session.",
            SERVER_ONLY = "This command does only work on a server!",
            UNKNOWN_PLAYER = "Unknown player!",
            PLAYER_NOT_SPECIFIED_ENOUGH = "There are %s people with the name %s. Please use their ID instead.",
            PLAYER_NOT_FOUND = "Player not found!",
            ITEM_PREFAB_INVALID = "Invalid item prefab provided!",
            PREFAB_INVALID = "Invalid prefab provided!",
            ITEM_NOT_FOUND = "Item not found!",
            MOD_ALREADY_BLOCKED = "The specified mod is already blocked on the server.",
            SHARD_NOT_FOUND = "The specified shard is not connected to Master!",
            DB_DISABLED = "The database is not enabled!",
            KLEI_SERVERS_UNREACHABLE = "There was an error contacting Klei servers.",
            MISSING_PARAMETER = "Missing required parameter \"%s\"!",
            INVALID_PARAM_VALUE = "Parameter \"%s\" has incorrect type! Please provide a \"%s\" instead.",
            INVALID_PARAM = "Invalid parameter \"%s\"!",
            STANDARDIZATION_FAILED = "Standardization failed for command \"%s\"!",
            VALIDATION_FAILED = "Failed to validate command \"%s\"!",
            JSON_DECODING_FAILED = "Failed to decode the provided JSON data!",
            INVALID_JSON = "Invalid JSON data provided!",
            SENT_TO_THIRDPARTY_FAILED = "Sending the command response to discord has failed!",
            NO_PARAMETER_PERMISSIONS = "You do not have permission to use the \"%s\" parameter!",
            VALUE_TOO_LOW = "The value of the parameter \"%s\" must be higher than or equal to %s!",
            VALUE_TOO_HIGH = "The value of the parameter \"%s\" must be lower than or equal to %s!",
            VALUE_TOO_SHORT = "The value of the parameter \"%s\" must be at least %s characters!",
            VALUE_TOO_LONG = "The value of the parameter \"%s\" must be at most %s characters!",
            COORDINATES_MISSING = "If you want to use coordinates, please provide at least the X and Z values! The Y value defaults to the ground Y coordinate."
        },

        CMD_WARN = {
            SAVE_REQUIRED = "In order for the changes to be correctly applied, you have to save the server.",
        },

        CMD_INFO = {
            SENT_TO_THIRDPARTY = "The response was sent to discord.",
            RECEIVED_FROM_THIRDPARTY = "Command was successfully received and processed!",
            BY_COMMAND = "using an command",
            NO_CHANGES = "No changes...",
        },

        -- Add more translations
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
                DESC       = "Removes the given player from the blacklist.",

                ON_SUCCESS  = "Player was successfully removed the blacklist and can join back now!",
                ON_NOTFOUND = "Player was not found on the blacklist...",
            },

            GIVE = {
                PRETTYNAME = "Give Item",
                DESC       = "Gives an item to any player you have specified.",

                ALL        = "Gave %sx %s to %s.",
                SOME       = "Gave only %sx %s to %s because the rest can not be dropped. Player is offline.",
                NONE       = "Wasn't able to add the provided item to the inventory!",
            },

            LEADERBOARD = {
                PRETTYNAME  = "Show Active Leaderboards",
                DESC        = "Displays the active leaderboards and players on them.",

                NOT_FOUND   = "Specified leaderboard was not found!",
            },

            STATS = {
                PRETTYNAME  = "Show My Stats",
                DESC        = "Shows your current statistics and place on the leaderboard.",

                RESULT      = "#%s/#%s - %s:\nReputation: %s\nGains for today: %s\nGains for this month: %s",
            },

            GIVEALL = {
                DESC         = "Give all items on the provided list to the player.",
                GAVE_ALL     = "Gave all %d items to %s!",
                GAVE_SOME    = "Gave %d items to %s! %d items were skipped because they were invalid or didn't fit in the inventory.",
                GAVE_NONE    = "Wasn't able to add any of the provided items!",
            },

            TAKE = {
                PRETTYNAME = "Take Item",
                DESC       = "Take an item from player you have specified.",

                ON_SUCCESS = "Took %sx %s from %s.",
            },

            DROP = {
                PRETTYNAME = "Drop Item(s)",
                DESC       = "Drops an player's item or the whole inventory if no item was specified.",

                ALL   = "%s's inventory was dropped!",
                SOME  = "Dropped %sx %s from %s's inventory!",
            },

            DEPOSIT = {
                PRETTYNAME = "Deposit Item(s)",
                DESC       = "Returns the specified item or the whole inventory back to the base.",

                ALL   = "%s's inventory was returned to the world!",
                SOME  = "Returned %sx %s from %s's inventory to the world!",
            },

            KILL = {
                PRETTYNAME = "Kill a Player",
                DESC       = "Kills the specified player on spot.",

                ON_SUCCESS = "Player was killed...",
            },

            TELEPORT = {
                PRETTYNAME = "Teleport Player",
                DESC       = "Teleports the specified player to the specified location or entity.",

                BAD_TARGET = "Please provide either the target entity or the target coordinates.",
                ON_SUCCESS = "Player was teleported to X: %s Y: %s Z: %s",
            },

            REVIVE = {
                PRETTYNAME = "Revive a Player",
                DESC       = "Revives the specified player on spot.",

                ON_SUCCESS = "Player was revived!",
            },

            SPAWN = {
                PRETTYNAME = "Spawn Entity",
                DESC       = "Spawns any entity by their prefab.",

                ON_SUCCESS = "Spawned %dx %s",
            },

            SPAWNBASE = {
                PRETTYNAME = "Spawn Base",
                DESC       = "Spawns a basic base at the chosen location in the world.",

                ON_SUCCESS = "Base was spawned at %s!",
                ON_MISSING = "Location %s was not found!",

                OPTIONS = {
                    PINGKING = "Ping King",
                    OASIS = "Oasis",
                    PORTAL = "Florid Postern",
                }
            },

            REMOVEALL = {
                PRETTYNAME = "Remove All",
                DESC       = "Removes all entities with the specified prefab from the world.",

                ON_SUCCESS = "Removed %dx %s from shard %s.",
            },

            SAVE = {
                PRETTYNAME = "Save the Game",
                DESC       = "Saves the current world!",
            },

            DESPAWN = {
                PRETTYNAME = "Despawn a Player",
                DESC       = "Despawns the specified player on spot. Inventory is dropped.",

                ON_SUCCESS = "Player was despawned and is now back in the lobby.",
            },

            PERMISSIVE = {
                PRETTYNAME = "Toggle Permissive Mode",
                DESC       = "Enables/Disables all the penalizations and rewards.",

                ON_TURN_OFF = "Permissive mode disabled! Reputation and autoban works again."
            },

            SETREP = {
                PRETTYNAME = "Set Player's Reputation",
                DESC       = "Sets the reputation amount for the specified player to whatever number you want.",

                ON_SUCCESS = "Reputation successfully set!",
                ON_FAILURE = "Failed to set the reputation.",
            },

            GIVEREP = {
                PRETTYNAME = "Give Reputation",
                DESC       = "Give reputation to someone who deserves it!",

                ON_SUCCESS = "Increased player's reputation!",
                ON_SELF    = "You cannot give reputation to yourself!",
            },

            INV = {
                PRETTYNAME = "Display Inventory",
                DESC       = "Displays player's inventory on discord.",

                ON_SUCCESS          = "Inventory was sent to discord.",
                ON_NOTFOUND         = "Inventory is empty or doesn't exist...",
                ON_FAILURE          = "Sending the inventory failed...",

                FAILED_TO_ENCODE    = "Failed to encode the inventory to the JSON format!",
                INVENTORY_HEADER    = "%s's Inventory:",
            },

            INVF = {
                PRETTYNAME = "Find Inventory",
                DESC       = "Searches for inventory containing specified item.",

                ON_SUCCESS          = "%d results were sent to discord.",
                ON_FAILURE          = "No results...",
            },

            GRANT = {
                PRETTYNAME = "Add to whitelist",
                DESC       = "Increases the allowlist with the given user ID.",

                ON_ALREADY_WHITELISTED = "Player is already on the whitelist.",
                ON_SUCCESS  = "Player was successfully added to the whitelist.",
                ON_FAILURE  = "An error occured while saving the changes...",
                ON_BANNED   = "Player is on the blacklist and has no access to this server.",
            },

            REVOKE = {
                PRETTYNAME = "Remove from allowlist",
                DESC       = "Attempts to remove the given player id from the allowlist.",

                ON_SUCCESS  = "Player was removed from the allowlist.",
                ON_FAILURE  = "An error occured while saving the changes...",
                ON_NOTFOUND = "Player was not found on the allowlist."
            },

            ADMINS = {
                PRETTYNAME = "Call the Admins",
                DESC       = "If you find yourself in a hopeless situation... call the admins!",
            },

            MODS = {
                PRETTYNAME = "Display Player's Mods",
                DESC       = "Check for some hacky modifications the players are using!",

                NO_CFD     = "Failed to fetch player's mods!",
                NO_MODS    = "This player does not use any mods now.",
                ON_SUCCESS = "The mod list was sent to discord.",
            },

            RELOAD = {
                PRETTYNAME = "Reload the Server",
                DESC       = "Internally restarts the server without disconnecting any players.",
            },

            RESCUE = {
                ON_DEATH   = "You can rescue at the portal!",
                NO_REVIVE  = "This command won't revive you! Try to find an other way. There are many.",
            },

            COUNT = {
                PRETTYNAME = "Count Prefab",
                DESC       = "Counts the number of occurrences of the specified prefab.",

                ON_SUCCESS = "There are %s %s's on shard %s.",
            },

            BLOCK_MOD = {
                PRETTYNAME = "Block Mod",
                DESC       = "Prohibit a modification for other players.",

                ON_SUCCESS = "Mod added to the blocklist.",
            },

            ALLOW_MOD = {
                PRETTYNAME = "Allow Mod",
                DESC       = "Make sure this modification is allowed for players to use.",

                ON_SUCCESS = "Mod added to the allowlist."
            },

            BAN = {
                ON_SUCCESS = "Player was added to the blocklist. Access to the server is prohibited from now.",
                ALREADY_BANNED = "Player is already banned on this server.",
            },

            KICK = {
                ON_SUCCESS = "Player was kicked from the server.",
            },

            SETDBFIELD = {
                DESC = "Set any field in the DB record to the desired value.",

                ON_SUCCESS = "Field successfully set!",
                ON_FAILURE = "Failed to set the specified field!",
            },

            SET_RARITY = {
                ON_SUCCESS = "The rarity value for the specified item was changed.",
                ON_DISABLED = "The Inventory Reporter module is disabled!\nYou need to enable it in the settings in order to use this command."
            },

            DM = {
                PRETTYNAME = "Send Direct Message",
                DESC       = "Sends a message visible only to the specified player and you!",

                ON_SUCCESS = "The message was sent to %s."
            },

            SYSTEM = {
                PRETTYNAME = "Send System Message",
                DESC       = "Sends a message as the server user.",
            },

            NOTIFY = {
                PRETTYNAME = "Send Notificaton",
                DESC       = "Sends a notification to the specified player.",

                ON_SUCCESS = "Notification sent!",
            },

            ANNOUNCE = {
                PRETTYNAME = "Announce",
                DESC       = "Displays an announcement in chat!",
            },

            PAIR = {
                PRETTYNAME = "Pair Discord Account",
                DESC       = "Links up your Klei and discord account in our database. The accounts need to be already paired.",

                ON_SUCCESS = "Account successfully paired!",
                ALREADY_PAIRED = "Account already paired!",
                NOT_PLAYED = "You have to play on our server first before pairing accounts!",
                ON_FAILED = "Failed to pair your account!",
                NOT_PAIR_OFFICIALLY = "In order to pair your account you need to add your Klei account to your Discord profile."
            },

            UNPAIR = {
                PRETTYNAME = "Unpair Discord Account",
                DESC       = "Removes the link with your discord account from our database.",

                ON_SUCCESS = "Account successfully unpaired!",
                NOT_PAIRED = "Account not paired!",
                ON_FAILURE = "Failed to unpair your account!",
            },

            PROFILE = {
                PRETTYNAME = "Show Player Profile",
                DESC       = "Shows profile of the given player or your own profile on discord.",

                MISSING_PERMISSION = "You do not have permission to display profiles of other players."
            },

            SKIP = {
                PRETTYNAME = "Skip Phase",
                DESC       = "Skips the current phase of the day.",
            },

            BORROWED = {
                PRETTYNAME = "Fetch Game Owner",
                DESC       = "Checks whether the user is also the actual owner of the game.",

                ON_SUCCESS = "Owner of the game is %s",
                ON_FAILURE = "Couldn't retrive the game owner for the specified account."
            },

            SET_SLOTS = {
                PRETTYNAME = "Set Server Slots Count",
                DESC       = "Sets the number of player slots for the server.",

                ON_INVALID_INPUT = "Invalid number of slots provided!",
                ON_COUNT_TOO_LOW = "The Specified number of slots is less than the total number of players!",
                NO_CHANGES = "No changes...",
                ON_SUCCESS = "The number of server slots has been updated!",
            },

            SYNC = {
                PRETTYNAME = "Sync Commands",
                DESC       = "Synchronizes all the proxy commands with the Discord bot.",

                ON_SUCCESS = "Commands successfully synchronized!",
                ON_FAILURE = "Failed to synchronize commands with Discord!",
            },

            NOTE = {
                PRETTYNAME = "Add Note",
                DESC       = "Adds a note to the player's profile visible only by the staff.",

                ON_ADDED = "Note successfully added!",
                ON_REMOVED = "Note removed!",
                NO_CHANGES = "No changes...",
                ON_FAILURE = "Failed to add the specified note..."
            },

            SERVER = {
                DESC = "Show server info.",
            },

            PLAYERS = {
                DESC = "Show information about players currently playing on the server.",
            },

            WORLD = {
                DESC = "Show information about the current world.",
            },

            REBOOT = {
                DESC = "Turn off and on the server.",
            },

            SHUTDOWN = {
                DESC = "Turn off the server.",
            },

            EXEC = {
                DESC = "Execute arbitrary Lua code on the server.",

                ON_INVALID_COMMAND = "The provided command is not a valid Lua."
            },

            SETRARITY = {
                DESC = "Set rarity of an item. Used when detecting suspicious inventories.",
            },

            SHOW = {
                DESC = "Show a DB record in it's raw JSON format.",
            },
        },

        SOCIAL_LINK_BUTTON_HOVERS = {
            DISCORD = "View Discord",
            TWITCH  = "View Twitch",
            YOUTUBE = "View YouTube",

            HOST    = "View Host",
        },

        AGREEMENT_BUTTON_HOVER = "View Agreement",

        INTRO_POPUP_BUTTON_CONTINUE = "Continue",
        AGREEMENT_SCREEN_BUTTON_FINISH = "Finish",
        AGREEMENT_SCREEN_BUTTON_ACCEPT = "Accept",
        AGREEMENT_SCREEN_BUTTON_DECLINE = "Decline",
        AGREEMENT_SCREEN_BUTTON_CLOSE = "Close",

        AGREEMENT_UPDATED_POPUP_TITLE = "Server Agreement Update",
        AGREEMENT_UPDATED_POPUP_BODY = "The server agreement has been updated and needs your review.",
        AGREEMENT_UPDATED_POPUP_CONTINUE = "Continue",

        AGREEMENT_DECLINE_POPUP_TITLE = "Decline the Server Agreement?",
        AGREEMENT_DECLINE_POPUP_BODY = "You won't be able to play on the server. Are you sure?",
        AGREEMENT_DECLINE_BUTTON_YES = "Yes",
        AGREEMENT_DECLINE_BUTTON_NO  = "No",

        AGREEMENT_DC_CHECKBOX_TEXT = "*I consent to the collection of my gaming data by the us - the Czechoslovak Community for improving our servers and services.",

        AGREEMENT_VERSION_LABEL = "Version: %s",
        AGREEMENT_LAST_UPDATE_LABEL = "Last updated on: %s",
        AGREEMENT_LAST_AGREE_LABEL = "Agreed on %s",
        AGREEMENT_NO_MODIFICATION_LABEL = "No modifications can be made at this point."
    },

    GRIEFER_WARNINGS        = {
        [1] = {
            [1] = "Oops?!",
            [2] = "Has Charlie seen that?!",
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

    NOVICE_ANNOUNCEMENTS = {
        "Say welcome to %s! It's their first time on the server!",
        "Say hi to %s! He is new here!",
        "For the first time! It's %s!",
        "Let's welcome %s!",
        "%s joined for the first time! Welcome!",
        "Glad you are here %s!",
        "Finaly %s has arrived! Welcome!"
    }
}

------------------------------------
-- Custom Disconnection Popups

PEARL.AddNetworkDisconnectPopupStrings("ID_DST_USER_INACTIVE",
    "Disconnected",
    "You have been disconnected from the server for long inactivity.\nFeel free to reconnect when you get back."
)

--- Built in
PEARL.AddNetworkDisconnectPopupStrings("ID_DST_IDLE_TIMEOUT",
    "Disconnected",
    "You have been disconnected from the server for long inactivity.\nFeel free to reconnect when you get back."
)

PEARL.AddNetworkDisconnectPopupStrings("ID_DST_USER_NOT_ALLOWED",
    "Not Whitelisted",
    "This server currently uses a whitelist you are not on."
)

PEARL.AddNetworkDisconnectPopupStrings("ID_DST_MODS_PROHIBITED",
    "Mods Prohibited",
    "Some of the mods your are using are disallowed by this server.\nPlease disable them and try again."
)

PEARL.AddNetworkDisconnectPopupStrings("ID_DST_ALL_MODS_PROHIBITED",
    "All Mods Prohibited",
    "All of the mods your are using are disallowed by this server.\nPlease disable them and try again."
)

PEARL.AddNetworkDisconnectPopupStrings("ID_DST_LOCALE_BLOCKED",
    "Community Server",
    "This server currently only accepts connections\nfrom the Czech Republic and Slovakia."
)

PEARL.AddNetworkDisconnectPopupStrings("ID_DST_SERVER_RESPONSE_TIMEOUT",
    "Server Not Responding",
    "The server is not responding. Please try again."
)

PEARL.AddNetworkDisconnectPopupStrings("ID_DST_USERNAME_BLOCKED",
    "Inappropiate User Name",
    "To continue playing on this server, please change your Steam user name."
)

PEARL.AddNetworkDisconnectPopupStrings("ID_DST_PROFILE_REP_TOO_LOW",
    "Reputation Too Low",
    "Your gaming reputation seems to be too low for this server."
)

PEARL.AddNetworkDisconnectPopupStrings("ID_DST_PLATFORM_NOT_SUPPORTED",
    "Platform Not Supported",
    "Your platform is not supported by this server... Sorry!"
)

PEARL.AddNetworkDisconnectPopupStrings("ID_DST_NO_COMMUNITY_PROFILE",
    "Missing Community Profile",
    "In order for participating in this server,\nplease set up a community profile for your Steam account."
)

PEARL.AddNetworkDisconnectPopupStrings("ID_DST_SERVER_CRASHED",
    "Server Crashed!",
    "Something went awry with the server... Sorry!\nWe will make sure to look into it."
)

return STRINGS
