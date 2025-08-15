--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- Provided by the environment:
--- folder_name, locale, ChooseTranslationTable


---@diagnostic disable: lowercase-global

name = "Pearl"
backend_name = "PearlOS"
author = "Fi7iP"
version = "Hotfix 3.0.7ddtmm"
description = [[
    “I'd been meaning to fix the place up for a while...” - Crabby Hermit
]]

priority = 1.7976931348623e+308 -- std::numeric_limits<lua_Number>::max()

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
hamlet_compatible = false
forge_compatible = false
client_only_mod = false

all_clients_require_mod = true

api_version = 10
forumthread = ""

mod_dependencies = {}
uncompatible_mods = {
    "workshop-3033694168", -- Better Wormwood (until we figure out a way how to fix the fonts)
    "workshop-3056140321", -- Menu Remix - Again, the games font system is broken...
                           -- Also these two are not compatible with each other as well.

    "workshop-3169441836", -- We implement our own "Better" crash screen >:-)
}

-------------------------------------
-- [[ Mod Specific Server Tags ]]
-------------------------------------

server_filter_tags = {
    "antigrief", "anticheat", "community", "announcement", "discord",
    "logs", "management", "monitoring", "moderation", "autoupdate"
}

-------------------------------------
-- [[ Configurations ]]
-------------------------------------

--- @TAGS:
--- - general - This configuration loads directly in modmain.lua
--- - name - Name of the configuration
--- - default - The default value of the configuration
--- - type - The more specific type definition of the configuration.
--- - public - Whether it is sent to the clients or not.
--- - warn - Whether to log a warning in when this option is not configured.
--- - master_only - Whether it shouldn't load in caves or vice versa.
--- - implicit - This configuration is meant to be used internally.
--- - zip - For public configurations. If set, we will attempt to zip the value before sending.

