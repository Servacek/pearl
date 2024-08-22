--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--[[
    Server specific stuff. Needs to be loaded only on the server.
--]]

--------------------------------
-- [[ Constants ]]
--------------------------------

PEARL.info("Loading BE constants...")

PEARL.SafeModTableExtend("CONSTS", {
    DST_WEB_GAME_ID = "DontStarveTogether",

    --> The discord module
    DISCORD = {
        API_VERSION                 = 10, -- Currently the newest

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

    DEFAULT_PROPAGATOR_RADIUS   = 5,
    LARGE_PROPAGATOR_RADIUS     = 8,
    MAX_FIRE_ATTEMPTS           = 3,
    REPAIR_RADIUS               = 24,
    EXTINGUISH_RADIUS           = 40,
    EXTINGUISH_AFTER            = 5,
    MONITORED_POPULATION_LIMIT  = 5,

    LEADERBOARD_DISPLAY_COUNT   = 5,
    STARTING_REPUTATION         = 100,

    --- @class REPUTATION_TABLES
    REPUTATION_TABLES           = {
        REVIVE              = 15,
        DIED                = -15,
        EXTINGUISH_STRUCT   = 2.5,
        EXTINGUISH          = 1.5,
        BOSS_DAMAGE         = 0.008, -- Per HP dealt
        COMPANION_DAMAGE    = -0.07, -- Companions have less HP
        FOLLOWER_DAMAGE     = -0.1,
        BURNABLE_NEAR_FIRE  = -3,
        POPULATION_EXTINCT  = -10,
        STRUCT_NEAR_FIRE    = -6,
        BUILT_STRUCTURE     = 4,
        FERTILIZED          = 1,
        CRAFTED_ITEM        = 1,
        CONSTRUCTED         = 8,
        QUEST_COMPLETED     = 12,
        LEFT_WITH_BAD_INV   = -20,
        PLAYER_HEALED       = 4,
        OFFENSIVE_WORD_USED = -1,
        AFK_GHOST           = -8,
        AFK_GHOST_KICKED    = -16,
        AFK_KICKED          = -8,
        PLANT               = 1,
        PLANT_RESOURCE      = 2,
        FUEL_WASTED         = -1, -- States for 100% fuel wasted.
        FUEL_TO_PROTECTOR   = 1,
        CHOPPED_PROHIBITED  = -20,
        COOKED_RARE         = -20, -- When rarity is 100%
        COOKED_RARE_INGRED  = -10,
        READ_OFFENSIVE_BOOK = -5,
        REPAIR_ITEM         = 1, -- For 100% repaired durability
        EAT_RARE            = -10, -- For 100% rarity
        EAT_VERY_RARE       = -20,
        WASTE_FOOD          = -5, -- For 100% of foods nutrition wasted (> 50%)
        HAMMER_STRUCTURE    = -1.5,
        IGNITED_STRUCTURE   = -6, -- Per One Structure
        IGNITED_PLANT       = -3,
        IGNITED_ENTITY      = -.5,
        IGNITING_AT_BASE    = -8,
        FIRE_MOB_KILLED     = -5,
        LEARNED_BLUEPRINT   = -5,
        LEARNED_RAREPRINT   = -10,
        DUG_UP_GOODS        = 2,
        DUG_UP_BAD          = -1,
        SEGMENT_SURVIVED    = 0.4, -- * 16 per day
        SEGMENT_DEAD        = -0.4,
        SEGMENT_AFK         = -0.3, -- Stacks with SEGMENT_DEATH
        BROKE_REPAIRABLE    = -3, -- For 0% rarity
    },

    ITEM_WEIGHT_BIAS       = {
        RENEWABLE           = -.001,
        PER_FOOD_POINT      = .0033,
        PER_FOOD_POINT_RAW  = .0024,

        MAX                 = 1,
        MIN                 = 0,
    },

    DEFAULT_ITEM_WEIGHT     = 0.001,

    SHARD_ID = {
        MASTER = 1,
    },

    BAN_AUTHORS = {
        SYSTEM = "SYSTEM",
    },

    TASK_ID = {
        INPUTPROXY_FETCH = 3,
    },

    ------------------------------------
    SKINS_PREVIEW_URL           = "https://items.kleientertainment.com/images/DST/%s/%s", -- .../DST/<skin prefab>/<size>
    SKINS_MARKET_URL            = "https://steamcommunity.com/market/listings/%s/%s", -- ../<APPID>/<skin_prefab_UPPER>
    DST_BUILDS                  = "https://s3.amazonaws.com/dstbuilds/builds.json",
    STEAM_ACCOUNT_URL           = "https://steamcommunity.com/profiles/%s",
    WIKI_URL                    = "https://dontstarve.fandom.com/wiki/%s",
    FSLS_QUERY_URL              = "https://login.kleientertainment.com/login/FamilySharingLookup",
    STEAM_UP_TO_DATE_CHECK      = "https://api.steampowered.com/ISteamApps/UpToDateCheck/v1/?appid=%s&version=%s",
    STEAM_WORKSHOP              = "https://steamcommunity.com/sharedfiles/filedetails/?id=%s",

    HELP_URLS = {
        ACCOUNT_BINDINGS        = "https://discord.com/channels/662329201721868293/1202878043878592532/1202906592841039872",
    },

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

    ------------------------------------

    KLEI_ID_PATTERN     = "KU_"..string.rep("[%d%a%p]", 8),
    STEAM_ID_PATTERN    = string.rep("%d", 17),
})
PEARL.CONSTS.ENT_ONEOF_TAGS = ArrayUnion(
    PEARL.CONSTS.BASE_STRUCTURE_TAGS, PEARL.CONSTS.RESOURCE_PLANT_TAGS
)

--------------------------------
-- [[ Config ]]
--------------------------------

PEARL.info("Loading server-side configurations...")

--- Load server specific configuration options.
--- This has to be loaded here in order to run all the important checks.
for _, option in ipairs(PEARL.MODINFO.configuration_options) do
    --if not option.general and PEARL.CONFIG[option.name] == nil then
        PEARL.ModConfig:LoadServerSideOverride(option)
    --end
end

--------------------------------
-- [[ Permissive Mode ]]
--------------------------------

do
    local PARAM = PEARL.GameInstParams:GetModParam(PEARL.INSTANCE_PARAMS.PERMISSIVE_MODE)

    -- Only setting the param to true will override the actual configuration.
    if PARAM == true then
        PEARL.CONFIG.PERMISSIVE_MODE = PARAM

        -- Save it for next game instance.
        PEARL.GameInstParams:SetModParam(PEARL.INSTANCE_PARAMS.PERMISSIVE_MODE, PEARL.CONFIG.PERMISSIVE_MODE)
    end
end

if TheShard:IsMaster() then
    local announced = false
    PEARL.AddWorldPostInit(function()
        if not announced and PEARL.CONFIG.PERMISSIVE_MODE and (PEARL.CONFIG.AUTOBAN or PEARL.CONFIG.INVENTORY_REPORTER.ENABLED) then
            TheNet:Announce(STRINGS.PEARL.LOGS.PERMISSIVE_MODE_WARNING)
            announced = true
        end
    end)
end

--------------------------------
-- [[ Server Token ]]
--------------------------------

do
    PEARL.info("Loading server token...")

    local token = PEARL.ClusterPersistence:GetFileContent(PEARL.CONSTS.SERVER_TOKEN_PATH, false)
    if not token then
        return error("Could not load the server token!")
    end

    PEARL.SERVER_TOKEN = token:strip()
end

----------------------------------------------------------------
-- [[ Mountable Lua ]]
----------------------------------------------------------------

do
    PEARL.info("Loading mountable extension scripts...")

    local lua_string = PEARL.ClusterPersistence:GetFileContent(PEARL.MOUNTABLE_SCRIPTS_PATH)
    if lua_string then
        PEARL.CONFIG.MOUNTABLE_LUA = lua_string
    else
        if PEARL.ClusterPersistence:FileExists(PEARL.MOUNTABLE_SCRIPTS_PATH) then
            PEARL.error("Loading mountable extension scripts has failed!")
        else
            local INITIAL_STRING = STRINGS.PEARL.FILES.MOUNTABLE_SCRIPTS
            PEARL.ClusterPersistence:SetFileContent(PEARL.MOUNTABLE_SCRIPTS_PATH, "\n"..INITIAL_STRING, false)
        end
    end
end

----------------------------------------------------------------
-- [[ Agreement/Welcome screen configurations ]]
----------------------------------------------------------------

if PEARL.CONFIG.INTRO_SCREEN then
    PEARL.info("Loading agreement and welcome files...")

    -- These are arrays of sections.
    -- Each section has two fields, a description and a title.
    -- A welcome popup has only 1 section but the agreement screen can have many.
    local ParseTxt = PEARL.loadfile("utils/txtparser")
    local AGREEMENT_SCREEN_CONTENT = ParseTxt("agreement.txt", true, true)
    local WELCOME_POPUP_CONTENT = ParseTxt("welcome.txt", true, false)

    if table.empty(AGREEMENT_SCREEN_CONTENT) == false then
        PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT = AGREEMENT_SCREEN_CONTENT
    else
        PEARL.warn("The body and content for the agreement screen are not set!")
    end

    if table.empty(WELCOME_POPUP_CONTENT) == false then
        PEARL.CONFIG.WELCOME_POPUP_CONTENT = WELCOME_POPUP_CONTENT
    else
        PEARL.warn("The body and content for the welcome popup are not set!")
    end
end

----------------------------------------------------------------
-- [[ Mod Blocker ]]
----------------------------------------------------------------

if PEARL.CONFIG.MOD_BLOCKER.ENABLED then
    PEARL.info("Loading mod blocker lists...")

    PEARL.CONFIG.MOD_BLOCKLIST = PEARL.ClusterPersistence:GetAllFileLines(PEARL.CONSTS.MOD_BLACKLIST_FILE_PATH, true, true)
    PEARL.CONFIG.MOD_ALLOWLIST = PEARL.ClusterPersistence:GetAllFileLines(PEARL.CONSTS.MOD_ALLOWLIST_FILE_PATH, true, true)
    PEARL.CONFIG.MOD_BLOCKLIST = PEARL.ClusterPersistence:GetAllFileLines(PEARL.CONSTS.MOD_BLACKLIST_FILE_PATH, true, true)
    PEARL.CONFIG.MOD_ALLOWLIST = PEARL.ClusterPersistence:GetAllFileLines(PEARL.CONSTS.MOD_ALLOWLIST_FILE_PATH, true, true)

    -- When the tables are empty, set them to nil to save some bytes when sending the config.
    -- Since these data are being zipped.
    if PEARL.CONFIG.MOD_BLOCKLIST and IsTableEmpty(PEARL.CONFIG.MOD_BLOCKLIST) then
        PEARL.CONFIG.MOD_BLOCKLIST = nil
    end

    if PEARL.CONFIG.MOD_ALLOWLIST and IsTableEmpty(PEARL.CONFIG.MOD_ALLOWLIST) then
        PEARL.CONFIG.MOD_ALLOWLIST = nil
    end

    if not PEARL.CONFIG.MOD_BLOCKLIST and not PEARL.CONFIG.MOD_ALLOWLIST then
        PEARL.info("Mod blocker is enabled but the mod allowlist and blocklist are empty!")
        PEARL.CONFIG.MOD_BLOCKER.ENABLED = false
    end
end

----------------------------------------------------------------
-- [[ Loading Tips Config ]]
----------------------------------------------------------------

if PEARL.CONFIG.CUSTOM_LOADING_TIPS then do
    PEARL.info("Loading custom loading tips file...")

    local fp = "../../loadingtips.lua"
    if not PEARL.ClusterPersistence:FileExists(fp) then
        PEARL.ClusterPersistence:SetFileContent(fp, "return { }")
    end

    -- Run the file in our environment so it has access to all the globals it could possibly need.
    local success, data = PEARL.ClusterPersistence:LoadLuaFile(fp, false, PEARL.ENV)
    if not success or type(data) ~= "table" then
        -- Data should be in this case the traceback.
        return PEARL.error("Failed to load the custom loading tips!", data)
    end

    -- Normalization
    for i = #data, 1, -1 do
        local lt = data[i]
        if lt.enabled == false then
            table.remove(data, i)
        else
            lt.enabled = nil
            lt.type = lt.type and string.upper(lt.type)
            if not PEARL.CONSTS.LT_TYPES[lt.type] then
                PEARL.error("Invalid type provided for loading tip!", lt.type, lt.text)
                lt.type = PEARL.CONSTS.LT_TYPES.OTHER
            end

            if lt.data and lt.type ~= PEARL.CONSTS.LT_TYPES.CONTROLS then
                PEARL.error("Loading tip contains control data but is not of type \"controls\"!", lt.type, lt.text)
                PEARL.warn("Changing type of this loading tip to", PEARL.CONSTS.LT_TYPES.CONTROLS)
                lt.type = PEARL.CONSTS.LT_TYPES.CONTROLS
            end

            lt.name = string.upper(lt.name or PEARL.MODNAME.."_TIP_"..tostring(i))
        end
    end

    PEARL.CONFIG.CUSTOM_LOADING_TIPS_DATA = data
end end

----------------------------------------------------------------
-- [[ Proxy Server Implcit Config ]]
----------------------------------------------------------------

--- Available to clients.
PEARL.CONFIG.DISCORD_PROXY_ENABLED = PEARL.CONFIG.DISCORD.PROXY.COMMANDS_ENABLED or PEARL.CONFIG.DISCORD.PROXY.CHAT_ENABLED


--------------------------------
-- [[ Maintenance ]]
--------------------------------

if not PEARL.INITIAL_LAUNCH then

    --- @type Cron
    PEARL.Cron = PEARL.loadfile("cron")

    do
        local MAINTENANCE_REBOOT_HOUR = tonumber(PEARL.CONFIG.MAINTENANCE_REBOOT)
        if MAINTENANCE_REBOOT_HOUR ~= nil then
            PEARL.info("Configuring maintenance reboot job...")

            PEARL.Cron:AddJob(PEARL.Cron:New(
                38, 15, "*", "*", "*", PEARL.Reboot
            ))
        end
    end
end

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
    table.insert(PEARL.MODINFO.server_filter_tags, tag)
end

--------------------------------
-- [[ Klei Metrics ]]
--------------------------------

if PEARL.CONFIG.SEND_KLEI_METRICS == false then
    PEARL.info("Disabling Klei metrics...")

    PEARL.OverrideValue(_G, "METRICS_ENABLED", false)
    PEARL.OverrideValue(_G, "STATS_ENABLE", false)
    PEARL.OverrideUserdataValue("SendProfileStats", function() end, TheNet)
end

--------------------------------
-- [[ Server-Side Name ]]
--------------------------------

PEARL.MODINFO.name = PEARL.MODINFO.server_side_name or PEARL.MODINFO.name

-- No need to load any further on the initial launch.
--*************************************************************************************************--
if PEARL.INITIAL_LAUNCH then ----------------------------------------------------------------------------------
    return ------------------------------------------------------------------------------------------
end -------------------------------------------------------------------------------------------------
--*************************************************************************************************--

--------------------------------
-- [[ Constants and Utilities ]]
--------------------------------

PEARL.info("Loading constants...")

--- @readonly
--- @type PREFABS table<table<string, boolean>>
PEARL.PREFABS = PEARL.loadfile("constants/prefabs")

--- @readonly
--- @type ICONS table<table<string, string>|table<table<string, string>>>
PEARL.ICONS = PEARL.loadfile("constants/icons")

--------------------------------
-- [[ Network ]]
--------------------------------
PEARL.info("Loading network components...")

PEARL.info("Loading Discord REST API wrappers...")

--- @type RestAPI
PEARL.DiscordRestAPI = PEARL.loadfile("libs/discordapi/restapi")
-- Enabling and disabling is changed internaly when rate limitting.
PEARL.DiscordRestAPI:SetIsEnabled(true)

PEARL.info("Loading server network...")

--- @type ServerNetwork
PEARL.ServerNetwork = PEARL.loadfile("servernetwork")

PEARL.loadfile("networkhandlers")

--------------------------------
-- [[ Discord Proxy ]]
--------------------------------

PEARL.info("Loading Discord Proxy wrapper...")

--- @class DiscordProxy
PEARL.DiscordProxy = PEARL.loadfile("libs/discordapi/discordproxy")

--------------------------------
-- [[ Steam API ]]
--------------------------------

PEARL.info("Loading the Steam Web API wrapper...")

--- @type SteamAPI
--- @class SteamAPI
PEARL.SteamAPI = PEARL.loadfile("libs/steam/steamapi")

--------------------------------
-- [[ Klei Accounts ]]
--------------------------------

PEARL.info("Loading Klei REST API wrapper...")

--- @type KleiAccounts
PEARL.KleiAccounts = PEARL.loadfile("libs/kleiaccounts")

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
PEARL.DiscordLogger = PEARL.loadfile("libs/discordapi/webhooks/logger")()

if not PEARL.CONFIG.DISCORD.LHOOK.ENABLED then
    PEARL.warn("Sending system logs to discord is disabled.")

    PEARL.DiscordLogger:SetIsDisabled(true)
end

--- @type Reporter
PEARL.DiscordReporter = PEARL.loadfile("libs/discordapi/webhooks/reporter")()
PEARL.DiscordReporter._webhook:FetchData()

--- Has to be loaded before leaderboard service
--- @type LeaderBorder
PEARL.DiscordLeaderBoarder = PEARL.loadfile("libs/discordapi/webhooks/leaderboarder")()
PEARL.DiscordLeaderBoarder:SetIsDisabled(true)

if TheShard:IsMaster() then
    PEARL.DiscordLeaderBoarder:SetIsDisabled(false)
end

-------------------------------------
-- [[ Player Libraries ]]
-------------------------------------

--- Has to be laaded before LeaderboardService
--- @type JSONDB
PEARL.DB = PEARL.loadfile("libs/database/jsondatabase")
PEARL.DB:SetIsEnabled(PEARL.CONFIG.DATABASE.ENABLED)

--- @type AccountBindings
PEARL.AccountBindings = PEARL.loadfile("libs/database/accountbindings")
PEARL.AccountBindings:Load() -- Needs the DB

--- @type Reputation
PEARL.Reputation = PEARL.loadfile("libs/reputation")
PEARL.Reputation:LoadReputationTables()

--------------------------------
-- [[ Leaderboard Service ]]
--------------------------------

--- @type LeaderboardService
PEARL.LeaderboardService = PEARL.loadfile("libs/database/leaderboardservice")
-- Leaderboarding is centralized.
if TheShard:IsMaster() then
    PEARL.LeaderboardService:SetIsEnabled(PEARL.CONFIG.LEADERBOARD.ENABLED and PEARL.CONFIG.DATABASE.ENABLED)
    if PEARL.LeaderboardService:IsEnabled() then
        PEARL.info("Loading leaderboard service...")
        PEARL.LeaderboardService:Load()
        PEARL.LeaderboardService:ValidateLoadedData()
    end
end

--------------------------------
-- [[ Extensions ]]
--------------------------------

local function LoadExtensions()
    PEARL.loadfile("extensions/profanityfilter")
    PEARL.loadfile("extensions/chathistory")

    PEARL.info("Loading game component extensions...")
    PEARL.loadfile("extensions/components/inventory")
    PEARL.loadfile("extensions/components/age")
    PEARL.loadfile("extensions/components/inventoryitem")
    PEARL.loadfile("extensions/components/container")
    PEARL.loadfile("extensions/components/edible")
    PEARL.loadfile("extensions/components/activable")
    PEARL.loadfile("extensions/components/constructionsite")
    PEARL.loadfile("extensions/components/burnable")

    -- Performance testing
    if PEARL.CONFIG.PERFORMANCE_MODE then
        PEARL.loadfile("extensions/components/updatelooper")
        PEARL.loadfile("extensions/components/timer")

        --PEARL.loadfile("extensions/class")
    end

    PEARL.info("Loading game script extensions...")
    PEARL.loadfile("extensions/scripts/entityscript")

    -- Extension for all prefabs
    PEARL.loadfile("extensions/prefabs/global")

    --- @type ExtensionManager
    local ExtensionManager = PEARL.loadfile("libs/loaders/extensionmanager")
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
PEARL.BlackList = PEARL.loadfile("libs/wrappers/blacklist")
PEARL.BlackList:Load()

PEARL.info("Loading whitelist...")

--- @type Whitelist
PEARL.WhiteList = PEARL.loadfile("libs/wrappers/whitelist")
PEARL.WhiteList:Load()

--- @TODO: Add configuration for this
if PEARL.CONFIG.STRICT_WHITELIST then
    PEARL.WhiteList:SetMode(PEARL.WhiteList.MODE.STRICT)
end

PEARL.info("Loading allowlist...")

--- @type AllowList
PEARL.AllowList = PEARL.loadfile("libs/wrappers/allowlist")
if PEARL.CONFIG.ALLOWLIST and TheShard:IsMaster() then
    PEARL.warn("Allowlist is enabled! Only players on the list or admins will be able to join.")
    PEARL.AllowList:SetIsEnabled(true)
end
PEARL.AllowList:Load()

PEARL.info("Loading adminlist...")

--- @type AdminList
PEARL.AdminList = PEARL.loadfile("libs/wrappers/adminlist")
PEARL.AdminList:Load()

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
    --PEARL.loadfile("debugtools")
    PEARL.loadfile("testing")

    PEARL.CreateWordFilterFile = PEARL.loadfile("utils/wordloader")
    PEARL.CreateWordFilterFile("czech.txt", "czech.lua")

    require("profiler")
    PEARL.Profiler = newProfiler("time", 10^6)

    require("debugcommands")
    require("debugkeys")
    -- Fix for a broken debug handler
    handlers[KEY_D] = nil

    PEARL.GenerateConfigFile = PEARL.loadfile("utils/configfilegenerator")
end

--------------------------------
-- [[ Modules ]]
--------------------------------

PEARL.info("Loading modules...")

--- @type ModuleManager
local ModuleManager = PEARL.loadfile("libs/loaders/modulemanager")
ModuleManager:SetLoader(PEARL.loadfile)
ModuleManager:SetModuleDirectory("modules")

--- Default Modules (always enabled)
ModuleManager:AddModule("timeupdates", true)
ModuleManager:AddModule("rephandlers", true)

--- Configurable modules
ModuleManager:AddModule("localizer", PEARL.CONFIG.LOCALIZER.ENABLED)
ModuleManager:AddModule("altdentifier", PEARL.CONFIG.BAN_ALT_ACCOUNTS)
-- This needs some refactoring and will probably be migrated to the clients.
--ModuleManager:AddModule("pingreporter", PEARL.CONFIG.REPORT_BAD_SERVER_LATENCY or PEARL.CONFIG.REPORT_BAD_CLIENT_LATENCY)
ModuleManager:AddModule("modreporter", PEARL.CONFIG.MOD_BLOCKER.REPORT_MODS)
ModuleManager:AddModule("inventoryreporter", PEARL.CONFIG.INVENTORY_REPORTER.ENABLED)
ModuleManager:AddModule("globalplayericons", PEARL.CONFIG.PLAYER_MAP_ICONS.ENABLED)
ModuleManager:AddModule("selfstacker", PEARL.CONFIG.SELF_STACKER.ENABLED)
ModuleManager:AddModule("lazyloading", PEARL.CONFIG.LAZY_LOAD_PREFABS)
ModuleManager:AddModule("healthinfo", PEARL.CONFIG.HEALTH_INFO.ENABLED)
ModuleManager:AddModule("characterblocker", PEARL.CONFIG.CHARACTER_BLOCKLIST)
ModuleManager:AddModule("player_recorder", PEARL.CONFIG.DATABASE.ENABLED)
ModuleManager:AddModule("steamprofilefetcher", PEARL.CONFIG.DATABASE.ENABLED)
ModuleManager:AddModule("globalbanlist", PEARL.CONFIG.GLOBAL_BANLIST.ENABLED and PEARL.CONFIG.GLOBAL_BANLIST.URL)
ModuleManager:AddModule("autoban", PEARL.CONFIG.AUTOBAN.ENABLED)

--- Filters
ModuleManager:AddModule("filters/usernamefilter", PEARL.CONFIG.FILTER_USERNAMES)
ModuleManager:AddModule("filters/platformfilter", PEARL.CONFIG.SUPPORTED_CLIENT_PLATFORMS)
ModuleManager:AddModule("filters/customfilters.lua", PEARL.CONFIG.CUSTOM_CONNECTION_FILTERS)
ModuleManager:AddModule("filters/profilefilter", PEARL.CONFIG.PROFILE_FILTER.ENABLED)

--- Load input proxy on all shards for the state netvars.
ModuleManager:AddModule("inputproxy", PEARL.CONFIG.DISCORD_PROXY_ENABLED)

-- Do only download the emojis from Master and save them to some file so other shards can access it from that.
ModuleManager:AddModule("emojiserver", PEARL.CONFIG.EMOJI_SERVER.ENABLED and PEARL.isvisiblestring(PEARL.CONFIG.EMOJI_SERVER.URL))

--- Master-only Modules
if TheShard:IsMaster() then
    ModuleManager:AddModule("modversionchecker", PEARL.CONFIG.MOD_VERSION_CHECKER.ENABLED)
    ModuleManager:AddModule("gameversionchecker", PEARL.CONFIG.GAME_VERSION_CHECKER.ENABLED)
    ModuleManager:AddModule("leaderboarding", PEARL.LeaderboardService:IsEnabled())
end

-- Logger Modules
ModuleManager:AddModule("logger/world", true)
ModuleManager:AddModule("logger/player", true)
ModuleManager:AddModule("logger/proxyserver", true)

-- Discord only loggers
if PEARL.DiscordLogger:IsEnabled() then
    ModuleManager:AddModule("logger/chat", true)
    ModuleManager:AddModule("logger/server", true)
end

ModuleManager:LoadAllModules()

--------------------------------
-- [[ Custom Prefabs ]]
--------------------------------

if type(PEARL.CONFIG.CUSTOM_PREFABS) == "table" and not table.empty(PEARL.CONFIG.CUSTOM_PREFABS) then
    PEARL.info("Loading custom prefabs...")

    -- Here are stored all the prefabs this mod adds to the game.
    -- This is being loaded after the builtin prefabs so we can override them.
    PrefabFiles = {}
    for prefab, enabled in pairs(PEARL.CONFIG.CUSTOM_PREFABS) do
        if enabled then
            PrefabFiles[#PrefabFiles + 1] = prefab
        end
    end
end
