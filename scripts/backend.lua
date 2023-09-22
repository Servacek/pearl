--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--[[
    Server specific stuff. Needs to be loaded only on the server.
--]]

--------------------------------
-- [[ Contants ]]
--------------------------------

PEARL.SafeModTableExtend("CONSTS", {
    DST_WEB_GAME_ID = "DontStarveTogether",

    --> The discord module
    DISCORD = {
        API_VERSION                 = 10, -- Currently the newest

        ADMIN_ROLE_ID               = "662346185411133451",

        --> Note: TheSim:QueryServer does only support HTTPS for POST requests
        --> .../api/<api version>/webhooks/<id>/<token>
        WEBHOOK_URL_TEMPLATE        = "https://discord.com/api/v%d/webhooks/%s/%s",

        MAX_EMOJI_NAME_LENGTH = 32,
        MAX_MESSAGE_CONTENT_LENGTH = 2000,
        MAX_EMBED_COUNT = 10,

        MAX_USER_MENTIONS = 100,
        MAX_ROLE_MENTIONS = 100,
    },

    STEAM_API_KEY_LENGTH = 32,

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

    DISCONNECT_KICK_TIME        = 0, -- No delay here.

    BAD_PING_THRESHOLD          = 300, -- This is what is used for server listing filters
    BAD_PERFORMANCE_THRESHOLD   = 2, -- These are just logical values (0 - GOOD, 1 - OK, 2 - BAD)

    MAX_REQUEST_RETRIES         = 3,

    DEFAULT_PROPAGATOR_RADIUS   = 5,
    LARGE_PROPAGATOR_RADIUS     = 8,
    MAX_FIRE_ATTEMPTS           = 3,
    REPAIR_RADIUS               = 24,
    EXTINGUISH_RADIUS           = 40,
    EXTINGUISH_AFTER            = 5,
    MONITORED_POPULATION_LIMIT  = 5,

    LEADERBOARD_MAX_LEN         = 5,
    STARTING_REPUTATION         = 100,

    REPUTATION_TABLES           = {
        REVIVE              = 35,
        DIED                = -15,
        EXTINGUISH_STRUCT   = 5,
        BOSS_DAMAGE         = 0.01, -- Per HP dealt
    },

    SHARD_ID = {
        MASTER = 1,
    },

    TASK_ID = {
        INPUTPROXY_FETCH = 3,
    },

    ------------------------------------
    SKINS_PREVIEW_URL           = "https://items.kleientertainment.com/images/DST/%s/%s", -- .../DST/<skin prefab>/<size>
    --- @deprecated: use steam's API instead
    DST_BUILDS                  = "https://s3.amazonaws.com/dstbuilds/builds.json",
    STEAM_ACCOUNT_URL           = "https://steamcommunity.com/profiles/%s",
    WIKI_URL                    = "https://dontstarve.fandom.com/wiki/%s",
    FSLS_QUERY_URL              = "https://login.kleientertainment.com/login/FamilySharingLookup",
    STEAM_UP_TO_DATE_CHECK      = "https://api.steampowered.com/ISteamApps/UpToDateCheck/v1/?appid=%s&version=%s",
    STEAM_WORKSHOP              = "https://steamcommunity.com/sharedfiles/filedetails/?id=%s",
    ------------------------------------

    BASE_STRUCTURE_TAGS         = {"structure", "wall"},
    RESOURCE_PLANT_TAGS         = {"witherable", "readyforharvest", "notreadyforharvest"},
    ENT_MUST_HAVE_TAGS          = {"canlight"},
    ENT_CANT_HAVE_TAGS          = {"FX", "NOCLICK", "DECOR", "INLIMBO", "burnt", "player", "monster", "tree"},
    DANGER_ONOF_TAGS            = {"hostile", "_combat", "trapdamage"},

    BURNABLE_MUST_TAGS          = {"canlight"},
    BURNABLE_CANT_TAGS          = {"FX", "NOCLICK", "DECOR", "INLIMBO", "burnt", "player", "monster", "frozen"},

    ------------------------------------

    MOD_BLACKLIST_FILE_PATH     = "../../modblacklist.txt",
    MOD_ALLOWLIST_FILE_PATH     = "../../modallowlist.txt",

    SERVER_TOKEN_PATH           = "../../cluster_token.txt",

    COMMON_CONFIG_PATH          = "../../commonconfig.lua"

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
})
PEARL.CONSTS.ENT_ONEOF_TAGS = ArrayUnion(
    PEARL.CONSTS.BASE_STRUCTURE_TAGS, PEARL.CONSTS.RESOURCE_PLANT_TAGS
)