configuration_options = {

    --------------------
    -- Discord
    --------------------

    {
        name = "DISCORD",
        default = {
            -- The IDs NEED to be strings because they could overflow
            LHOOK = {
                ID              = "",
                TOKEN           = "",
                ENABLED         = true,
                BUFFER_TIMEOUT  = 4,
            },
            RHOOK = {
                ID          = "",
                TOKEN       = "",
                ENABLED     = true,
                COOLDOWN    = 300, -- 5 minutes
                MAX_REPORTS = 5,   -- Number of reports until cooldown is triggered.
                -- Note: During cooldown are all reports ignored (except uncatched ones)
            },
            BHOOK = {
                ID      = "",
                TOKEN   = "",
                ENABLED = false,
            },

            PROXY = {
                URL                     = "http://localhost:10997",

                CHAT_ENABLED            = false,
                COMMANDS_ENABLED        = false,

                MIN_FETCH_PERIOD        = 10, -- Fetch request at most once every 10 seconds
                FETCH_TIMEOUT           = 1024,

                START_SESSION_RETRIES   = 3,
                FETCH_RETRIES           = 3,

                TIME_BETWEEN_FETCH_RETRIES = 10,
                TIME_BETWEEN_START_SESSION_RETRIES = 10,

                ENSURE_CONNECTION_PERIOD = 30 * 60, -- Ensure every half hour
            },

            GUILDS = {}
        },
        type = "table<string, any>",
        checks = {
            ID = "string",
            TOKEN = "string",
        }
    },

    --------------------
    -- Folders
    --------------------

    {
        name = "SERVER_FOLDERS",
        default = {
            CLUSTER = "MyDediServer",
            SHARD = "Master",
            UGC_MODS_ROOT = "ugc_mods",
        },
        type = "table<string, string?>"
    },

    --------------------
    -- Social Links
    --------------------

    {
        name = "SOCIAL_LINKS",
        default = {
            DISCORD = nil,
            YOUTUBE = nil,
            TWITCH  = nil,
        },
        public = true,
        type = "table<string, string?>"
    },

    --------------------
    -- Steam
    --------------------

    {
        name = "STEAM",
        default = {
            API_KEY = nil,
            BASE_URL = "https://steamcommunity.com",
            BASE_API_URL = "https://api.steampowered.com",
            VERIFY_NEW_ACCOUNTS = true,
        },
        type = "table<string, any>",
    },

    --------------------
    -- Klei Lobby
    --------------------

    {
        name = "KLEI_LOBBY",
        default = {
            BASE_URL = "https://lobby-v2-eu-central-1.klei.com/lobby/",
            REGIONS_URL = "https://lobby-v2-cdn.klei.com/regioncapabilities-v2.json",
        },
        type = "table<string, string>",
    },

    --------------------
    -- Leadeboard
    --------------------

    {
        name = "LEADERBOARD",
        default = {
            ENABLED = false,
            ENCODE_DATA = false,
            DIRECTORY = ".",
            TYPES = {
                MONTHLY = true,
                ABSOLUTE = true,
            }
        },
        type = "table",
    },

    --------------------
    -- Database
    --------------------

    {
        name = "DATABASE",
        default = {
            ENABLED = false,
            ENCODE_DATA = false,
            DIRECTORIES = {
                ROOT = ".",
                RECORDS = ".",
                BINDINGS = ".",
            },
        },
        type = "table",
    },

    --------------------
    -- Logging
    --------------------

    {
        name = "LOGGING",
        general = true,
        default = {
            ENABLED = true,
            --VERBOSITY = "info",  -- "debug"|"info"|"warn"|"error"
            DEBUG_FILE = false,
        },

        public = "LOGGING.ENABLED",
        type = "table",
    },

    --------------------
    -- Proxy
    --------------------

    {
        name = "PROXY",
        general = true,
        default = {
            ENABLED = false,
            URL = nil,
        },
        type = "table",
    },

    --------------------
    -- Auto-Ban
    --------------------

    {
        name = "AUTOBAN",
        default = {
            ENABLED = false,
            THRESHOLD = 0,
            DURATION = nil, -- Forever
        },
        type = "table",
    },

    --------------------
    -- Languages
    --------------------

    {
        name = "LANGUAGE",
        default = "english",
        options = {
            "english",
            "slovak",
        },
        type = "string",
        general = true,
        public = true,
    },

    {
        name = "CUSTOM_TRANSLATIONS",
        default = {},
        type = "table<string, string>",
        public = true,
    },

    {
        name="PROFANITY_FILTERS",
        default= {
            default = true,
            enabled = true,
            ["czech"] = true,
        },
        type = "table<string, boolean>",
    },

    {
        name = "FILTER_USERNAMES",
        default = true,
        options = {
            true,
            false,
        },
        type = "boolean",
    },

    {
        name = "PROFILE_FILTER",
        default = {
            ENABLED = true,
            ENSURE_PROFILE = true,

            MAX_REPUTATION = 40,
            MIN_REPUTATION = -40,
        },
        type = "boolean",
    },

    { -- regenerate, rollback, kick...
        name="COMMAND_BLOCKLIST",
        default={},
        type = "table<string, boolean>",
        public = true,
    },

    { -- regenerate, rollback, kick...
        name="CHARACTER_BLOCKLIST",
        default={},
        type = "table<string, boolean>",
        public = true,
    },

    {
        name = "STEAM_GROUP_BLOCKLIST",
        default = {},
        type = "table<string, boolen>",
        public = true,
    },

    {
        name = "DATA_ROOT_DIRECTORY",
        default = ".", -- at DoNotStarveTogetherDedicatedServer/data
        type = "string",
    },

    --------------------
    -- Mod Blocker Module
    --------------------

    {
        name="MOD_BLOCKER",
        default={
            STRICT = false,
            ENABLED = true,
            ALLOWLIST = false,
            REPORT_MODS = true,
        }, -- Setting strict key to true will kick out all players who have such mods enabled.
        type = "table<string, boolean>",

        warn = true,
        public = true,
    },

    {
        -- Similiar to blocked mods but these will be disabled only temporary and silently.
        name="UNCOMPATIBLE_MODS",
        default={},
        type = "table",
        public = true,
    },

    --------------------
    -- Server
    --------------------

    { -- Additional table of tags
        name = "CUSTOM_SERVER_TAGS",
        default = {},
        type = "table<string>",
    },

    {
        name = "CUSTOM_LOADING_TIPS",
        default = false,
        options = {
            true,
            false,
        },
        type = "boolean",
    },

    { -- Here we cannot implement option for adding custom backgrounds.
      -- Because there isn't a way to (aside from using a REST API) to get
      -- the required images to the client.
        name = "CUSTOM_LOADING_IMAGES",
        default = false,
        public = true,
        options = {
            true,
            false,
        },
        type = "boolean",
    },

    {
        name = "CUSTOM_CONNECTION_FILTERS",
        default = nil,
        options = nil,
        type = "table<number, function>",
    },

    {
        name = "WHISPER_WARNING",
        default = false,
        public = true,
        options = {
            true,
            false,
        },
        type = "boolean",
    },

    {
        name = "EMPTY_SERVER_POPUP",
        default = true,
        type = "boolean",
        public = true,
    },


    {
        name="BASE_SPAWNER",
        default = {
            ENABLED = false,
            TRUSTED_ONLY = true,
            BASE_RADIUS = 16,
            UNIQUE_BASE_STRUCTURE_THRESHOLD = 4,
            -- Sorted by priority
            SPAWN_STRUCTURE_PREFABS = {
                "oasislake",
                "firepit",
                "coldfirepit",
                "treasurechest",
                "dragonflychest",
                "icebox",
                "saltbox",
                "reasearchlab3",
                "researchlab2",
                "researchlab3",
                "researchlab",
                "tent",
                "siestahut",
                "dryingrack",
            },
        },
        type = "table",
        public = true,
    },

    {
        name = "HIDE_SERVER_ONLY_MODS",
        default = false,
        options = {
            true,
            false,
        },
        type = "boolean",
    },

    -- {
    --     name = "CUSTOM_CONTROLS",
    --     default = true,
    --     options = {
    --         true,
    --         false,
    --     },
    --     type = "boolean",
    --     public = true,
    -- },

    {
        name = "SHARD_NAME",
        default = nil,
        type = "string?",
    },

    {
        name = "HOST",
        default = {
            NAME = nil,
            URL  = nil,
        },
        public = true,
        type = "table",
    },

    --------------------
    -- Global Player Icons
    --------------------

    {
        name="PLAYER_MAP_ICONS",
        default={
            ENABLED = true,
            ONLY_FOR_TRUSTED = false, -- Whether to show the icons only for trusted players
        },
        type = "table",
    },

    {
        name = "TRUST_AGE",
        default = 24,
        type = "number",
    },

    {
        name = "TRUST_AGE_PERCENT",
        default = .3,
        type = "number",
    },

    --------------------
    -- Other Modules
    --------------------

    {
        name="BETTER_WORMWOOD_FONT",
        default = true,
        type = "boolean",
        public = true,
    },

    {
        name="CUSTOM_EMOJI_PACKS",
        default = {
            ["discord_emojis"] = true,
            ["discord_emojis_animated"] = true,
        },
        type = "table",
        public = true,
    },

    {
        -- Function returning a table of emoji aliases in the following format:
        --[[
            {
                "<EMOJI_ALIAS>": <ROOT_EMOJI>,
            }
        --]]
        -- The first parameter to the function is the main PEARL table providing all the needed
        -- emojis that can be aliased.
        -- Key and Values should be always of the oposite type.
        name="EMOJI_ALIASES",
        default = function() end,
        type = "function",
    },

    {
        name="EMOJI_MENU",
        default = true,
        type = "boolean",
        public = true,
    },

    {
        name="HEALTH_INFO",
        default = {
            ENABLED = false,
            TAGS = {},
        },
        type = "table",
        public = true,
    },

    {
        name="GLOBAL_BANLIST",
        default={
            ENABLED = false,
            STRICT  = false,
            URL     = nil,
        },
        type = "table",
    },

    {
        name="LANGUAGE_SERVER",
        public = true,
        default={
            ENABLED     = false,
            AUTOUPDATE  = false,
            URL         = nil,
            FILENAME    = nil,
            --LANGUAGE    = nil,
        },
        type = "table",
    },

    {
        name="EMOJI_SERVER",
        default = {
            ENABLED = false,
            AUTOUPDATE = false,
            URL = nil,
            FILENAME = nil,
        },
        type = "table",
    },

    {
        name="COMMON_MOD_CONFIG",
        default = true,
        general = true,
        type = "boolean",
    },

    {
        name = "SUPPORTED_CLIENT_PLATFORMS",
        default = { -- We do only support Steam as the platform by default
            -- Commented out for now so the checker is disabled by default since
            -- cross-platform is not supported currently.
            -- But in can be still enabled via modoverrides.lua in case something changes...
            --"WIN32_STEAM",
            --"LINUX_STEAM",
            --"OSX_STEAM",
        },
        type = "table",
    },

    {
        name="INVENTORY_REPORTER",
        default={
            DROP_AFTER_CYCLE = 30,
            DROP_ALL_UNDER_REP = 100,
            DROP_RARE_UNDER_REP = 200,
            SEND_REPORT = true,
            USE_AI = true,
            AI_REPORT_CHANNEL = nil,
            ENABLED = true,
        },
        type = "table",
    },

    {
        name="BAN_ALT_ACCOUNTS",
        default=true,
        options = {
            true,
            false,
        },
        type = "boolean",
    },

    {
        name="REPORT_BAD_CLIENT_LATENCY",
        default=true,
        options = {
            true,
            false,
        },
        type = "boolean",
    },

    {
        name="REPORT_BAD_SERVER_LATENCY",
        default=true,
        options = {
            true,
            false,
        },
        type = "boolean",
    },

    {
        name="SEND_KLEI_METRICS",
        default=true,
        options = {
            true,
            false,
        },
        type = "boolean",
    },

    {
        name = "VERSION_CHECKER",
        default = {
            ENABLED = true,
            FREQUENCY = 30, -- In Minutes
            UPDATE_AFTER = 0, -- In Seconds, 0> if disabled, 0 for immeadiate updates
        },
        type = "table",
    },

    --------------------
    -- Commands
    --------------------

    {
        name="SLASH_COMMANDS",
        default=true,
        options = {
            true,
            false,
        },
        type = "boolean",
        public = true,
    },

    {
        name="SLASH_COMMAND_HISTORY",
        default=true,
        options = {
            true,
            false,
        },
        type = "boolean",
        public = true,
    },

    {
        name="CONSOLE_COMMANDS",
        default=true,
        options = {
            true,
            false,
        },
        type = "boolean",
        public = true,
    },

    { -- Discord commands are server only.
        name="DISCORD_COMMANDS",
        default=false,
        options = {
            true,
            false,
        },
        type = "boolean",
    },

    {
        name="CLIENT_CONSOLE_ENABLED",
        default=false,
        options = {
            true,
            false,
        },
        type = "boolean",
        public = true,
    },

    {
        name="LOG_CONSOLE_COMMANDS",
        default=true,
        options = {
            true,
            false,
        },
        type = "boolean",
    },

    --------------------
    -- Anti-AFK Module
    --------------------

    { -- Time in seconds represeting the inactive time after which a player is considered AFK
      -- Settings this to 0 or lower will disable afk state (so no announcement).
        name = "AFK_TIME",
        default = 1 * 60,
        type = "number",
        public = true,
    },

    { -- Total AFK time in seconds after which the player
      -- will by disconnected from the server.
      -- Setting this to 0 or lower will prevent kicking AFK players.
        name = "AFK_TIME_KICK",
        default = 5 * 60,
        type = "number",
        public = true,
    },

    --------------------
    -- Localizer Module
    --------------------

    { -- This is an experimental feature.
        name = "LOCALIZER",
        default = {
            ENABLED = false,
            --> e.g.:
            --[[
                ALLOWED_LOCALES = {
                    ["SK"] = true,
                    ["CZ"] = true,
                    ...
                },
            --]]
            ALLOWED_LOCALES = {},
            CACHE = true,
        },
        type = "table<string, any>",

        checks = {
            ALLOWED_LOCALES = "table",
        }
    },

    --------------------
    -- Access Lists
    --------------------

    {
        name = "ALLOWLIST",
        default = false,
        options = {
            true,
            false,
        },
        type = "boolean",
    },

    --------------------
    -- Voting
    --------------------

    {
        name = "MIN_VOTE_AGE",
        default = nil, -- When nil, uses the default built-in value
        type = "number|nil",
        public = true,
    },

    --------------------
    -- Admin Calls
    --------------------

    {
        name = "ADMIN_CALL_COOLDOWN",
        default = 5 * 60, -- When nil or 0, there is no cooldown
        type = "number|nil",
        public = true,
    },

    --------------------
    -- Intro Screen
    --------------------

    {
        name = "INTRO_SCREEN",
        default = {
            ENABLED = false,
            SHOW_AGREEMENT = true,
            SHOW_WELCOME_POPUP = true,
            SHOW_AGREEMENT_BUTTON = true,
        },
        master_only = true,
        type = "table",
        public = true,
    },

    {
        name = "INTRO_MOVIE_FILENAME", -- Name of the file with an optional extension (.ogv)
        default = nil,
        type = "string",
        public = true,
    },

    --------------------
    -- Mods
    --------------------

    {
        name = "REQUIRED_CLIENT_MODS", -- List of mods to be installed to clients.
        default = {},
        type = "table",
    },

    --------------------
    -- Network
    --------------------

    {
        name = "FAIL_SAFE_NETWORK",
        default = false,
        options = {
            true,
            false,
        },
        type = "boolean",
        public = true,
    },

    {
        name = "AUTH_TIMEOUT",
        default = 20,
        type = "number",
        public = true,
    },

    --------------------
    -- Announcements
    --------------------

    --> e.g.:
    --[[
        ANNOUNCEMENTS = {
            ["defeat"] = true,
            ["kill"] = false,
            ...
        },
    --]]
    {
        name = "ANNOUNCEMENTS",
        default = {
            all = nil,
            default = true,
        },
        type = "table<string, boolean>",
    },

    --------------------
    -- World gen
    --------------------

    --[[
        Accepts an key-value like table where all the keys are the taskset names and values
        are arrays of tasks that are required in these tasksets. So for example:

        "REQUIRED_WORLDGEN_TASKS" = {
            "reguired task name"
        }

        By default there are 2 main tasksets,
        one for overworld ("default") and another for caves ("caves_default").

        Task names can be found in map/tasksets/forest.lua and map/tasksets/caves.lua.
    --]]
    {
        name = "REQUIRED_WORLDGEN_TASKS",
        default = {},
        type = "table<string>",
    },

    {
        name="SEED",
        default = nil,
        type = "number|nil",
    },

    --------------------
    -- Prefabs
    --------------------

    {
        name = "CUSTOM_PREFABS",
        default = {},
        type = "table<string>",
    },

    {
        name = "PREFAB_EXTENSIONS",
        default = {},
        type = "table<string>",
    },

    --------------------
    -- Modes
    --------------------

    {
        name="DEBUG_MODE",
        default = false,
        type = "boolean",
        public = true,
        general = true,
        options = {
            true,
            false,
        },
    },

    {
        name="PERMISSIVE_MODE",
        default = false,
        type = "boolean",
        options = {
            true,
            false,
        },
    },

    --------------------
    -- Performance
    --------------------

    {
        name = "PERFORMANCE_MODE",
        default = false,
        type = "boolean",
        experimental = true,
    },

    {
        name = "SELF_STACKER",
        default = {
            PREFABS = {},
            ENABLED = false,
            RADIUS = 20, -- Taken from selfstacker.lua
        },
        type = "table",
    },

    {
        name = "LAZY_LOAD_PREFABS",
        default = false,
        general = true,
        type = "boolean",
        options = {
            true,
            false,
        }
    },

    --------------------
    -- Implicit Configurations
    --------------------
    -- These are configurations that are not being explicitly set
    -- by the user but are being configured implicitly by the mod instead.

    -- The strings here can be HUGE, so rather encode and ZIP them before sending...
    {
        name="AGREEMENT_SCREEN_CONTENT",
        default = nil,
        type = "table|nil",
        zip = true,
        master_only = true,
        public = true,
        implicit = true,
    },

    {
        name="WELCOME_POPUP_CONTENT",
        default = nil,
        type = "table|nil",
        zip = true,
        public = true,
        master_only = true,
        implicit = true,
    },

    {
        name="CUSTOM_LOADING_TIPS_DATA",
        default = {},
        type = "table",
        zip = true,
        public = true,
        implicit = true,
    },

    {
        name="MOD_BLOCKLIST",
        default = {},
        type = "table",
        zip = true,
        public = true,
        implicit = true,
    },

    {
        name="MOD_ALLOWLIST",
        default = {},
        type = "table",
        zip = true,
        public = true,
        implicit = true,
    },

    {
        name="DISCORD_PROXY_ENABLED",
        default = false,
        type = "boolean",
        public = true,
        implicit = true,
    },

    { -- Executed client side and server side, do some checks in it to determine where we are first.
        name = "MOUNTABLE_LUA",
        default = "",
        type = "string", -- lua loadable string (optional)
        public = true,
        zip = true,
        implicit = true,
    },
}
