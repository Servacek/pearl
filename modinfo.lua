---@diagnostic disable: lowercase-global
name = "Server Utilities - Backend" -- aka SUB
description = "Funkčnosť nieje garantována, ostáva len dúfať..."
author = "Fi7iP"
version = "1.5"
priority = 10 -- this needs to be loaded before SUF

dst_compatible = true
client_only_mod = false
all_clients_require_mod = false

api_version = 10


configuration_options = {
    -- Logging
    {
        name="DISCORD_LOGS",
        default=true,
    },

    -- Anti-Grief
    {
        name="FIRE_PROTECTION",
        default=true,
    },

    -- Determines the amount of attempts to burn the base by a player until kick
    {
        name="MAX_FIRE_ATTEMPTS",
        default=3,
    },

    {
        name="WHITELIST",
        default=false,
    },

    -- Webhook Identifiers (required if DISCORD_LOGS option is enabled)
    {
        name="WEBHOOK_ID",
        default="",
    },

    {
        name="WEBHOOK_TOKEN",
        default="",
    },

    {
        name="DEBUG_MODE",
        default=false,
    },

    --------------------------------

    {
        name="REQUEST_FREQUENCY", -- In seconds
        default=4,
    },

    {
        name="VERSION_CHECK_FREQUENCY", -- In minutes
        default=10,
    },

    {
        name="UPDATE_SERVER_AFTER", -- In minutes
        default=5,
    },


    {
        name="USE_WALL_SCHEDULER",
        default=true,
    },

    ----------

    {
        name="ANNOUNCE_IGNITE",
        default=true,
    },

    {
        name="ANNOUNCE_BURNTUP",
        default=true,
    },

    -- {
    --     name="ANNOUNCE_PICKUP",
    --     default=true,
    -- },

    {
        name="ANNOUNCE_DESTROY",
        default=true,
    },

    {
        name="ANNOUNCE_KILLBOSS",
        default=true,
    },

    {
        name="ANNOUNCE_KILLFOLLOWER",
        default=true,
    },

    {
        name="ANNOUNCE_KILLMONITORED",
        default=true,
    },

    {
        name="ANNOUNCE_EATRARE",
        default=true,
    },

    --------------------
    -- World gen
    --------------------

    {
        name="FORCE_MACTUSK",
        default=false,
    }

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
