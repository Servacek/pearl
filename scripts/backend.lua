--[[
    Server specific stuff. Needs to be loaded only on the server.
--]]

--local PEARL = PEARL

PEARL.info("Loading BE...")

--------------------------------
-- [[ Contants ]]
--------------------------------

PEARL.ModTableSafeAppend("CONSTS", {
    -- The discord module
    DISCORD = {
        API_VERSION                 = 10, -- Currently the newest

        ADMIN_ROLE_ID               = "662346185411133451",

        -- .../api/<api version>/webhooks/<id>/<token>
        WEBHOOK_URL_TEMPLATE        = "https://discord.com/api/v%d/webhooks/%s/%s",

        MAX_EMOJI_NAME_LENGTH = 32,
        MAX_MESSAGE_CONTENT_LENGTH = 2000,
        MAX_LOGLINE_COUNT = 16,
        MAX_EMBED_COUNT = 10,
        -- 1800 / 6
        MAX_LOGLINE_CONTENT_LENGTH = 300,

        MAX_USER_MENTIONS = 100,
        MAX_ROLE_MENTIONS = 100,
    },

    -- Penalozation module
    GRIEF_ACTS                  = {
        LIGHT                   = { penalty = 2, penalty_per_ent = 1, base_mult = 2},
        HAMMER                  = { penalty = 3, base_mult = 2 },
        BUILD                   = { penalty = 2.5, penalty_per_ent = 0.75, base_mult = 2},
        -- Points for this action in more detail are defined in prefabs.lua
        EAT                     = { penalty = 5 },
        DEPLOY                  = { penalty = 6 },
    },

    -- Anti-Grief
    GRIEFER_BAN_TIME            = 3 * 24 * 60,

    GRIEFNESS_DRAIN_DELAY       = 10,
    GRIEFNESS_DRAIN_RATE        = 1,
    GRIEFNESS_DRAIN_PERIOD      = 60,
    GRIEFNESS_MAX_WARNINGS      = 2,
    GRIEFNESS_MAX               = 18,

    -----------------------------------------

    DISCONNECT_KICK_TIME        = 2 * 60,
    LOCALIZATION_TIMEOUT        = 30,

    DEFAULT_PROPAGATOR_RADIUS   = 5,
    LARGE_PROPAGATOR_RADIUS     = 8,
    MAX_FIRE_ATTEMPTS           = 3,
    EXTINGUISH_RADIUS           = 40,
    EXTINGUISH_AFTER            = 5,
    MONITORED_POPULATION_LIMIT  = 5,

    ------------------------------------
    SKINS_PREVIEW_URL           = "https://items.kleientertainment.com/images/DST/%s/%s", -- .../DST/<skin prefab>/<size>
    DST_BUILDS                  = "https://s3.amazonaws.com/dstbuilds/builds.json",
    STEAM_ACCOUNT_URL           = "https://steamcommunity.com/profiles/%s",
    WIKI_URL                    = "https://dontstarve.fandom.com/wiki/%s",
    FSLS_QUERY_URL              = "https://login.kleientertainment.com/login/FamilySharingLookup",
    ------------------------------------

    BASE_STRUCTURE_TAGS         = {"structure", "wall"},
    RESOURCE_PLANT_TAGS         = {"witherable", "readyforharvest", "notreadyforharvest"},
    ENT_CANT_HAVE_TAGS          = {"FX", "NOCLICK", "DECOR", "INLIMBO", "burnt", "player", "monster", "tree"},
    DANGER_ONOF_TAGS            = {"hostile", "_combat", "trapdamage"},

    --- @deprecated
    -- MARKDOWN_PATTERN            = "%~%*%_%>%|%~%`%:%[]",
    -- FORMAT_CHARS = {
    --     "*",
    --     "_",
    --     ">",
    --     "|",
    --     "~",
    --     "`",
    --     ":", -- escape discord emojis as well, ex. :wave: (this also escapes links)
    --     "[", -- hyperlinks ([text](url))
    -- },

    MOD_ERROR                   = false,
})
PEARL.CONSTS.ENT_ONEOF_TAGS = ArrayUnion(
    PEARL.CONSTS.BASE_STRUCTURE_TAGS, PEARL.CONSTS.RESOURCE_PLANT_TAGS
)

--------------------------------
-- [[ Config ]]
--------------------------------

