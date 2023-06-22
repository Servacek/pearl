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

    SHARD_ID = {
        MASTER = 1,
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

--- Push mod config warnings only for the server owner to see.
local function LoadConfigOption(option)
    if PEARL.CONFIG[option.name] then
        return PEARL.warn("Config option", option.name, "already loaded!")
    end

    local failed = false
    if option.saved ~= nil then
        if option.master_only and TheShard:IsSecondary() then
            PEARL.warn("Option", option.name, "is only available for the master shard!")
            failed = true
        end

        if option.caves_only and TheShard:IsMaster() then
            PEARL.warn("Option", option.name, "is only available for the secondary shard!")
            failed = true
        end

        if type(option.type) == "string" and option.type:match(type(option.saved)) == nil then
            PEARL.warn("Option", option.name, "has incorrect type!")
            failed = true
        end
    end

    -- If it's a required option then check if we have configured it.
    if option.warn == true and option.saved == nil then
        PEARL.warn("Option", option.name, "is not configured! Some functionality may not work.")
    end

    if option.experimental == true and (
        option.saved == true or
        (type(option.saved) == "table" and option.saved.ENABLED == true)
    ) then
        PEARL.warn("Experimental feature", option.name, "is enabled!")
    end

    -- Set this even for implicit configurations
    -- since they will override it later.
    PEARL.CONFIG[option.name] = failed and option.default or PEARL.GetConfigData(option.name)

    -- if type(option.checks) == "table" and not IsTableEmpty(option.checks) then
    --     local failed = RunOptionChecksRecursively(option)
    --     if not IsTableEmpty(failed) then
    --         PEARL.warn(
    --             "Module", option.name, "is enabled. However, these parameters are required by it but not provided:", table.concat(failed, ", ")
    --         )
    --         PEARL.warn("In order for the module to function correctly, please add them to modoverrides.lua")
    --     end
    -- end
end

--- @TODOv2.1 Put this to servermodconfig.lua

--- Load backend specific configuration options.
for _, option in ipairs(PEARL.MOD_INFO.configuration_options) do
    if not option.general then
        LoadConfigOption(option)
    end
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

    PEARL.CONFIG.MOD_BLOCKLIST = PEARL.GetAllPersistentStringLines("../../modblacklist.txt", true, true)
    PEARL.CONFIG.MOD_ALLOWLIST = PEARL.GetAllPersistentStringLines("../../modallowlist.txt", true, true)

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

PEARL.OverrideValue(_G, "METRICS_ENABLED", PEARL.CONFIG.SEND_KLEI_METRICS)

--------------------------------
-- [[ Constants and Utilities ]]
--------------------------------

-- No need to load any further on the initial launch.
if PEARL.INIT then
    return
end

PEARL.info("Loading constants...")
--- @type table<table<string, boolean>>
PEARL.PREFABS = PEARL.loadfile("constants/prefabs")

-- Load emotes before icons
--- @type table<table<string, string>>
PEARL.EMOTES = PEARL.loadfile("constants/emotes")
--- @type table<table<string, string>|table<table<string, string>>>
PEARL.ICONS = PEARL.loadfile("constants/icons")

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

--- @type RestClient
PEARL.RestClient = PEARL.loadfile("libraries/restclient")()
    :SetRequestFrequency(PEARL.CONFIG.REQUEST_FREQUENCY)

--- @type RestAPI
PEARL.DiscordRestAPI = PEARL.loadfile("libraries/discordapi/restapi")()

PEARL.info("Loading server network...")

--- @type ServerNetwork
PEARL.ServerNetwork = PEARL.loadfile("servernetwork")

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

--------------------------------
-- [[ Extensions ]]
--------------------------------

local function LoadExtensions()
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
-- [[ Player Database ]]
-------------------------------------

PEARL.info("Loading player database...")

--- @TODO: Add some configsx here
PEARL.PlayerDB = PEARL.loadfile("libraries/playerdatabase")
if PEARL.CONFIG.DATABASE.ENABLED then
    if PEARL.PlayerDB:Load() then
        PEARL.info("Database loaded!")
    else
        PEARL.error("Failed to load player database! Please disable it in the mod settings until the issue is resolved.")
    end
end

--------------------------------
-- [[ Debug Mode ]]
--------------------------------

if PEARL.CONFIG.DEBUG_MODE then
    PEARL.warn("Debug mode enabled! This is not recommended for production use.")
    PEARL.loadfile("debugtools")
    PEARL.loadfile("testing")

    -- PEARL.CreateWordFilterFile = PEARL.loadfile("utils/wordloader")
    -- PEARL.CreateWordFilterFile("czech.txt", "czech.lua")

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
ModuleManager:AddModule("inventoryreporter", PEARL.CONFIG.REPORT_INVENTORIES)
ModuleManager:AddModule("globalplayericons", PEARL.CONFIG.SHOW_PLAYER_ICONS)
ModuleManager:AddModule("profanityfilter", PEARL.CONFIG.PROFANITY_FILTERS.enabled)
ModuleManager:AddModule("consolecommands", PEARL.CONFIG.CONSOLE_COMMANDS)
ModuleManager:AddModule("slashcommands", PEARL.CONFIG.SLASH_COMMANDS)
ModuleManager:AddModule("selfstacker", PEARL.CONFIG.SELF_STACKER.ENABLED)
ModuleManager:AddModule("lazyloading", PEARL.CONFIG.LAZY_LOAD_PREFABS)
ModuleManager:AddModule("healthinfo", PEARL.CONFIG.HEALTH_INFO.ENABLED)
ModuleManager:AddModule("characterblocker", not table.empty(PEARL.CONFIG.CHARACTER_BLOCKLIST))
ModuleManager:AddModule("playertracker", PEARL.CONFIG.DATABASE.ENABLED)
ModuleManager:AddModule("versionchecker", PEARL.CONFIG.VERSION_CHECKER.ENABLED)

-- Logger Modules
ModuleManager:AddModule("logger/world", true)
ModuleManager:AddModule("logger/player", true)

-- Discord only loggers
if PEARL.DiscordLogger:IsEnabled() then
    ModuleManager:AddModule("logger/chat", true)
    ModuleManager:AddModule("logger/server", true)
end

ModuleManager:LoadAllModules()

--------------------------------
-- [[ Anti-Grief ]]
--------------------------------

--- @TODOv2.1
-- if PEARL.CONFIG.GRIEF_PROTECTION then
--     PEARL.info("Enabling griefer protection...")
--     modimport(PEARL.SOURCE_DIR_NAME.."/actions")
--     modimport(PEARL.SOURCE_DIR_NAME.."/protector")
--     modimport(PEARL.SOURCE_DIR_NAME.."/penalizer")
-- end

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
