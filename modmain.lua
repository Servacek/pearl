
do
	local GLOBAL = GLOBAL
	local modEnv = GLOBAL.getfenv(1)
	local rawget, setmetatable = GLOBAL.rawget, GLOBAL.setmetatable
	setmetatable(modEnv, {
		__index = function(_, index)
			return rawget(GLOBAL, index)
		end
	})

	_G = GLOBAL
end

if not _G.TheNet:GetIsServer() and not _G.TheNet:IsDedicated() then
    print("This mod is server-side only! Disabling...")
    return
end

--------------------------------

_G.SUB = {
    env = getfenv(1)
}

--------------------------------
-- [[ Setup ]]
--------------------------------

print("Starting setup process...")
print("Loading Configuration...")

_G.SUB.CONSTANTS = {
    -- Discord Logger
    WEBHOOK_ID                  = "798845831646150686",--GetModConfigData("WEBHOOK_ID"),
    WEBHOOK_TOKEN               = "GUuF2W5W9bVgjLTDK2zgbKr7qXpQCfo2VhDXPlIh_0tj_UbVJyEBR2IKK23oBTfZN-aa",--GetModConfigData("WEBHOOK_TOKEN"),
    DISCORD_LOGS_ENABLED        = GetModConfigData("DISCORD_LOGS"),
    REQUEST_FREQUENCY           = GetModConfigData("REQUEST_FREQUENCY"),

    -- Version Checker
    UPDATE_CHECK_FREQUENCY      = 1, --GetModConfigData("VERSION_CHECK_FREQUENCY"), -- In Minutes
    TIME_UNTIL_SERVER_UPDATE    = 0,--GetModConfigData("UPDATE_SERVER_AFTER"), -- minutes

    USE_WALL_SCHEDULER          = false, --GetModConfigData("USE_WALL_SCHEDULER"),

    -- Game Announcements
    ANNOUNCE_IGNITE             = GetModConfigData("ANNOUNCE_IGNITE"),
    ANNOUNCE_BURNTUP            = GetModConfigData("ANNOUNCE_BURNTUP"),
    ANNOUNCE_PICKUP             = GetModConfigData("ANNOUNCE_PICKUP"), -- Disabled
    ANNOUNCE_DESTROY            = GetModConfigData("ANNOUNCE_DESTROY"),
    ANNOUNCE_KILLBOSS           = GetModConfigData("ANNOUNCE_KILLBOSS"),
    ANNOUNCE_KILLFOLLOWER       = GetModConfigData("ANNOUNCE_KILLFOLLOWER"),
    ANNOUNCE_KILLMONITORED      = GetModConfigData("ANNOUNCE_KILLMONITORED"),
    ANNOUNCE_KILLFIRE_SPREADER  = GetModConfigData("ANNOUNCE_KILLFIRE_SPREADER"),
    ANNOUNCE_EATRARE            = GetModConfigData("ANNOUNCE_EATRARE"),

    -- Anti-Grief
    FIRE_PROTECTION_ENABLED     = GetModConfigData("FIRE_PROTECTION"),
    WHITELIST_ENABLED           = GetModConfigData("WHITELIST"),

    DEBUG_MODE_ENABLED          = false,--GetModConfigData("DEBUG_MODE"),

    -- World Generation
    FORCE_MACTUSK               = GetModConfigData("FORCE_MACTUSK"),

    -----------------------------------------

    SRC_DIR                     = "scripts",
    -- There should be a better way of obtainig the mods name
    MOD_NAME                    = "server_utils_backend",
    WHITELIST_FILE              = MODROOT .. "whitelist.txt",

    FIRE_RADIUS                 = 6,
    MAX_FIRE_ATTEMPTS           = 3,
    EXTINGUISH_RADIUS           = 40,
    EXTINGUISH_AFTER            = 5,

    BOSS_HP                     = 1200,

    CONTENT_LENGHT_LIMIT        = 2000,
    EMBED_COUNT_LIMIT           = 10,
    DISCORD_API_VERSION         = 10,

    ------------------------------------
    SKINS_PREVIEW_URL           = "https://items.kleientertainment.com/images/DST/%s/%s", -- .../DST/<skin prefab>/<size>
    WEBHOOK_URL_TEMPLATE        = "https://discord.com/api/v%d/webhooks/%s/%s", -- .../api/<api version>/webhooks/<id>/<token>
    DST_BUILDS                  = "https://s3.amazonaws.com/dstbuilds/builds.json",
    FSLS_QUERY_URL              = "https://login.kleientertainment.com/login/FamilySharingLookup",
    ------------------------------------

    FIRE_MUSTHAVE_TAGS          = nil,
    FIRE_CANTHAVE_TAGS          = {"burnt", "fire", "wildfireprotected", "tree", "fireimmune"},
    FIRE_ONEOF_TAGS             = {"structure", "plant"},

    FORMAT_CHARS = {
        "*",
        "_",
        ">",
        "|",
        "~",
        "`",
        ":", -- for discord emojis :wave:
    },

    RPC                         = "sub_rpc",
    SHUTDOWN_RPC_NAME           = "safe_shard_shutdown_broadcast",

    WEB_API_TOKEN               = nil
}
_G.SUB.CONSTANTS.WEBHOOK_URL = string.format(_G.SUB.CONSTANTS.WEBHOOK_URL_TEMPLATE,
    _G.SUB.CONSTANTS.DISCORD_API_VERSION, _G.SUB.CONSTANTS.WEBHOOK_ID, _G.SUB.CONSTANTS.WEBHOOK_TOKEN
)

