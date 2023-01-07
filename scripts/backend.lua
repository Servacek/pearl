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

--local PEARL = PEARL

PEARL.info("Loading BE...")

--------------------------------
-- [[ Contants ]]
--------------------------------

PEARL.SafeModTableExtend("CONSTS", {
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
        --- @TODO: Calculate this according to the message's space.
        --- So the first logline would have max ~2000 characters.
        --- The second would have 2000 - prev.length, etc...
        MAX_LOGLINE_CONTENT_LENGTH = 400,

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
})
PEARL.CONSTS.ENT_ONEOF_TAGS = ArrayUnion(
    PEARL.CONSTS.BASE_STRUCTURE_TAGS, PEARL.CONSTS.RESOURCE_PLANT_TAGS
)

--------------------------------
-- [[ Config ]]
--------------------------------

PEARL.info("Loading Configuration...")
PEARL.SafeModTableExtend("CONFIG", {
    -- The discord module
    DISCORD                     = {
        ENABLED                 = PEARL.GetConfigData("DISCORD_LOGS"),

        LHOOK                   = PEARL.GetConfigData("LOG_WEBHOOK"),
        RHOOK                   = PEARL.GetConfigData("REPORT_WEBHOOK"),

        LHOOK_BUFFER_TIMEOUT    = PEARL.GetConfigData("LHOOK_BUFFER_TIMEOUT"),
    },

    -- REST Client
    REQUEST_FREQUENCY           = PEARL.GetConfigData("REQUEST_FREQUENCY"),

    COMMAND_BLOCKLIST           = PEARL.GetConfigData("COMMAND_BLOCKLIST"),
    CUSTOM_SERVER_TAGS          = PEARL.GetConfigData("CUSTOM_SERVER_TAGS"),

    -- OPTIMIZED_SCHEDULER         = PEARL.GetConfigData("OPTIMIZED_SCHEDULER"),

    ANNOUNCEMENTS               = PEARL.GetConfigData("ANNOUNCEMENTS"),

    -- Version Checker
    VERSION_CHECK_FREQUENCY     = PEARL.GetConfigData("VERSION_CHECK_FREQUENCY"), -- minutes
    UPDATE_SERVER_AFTER         = PEARL.GetConfigData("UPDATE_SERVER_AFTER"), -- minutes

    -- Anti-Grief
    --GRIEF_PROTECTION            = PEARL.GetConfigData("FIRE_PROTECTION"),

    TRUST_AGE                   = PEARL.GetConfigData("TRUST_AGE"),
    TRUST_AGE_PERCENT           = PEARL.GetConfigData("TRUST_AGE_PERCENT"),
    LOG_SUSPICIOUS_INVENTORIES  = PEARL.GetConfigData("LOG_SUSPICIOUS_INVENTORIES"),
    ALLOWED_LOCALES             = PEARL.GetConfigData("ALLOWED_LOCALES"),
    STRICT_WHITELIST            = PEARL.GetConfigData("STRICT_WHITELIST"),
    INTRO_SCREEN                = PEARL.GetConfigData("INTRO_SCREEN"),
    ALLOWLIST                   = PEARL.GetConfigData("ALLOWLIST"),
    PROFANITY_FILTER            = PEARL.GetConfigData("PROFANITY_FILTER"),
    CONSOLE_COMMANDS            = PEARL.GetConfigData("CONSOLE_COMMANDS"),
    SLASH_COMMANDS              = PEARL.GetConfigData("SLASH_COMMANDS"),
    CUSTOM_LOADING_TIPS         = PEARL.GetConfigData("CUSTOM_LOADING_TIPS"),
    CUSTOM_CONTROLS             = PEARL.GetConfigData("CUSTOM_CONTROLS"),
    SHOW_PLAYER_ICONS           = PEARL.GetConfigData("SHOW_PLAYER_ICONS"),
    BAN_ALT_ACCOUNTS            = PEARL.GetConfigData("BAN_ALT_ACCOUNTS"),

    CUSTOM_PREFABS              = PEARL.GetConfigData("CUSTOM_PREFABS"),
})

----------------------------------------------------------------
-- [[ Agreement/Welcome screen configurations ]]
----------------------------------------------------------------

local ParseTxt = PEARL.loadfile("utils/txtparser")
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
--- @type table<table<string, boolean>>
PEARL.PREFABS = PEARL.loadfile("constants/prefabs")

-- Load emotes before icons
--- @type table<table<string, string>>
PEARL.EMOTES = PEARL.loadfile("constants/emotes")
--- @type table<table<string, string>|table<table<string, string>>>
PEARL.ICONS = PEARL.loadfile("constants/icons")

--------------------------------
-- [[ Scheduler ]]
--------------------------------

PEARL.info("Setting up the wall-scheduler...")

--- @type WallScheduler
PEARL.Scheduler = PEARL.loadfile("libraries/wallscheduler")
PEARL.Scheduler:StartWallUpdate()

--------------------------------
-- [[ Webhooks ]]
--------------------------------

PEARL.info("Setting up the webhooks...")


--- @type Logger
PEARL.DiscordLogger = PEARL.loadfile("libraries/discordapi/webhooks/logger")()
PEARL.DiscordLogger:SetBufferTimeout(
    PEARL.CONFIG.DISCORD.LHOOK_BUFFER_TIMEOUT
)


--- @type Reporter
PEARL.DiscordReporter = PEARL.loadfile("libraries/discordapi/webhooks/reporter")()

--------------------------------
-- [[ Extensions ]]
--------------------------------

