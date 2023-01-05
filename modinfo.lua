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
version = "2.0"
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

--- @TODO
-- icon_atlas = "statusannouncements.xml"
-- icon = "statusannouncements.tex"

server_filter_tags = {
    "antigrief", "anticheat", "community", "announcement", "discord",
    "logs", "management", "monitoring", "moderation", "autoupdate"
}

configuration_options = {

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
    },

    {
        name="PROFANITY_FILTER",
        default=true,
        options = {
            true,
            false,
        },
        type = "boolean",
    },

    { -- regenerate, rollback, kick...
        name="COMMAND_BLOCKLIST",
        default={},
        type = "table",
    },

    --------------------
    -- Mod Blocker Module
    --------------------

    {
        name="MOD_BLACKLIST",
        default={},
        type = "table",
    },

    --------------------
    -- Server
    --------------------

    { -- Additional table of tags
        name = "CUSTOM_SERVER_TAGS",
        default = {},
        type = "table",
    },

    { --- @TODO: Option to add custom loading tips.
        name = "CUSTOM_LOADING_TIPS",
        default = true,
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


    --------------------
    -- Other Modules
    --------------------

    {
        name="LOG_SUSPICIOUS_INVENTORIES",
        default=true,
        options = {
            true,
            false,
        },
        type = "boolean",
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

    --------------------
    -- Anti-AFK Module
    --------------------

    { -- Time in seconds represeting the inactive time after which a player is considered AFK
      -- Settings this to 0 or lower will disable afk state (so no announcement).
        name = "AFK_TIME",
        default = 1 * 60,
        type = "number"
    },

    { -- Total AFK time in seconds after which the player
      -- will by disconnected from the server.
      -- Setting this to 0 or lower will prevent kicking AFK players.
        name = "AFK_TIME_KICK",
        default = 5 * 60,
        type = "number"
    },

    --------------------
    -- Localizer Module
    --------------------

    { -- This is an experimental feature.
        name = "CZSK_ONLY",
        default = false,
        options = {
            true,
            false,
        },
        type = "boolean",
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
    },

    --------------------
    -- Admin Calls
    --------------------

    {
        name = "ADMIN_CALL_COOLDOWN",
        default = nil, -- When nil or 0, there is no cooldown
        type = "number|nil",
    },

    --------------------
    -- Intro Screen
    --------------------

    {
        name = "INTRO_SCREEN",
        default = false,
        options = {
            true,
            false,
        },
        type = "boolean",
    },

    --------------------
    -- Discord Module
    --------------------

    -- Note: The url should contain also the protocol prefix
    {
        name = "DISCORD_INVITE",
        default = nil,
        type = "string|nil",
    },

    -- Webhook Identifiers (required if DISCORD_LOGS option is enabled)
    {
        name="LOG_WEBHOOK",
        default={
            ID = "",
            TOKEN = "",
            ENABLED = true,
        },
        type = "table",
    },

    {
        name="REPORT_WEBHOOK",
        default={
            ID = "",
            TOKEN = "",
            ENABLED = true,
        },
        type = "table",
    },

    {
        name="LHOOK_BUFFER_TIMEOUT",
        default = 4,
        type = "number",
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
    -- Update Checker
    --------------------

    {
        name="VERSION_CHECK_FREQUENCY", -- In minutes
        default=30,
        type = "number",
    },

    {
        name="UPDATE_SERVER_AFTER", -- In minutes
        default=5,
        type = "number",
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
        default = {},
        type = "table",
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
        type = "table",
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
        type = "table",
    },

    --------------------
    -- Debugging
    --------------------

    {
        name="DEBUG_MODE",
        default = false,
        type = "boolean",
        options = {
            true,
            false,
        },
    },
}