_G.SUB.STRINGS = {
    EAT                     = "%s zjedol/la %s!",
    FEED                    = "%s nakrmil/a %s s %s!",
    MOB_KILLED              = "%s zabil/a %s!",
    MOB_KILLED_NEAR         = "%s zabil/a %s pri %s!",
    MONITORED_MOB_KILLED    = "%s zabil/a %s! Ostáva: %d",
    FOLLOWER_KILLED         = "%s zabil/a %s! Majiteľ: %s",
    BURNTUP                 = "Zhorel/a %s!",
    ITEM_PICKED             = "%s vzal/a %dx %s!",
    IGNITE                  = "%s zapálil/a %s!",
    IGNITE_NEAR             = "%s zapálil/a %s pri %s!",
    USE_STAFF_NEAR          = "%s použil %s pri %s!",
    USE_STAFF_ON            = "%s použil %s na %s!",
    USE_STAFF_ON_NEAR       = "%s použil %s na %s pri %s!",
    FIRE_SOURCE_BUILT_NEAR  = "%s postavil %s pri %s!",
    DESTROY                 = "%s rozbil/a %s!",
    --PLAYER_COUNT            = "%s Total players: %d/%d", -- Not needed currently

    PRECIPITATION           = "Temperature: %s °C",

    SAY                     = "(%s) %s: %s",
    SAY_WHISPER             = "(%s) [W] %s: %s",
    SLASH_CMD               = "%s -> /%s",
    CONSOLE_CMD             = "Received console command input from user %s -> %s",
    AUTH                    = "%s authenticated as %s",
    NOT_WHITELISTED         = "%s is not whitelisted! Kicking this client from the server...",
    BANNED_ROOT_CLIENT      = "%s is an alt account of banned %s! Banning as well...",
    DISCONNECT              = "%s has been disconnected from shard %s",
    CAVES_STATE_UPDATE      = "Secondary shard Caves (%s) is now %s!",
    MIGRATING               = "%s is migrating to shard %s",
    SKIN_RECEIVED           = "%s has received %s!",

    AUTO_UPDATE_FIRST       = "Aktuálna verzia servera je zastaralá, hráči na najnovšej verzii hry sa nebudú môcť pripojiť. Server bude automaticky aktualizovaný o %s minút.",
    AUTO_UPDATE_FIRST_DIS   = "Aktuálna verzia servera je zastaralá, hráči na najnovšej verzii hry sa nebudú môcť pripojiť. Automatické aktualizácie sú vypnuté.",
    AUTO_UPDATE_SECOND      = "Ostáva 15 sekúnd do automatickej aktualizácie servera. Progres aktuálneho sveta bude zachovaný. Nezbudnite si aktualizovať aj vašu hru :)",
    AUTO_UPDATE_START       = "Aktualizovanie servera na verziu %s...",

    RESTART                 = "Restarting the server...",
    ROLLBACK                = "Rolling server %d snapshot(s) back!",
    RESET                   = "Regenerating world on shard %s...",
    SHUTDOWN                = "Saving and shutting down %s...",
    AUTOPAUSE               = "Server was autopaused.",
    PAUSE_BY                = "%s paused the server.",
    PAUSE                   = "Server was paused.",
    UNPAUSE                 = "Server was unpaused.",
    VERSION_MISMATCH        = "Aktuálna verzia servera je zastaralá a je potrebné ho reštartovať.",

    EXTINGUISH              = "Ohne boli uhasené!",
    EXTINGUISH_NEAR         = "Ohne v blízkosti hráča %s boli uhasené!",
}