PEARL.info("Loading Configuration...")
PEARL.ModTableSafeAppend("CONFIG", {
    -- What configurations should be sent to clients
    PUBLIC = {
        ["DEBUG_MODE"] = true,
        ["DISCORD_INVITE"] = true,
        ["MOD_BLACKLIST"] = true,
        ["KICK_AFK_PLAYERS"] = true,
        ["CZSK_ONLY"] = true,
        ["IGNORE_LOCALE"] = false,
        ["LANGUAGE"] = true,
    },

    -- The discord module
    DISCORD                     = {
        ENABLED                 = PEARL.GetConfigData("DISCORD_LOGS"),

        LHOOK                   = PEARL.GetConfigData("LOG_WEBHOOK"),
        RHOOK                   = PEARL.GetConfigData("REPORT_WEBHOOK"),
    },

    -- Discord Logger
    REQUEST_FREQUENCY           = PEARL.GetConfigData("REQUEST_FREQUENCY"),
    -- Maybe move this to DISCORD as well?
    MESSAGE_WRAPPER_PERIOD      = PEARL.GetConfigData("MESSAGE_WRAPPER_PERIOD"),

    COMMAND_BLOCKLIST           = PEARL.GetConfigData("COMMAND_BLOCKLIST"),
    CUSTOM_SERVER_TAGS          = PEARL.GetConfigData("CUSTOM_SERVER_TAGS"),

    -- Version Checker
    VERSION_CHECK_FREQUENCY     = PEARL.GetConfigData("VERSION_CHECK_FREQUENCY"), -- minutes
    UPDATE_SERVER_AFTER         = PEARL.GetConfigData("UPDATE_SERVER_AFTER"), -- minutes

    -- Anti-Grief
    GRIEF_PROTECTION            = PEARL.GetConfigData("FIRE_PROTECTION"),
    LOG_SUSPICIOUS_INVENTORIES  = PEARL.GetConfigData("LOG_SUSPICIOUS_INVENTORIES"),
    CZSK_ONLY                   = PEARL.GetConfigData("CZSK_ONLY"),
    WHITELIST                   = PEARL.GetConfigData("WHITELIST"),
    ALLOWLIST                   = PEARL.GetConfigData("ALLOWLIST"),
    PROFANITY_FILTER            = PEARL.GetConfigData("PROFANITY_FILTER"),
    SHOW_PLAYER_ICONS           = PEARL.GetConfigData("SHOW_PLAYER_ICONS"),
    BAN_ALT_ACCOUNTS            = PEARL.GetConfigData("BAN_ALT_ACCOUNTS"),

    -- World Generation
    FORCE_MACTUSK               = PEARL.GetConfigData("FORCE_MACTUSK"),
    FORCE_REED_TRAP             = PEARL.GetConfigData("FORCE_REEDTRAP"),

    BETTER_EYE                  = PEARL.GetConfigData("BETTER_EYE"),
})

--------------------------------
-- [[ Modules ]]
--------------------------------

local ModuleManager = require("libraries/modulemanager")
if TheShard:IsMaster() then
    ModuleManager.AddModule("whitelist", PEARL.CONFIG.WHITELIST)
    ModuleManager.AddModule("allowlist", PEARL.CONFIG.ALLOWLIST or PEARL.CONFIG.CZSK_ONLY)
    ModuleManager.AddModule("versionchecker", PEARL.CONFIG.VERSION_CHECK_FREQUENCY > 0 or PEARL.CONFIG.UPDATE_SERVER_AFTER > 0)
end

ModuleManager.AddModule("globalplayericons", PEARL.CONFIG.SHOW_PLAYER_ICONS)
ModuleManager.AddModule("profanityfilter", PEARL.CONFIG.PROFANITY_FILTER)
ModuleManager.AddModule("altdentifier", PEARL.CONFIG.BAN_ALT_ACCOUNTS)
ModuleManager.AddModule("localizer", PEARL.CONFIG.CZSK_ONLY)
ModuleManager.AddModule("commandblocker", not IsTableEmpty(PEARL.CONFIG.COMMAND_BLOCKLIST or {}))

-- Logger Modules
ModuleManager.AddModule("logger/server", true)
ModuleManager.AddModule("logger/world", true)
ModuleManager.AddModule("logger/player", true)
ModuleManager.AddModule("logger/inventory", true)
ModuleManager.AddModule("logger/chat", true)

--------------------------------
-- [[ Discord logs ]]
--------------------------------

if PEARL.CONFIG.DISCORD.ENABLED
and (PEARL.CONFIG.DISCORD.LHOOK_TOKEN == "" or PEARL.CONFIG.DISCORD.LHOOK_ID == "")
then
    PEARL.info("Warning: Logging to discord is enabled, however, not all required webhook indetifiers were specified.")

    PEARL.CONFIG.DISCORD.ENABLED = false
end

--------------------------------
-- [[ Server Tags ]]
--------------------------------

PEARL.info("Loading custom server tags...")
for _, tag in ipairs(PEARL.CONFIG.CUSTOM_SERVER_TAGS) do
    table.insert(PEARL.MOD_INFO.server_filter_tags, tag)
end

-- Gets called after modindex is loaded and when a shard connects.
-- UpdateServerTagsString()

--------------------------------
-- [[ Constants and Utilities ]]
--------------------------------

PEARL.info("Loading constants...")
modimport(PEARL.SOURCE_DIR_NAME.."/constants/prefabs")
-- Load emotes before icons
modimport(PEARL.SOURCE_DIR_NAME.."/constants/emotes")
modimport(PEARL.SOURCE_DIR_NAME.."/constants/icons")

