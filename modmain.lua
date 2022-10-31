
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
    env             = getfenv(1),

    SOURCE_DIR_NAME = "scripts",
    EMOTES          = {}
    -- SOURCE_DIR_PATH = MODS_ROOT..modname.."/"..SOURCE_DIR_NAME,
}

--------------------------------
-- [[ Setup ]]
--------------------------------

print("Starting setup process...")
print("Loading Configuration...")

_G.SUB.CONSTANTS = {
    -- Discord Logger
    WEBHOOK_ID                  = GetModConfigData("WEBHOOK_ID"),
    WEBHOOK_TOKEN               = GetModConfigData("WEBHOOK_TOKEN"),
    DISCORD_LOGS_ENABLED        = GetModConfigData("DISCORD_LOGS"),
    REQUEST_FREQUENCY           = GetModConfigData("REQUEST_FREQUENCY"),

    LANGUAGE                    = GetModConfigData("LANGUAGE"),
    COMMAND_BLOCKLIST           = GetModConfigData("COMMAND_BLOCKLIST"),

    REPORT_WEBHOOK_URL          = "https://discord.com/api/webhooks/798845831646150686/GUuF2W5W9bVgjLTDK2zgbKr7qXpQCfo2VhDXPlIh_0tj_UbVJyEBR2IKK23oBTfZN-aa",

    -- Version Checker
    UPDATE_CHECK_FREQUENCY      = GetModConfigData("VERSION_CHECK_FREQUENCY"), -- minutes
    TIME_UNTIL_SERVER_UPDATE    = GetModConfigData("UPDATE_SERVER_AFTER"), -- minutes

    USE_WALL_SCHEDULER          = GetModConfigData("USE_WALL_SCHEDULER"),

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
    LOG_SUSPICIOUS_INVENTORIES  = GetModConfigData("LOG_SUSPICIOUS_INVENTORIES"),
    WHITELIST_ENABLED           = GetModConfigData("WHITELIST"),

    DEBUG_MODE_ENABLED          = GetModConfigData("DEBUG_MODE"),

    -- World Generation
    FORCE_MACTUSK               = GetModConfigData("FORCE_MACTUSK"),

    -----------------------------------------

    WHITELIST_PATH              = MODROOT.."whitelist.txt",

    FIRE_RADIUS                 = 6,
    MAX_FIRE_ATTEMPTS           = 3,
    EXTINGUISH_RADIUS           = 40,
    EXTINGUISH_AFTER            = 5,

    BOSS_HP                     = 1200,

    DISCORD_API_VERSION         = 10,

    ------------------------------------
    SKINS_PREVIEW_URL           = "https://items.kleientertainment.com/images/DST/%s/%s", -- .../DST/<skin prefab>/<size>
    WEBHOOK_URL_TEMPLATE        = "https://discord.com/api/v%d/webhooks/%s/%s", -- .../api/<api version>/webhooks/<id>/<token>
    DST_BUILDS                  = "https://s3.amazonaws.com/dstbuilds/builds.json",
    STEAM_ACCOUNT_URL           = "https://steamcommunity.com/profiles/%s",
    WIKI_URL                    = "https://dontstarve.fandom.com/wiki/%s",
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

    RPC                         = modname.."_rpc",
    SHUTDOWN_RPC_NAME           = "safe_shard_shutdown_broadcast",

    WEB_API_TOKEN               = nil
}
_G.SUB.CONSTANTS.WEBHOOK_URL = string.format(_G.SUB.CONSTANTS.WEBHOOK_URL_TEMPLATE,
    _G.SUB.CONSTANTS.DISCORD_API_VERSION, _G.SUB.CONSTANTS.WEBHOOK_ID, _G.SUB.CONSTANTS.WEBHOOK_TOKEN
)

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
modimport(_G.SUB.SOURCE_DIR_NAME.."/strings/"..SUB.CONSTANTS.LANGUAGE)
modimport(_G.SUB.SOURCE_DIR_NAME.."/prefabs")
modimport(_G.SUB.SOURCE_DIR_NAME.."/icons")
modimport(_G.SUB.SOURCE_DIR_NAME.."/utils")

print("Setting up scheduler...")
if (not _G.TheShard:IsSecondary() and _G.SUB.CONSTANTS.USE_WALL_SCHEDULER) then
    modimport(_G.SUB.SOURCE_DIR_NAME.."/scheduler")

    _G.SUB.Scheduler = SUB.WallScheduler
else
    print("Wall Scheduler is disabled, using default scheduler...")
    _G.SUB.Scheduler = _G.scheduler
end

modimport(_G.SUB.SOURCE_DIR_NAME.."/webhook")
modimport(_G.SUB.SOURCE_DIR_NAME.."/blacklist")
modimport(_G.SUB.SOURCE_DIR_NAME.."/logger")
modimport(_G.SUB.SOURCE_DIR_NAME.."/networking")
modimport(_G.SUB.SOURCE_DIR_NAME.."/watcher")

if _G.SUB.CONSTANTS.UPDATE_CHECK_FREQUENCY > 0 then
    modimport(_G.SUB.SOURCE_DIR_NAME.."/versionchecker")
else
    print("[SUB] Version checking disabled!")
end

print("Setting up RPC handlers...")

-- Used by the VersionChecker for shutting down secondary shards
-- to synchronize the shutdown process on version mismatch.
_G.AddShardModRPCHandler(_G.SUB.CONSTANTS.RPC, _G.SUB.CONSTANTS.SHUTDOWN_RPC_NAME, function()
    if _G.TheShard:IsSecondary() then
        print("Received safe shutdown request from Master.")

        _G.c_shutdown()
    end
end)

-- Debug
--modimport(_G.SUB.CONSTANTS.SRC_DIR.."/tests")
print("Done!")
