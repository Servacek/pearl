--[[
    Server specific stuff. Needs to be loaded only on the server.
--]]

--local PEARL = PEARL

PEARL.info("Loading BE...")

--------------------------------
-- [[ Contants ]]
--------------------------------

PEARL.ModTableSafeAppend("CONSTS", {
    --> The discord module
    DISCORD = {
        API_VERSION                 = 10, -- Currently the newest

        ADMIN_ROLE_ID               = "662346185411133451",

        --> Note: TheSim:QueryServer does only support HTTPS for POST requests
        --> .../api/<api version>/webhooks/<id>/<token>
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
    REPAIR_RADIUS               = 24,
    EXTINGUISH_RADIUS           = 40,
    EXTINGUISH_AFTER            = 5,
    MONITORED_POPULATION_LIMIT  = 5,

    ------------------------------------
    SKINS_PREVIEW_URL           = "https://items.kleientertainment.com/images/DST/%s/%s", -- .../DST/<skin prefab>/<size>
    --- @deprecated: use steam's API instead
    DST_BUILDS                  = "https://s3.amazonaws.com/dstbuilds/builds.json",
    STEAM_ACCOUNT_URL           = "https://steamcommunity.com/profiles/%s",
    WIKI_URL                    = "https://dontstarve.fandom.com/wiki/%s",
    FSLS_QUERY_URL              = "https://login.kleientertainment.com/login/FamilySharingLookup",
    STEAM_UP_TO_DATE_CHECK      = "https://api.steampowered.com/ISteamApps/UpToDateCheck/v1/?appid=%s&version=%s",
    ------------------------------------

    BASE_STRUCTURE_TAGS         = {"structure", "wall"},
    RESOURCE_PLANT_TAGS         = {"witherable", "readyforharvest", "notreadyforharvest"},
    ENT_MUST_HAVE_TAGS          = {"canlight"},
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
        ["AFK_TIME"] = true,
        ["AFK_TIME_KICK"] = true,
        ["CZSK_ONLY"] = true,
        ["LANGUAGE"] = true,
        ["INTRO_POPUP_TITLE"] = true,
        ["INTRO_POPUP_BODY"] = true,
        ["AGREEMENT_SCREEN_CONTENT"] = true,
        ["WELCOME_POPUP_CONTENT"] = true,
    },

    -- The discord module
    DISCORD                     = {
        ENABLED                 = PEARL.GetConfigData("DISCORD_LOGS"),

        LHOOK                   = PEARL.GetConfigData("LOG_WEBHOOK"),
        RHOOK                   = PEARL.GetConfigData("REPORT_WEBHOOK"),
    },

    -- REST Client
    REQUEST_FREQUENCY           = PEARL.GetConfigData("REQUEST_FREQUENCY"),
    --- @TODO
    -- Maybe move this to DISCORD as well?
    MESSAGE_WRAPPER_PERIOD      = PEARL.GetConfigData("MESSAGE_WRAPPER_PERIOD"),

    COMMAND_BLOCKLIST           = PEARL.GetConfigData("COMMAND_BLOCKLIST"),
    CUSTOM_SERVER_TAGS          = PEARL.GetConfigData("CUSTOM_SERVER_TAGS"),

    -- OPTIMIZED_SCHEDULER         = PEARL.GetConfigData("OPTIMIZED_SCHEDULER"),

    -- Version Checker
    VERSION_CHECK_FREQUENCY     = PEARL.GetConfigData("VERSION_CHECK_FREQUENCY"), -- minutes
    UPDATE_SERVER_AFTER         = PEARL.GetConfigData("UPDATE_SERVER_AFTER"), -- minutes

    -- Anti-Grief
    --GRIEF_PROTECTION            = PEARL.GetConfigData("FIRE_PROTECTION"),
    TRUST_AGE                   = PEARL.GetConfigData("TRUST_AGE"),
    LOG_SUSPICIOUS_INVENTORIES  = PEARL.GetConfigData("LOG_SUSPICIOUS_INVENTORIES"),
    CZSK_ONLY                   = PEARL.GetConfigData("CZSK_ONLY"),
    WHITELIST                   = PEARL.GetConfigData("WHITELIST"),
    INTRO_SCREEN                = PEARL.GetConfigData("INTRO_SCREEN"),
    ALLOWLIST                   = PEARL.GetConfigData("ALLOWLIST"),
    PROFANITY_FILTER            = PEARL.GetConfigData("PROFANITY_FILTER"),
    CONSOLE_COMMANDS            = PEARL.GetConfigData("CONSOLE_COMMANDS"),
    SHOW_PLAYER_ICONS           = PEARL.GetConfigData("SHOW_PLAYER_ICONS"),
    BAN_ALT_ACCOUNTS            = PEARL.GetConfigData("BAN_ALT_ACCOUNTS"),

    -- World Generation
    FORCE_MACTUSK               = PEARL.GetConfigData("FORCE_MACTUSK"),
    FORCE_REED_TRAP             = PEARL.GetConfigData("FORCE_REEDTRAP"),

    BETTER_EYE                  = PEARL.GetConfigData("BETTER_EYE"),
})