PEARL.info("Loading game component extensions...")
PEARL.loadfile("extensions/components/inventory")
PEARL.loadfile("extensions/components/workable")
PEARL.loadfile("extensions/components/age")
PEARL.loadfile("extensions/components/inventoryitem")
PEARL.loadfile("extensions/components/container")
PEARL.loadfile("extensions/components/stackable")
PEARL.loadfile("extensions/components/edible")
PEARL.loadfile("extensions/components/activable")

PEARL.info("Loading game script extensions...")
PEARL.loadfile("extensions/scripts/entityscript")
PEARL.loadfile("extensions/scripts/playercommon")

-------------------------------------
-- [[ Blacklist/Whitelist Wrappers ]]
-------------------------------------

--- @type BlackList
PEARL.BlackList = PEARL.loadfile("libraries/wrappers/blacklist")

--- @type Whitelist
PEARL.WhiteList = PEARL.loadfile("libraries/wrappers/whitelist")
--- @deprecated Use AllowList instead.
if PEARL.CONFIG.STRICT_WHITELIST then
    PEARL.WhiteList:SetMode(PEARL.WhiteList.MODE.ALLOWLIST)
    PEARL.WhiteList:SyncReservedWithSlots()
end

--- @type AllowList
PEARL.AllowList = PEARL.loadfile("libraries/wrappers/allowlist")
if PEARL.CONFIG.ALLOWLIST and TheShard:IsMaster() then
    PEARL.warn("Allowlist is enabled! Only players on the list or admins will be able to join.")
    PEARL.AllowList:SetIsEnabled(true)
end
PEARL.AllowList:Load()

--- @type AdminList
PEARL.AdminList = PEARL.loadfile("libraries/wrappers/adminlist")
PEARL.AdminList:Load()

--------------------------------
-- [[ Modules ]]
--------------------------------

PEARL.info("Loading modules...")

--- @type ModuleManager
local ModuleManager = PEARL.loadfile("libraries/modulemanager")
ModuleManager:SetLoader(PEARL.loadfile)
ModuleManager:SetModuleDirectory("modules")

-- Master only modules
if TheShard:IsMaster() then
    ModuleManager:AddModule("versionchecker", PEARL.CONFIG.VERSION_CHECK_FREQUENCY > 0 or PEARL.CONFIG.UPDATE_SERVER_AFTER > 0)
    -- Master handles the connections
    ModuleManager:AddModule("localizer", PEARL.CONFIG.LOCALIZER)
    ModuleManager:AddModule("altdentifier", PEARL.CONFIG.BAN_ALT_ACCOUNTS)
end

ModuleManager:AddModule("globalplayericons", PEARL.CONFIG.SHOW_PLAYER_ICONS)
ModuleManager:AddModule("profanityfilter", PEARL.CONFIG.PROFANITY_FILTER)
-- This should not be called in backend I guess
--ModuleManager:AddModule("commandblocker", not IsTableEmpty(PEARL.CONFIG.COMMAND_BLOCKLIST or {}))
ModuleManager:AddModule("consolecommands", PEARL.CONFIG.CONSOLE_COMMANDS)
ModuleManager:AddModule("slashcommands", PEARL.CONFIG.SLASH_COMMANDS)

-- Logger Modules
ModuleManager:AddModule("logger/world", true)
ModuleManager:AddModule("logger/player", true)

-- Discord report channel logs only
if PEARL.DiscordReporter:IsEnabled() then
    ModuleManager:AddModule("logger/inventory", true)
end

-- Discord only loggers
if PEARL.DiscordLogger:IsEnabled() then
    ModuleManager:AddModule("logger/chat", true)
    ModuleManager:AddModule("logger/server", true)
end

ModuleManager:LoadAllModules()

--------------------------------
-- [[ Anti-Grief ]]
--------------------------------

-- PEARL.info("Loading other components...")
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
PEARL.RestClient = PEARL.loadfile("libraries/restclient")()
    :SetRequestFrequency(PEARL.CONFIG.REQUEST_FREQUENCY)

--- @type RestAPI
PEARL.DiscordRestAPI = PEARL.loadfile("libraries/discordapi/restapi")()

PEARL.info("Loading server network...")

--- @type ServerNetwork
PEARL.ServerNetwork = PEARL.loadfile("servernetwork")

--------------------------------
-- [[ Error Handler ]]
--------------------------------

if PEARL.DiscordReporter:IsEnabled() then
    -- This should be loaded after the webhooks are set up.
    PEARL.info("Loading mod error handler...")
    PEARL.loadfile("error")
end

--------------------------------
-- [[ Discord logs ]]
--------------------------------

if PEARL.CONFIG.DISCORD.LHOOK.ENABLED
    and (PEARL.CONFIG.DISCORD.LHOOK_TOKEN == "" or PEARL.CONFIG.DISCORD.LHOOK_ID == "")
then
    PEARL.warn("Logging to discord is enabled, however, not all required webhook indetifiers were specified.")

    PEARL.CONFIG.DISCORD.LHOOK.ENABLED = false
end

if not PEARL.CONFIG.DISCORD.LHOOK.ENABLED then
    PEARL.info("Sending system logs to discord is disabled.")

    PEARL.DiscordLogger:SetIsDisabled(true)
    PEARL.DiscordRestAPI:SetIsDisabled(true)
end

--------------------------------
-- [[ Debug Mode ]]
--------------------------------

if PEARL.CONFIG.DEBUG_MODE then
    PEARL.warn("Debug mode enabled! This is not recommended for production use.")
    PEARL.loadfile("debugtools")

    -- PEARL.CreateWordFilterFile = PEARL.loadfile("utils/wordloader")

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

    PEARL.GenerateConfigFile = require("utils/configfilegenerator")

    PEARL.DataDumper = require("utils/datadumper")
end

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