--------------------------------
-- [[ Config ]]
--------------------------------

PEARL.info("Loading Configuration...")

-- local CHECKS = {
--     ["string"] = function(v) return type(v) == "string" and #v > 0 end,
--     ["table"]  = function(v) return type(v) == "table" and next(v) ~= nil end,
-- }

--- @TODO: rethink this a bit more.
-- We expect option.checks to be a valid table here.
-- local function RunOptionChecksRecursively(option, level, failed)
--     -- By default all checks have failed.
--     failed = failed or table.getkeys(option.checks)
--     level = level or PEARL.CONFIG[option.name] or option.default
--     if type(level) ~= "table" then
--         return
--     end

--     for k, v in pairs(level) do
--         print(k, v)
--         if level.ENABLED == true and type(CHECKS[option.checks[k]]) == "function" and CHECKS[option.checks[k]](v) == false then
--             failed[#failed+1] = k
--             level.ENABLED = false
--         elseif type(v) == "table" then
--             RunOptionChecksRecursively(option, v, failed)
--         end
--     end

--     return failed
-- end

--- Load backend specific configuration options.
for _, option in ipairs(PEARL.MOD_INFO.configuration_options) do
    if not option.general then
        PEARL.ModConfig:LoadConfigOption(option)
    end
end

--------------------------------
-- [[ Common Config ]]
--------------------------------

if PEARL.CONFIG.COMMON_MOD_CONFIG then
    local config = PEARL.ModConfig:LoadCommmonConfig()
    if type(config) == "table" then
        PEARL.ModConfig:ApplyCommonConfig(config)
    end
end

--------------------------------
-- [[ Server Token ]]
--------------------------------

PEARL.info("Loading server token...")

do
    local success, token = PEARL.GetPersistentString(PEARL.CONSTS.SERVER_TOKEN_PATH, false)
    if not success or type(token) ~= "string" then
        return error("Could not load the server token!")
    end

    PEARL.SERVER_TOKEN = token:strip()
end

----------------------------------------------------------------
-- [[ Agreement/Welcome screen configurations ]]
----------------------------------------------------------------

if PEARL.CONFIG.INTRO_SCREEN then
    -- These are arrays of sections.
    -- Each section has two fields, a description and a title.
    -- A welcome popup has only 1 section but the agreement screen can have many.¨
    local ParseTxt = PEARL.loadfile("utils/txtparser")
    PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT = ParseTxt("agreement.txt", true, true)
    PEARL.CONFIG.WELCOME_POPUP_CONTENT = ParseTxt("welcome.txt", true, false)

    if type(PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT) ~= "table" or IsTableEmpty(PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT) then
        PEARL.warn("The body and content for the agreement screen are not setuped!")
        PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT = nil
    end

    if type(PEARL.CONFIG.WELCOME_POPUP_CONTENT) ~= "table" or IsTableEmpty(PEARL.CONFIG.WELCOME_POPUP_CONTENT) then
        PEARL.warn("The body and content for the welcome popup are not setuped!")
        PEARL.CONFIG.WELCOME_POPUP_CONTENT = nil
    end
end

if PEARL.CONFIG.MOD_BLOCKER.ENABLED then
    PEARL.info("Loading mod blocker configurations...")

    PEARL.CONFIG.MOD_BLOCKLIST = PEARL.GetAllPersistentStringLines(PEARL.CONSTS.MOD_BLACKLIST_FILE_PATH, true, true)
    PEARL.CONFIG.MOD_ALLOWLIST = PEARL.GetAllPersistentStringLines(PEARL.CONSTS.MOD_ALLOWLIST_FILE_PATH, true, true)

    -- When the tables are empty, set them to nil to save some bytes when sending the config.
    -- Since these data are being zipped.
    if PEARL.CONFIG.MOD_BLOCKLIST and IsTableEmpty(PEARL.CONFIG.MOD_BLOCKLIST) then
        PEARL.CONFIG.MOD_BLOCKLIST = nil
    end

    if PEARL.CONFIG.MOD_ALLOWLIST and IsTableEmpty(PEARL.CONFIG.MOD_ALLOWLIST) then
        PEARL.CONFIG.MOD_ALLOWLIST = nil
    end

    if not PEARL.CONFIG.MOD_BLOCKLIST and not PEARL.CONFIG.MOD_ALLOWLIST then
        PEARL.info("Mod blocker is enabled by the mod allowlist and blocklist are empty!")
        PEARL.CONFIG.MOD_BLOCKER.ENABLED = false
    end
end

----------------------------------------------------------------
-- [[ Loading Tips Config ]]
----------------------------------------------------------------

if PEARL.CONFIG.CUSTOM_LOADING_TIPS then do
    local fp = "../../loadingtips.lua"
    if not PEARL.PersistentStringExists(fp) then
        PEARL.SetPersistentString(fp, "return { }")
    end

    -- Run the file in our environment so it has access to all the globals it could possibly need.
    local success, data = PEARL.LoadPersistentLuaString(fp, false, PEARL.ENV)
    if not success or not data then
        -- Data should be in this case the traceback.
        return PEARL.error("Failed to load the custom loading tips!", data)
    end

    PEARL.CONFIG.CUSTOM_LOADING_TIPS_DATA = data
end end

--------------------------------
-- [[ Simulation Handlers ]]
--------------------------------

PEARL.info("Loading simulation handlers...")
PEARL.loadfile("simulation")

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
-- [[ Klei Metrics ]]
--------------------------------

--- @TODO: This seems to not be sufficient
PEARL.OverrideValue(_G, "METRICS_ENABLED", PEARL.CONFIG.SEND_KLEI_METRICS)
PEARL.OverrideValue(_G, "STATS_ENABLE", PEARL.CONFIG.SEND_KLEI_METRICS)
if PEARL.CONFIG.SEND_KLEI_METRICS == false then
    PEARL.OverrideUserdataVariable("SendProfileStats", function() end, TheNet)
end

--------------------------------
-- [[ Constants and Utilities ]]
--------------------------------

-- No need to load any further on the initial launch.
if PEARL.INIT then
    return
end

local _default_mt = getmetatable({})
_default_mt.__newindex = function()
    if PEARL.CONFIG.DEBUG_MODE then
        return error("Attempted to change a constant!")
    end

    return PEARL.error("Attempted to change a constant!")
end

local _const_mt = _default_mt

PEARL.info("Loading constants...")
--- @type table<table<string, boolean>>
PEARL.PREFABS = PEARL.loadfile("constants/prefabs")

-- Load emotes before icons
--- @type table<table<string, string>>
PEARL.EMOTES = PEARL.loadfile("constants/emotes")
--- @type table<table<string, string>|table<table<string, string>>>
PEARL.ICONS = PEARL.loadfile("constants/icons")

setmetatable(PEARL.PREFABS, _const_mt)
setmetatable(PEARL.EMOTES, _const_mt)
setmetatable(PEARL.ICONS, _const_mt)

--------------------------------
-- [[ Wall Scheduler ]]
--------------------------------

PEARL.info("Setting up the wall-scheduler...")

--- @type WallScheduler
PEARL.WallScheduler = PEARL.loadfile("libraries/wallscheduler")
PEARL.WallScheduler:StartWallUpdate()

--------------------------------
-- [[ Network ]]
--------------------------------
PEARL.info("Loading network components...")

--- @type HTTPClient
PEARL.HTTPClient = PEARL.loadfile("libraries/http/httpclient")
PEARL.HTTPClient:Setup()
PEARL.HTTPClient:SetRequestFrequency(PEARL.CONFIG.REQUEST_FREQUENCY)

--- @type RestAPI
PEARL.DiscordRestAPI = PEARL.loadfile("libraries/discordapi/restapi")

PEARL.info("Loading server network...")

--- @type ServerNetwork
PEARL.ServerNetwork = PEARL.loadfile("servernetwork")

--------------------------------
-- [[ Server Listing ]]
--------------------------------

PEARL.info("Loading server listing...")

--- @type ServerListing
PEARL.ServerListing = PEARL.loadfile("serverlisting")

--------------------------------
-- [[ Webhooks ]]
--------------------------------

PEARL.info("Setting up the webhooks...")

--- @type Logger
PEARL.DiscordLogger = PEARL.loadfile("libraries/discordapi/webhooks/logger")()

if not PEARL.CONFIG.DISCORD.LHOOK.ENABLED then
    PEARL.warn("Sending system logs to discord is disabled.")

    PEARL.DiscordLogger:SetIsDisabled(true)
end


--- @type Reporter
PEARL.DiscordReporter = PEARL.loadfile("libraries/discordapi/webhooks/reporter")()
PEARL.DiscordReporter._webhook:FetchData()

--- @type LeaderBorder
PEARL.DiscordLeaderBoarder = PEARL.loadfile("libraries/discordapi/webhooks/leaderboarder")()

--------------------------------
-- [[ Steam API ]]
--------------------------------

PEARL.info("Wrapping up the Steam Web API...")

--- @type SteamAPI
--- @class SteamAPI
PEARL.SteamAPI = PEARL.loadfile("libraries/steamapi")

--------------------------------
-- [[ Extensions ]]
--------------------------------

local function LoadExtensions()
    PEARL.loadfile("extensions/profanityfilter")
    PEARL.loadfile("extensions/chathistory")

    PEARL.info("Loading game component extensions...")
    PEARL.loadfile("extensions/components/inventory")
    PEARL.loadfile("extensions/components/workable")
    PEARL.loadfile("extensions/components/age")
    PEARL.loadfile("extensions/components/inventoryitem")
    PEARL.loadfile("extensions/components/container")
    PEARL.loadfile("extensions/components/edible")
    PEARL.loadfile("extensions/components/activable")

    -- Performance testing
    if PEARL.CONFIG.PERFORMANCE_MODE then
        PEARL.loadfile("extensions/components/updatelooper")
        PEARL.loadfile("extensions/components/timer")

        --PEARL.loadfile("extensions/class")
    end

    PEARL.info("Loading game script extensions...")
    PEARL.loadfile("extensions/scripts/entityscript")
    PEARL.loadfile("extensions/scripts/playercommon")

    PEARL.info("Loading mob brain extensions...")
    PEARL.loadfile("extensions/brains/pigbrain")

    --- @type ExtensionManager
    local ExtensionManager = PEARL.loadfile("libraries/extensionmanager")
    PEARL.info("Loading prefab extensions...")
    for _, prefab in ipairs(PEARL.CONFIG.PREFAB_EXTENSIONS) do
        ExtensionManager:ExtendPrefab(prefab)
    end
end

-- Load our extensions after all mods are loaded,
-- in case some of them override the extended files.
PEARL.AddFrontEndPreInit(LoadExtensions)

-------------------------------------
-- [[ Blacklist/Whitelist Wrappers ]]
-------------------------------------

PEARL.info("Loading blacklist...")

--- @type BlackList
PEARL.BlackList = PEARL.loadfile("libraries/wrappers/blacklist")
PEARL.BlackList:Load()

PEARL.info("Loading whitelist...")

--- @type Whitelist
PEARL.WhiteList = PEARL.loadfile("libraries/wrappers/whitelist")
--- @deprecated Use AllowList instead.
if PEARL.CONFIG.STRICT_WHITELIST then
    PEARL.WhiteList:SetMode(PEARL.WhiteList.MODE.ALLOWLIST)
    PEARL.WhiteList:SyncReservedWithSlots()
end

PEARL.info("Loading allowlist...")

--- @type AllowList
PEARL.AllowList = PEARL.loadfile("libraries/wrappers/allowlist")
if PEARL.CONFIG.ALLOWLIST and TheShard:IsMaster() then
    PEARL.warn("Allowlist is enabled! Only players on the list or admins will be able to join.")
    PEARL.AllowList:SetIsEnabled(true)
end
PEARL.AllowList:Load()

PEARL.info("Loading adminlist...")

--- @type AdminList
PEARL.AdminList = PEARL.loadfile("libraries/wrappers/adminlist")
PEARL.AdminList:Load()

-------------------------------------
-- [[ Player Libraries ]]
-------------------------------------

--- @type PlayerDB
PEARL.PlayerDB = PEARL.loadfile("libraries/playerdatabase")
PEARL.PlayerDB:SetIsEnabled(PEARL.CONFIG.DATABASE.ENABLED)
if PEARL.PlayerDB:IsEnabled() then
    PEARL.PlayerDB:LoadUseridList()
end

--- @type Reputation
PEARL.Reputation = PEARL.loadfile("libraries/reputation")

-------------------------------------
-- [[ Commands ]]
-------------------------------------

PEARL.info("Loading commands...")
PEARL.loadfile("extensions/usercommands")
PEARL.loadfile("extensions/commands")

--------------------------------
-- [[ Debug Mode ]]
--------------------------------

if PEARL.CONFIG.DEBUG_MODE then
    PEARL.warn("Debug mode enabled! This is not recommended for production use.")
    PEARL.loadfile("debugtools")
    PEARL.loadfile("testing")

    PEARL.CreateWordFilterFile = PEARL.loadfile("utils/wordloader")
    PEARL.CreateWordFilterFile("czech.txt", "czech.lua")

    require("profiler")
    PEARL.Profiler = newProfiler("time", 10^6)

    require("debugcommands")
    require("debugkeys")
    -- Fix for a broken debug handler
    handlers[KEY_D] = nil

    -- Better c_reset
    PEARL.AddGlobalFunctionPreCall("c_reset", function()
        TheSim:ResetError()
    end)

    PEARL.GenerateConfigFile = PEARL.loadfile("utils/configfilegenerator")

    PEARL.DataDumper = PEARL.loadfile("utils/datadumper")
end

--------------------------------
-- [[ Modules ]]
--------------------------------

PEARL.info("Loading modules...")

--- @type ModuleManager
local ModuleManager = PEARL.loadfile("libraries/modulemanager")
ModuleManager:SetLoader(PEARL.loadfile)
ModuleManager:SetModuleDirectory("modules")

ModuleManager:AddModule("localizer", PEARL.CONFIG.LOCALIZER.ENABLED)
ModuleManager:AddModule("altdentifier", PEARL.CONFIG.BAN_ALT_ACCOUNTS)
-- This needs some refactoring and will probably be migrated to the clients.
--ModuleManager:AddModule("pingreporter", PEARL.CONFIG.REPORT_BAD_SERVER_LATENCY or PEARL.CONFIG.REPORT_BAD_CLIENT_LATENCY)
ModuleManager:AddModule("modreporter", PEARL.CONFIG.MOD_BLOCKER.REPORT_MODS)
ModuleManager:AddModule("inventoryreporter", PEARL.CONFIG.INVENTORY_REPORTER.ENABLED)
ModuleManager:AddModule("globalplayericons", PEARL.CONFIG.SHOW_PLAYER_ICONS)
-- ModuleManager:AddModule("slashcommands", PEARL.CONFIG.SLASH_COMMANDS)
ModuleManager:AddModule("selfstacker", PEARL.CONFIG.SELF_STACKER.ENABLED)
ModuleManager:AddModule("lazyloading", PEARL.CONFIG.LAZY_LOAD_PREFABS)
ModuleManager:AddModule("healthinfo", PEARL.CONFIG.HEALTH_INFO.ENABLED)
ModuleManager:AddModule("characterblocker", not table.empty(PEARL.CONFIG.CHARACTER_BLOCKLIST))
ModuleManager:AddModule("player_recorder", PEARL.CONFIG.DATABASE.ENABLED)
ModuleManager:AddModule("steamprofilechecker", PEARL.CONFIG.FILTER_NEW_PROFILES)
ModuleManager:AddModule("usernamefilter", PEARL.CONFIG.FILTER_USERNAMES)
--- Looks like currently only Steam is supported as a platform.
ModuleManager:AddModule("platformchecker", not table.empty(PEARL.CONFIG.SUPPORTED_CLIENT_PLATFORMS))

--- Master-only Modules
if TheShard:IsMaster() then
    ModuleManager:AddModule("versionchecker", PEARL.CONFIG.VERSION_CHECKER.ENABLED)
    ModuleManager:AddModule("inputproxy", PEARL.CONFIG.DISCORD.PROXY.COMMANDS_ENABLED or PEARL.CONFIG.DISCORD.PROXY.CHAT_ENABLED)

    if PEARL.CONFIG.PROXY.ENABLED then
        ModuleManager:AddModule("leaderboard", PEARL.DiscordLeaderBoarder:IsEnabled() and PEARL.CONFIG.LEADERBOARD.ENABLED and PEARL.CONFIG.DATABASE.ENABLED)
    end
end

-- Logger Modules
ModuleManager:AddModule("logger/world", true)
ModuleManager:AddModule("logger/player", true)

-- Discord only loggers
if PEARL.DiscordLogger:IsEnabled() then
    ModuleManager:AddModule("logger/chat", true)
    ModuleManager:AddModule("logger/server", true)
end

ModuleManager:AddModule("timeupdates", true)

ModuleManager:LoadAllModules()

--------------------------------
-- [[ Custom Prefabs ]]
--------------------------------

-- Here are stored all the prefabs this mod adds to the game.
-- This is being loaded after the builtin prefabs so we can override them.
PrefabFiles = {}

if type(PEARL.CONFIG.CUSTOM_PREFABS) == "table" then
    -- Here are stored all the prefabs this mod adds to the game.
    -- This is being loaded after the builtin prefabs so we can override them.
    PrefabFiles = {}

    for prefab, enabled in pairs(PEARL.CONFIG.CUSTOM_PREFABS) do
        if enabled then
            PrefabFiles[#PrefabFiles + 1] = prefab
        end
    end
end
