--[[
Copyright (c) 2023 Fi7iP
The Czechoslovakian Don't Starve Together Game Comunity
<https://discord.gg/RHzJxut>

This file is part of the 'Pearl'.

The source code of this program and all its parts are shared under
the RECEX SHARED SOURCE LICENSE (version 1.0).
This is NOT Free and Open Source software, and the code is
NOT redistributable without permission of the author(s).
The source code licensed under this license is shared "as is" and does
not come with any warranty including the implied warranty of merchandise.
Read the RECEX SHARED SOURCE LICENSE for details.

You should have received a copy of the RECEX SHARED SOURCE LICENSE
in the form of a LICENSE file in the root of the source directory.
If not, please refer to
<https://raw.githubusercontent.com/Recex/Licenses/master/SharedSourceLicense/LICENSE.txt>

You can contact the author(s) at
<https://steamcommunity.com/profiles/76561198339302667/>
--]]



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
        name="LANGUAGE",
        default="en",
    },

    {
        name="PROFANITY_FILTER",
        default=true,
    },

    { -- regenerate, rollback, kick...
        name="COMMAND_BLOCKLIST",
        default={},
    },

    --------------------
    -- Mod Blocker Module
    --------------------

    {
        name="MOD_BLACKLIST",
        default={},
    },

    --------------------
    -- Server
    --------------------

    { -- Additional table of tags
        name = "CUSTOM_SERVER_TAGS",
        default = {},
    },

    {
        name = "CUSTOM_LOADING_TIPS",
        default = true,
    },

    {
        name = "CUSTOM_CONTROLS",
        default = true,
    },

    --------------------
    -- Global Player Icons
    --------------------

    {
        name="SHOW_PLAYER_ICONS",
        default=true,
    },

    {
        name = "TRUST_AGE",
        default = 24,
    },


    --------------------
    -- Other Modules
    --------------------

    {
        name="LOG_SUSPICIOUS_INVENTORIES",
        default=true,
    },

    {
        name="BAN_ALT_ACCOUNTS",
        default=true,
    },

    --------------------
    -- Commands
    --------------------

    {
        name="SLASH_COMMANDS",
        default=true,
    },

    {
        name="CONSOLE_COMMANDS",
        default=true,
    },

    --------------------
    -- Anti-AFK Module
    --------------------

    { -- Time in seconds represeting the inactive time after which a player is considered AFK
      -- Settings this to 0 or lower will disable afk state (so no announcement).
        name = "AFK_TIME",
        default = 1 * 60,
    },

    { -- Total AFK time in seconds after which the player
      -- will by disconnected from the server.
      -- Setting this to 0 or lower will prevent kicking AFK players.
        name = "AFK_TIME_KICK",
        default = 5 * 60,
    },

    --------------------
    -- Localizer Module
    --------------------

    { -- This is an experimental feature.
        name = "CZSK_ONLY",
        default = false,
    },

    --------------------
    -- Access Lists
    --------------------

    --- @disabled for now, use allowlist instead which is more reliable.
    -- Keeping it here just in case it is useful for something.
    {
        name = "WHITELIST_MODE",
        default = false,
    },

    {
        name = "ALLOWLIST",
        default = false,
    },

    --------------------
    -- Intro Screen
    --------------------

    {
        name = "INTRO_SCREEN",
        default = false,
    },

    --------------------
    -- Discord Module
    --------------------

    --- @TODO: Shutdown the logs by shutting down the rhook and lhook webhooks
    -- Logging
    -- {
    --     name="DISCORD_LOGS",
    --     default=true,
    -- },

    -- Note: The url should contain also the protocol prefix
    {
        name="DISCORD_INVITE",
        default=nil,
    },

    -- Webhook Identifiers (required if DISCORD_LOGS option is enabled)
    {
        name="LOG_WEBHOOK",
        default={
            ID = "",
            TOKEN = "",
            ENABLED = true,
        }
    },

    {
        name="REPORT_WEBHOOK",
        default={
            ID = "",
            TOKEN = "",
            ENABLED = true,
        },
    },

    {
        name="LHOOK_BUFFER_TIMEOUT",
        default = 4
    },

    --------------------
    -- REST API
    --------------------

    {
        name="REQUEST_FREQUENCY", -- In seconds
        default=2,
    },

    --------------------
    -- Update Checker
    --------------------

    {
        name="VERSION_CHECK_FREQUENCY", -- In minutes
        default=30,
    },

    {
        name="UPDATE_SERVER_AFTER", -- In minutes
        default=5,
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
    },

    -- {
    --     name="IGNITE",
    --     default=true,
    -- },

    -- {
    --     name="BURNTUP",
    --     default=true,
    -- },

    -- {
    --     name="TAKE",
    --     default=true,
    -- },

    -- {
    --     name="DESTROY",
    --     default=true,
    -- },

    -- {
    --     name="KILLBOSS",
    --     default=true,
    -- },

    -- {
    --     name="KILLFOLLOWER",
    --     default=true,
    -- },

    -- {
    --     name="KILLMONITORED",
    --     default=true,
    -- },

    -- {
    --     name="EATRARE",
    --     default=true,
    -- },

    -- {
    --     name="DANGER_AT_PORTAL",
    --     default=true,
    -- },

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
    },

    {
        name="SEED",
        default = nil,
    },

    --------------------
    -- Prefabs
    --------------------

    {
        name = "CUSTOM_PREFABS",
        default = {},
    },

    --------------------
    -- Debugging
    --------------------

    {
        name="DEBUG_MODE",
        default = false,
    },
}