--------------------------------
-- [[ Scheduler ]]
--------------------------------

do
    PEARL.info("Setting up the wall-scheduler...")
    local WallScheduler = require("libraries/wallscheduler")

    PEARL.Scheduler = WallScheduler()
end

--------------------------------
-- [[ Webhooks ]]
--------------------------------

PEARL.info("Setting up the webhooks...")
PEARL.Logger = require("logger")()
PEARL.Logger:SetBufferTimeout(PEARL.CONFIG.MESSAGE_WRAPPER_PERIOD)

PEARL.Reporter = require("reporter")()

--------------------------------
-- [[ Overrides ]]
--------------------------------

PEARL.info("Loading extensions...")
modimport(PEARL.SOURCE_DIR_NAME.."/extensions/inventory")
modimport(PEARL.SOURCE_DIR_NAME.."/extensions/workable")
modimport(PEARL.SOURCE_DIR_NAME.."/extensions/age")
modimport(PEARL.SOURCE_DIR_NAME.."/extensions/entityscript")
modimport(PEARL.SOURCE_DIR_NAME.."/extensions/inventoryitem")
modimport(PEARL.SOURCE_DIR_NAME.."/extensions/container")
modimport(PEARL.SOURCE_DIR_NAME.."/extensions/stackable")
modimport(PEARL.SOURCE_DIR_NAME.."/extensions/playercommon")
modimport(PEARL.SOURCE_DIR_NAME.."/extensions/playerspawner")
modimport(PEARL.SOURCE_DIR_NAME.."/extensions/edible")

--------------------------------
-- [[ Modules ]]
--------------------------------

--- @type Blacklist
PEARL.BlackList = require("wrappers/blacklist")

PEARL.info("Loading modules...")
ModuleManager.LoadAllModules()

PEARL.info("Loading other components...")
--- v2.1
-- if PEARL.CONFIG.GRIEF_PROTECTION then
--     PEARL.info("Enabling griefer protection...")
--     modimport(PEARL.SOURCE_DIR_NAME.."/actions")
--     modimport(PEARL.SOURCE_DIR_NAME.."/protector")
--     modimport(PEARL.SOURCE_DIR_NAME.."/penalizer")
-- end

--------------------------------
-- [[ Logging ]]
--------------------------------

-- modimport(PEARL.SOURCE_DIR_NAME.."/logger")
-- modimport(PEARL.SOURCE_DIR_NAME.."/maincallbacks")
-- modimport(PEARL.SOURCE_DIR_NAME.."/watcher")

--------------------------------
-- [[ Network ]]
--------------------------------

--- @type RestClient
PEARL.RestClient = require("wrappers/restclient")()
    :SetRequestFrequency(PEARL.CONFIG.REQUEST_FREQUENCY)

--- @type RestAPI
PEARL.DiscordRestAPI = require("libraries/discordapi/rest")()

PEARL.info("Loading server network...")
modimport(PEARL.SOURCE_DIR_NAME.."/servernetwork")

--------------------------------
-- [[ Debug Mode ]]
--------------------------------

if PEARL.CONFIG.DEBUG_MODE then
    PEARL.warn("Debug mode enabled! This is not recommended for production use.")
    modimport(PEARL.SOURCE_DIR_NAME.."/debugtools")

    --PEARL.CreateWordFilterFile = require("utils/wordloader")

    require("profiler")
    PEARL.Profiler = newProfiler()

    require("debugcommands")
    require("debugkeys")
    -- Fix for a broken debug handler
    handlers[KEY_D] = nil
end

--------------------------------
-- [[ Prefabs ]]
--------------------------------
-- Here are stored all the prefabs this mod adds to the game.
-- This is being loaded after the builtin prefabs so we can override them.
PrefabFiles = {}

if PEARL.CONFIG.BETTER_EYE then
    PrefabFiles[#PrefabFiles + 1] = "terrarium"
end

---------------------------------
-- [[ Initialization Handlers ]]
---------------------------------

PEARL.OverrideGlobal("GetEnabledServerModsConfigData", function()
    local mods_config_data = {}

	for _, mod_name in ipairs(ModManager:GetEnabledServerModNames()) do
		local modinfo = KnownModIndex:GetModInfo(mod_name)
		if modinfo ~= nil and modinfo.all_clients_require_mod then
			local config_data = {}

			local config = KnownModIndex:LoadModConfigurationOptions(mod_name, false)
			if type(config) == "table" then
				for _, v in ipairs(config) do
                    if mod_name ~= PEARL.MODNAME or PEARL.CONFIG.PUBLIC[v.name] == true then
                        config_data[v.name] = v.saved ~= nil and v.saved or v.default
                    end
				end
			end

			mods_config_data[mod_name] = config_data
		end
	end

    return DataDumper(mods_config_data, nil, false)
end)