----------------------------------------------------------------
-- [[ Agreement/Welcome screen configurations ]]
----------------------------------------------------------------

local ParseTxt = require("utils/txtparser")
if PEARL.CONFIG.INTRO_SCREEN then
    PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT = ParseTxt("agreement.txt", true, true)
    PEARL.CONFIG.WELCOME_POPUP_CONTENT = ParseTxt("welcome.txt", true, false)

    if type(PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT) ~= "table" or #PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT < 1 then
        PEARL.warn("The body and content for the agreement screen are not setuped!")
        PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT = nil
    end

    if type(PEARL.CONFIG.WELCOME_POPUP_CONTENT) ~= "table" or #PEARL.CONFIG.WELCOME_POPUP_CONTENT < 1 then
        PEARL.warn("The body and content for the welcome popup are not setuped!")
        PEARL.CONFIG.WELCOME_POPUP_CONTENT = nil
    end
end

--------------------------------
-- [[ Modules ]]
--------------------------------

local ModuleManager = require("libraries/modulemanager")

-- Master only modules
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
ModuleManager.AddModule("consolecommands", PEARL.CONFIG.CONSOLE_COMMANDS)

-- Logger Modules
ModuleManager.AddModule("logger/world", true)
ModuleManager.AddModule("logger/player", true)

-- Discord only loggers
if PEARL.CONFIG.DISCORD.ENABLED then
    ModuleManager.AddModule("logger/chat", true)
    ModuleManager.AddModule("logger/inventory", true)
    ModuleManager.AddModule("logger/server", true)
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
require("constants/prefabs")
-- Load emotes before icons
require("constants/emotes")
require("constants/icons")

--------------------------------
-- [[ Scheduler ]]
--------------------------------

PEARL.info("Setting up the wall-scheduler...")

--- @type WallScheduler
PEARL.Scheduler = require("libraries/wallscheduler")
PEARL.Scheduler:StartWallUpdate()

--------------------------------
-- [[ Webhooks ]]
--------------------------------

PEARL.info("Setting up the webhooks...")

--- @type Logger
PEARL.DiscordLogger = require("logger")()
PEARL.DiscordLogger:SetBufferTimeout(PEARL.CONFIG.MESSAGE_WRAPPER_PERIOD)

--- @type Reporter
PEARL.DiscordReporter = require("reporter")()

--------------------------------
-- [[ Overrides ]]
--------------------------------

PEARL.info("Loading extensions...")
require("extensions/components/inventory")
require("extensions/components/workable")
require("extensions/components/age")
require("extensions/components/entityscript")
require("extensions/components/inventoryitem")
require("extensions/components/container")
require("extensions/components/stackable")
require("extensions/components/playercommon")
require("extensions/components/edible")

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
PEARL.info("Loading network components...")

--- @type RestClient
PEARL.RestClient = require("wrappers/restclient")()
    :SetRequestFrequency(PEARL.CONFIG.REQUEST_FREQUENCY)

--- @type RestAPI
PEARL.DiscordRestAPI = require("libraries/discordapi/rest")()

PEARL.info("Loading server network...")

--- @type ServerNetwork
PEARL.ServerNetwork = require("servernetwork")

--------------------------------
-- [[ Discord logs ]]
--------------------------------

if PEARL.CONFIG.DISCORD.ENABLED
    and (PEARL.CONFIG.DISCORD.LHOOK_TOKEN == "" or PEARL.CONFIG.DISCORD.LHOOK_ID == "")
then
    PEARL.warn("Logging to discord is enabled, however, not all required webhook indetifiers were specified.")

    PEARL.CONFIG.DISCORD.ENABLED = false
end

if not PEARL.CONFIG.DISCORD.ENABLED then
    PEARL.info("Sending system logs to discord is disabled.")

    PEARL.DiscordLogger:SetIsDisabled(true)
    PEARL.DiscordRestAPI:SetIsDisabled(true)
end

--------------------------------
-- [[ Debug Mode ]]
--------------------------------

if PEARL.CONFIG.DEBUG_MODE then
    PEARL.warn("Debug mode enabled! This is not recommended for production use.")
    modimport(PEARL.SOURCE_DIR_NAME.."/debugtools")

    --PEARL.CreateWordFilterFile = require("utils/wordloader")

    require("profiler")
    PEARL.Profiler = newProfiler("time", 10^6)

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

--- @TODO: Add option to enable/disable every prefab seperately
if PEARL.CONFIG.BETTER_EYE then
    PrefabFiles[#PrefabFiles + 1] = "terrarium"
end

---------------------------------
-- [[ Server Mod Configuration ]]
---------------------------------

require("servermodconfig")
