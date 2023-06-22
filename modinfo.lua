--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


---@diagnostic disable: lowercase-global

name = "Pearl"
author = "Fi7iP"
version = "Review 2.4.3"
description = [[
    “Nothin' wrong with being independent.” - Winona
]]

priority = 2^31-2

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
hamlet_compatible = false
forge_compatible = false
client_only_mod = false

all_clients_require_mod = true

api_version = 10
forumthread = ""

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

--- @TODO: Create the checks API.
configuration_options = {

    --------------------
    -- Discord
    --------------------

    {
        name = "DISCORD",
        default = {
            INVITE = nil,
            -- The IDs NEEDS to be strings because they could overflow
            LHOOK = {
                ID = "",
                TOKEN = "",
                ENABLED = true,
                BUFFER_TIMEOUT = 4,
            },
            RHOOK = {
                ID = "",
                TOKEN = "",
                ENABLED = true,
            }
        },
        type = "table<string, any>",
        public = "DISCORD.INVITE",
        checks = {
            ID = "string",
            TOKEN = "string",
            INVITE = "string",
        }
    },

    --------------------
    -- REST API
    --------------------

    {
        name="REQUEST_FREQUENCY", -- In seconds
        default=2,
        type = "number",
    },

    --------------------
    -- Languages
    --------------------

    {
        name = "LANGUAGE",
        default = "en",
        options = {
            "en",
            "sk",
        },
        type = "string",
        general = true,
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

    --------------------
    -- Server
    --------------------

    { -- Additional table of tags
        name = "CUSTOM_SERVER_TAGS",
        default = {},
        type = "table<string>",
    },

    { --- @TODO: Option to add custom loading tips.
        name = "CUSTOM_LOADING_TIPS",
        default = false,
        options = {
            true,
            false,
        },
        type = "boolean",
    },

    {
        name = "CUSTOM_CONTROLS",
        default = true,
        options = {
            true,
            false,
        },
        type = "boolean",
        public = true,
    },

    {
        name = "SHARD_NAME",
        default = nil,
        type = "string?",
    },

    --------------------
    -- Global Player Icons
    --------------------

    {
        name="SHOW_PLAYER_ICONS",
        default=true,
        options = {
            true,
            false,
        },
        type = "boolean",
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
        name="INVENTORY_REPORTER",
        default={
            DROP_UNDER_AGE = 0, -- Setting this to zero will disable dropping.
            SEND_REPORT = true,
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
        name = "DATABASE",
        default = {
            ENABLED = false,
        },
        type = "table",
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
        name="CONSOLE_COMMANDS",
        default=true,
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

    --- @disabled for now, use allowlist instead which is more reliable.
    -- Keeping it here just in case it is useful for something.
    {
        name = "WHITELIST_MODE",
        default = false,
        options = {
            true,
            false,
        },
        type = "boolean",
    },

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
        default = false,
        master_only = true,
        options = {
            true,
            false,
        },
        type = "boolean",
        public = true,
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
            all = true,
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
            ["some_taskset"] = {"some_required_task", "another_required_task"}
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
        name="SERVER_REQUIRE_CFD",
        default = true, -- Let this be always true because a lot of systems depend on these.
        type = "boolean",
        public = true,
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
        name="HEALTH_INFO",
        default = {
            ENABLED = false,
            TAGS = {},
        },
        type = "table",
        public = true,
    },
}
