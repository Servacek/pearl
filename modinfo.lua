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
    -- Logging
    {
        name="DISCORD_LOGS",
        default=true,
    },

    -- Note: The url should contain also the protocol prefix
    {
        name="DISCORD_INVITE",
        default=nil,
    },

    {
        name="LANGUAGE",
        default="en",
    },

    { -- regenerate, rollback, kick...
        name="COMMAND_BLOCKLIST",
        default={},
    },

    {
        name="MOD_BLACKLIST",
        default={},
    },

    { -- Additional table of tags
        name="CUSTOM_SERVER_TAGS",
        default={},
    },

    -- Anti-Grief
    -- {
    --     name="FIRE_PROTECTION",
    --     default=true,
    -- },

    {
        name="LOG_SUSPICIOUS_INVENTORIES",
        default=true,
    },

    {
        name="PROFANITY_FILTER",
        default=true,
    },

    {
        name="CONSOLE_COMMANDS",
        default=true,
    },

    {
        name="SHOW_PLAYER_ICONS",
        default=true,
    },

    {
        name="BAN_ALT_ACCOUNTS",
        default=true,
    },

    { -- Time in seconds represeting the inactive time after which a player is considered AFK
      -- Settings this to 0 or lower will disable afk state (so no announcement).
        name="AFK_TIME",
        default=1 * 60,
    },

    { -- Total AFK time in seconds after which the player
      -- will by disconnected from the server.
      -- Setting this to 0 or lower will prevent kicking AFK players.
        name = "AFK_TIME_KICK",
        default = 5 * 60,
    },

    { -- This is an experimental feature.
        name="CZSK_ONLY",
        default=false,
    },

    -- Determines the amount of attempts to burn the base by a player until kick
    -- {
    --     name="MAX_FIRE_ATTEMPTS",
    --     default=3,
    -- },

    {
        name = "TRUST_AGE",
        default = 24,
    },

    {
        name="WHITELIST",
        default=false,
    },

    {
        name="ALLOWLIST",
        default=false,
    },

    {
        name="INTRO_SCREEN",
        default=false,
    },

    -- Webhook Identifiers (required if DISCORD_LOGS option is enabled)
    {
        name="LOG_WEBHOOK",
        default={
            ID = "",
            TOKEN = "",
        }
    },

    {
        name="REPORT_WEBHOOK",
        default={
            ID = "",
            TOKEN = "",
        },
    },

    {
        name="DEBUG_MODE",
        default=false,
    },

    --------------------------------

    {
        name="REQUEST_FREQUENCY", -- In seconds
        default=2,
    },

    {
        name="MESSAGE_WRAPPER_PERIOD",
        default=4
    },

    {
        name="VERSION_CHECK_FREQUENCY", -- In minutes
        default=30,
    },

    {
        name="UPDATE_SERVER_AFTER", -- In minutes
        default=5,
    },

    -- {
    --     name="OPTIMIZED_SCHEDULER",
    --     default=true,
    -- },

    ----------

    --- @TODO: Separate the announcement settings from other things somehow

    {
        name="IGNITE",
        default=true,
    },

    {
        name="BURNTUP",
        default=true,
    },

    {
        name="TAKE",
        default=true,
    },

    {
        name="DESTROY",
        default=true,
    },

    {
        name="KILLBOSS",
        default=true,
    },

    {
        name="KILLFOLLOWER",
        default=true,
    },

    {
        name="KILLMONITORED",
        default=true,
    },

    {
        name="EATRARE",
        default=true,
    },

    {
        name="DANGER_AT_PORTAL",
        default=true,
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
    },

    --- @TODO
    -- {
    --     name = "FORCE_REEDTRAP",
    --     default = false,
    -- },

    {
        name="SEED",
        default = nil,
    },

    --------------------
    -- Misc
    --------------------

    {
        name = "BETTER_EYE",
        default = false,
    },

    --[[
        This needs to be a key-value styled table,
        where the key is the prefab name (without quotes) and the value 1 or true.
        Like this:

            PREFAB_BLACKLIST = {
                <prefab_name1> = 1,
                <prefab_name2> = 1,
                ...
            }

        Entities whose prefab will be on this list will not be contained in the neighbor
        entity list for actions like ignite, etc...
    --]]
    -- {
    --     name="PREFAB_BLACKLIST",
    --     options={},
    --     default={},
    -- }
}