-----------------------------------------------------

if _G.SUB.CONSTANTS.DISCORD_LOGS_ENABLED
and (_G.SUB.CONSTANTS.WEBHOOK_TOKEN == "" or _G.SUB.CONSTANTS.WEBHOOK_ID == "")
then
    print("Warning: Logging to discord is enabled, however, not all required webhook indetifiers were specified.")

    _G.SUB.CONSTANTS.DISCORD_LOGS_ENABLED = false
end

if not _G.SUB.CONSTANTS.DISCORD_LOGS_ENABLED then
    print("Disabling logging to discord...")
end

print("Loading modules...")
modimport(_G.SUB.CONSTANTS.SRC_DIR.."/prefabs")
modimport(_G.SUB.CONSTANTS.SRC_DIR.."/icons")
modimport(_G.SUB.CONSTANTS.SRC_DIR.."/utils")
modimport(_G.SUB.CONSTANTS.SRC_DIR.."/webhook")
modimport(_G.SUB.CONSTANTS.SRC_DIR.."/blacklist")

print("Setting up scheduler...")
_G.SUB.Scheduler = nil
if _G.TheShard:IsMaster() and _G.SUB.CONSTANTS.USE_WALL_SCHEDULER then
    modimport(_G.SUB.CONSTANTS.SRC_DIR.."/scheduler")
    _G.SUB.Scheduler = SUB.WallScheduler
else
    print("Wall Scheduler is disabled, using default scheduler...")
    _G.SUB.Scheduler = _G.scheduler
end

modimport(_G.SUB.CONSTANTS.SRC_DIR.."/logger")
modimport(_G.SUB.CONSTANTS.SRC_DIR.."/networking")
modimport(_G.SUB.CONSTANTS.SRC_DIR.."/watcher")

if _G.SUB.CONSTANTS.UPDATE_CHECK_FREQUENCY > 0 then
    modimport(_G.SUB.CONSTANTS.SRC_DIR.."/versionchecker")
else
    print("[SUB] Version checking disabled!")
end

print("Setting up RPC handlers...")

-- Used by the VersionChecker for shutting down secondary shards
-- to synchronize the shutdown process on version mismatch.
_G.AddShardModRPCHandler(_G.SUB.CONSTANTS.RPC, _G.SUB.CONSTANTS.SHUTDOWN_RPC_NAME, function()
    if TheShard:IsSecondary() then
        print("Received safe shutdown request from Master.")

        _G.c_shutdown()
    end
end)

-- Debug
--modimport(_G.SUB.CONSTANTS.SRC_DIR.."/tests")
print("Done!")
