--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



-- Note: Prefer %s over %d because sometimes we want to format
-- the number variables as a codeline.
--- @TODO: Maybe most of the markdown should be added here instead of dynamically.
--- @TODO: Fix some incorrect translations on the UI.

local MARKDOWN = PEARL.loadfile("libraries/markdown")

------------------------------------
-- Mod Specific Strings
STRINGS.PEARL = {
    ACTIONS     = {
        -- Prefer subftm over string.format when there are multiple versions
        EAT                     = "%s ate %s!",
        FEED                    = "%s feed %s with %s!",
        TURNOFF                 = "%s turned off %s!",
        TURNON                  = "%s turned on %s!",
        TEACH                   = "%s learnt %s!",
        READ                    = "%s read %s!",
        ACTIVATE                = "%s activated %s!",
        COOK                    = "%s cooked %s!",
        --DEFEAT                  = "%s defeated %s!",

        TAKE_ITEM = {
            GENERIC     = "{doer} took {item}!",
            FROM        = "{doer} took {items} from {target}!",
            WITH        = "{doer} took {item} with {with}!"
        },

        KILL = {
            GENERIC     = "{doer} killed {target}!",
            NEAR        = "{doer} killed {target} near {near}!",
            REMAINING   = "{doer} killed {target}! Remaining: {remaining}",
            LAST        = "{doer} killed the last {target}!",
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
            ON_OWNERED  = "{doer} used {item} on {target}! Owner: {owner}",
            ON_NEAR     = "{doer} used {item} on {target} near {near}!",
            ON_OWN_NEAR = "{doer} used {item} on {target} near {near}! Owner: {owner}"
        },

        BUILD = {
            GENERIC     = "{doer} built {target}!",
            NEAR        = "{doer} built {target} near {near}!",
        },

        DEPLOY = {
            GENERIC     = "{doer} placed {item}!",
            NEAR        = "{doer} placed {item} near {near}!",
        },

        BURNTUP = {
            GENERIC     = "{target} burnt up!",
            OWNED       = "{target} burnt up! Owner: {owner}"
        },

        HAMMER = {
            GENERIC     = "{doer} hammered {target}!",
            OWNED       = "{doer} hammered {target}! Owner: {owner}"
        }
    },

    SHARDS = {
        MASTER      = "Master",
        SECONDARY   = "Caves",
        UNKNOWN     = "Unknown",
    },

    EMBEDS = {
        STARTUP = {
            THMB_URL = "https://cdn.discordapp.com/attachments/1066442901380403333/1066442981353201854/dedicated.png",
            TITLE = "Server Launched",
            FD_NAMES = {
                PLATFORM    = "Plaform",
                GAME_V      = "Game Version",
                MOD_V       = "Mod Version",
                SEED        = "World Seed",
                PLAYSTYLE   = "Playstyle",
                EVENT       = "Event",
            },
        },

        REGEN = {
            TITLE = "Shard `%s` Regenerated",
            THMB_URL = "https://cdn.discordapp.com/attachments/1066442901380403333/1066443002630918236/world.png",
            FD_NAMES = {
                SEED            = "New World Seed",
                SESSION_ID      = "World ID",
                SAVE_VERSION    = "Save Version",
                --- @TODO
                REED_TRAP       = "Reed Trap",
                WALRUS_CAMPS    = "Walrus Camps",
            },
        },

        INV = {
            TITLE = "%s %s `%s`",
            INVENTORY = MARKDOWN.bold("Inventory"),
            INVENTORY_EMPTY = MARKDOWN.italic("*Inventory Empty*"),
            SURVIVED = "`%s/%s`",
            FD_NAMES = {
                SURVIVED        = "Days Survived",
                SUSPICIOUSNESS  = "Suspiciousness",
            },
        },

        MODS = {
            TITLE = "%s's Enabled Mods"
        }
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

        INV_REPORT_TITLE        = "%s %s's Inventory",
        INV_REPORT_EMPTY        = "*Loading failed or the inventory is empty.*",
        INV_REPORT_ITEM_RARE    = "**%dx\t%s (\"%s\")**",
        INV_REPORT_ITEM         = MARKDOWN.codeline("%dx").."\t%s\t\t\t\t"..MARKDOWN.codeline("%s"),

        SAY                     = MARKDOWN.bold("%s")..": %s",
        SAY_COMMAND             = MARKDOWN.bold("%s")..": "..MARKDOWN.codeline("/%s"),
        SAY_WHISPER             = STRINGS.UI.CHATINPUTSCREEN.WHISPER_DESIGNATOR.." "..MARKDOWN.bold("%s")..": "..MARKDOWN.italic("%s"),
        CONNECTION_CLOSE        = "Connection for %s was closed -> %s",
        CONSOLE_CMD             = "`%s executed remote command:`\n```lua\n%s```",
        AUTH                    = "%s authenticated as %s",
        DISCONNECT_GENERIC      = "%s was disconnected from shard %s.",
        DISCONNECT              = "%s was disconnected from shard %s as %s.",
        DISCONNECT_UNEXPECTED   = "%s was unexpectedly disconnected from shard %s as %s.",
        DISCONNECT_REASON       = "%s was disconnected from shard %s as %s. %s",
        CONNECTED_TO_SHARD      = "%s was connected to shard %s as %s.",
        CAVES_STATE_UPDATE      = "Secondary shard Caves has been %s.",
        LOCALIZATION_TIMEOUT    = "Localization process for client %s has timed out!",
        MIGRATING               = "%s is migrating to shard %s.",
        WARNED                  = "%s was warned for griefing!",
        STAFF_CALLED            = "Admins and server moderators were notified.",
        SKIN_RECEIVED           = "%s received %s!",
        DAY                     = "Day %d - %s (%s °C) - %d/%d Players",
        PHASE                   = "%s",

        PRECIPITATION_START     = "It started %s!",
        PRECIPITATION_STOP      = "It stopped %s.",

        START_VOTE              = "%s started %s.",
        START_VOTE_ANONYMOUS    = "%s started.",
        STOP_VOTE               = "The vote was stopped.",

        NEW_PLAYER_SPAWN        = "%s entered the constant as %s!",
        PLAYER_DESPAWN          = "%s left the constant as %s.",

        RESET_COUNTDOWN_START   = "World reset countdown has started! The server will be regenerated in %s seconds.",
        RESET_COUNTDOWN_STOP    = "World reset countdown has stopped.",

        SERVER_INITIALIZED      = "The system has been initialized. Loading the server...",
        SHARD_LOADED_MASTER     = "Shard `%s` was loaded.",
        SHARD_LOADED_SECONDARY  = "Shard `%s` was loaded. Connecting to shard `%s`...",

        AUTO_UPDATE_FIRST       = "Server's version is outdated, new players aren't able to connect. It will be automatically updated in %s seconds.",
        AUTO_UPDATE_FIRST_DIS   = "Server's version is outdated, new players aren't able to connect.",
        AUTO_UPDATE_SECOND      = "Server will be automatically updated in 15 seconds. All your current progress will remain untouched. Don't forget to update your game as well :)",
        AUTO_UPDATE_START       = "Updating the server to version %s...",

        GAME_LOADED             = "Shard %s was loaded.",
        RESTART                 = "Restarting the server...",
        ROLLBACK                = "Rolling server %s snapshots back!",
        ROLLBACK_DAYS           = "Rolling server back to day %s!",
        SAVE                    = "Saving world on shard %s...",
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
        SERVER_STARTED          = "Server successfully started on version %s!",

        SIM_PAUSED              = "Simulation was paused.",
        SIM_UNPAUSED            = "Simulation was unpaused.",

        EXCEPTION_CATCHED       = "Catched exception on shard %s:\n%s",
        EXCEPTION_UNCATCHED     = "Uncatched exception on shard %s:\n%s",
        EXCEPTION_UNCATCHED_CL  = "Uncatched exception on client %s:\n%s",
        HTTP_ERROR              = "HTTP Error status code on shard %s:\n%s",

        INVALIDRPC              = "Received invalid RPC %s from client %s!",

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

        SEARCH_RESULTS_FOR = "**Search results for `%s` (`%d`):**",
        SUSPICIOUS_INVENTORY = "**Suspicious Inventory Detected:**",

        PLAYER_REPORT         = "%s [@here] `%s` **%s**: %s",
        PLAYER_REPORT_EMPTY   = "%s [@here] `%s` **%s**",
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
        ["rain"] = "raining",
        ["snow"] = "snowing",
        ["none"] = "no precipitation",
    },

    -- Create a copy of the game's seasons so we do not modify the actual table when translating
    SEASONS = shallowcopy(STRINGS.UI.SERVERLISTINGSCREEN.SEASONS),
    PHASES  = shallowcopy(STRINGS.UI.SERVERLISTINGSCREEN.PHASES),

    SEASON_UNKNOWN          = "Unknown Season",

    UI = {
        CONSOLE_DISABLED = "Disabled :)",

        -- Mod blocker popup
        MODS_BLOCKED_TITLE = "Mods Disabled",
        MODS_BLOCKED_BODY  = "Some of the mods you are using were blocked by the server.",

        TIP_TOGGLE_CHAT = "Anytime you get bored with the chat, don't forget that {toggle} will toggle it for you!",

        CMD_ERRORS = {
            EXECUTION = "Error while executing the command!",
            NO_RHOOK = "Report webhook is disabled! Enable 'RHOOK' in modoverrides.lua.",
            NO_SNAPSHOT_FOUND = "Couldn't find any snaphots for day %d.",
            FAILED_SNAPHOTS_LOAD = "Failed to load the snapshots for this session.",
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
                DESC       = "Removes the given player from the blacklist. Accepts both, Klei ID and Steam ID.",

                ON_SUCCESS  = "Player was successfully removed the blacklist and can join back now!",
                ON_NOTFOUND = "Player was not found on the blacklist...",
            },

            INV = {
                PRETTYNAME = "Display Inventory",
                DESC       = "Displays player's inventory on discord.",

                ON_SUCCESS          = "Inventory was sent to discord.",
                ON_NOTFOUND         = "Inventory is empty or doesn't exist...",
            },

            INV_FIND = {
                PRETTYNAME = "Find Inventory",
                DESC       = "Searches for inventory containing specified item.",

                ON_SUCCESS          = "%d results were sent to discord.",
                ON_FAILURE          = "No results...",
            },

            ALLOWLIST_ADD = {
                PRETTYNAME = "Add to whitelist",
                DESC       = "Increases the allowlist with the given user ID.",

                ON_ALREADY_WHITELISTED = "Player is already on the whitelist.",
                ON_SUCCESS  = "Player was successfully added to the whitelist.",
                ON_FAILURE  = "An error occured while saving the changes...",
                ON_BANNED   = "Player is on the blacklist and has no access to this server.",
                -- ON_DISABLED = "Allowlist je aktuálne vypnutý.",
            },

            ALLOWLIST_REMOVE = {
                PRETTYNAME = "Remove from allowlist",
                DESC       = "Attempts to remove the given player id from the allowlist.",

                ON_SUCCESS  = "Player was removed from the allowlist.",
                -- ON_DISABLED = "Allowlist je aktuálne vypnutý.",
                ON_FAILURE  = "An error occured while saving the changes...",
                ON_NOTFOUND = "Player was not found on the allowlist."
            },

            -- ALLOWLIST_TOGGLE = {
            --     PRETTYNAME = "Toggle the allowlist",
            --     DESC       = "Turns on/off the allowlisting.",

            --     ON_ENABLED  = "Allowlisting was enabled! Only players on the list will be able to join.",
            --     ON_DISABLED = "Allowlisting was disabled! Everyone can join now."
            -- }

            DAYSBACK = {
                PRETTYNAME = "Rollback by Days",
                DESC       = "Roll the server back by actual days instead of snapshots.\nChanges in the current snapshot will be lost!",
            },

            SOS = {
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
        },

        DISCORD_BUTTON_HOVER = "View Discord",

        INTRO_POPUP_BUTTON_CONTINUE = "Continue",
        AGREEMENT_SCREEN_BUTTON_FINISH = "Finish",
        AGREEMENT_SCREEN_BUTTON_AGREE = "I agree",
        AGREEMENT_SCREEN_BUTTON_DISAGREE = "I disagree",

        AGREEMENT_UPDATED_POPUP_TITLE = "Server Agreement Update",
        AGREEMENT_UPDATED_POPUP_BODY = "The server agreement has been updated and needs your review.",
        AGREEMENT_UPDATED_POPUP_CONTINUE = "Continue",

        AGREEMENT_DECLINE_POPUP_TITLE = "Decline the Server Agreement?",
        AGREEMENT_DECLINE_POPUP_BODY = "You will not be able to play on the server. Are you sure?",
        AGREEMENT_DECLINE_BUTTON_YES = "Yes",
        AGREEMENT_DECLINE_BUTTON_NO  = "No",
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

    --- @TODO: Add a bit more strings here.
    NOVICE_ANNOUNCEMENTS = {
        "Say welcome to %s! It's their first time on the server!",
        "Say hi to %s! He is new here!",
        "For the first time! It's %s!",
        "Let's welcome %s!",
        "%s joined for the first time! Welcome!",
        "Glad you are here %s!",
        "Finaly %s has arrived! Welcome!"
    }--"Say welcome to %s! It's their first time on the server!"
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
