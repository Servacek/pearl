dft_utils_backend = {
    configuration_options = {
        -- Sending logs to discord via the REST API
        DISCORD_LOGS = true, -- [true | false], default = true
        WEBHOOK_ID = "", -- Needs to be configured
        WEBHOOK_TOKEN = "", -- Needs to be configured
        -- The message cache processing interval in seconds
        -- Setting this to 0 will disable the cache (not recommended)
        REQUEST_FREQUENCY = 5, -- [..3, 4, 5...], default = 5

        -- The server version check interval in minutes
        -- If new version is detected, players will be notified.
        -- Settings this to 0 will disable version checking and auto updates
        VERSION_CHECK_FREQUENCY = 30, -- [..5, 10, 15...], default = 30
        -- The time after which the server will shutdown if a new version is detected
        -- This system expects the server to automatically boot after that.
        -- Settings this to 0 will disable automatic updates
        UPDATE_SERVER_AFTER = 5, -- [..5, 10, 15...], default = 5

        -- Whether it should use the default scheduler which uses TheSim
        -- or the WallScheduler which uses WallUpdates for scheduling tasks.
        --
        -- The main advantage of WallScheduler over the default one is that,
        -- it works even if the simulation is paused.
        --
        -- This is useful when scheduling tasks
        -- such as the version check task which we want to run
        -- even when the server is empty for example.
        USE_WALL_SCHEDULER = true, -- [true | false], default = true

        -- Logging suspicious inventories to discord after their owner disconnects
        --
        -- This is a simple feture we use on the CZ/SK server
        -- I do not think this will be useful for DFT in some way.
        LOG_SUSPICIOUS_INVENTORIES = false, -- [true | false], default = false

        -- Automatically extinguish fires after a fire grief attempt on the base
        FIRE_PROTECTION = true, -- [true | false], default = true
        -- The number of fire grief attempts a player must do
        -- in order to be kicked out from the server
        MAX_FIRE_ATTEMPTS = 3, -- [...2, 3, 4...], default = 3

        -- Whether the triple mactusk should be guranted or not
        FORCE_MACTUSK = false, -- [true, | false], default = false

        -- The fire spread announcement
        IGNITE = true, -- [true, | false], default = true
        -- The strucuture burned up announcement
        BURNTUP = true, -- [true, | false], default = true
        -- The structure was destroyed by a player announcement
        DESTROY = true, -- [true, | false], default = true
        -- The boss was killed announcement
        KILLBOSS = true, -- [true, | false], default = true
        -- The follower was killed announcement (for example Chester or friendly pigman)
        KILLFOLLOWER = true, -- [true, | false], default = true
        -- A monitored mob was killed announcement (for example beefalo since it can't respawn)
        KILLMONITORED = true, -- [true, | false], default = true
        -- The ate or gave to announcement
        EATRARE = true, -- [true, | false], default = true

        -- Only allow players whose id is in the whitelist.txt to join
        WHITELIST = false, -- [true | false], default = false
        DEBUG_MODE = false, -- [true | false], default = false
    },
    enabled=true,
}