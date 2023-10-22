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

        EAT = {
            GENERIC     = "{doer} ate {target}.",
            FULL        = "{doer} overeated with {target}."
        },

        READ = {
            GENERIC     = "{doer} read {target}.",
            NEAR        = "{doer} read {target} near {near}!",
        },

        TEACH = {
            GENERIC     = "{doer} learnt {target}.",
        },

        COOK = {
            GENERIC     = "{doer} cooked {target}!",
            ON          = "{doer} cooked {target} on {tool}!",
            IN          = "{doer} cooked {target} in {tool}!",
        },

        EXTINGUISH = {
            GENERIC     = "{doer} extinguished {target}.",
            WITH        = "{doer} extinguished {target} using {tool}.",
        },

        KILL = {
            GENERIC     = "{doer} killed {target}!",
            NEAR        = "{doer} killed {target} near {near}!",
            REMAINING   = "{doer} killed {target}! Remaining: {remaining}",
            LAST        = "{doer} killed the last {target}!",
            FOLLOWER    = "{doer} killed {target}! Owner: {owner}",
            BOSS        = "{target} defeated {doer}!"
        },

        CHOP = {
            GENERIC     = "{doer} chopped down {target}.",
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
        },

        FERTILIZE = {
            GENERIC     = "{doer} fertilized {target}.",
            WITH        = "{doer} fertilized {target} with {item}.",
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
            DESC_TITLE = "**World Setting Overrides**",
            FD_NAMES = {
                SEED            = "New World Seed",
                SESSION_ID      = "World ID",
                SAVE_VERSION    = "Save Version",
                --- @TODO
                REED_TRAP       = "Reed Trap",
                WALRUS_CAMPS    = "Walrus Camps",
            },
        },

        LEADERBOARD = {
            TITLE_ABS = "Total Leaderboard",
            TITLE_CUR = "Month Leaderboard",
            TITLE_ARCHIVED = "Archived",

            FD_NAMES = {
                INDEX_COL   = "Place",
                NAME_COL    = "Name",
                REP_COL     = "Reputation",
                MONTH       = "Month",
                CREATED     = "Data From",
            },

            FD_VALUES = {
                MONTH = "%s %s",
            },

            THMB_ABS_URL = "https://cdn.discordapp.com/attachments/1066442901380403333/1129005246027419648/trophy-big.png",
            THMB_CUR_URL = "https://cdn.discordapp.com/attachments/1066442901380403333/1127332501858291732/daychanges.png",

            NOT_ENOUGH_DATA = "*Not enough data*"
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
            TITLE = "%s's Enabled Mods",
            FOOTER = "%s/%s",
        },

        PROFILE = {
            -- Prefab + Username
            TITLE = "%s %s",
            FOOTER = "Klei ID: %s Steam ID: %s Root Klei ID: %s",
            FD_NAMES = {
                PLAYED  = "Total Days Played",
                REP     = "Reputation",
                JOINED  = "Joined At",
                LOCALE  = "Locale",
                SEEN    = "Last Time Seen",
                DISCORD = "Discord",
            },
        },
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
        INV_REPORT_DROPPED      = "Player's inventory was dropped before despawning.",
        INV_RARE_ITEMS_DROPPED  = "Rare items were dropped from player's inventory before despawning.",

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
        STAFF_CALLED            = "Admins and server moderators were notified.",
        SKIN_RECEIVED           = "%s received %s!",
        --DAY                     = "Day %d - %s (%s °C) - %d/%d Players",
        DAY                     = "Day %d - %s (%s °C)",
        PHASE                   = "%s",

        SPAWN_AT                = "Spawning %s in shard %s at: X: %d Y: %2.2f Z: %2.2f",

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

        -- We assume that catched exceptions are always caused by us.
        EXC_CATCHED_SERVER      = "Catched exception on server %s:\n%s",
        EXC_CATCHED_SHARD       = "Catched exception on shard %s:\n%s",
        EXC_CATCHED_CLIENT      = "Catched exception on client (%s) %s:\n%s",

        EXC_SERVER              = "Uncatched exception:\n%s",
        EXC_SHARD               = "Uncatched exception on shard %s:\n%s",
        EXC_CLIENT              = "Uncatched exception on client (%s) %s:\n%s",

        EXC_SELF_SERVER         = "Caused uncatched exception:\n%s",
        EXC_SELF_SHARD          = "Caused uncatched exception on shard %s:\n%s",
        EXC_SELF_CLIENT         = "Caused uncatched exception on client (%s) %s:\n%s",

        EXC_MOD_SERVER          = "Mod %s caused uncatched exception:\n%s",
        EXC_MOD_SHARD           = "Mod %s caused uncatched exception on shard %s:\n%s",
        EXC_MOD_CLIENT          = "Mod %s caused uncatched exception on client (%s) %s:\n%s",

        EXC_ENABLED_MODS        = "Enabled Mods (%s):\n%s",

        AFFLICTER_MOD_DISABLED  = "The crashed mod was disabled.",
        HTTP_ERROR              = "HTTP Error status code on shard %s:\n%s",

        INVALIDRPC              = "Received invalid RPC %s from client %s!",

        EXTINGUISH              = "Fires were extinguished!",
        EXTINGUISH_DOER         = "%s extinguished all fires!",
        EXTINGUISH_NEAR         = "Fires near %s were extinguished!",
        EXTINGUISH_NEAR_DOER    = "%s extinguished fires near %s!",
        EXTINGUISH_ALL          = "%s extinguished fires near all players!",

        REPAIR                  = "Burnt structures were restored!",
        REPAIR_NEAR             = "Burnt structures near %s were restored!",
        REPAIR_NEAR_DOER        = "%s restored burnt structures near %s!",
        REPAIR_NEAR_ALL         = "%s restored burnt structures near all players!",
        REPAIR_ALL              = "All burnt structures were restored!",
        REPAIR_ALL_DOER         = "%s restored all burnt structures!",

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

    DATE_FORMAT = "%s. of %s %s",
    FULL_MONTH_NAME = "%s %s", -- First is fancy month name and then the year number

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
        CONSOLE_DISABLED = "Disabled :)",

        ALLOWED = "Allowed",
        BLOCKED = "Blocked",

        -- Mod blocker popup
        MODS_BLOCKED_TITLE = "Mods Disabled",
        MODS_BLOCKED_ALL_TITLE = "All Mods Blocked",
        MODS_BLOCKED_BODY  = "Some of the mods you are using were blocked by the server.",
        MODS_BLOCKED_ALL_BODY = "All of your mods were blocked by the server.",

        TIP_TOGGLE_CHAT = "Anytime you get bored with the chat, don't forget that {toggle} will toggle it for you!",

        WHISPER_WARN_TEXT = "Messages sent in the Whisper Mode will be only visible to nearby players. Use %s in order to display your message for everyone.",

        DM_DESIGNATOR = "[DM]",

        LOADING_VERIFICATION = "Verifying connection...",
        LOADING_ERROR = "Maybe it didn't work that well at the end...",

        CMD_ERRORS = {
            EXECUTION = "Error while executing the command!",
            NO_RHOOK = "Report webhook is disabled! Enable 'RHOOK' in modoverrides.lua.",
            NO_SNAPSHOT_FOUND = "Couldn't find any snaphots for day %d.",
            FAILED_SNAPHOTS_LOAD = "Failed to load the snapshots for this session.",
            SERVER_ONLY = "This command does only work on a server!",
            PLAYER_NOT_FOUND = "Player not found!",
            ITEM_PREFAB_INVALID = "Invalid item prefab provided!",
            ITEM_NOT_FOUND = "Item not found!",
            MOD_ALREADY_BLOCKED = "The specified mod is already blocked on the server.",
            SHARD_NOT_FOUND = "The specified shard is not connected to Master!",
            DB_DISABLED = "The database is not enabled!",
            KLEI_SERVERS_UNREACHABLE = "There was an error contacting Klei servers."
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

            GIVE = {
                PRETTYNAME = "Give Item",
                DESC       = "Gives an item to any player you have specified.",

                ON_SUCCESS = "Gave %sx %s to %s."
            },

            TAKE = {
                PRETTYNAME = "Take Item",
                DESC       = "Take an item from player you have specified.",

                ON_SUCCESS = "Took %sx %s from %s.",
            },

            DROP = {
                PRETTYNAME = "Drop Item(s)",
                DESC       = "Drops an player's item or the whole inventory if no item was specified.",

                DROP_ALL   = "%s's inventory was dropped!",
                DROP       = "Dropped %sx %s from %s's inventory!",
            },

            KILL = {
                PRETTYNAME = "Kill a Player",
                DESC       = "Kills the specified player on spot.",

                ON_SUCCESS = "Player was killed...",
            },

            REVIVE = {
                PRETTYNAME = "Revive a Player",
                DESC       = "Revives the specified player on spot.",

                ON_SUCCESS = "Player was revived!",
            },

            PAUSE = {
                PRETTYNAME = "Pause/Resume",
                DESC       = "Toggle pause the server.",
            },

            DESPAWN = {
                PRETTYNAME = "Despawn a Player",
                DESC       = "Despawns the specified player on spot. Inventory is dropped.",

                ON_SUCCESS = "Player was despawned and is now back in the lobby.",
            },

            SETREP = {
                PRETTYNAME = "Set Player's Reputation",
                DESC       = "Sets the reputation amount for the specified player to whatever number you want.",

                ON_SUCCESS = "Reputation successfully set!",
                ON_FAILURE = "Failed to set reputation.",
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

            RELOAD = {
                PRETTYNAME = "Reload the Server",
                DESC       = "Internally restarts the server without disconnecting any players."
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

            SET_DB_FIELD = {
                ON_SUCCESS = "Field successfully set!",
                ON_FAILURE = "Failed to set the specified field!",
            },

            BOOST = {
                ON_SUCCESS = "Lower server latency for 2 minutes!",
                ON_TIMEOUT = "Server response latency back to normal.",
                ON_FAILURE = "Wasn't able to lower the server latency!",
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

            GAMEOWNER = {
                ON_SUCCESS = "Owner of the game is %s",
                ON_FAILURE = "Couldn't retrive the game owner for the specified account."
            },

            SET_SLOTS = {
                PRETTYNAME = "Set Server Slots Count",
                DESC       = "Sets the number of player slots for the server.",

                ON_INVALID_INPUT = "Invalid number of slots provided!",
                ON_COUNT_TOO_LOW = "The Specified number of slots is less than the total number of players!",
                ON_SUCCESS = "The number of server slots has been updated!",
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
