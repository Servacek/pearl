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
    NOTES:
    - APP_ARCHITECTURE determines whether we are using
        64bit or 32bit version. Possible stored values are:
        "x64" and "x32"

    - GLOBAL is a table for accessing the globals from the outer world, since
      our environment is separated from the main one to prevent any naming conflicts.

    - For bitwise operations in LUA 5.1 see the 'bit' table.
        Avaible functions:
            - rshift
            - lshift
            - bor
            - band
            - bnot
            - bxor

    - Via TheSim:GetMOTDQueryURL we can fetch the actual locale of the user.

    - Be carefull with declaring some of DST specific globals as locals on the
      start of a file, because some of them may not be loaded yet and refer to nil.

    - Always pass discord ids as string since the newer ones do not fit in 64 bits

    - pcall will return false if there was thrown an error before.

    - Using TheSim:GetPersistentString("../customcommands.lua", ...) it is technically
      possible to get the content of whitelist.txt and other files in the cluster.

    - Setting client_mods_disabled to false in modoverrides.lua will temp disable
      all mods for a connecting client.

    - The 'global(...)' function declares a global variable(s).

    - Always use 'rawget' when attempting to check whether a field is
      declared in the main global env since it's metatable is being
      modified in strict.lua.

    - With 'GetEnabledModsModInfoDetails' we can control what mods are being
      displayed to the users. It is being called from C++ side via TheNet:StartServer.

    - Probably modimport should be used over the basic require since some of the module
      names can conflict with the built-in ones.

    - 'require' doesn't support mod specific pathes.

    - Master shard is always restarted the first

    - Try to not push in-game events.

    - Use raw tables for singleton non-inherited classes.

    - For singletons use locals as private variables and functions without the '_' prefix.

    - Do not use raw RPCs! Use the built-in mod API. They are being registered
      after TheFrontEnd.

    - inst.persists does modify the saving behavior for an entity.

    - Do not use "return PEARL.log(...)" because that counts as a new scope.

    - CWD - Current Working Directory (global C defined constant)

    - TheNet:Disconnect() is REALLY unstable!

    - Built-in utf8 library:
        string.utf8char = utf8char -- decode a codepoint
        string.utf8sub = utf8substr -- "byte-aware" string.sub
        string.utf8len = utf8strlen -- "byte-awate" string.len
        string.utf8upper = utf8strtoupper
        string.utf8lower = utf8strtolower

    - table.sort({"string", 1}) -> attempt to compare number with string
--]]

--- @TODO: Implement a way to modify the configuration files by using a command.

GLOBAL.assert(GLOBAL.rawget(GLOBAL, "PEARL") == nil, "Multiple instances of the PEARL mod loaded!")

local GLOBAL = GLOBAL
local setmetatable, rawget = GLOBAL.setmetatable, GLOBAL.rawget

--------------------------------
-- [[ Local Constants ]]
--------------------------------

local ENV = GLOBAL.getfenv()
local MT = {
    -- Called when lua is not able to find the field in our environment table.
    -- This allows implicit access to fields of the GLOBAL table.
    -- This is beign called... a lot.
    __index = function(env, index)
        return rawget(GLOBAL, index)
    end,
}

--------------------------------
-- [[ Local Functions ]]
--------------------------------

-- Setup the enviroment so we do not have to type GLOBAL
-- everytime we access something from that table.
--- @return table
local function setupenv()
    -- Modify the metatable of the current safe separated mod environment.
    return setmetatable(ENV, MT)
end

--------------------------------
-- [[ Setup ]]
--------------------------------

setupenv()

-- This is where we store basically all mod specific functions and variables
-- so it doesn't conflict with any ingame or other mod stuff.
--
-- Add this table to the main environment so it's accessible everywhere.
GLOBAL.PEARL = setmetatable({
    -- expose these to all the components

    SRCDIR              = MODROOT.."scripts/",
    DATADIR             = MODROOT.."data/",

    BANNER_PATH         = "banner.txt",
    COMMONCONFIG_PATH   = "../../commonconfig.lua",

    -- Used for accessing environment specific functions outside modmain.lua
    ENV                 = ENV,
    ENV_MT              = MT,
    MODNAME             = modname,
    MODID               = GetWorkshopIdNumber(modname),
    MOD_INFO            = KnownModIndex:GetModInfo(modname),
    RPC_NAME            = modname.."_rpc",

    GetConfigData       = function(opt_name, no_supp, ...)
        local data = ENV.GetModConfigData(opt_name, ...)
        if type(data) ~= "table" or no_supp then
            return data
        end

        -- Make sure the newly returned option will inherit everything from the defaults.
        local function supplement(default, actual)
            for name, value in pairs(default) do
                if actual[name] == nil and actual[name] ~= value then
                    actual[name] = value
                elseif type(default[name]) == "table" then
                    if type(actual[name]) ~= "table" then
                        actual[name] = {}
                    end

                    supplement(default[name], actual[name])
                end
            end
        end

        for _, option in ipairs(PEARL.MOD_INFO.configuration_options) do
            if option.name == opt_name then
                if type(option.default) == "table" then
                    supplement(option.default, data)
                end

                break
            end
        end

        return data
    end,

    SOURCE_DIR_NAME     = "scripts",
    DATA_DIR_NAME       = "data",
    LANG_DIR_NAME       = "languages",
    MODULES_DIR_NAME    = "modules",
    FILTERS_DIR_NAME    = "filters",
    IMAGES_DIR_NAME     = "images",
    LIBRARY_DIR_NAME    = "libraries",

    DEFAULT_LANGUAGE    = "english",
    LANGUAGES = {
        SK = "slovak",
        EN = "english",
    },

    INSTANCE_PARAMS     = {
        PERMISSIVE_MODE = "CONFIG.PERMISSIVE_MODE",
    },

    FRONTEND            = TheNet:GetIsClient(),

    -- Whether this is the initial launch of the mod or not.
    -- We only care about this on dedicated servers.
    INIT                = TheSim:GetNumLaunches() == 1, -- i.e. First launch of the game.
    INIT_FULL           = TheSim:GetNumLaunches() == 2,
    LAUNCHES            = TheSim:GetNumLaunches(),

    PREFAB              = "MOD_"..modname,
    FONTS_PREFAB        = "MODFONTS_"..modname,

    BACKUP_ID           = "2924921999",

    --- @type string?
    SHARDID             = TheNet:IsDedicated() and tostring(TheShard:GetShardId()) or nil,

    -- Used for sending internal mod events.
    --- @type EventProcessor
    EventProcessor   = EventProcessor(),
}, {
    __index = function(tbl, name)
        return rawget(PEARL.ENV, name)
    end
})

PEARL = GLOBAL.PEARL
PEARL.CONFIG = {}

PEARL.LUATYPES = {
    STRING      = "string",
    FUNCTION    = "function",
    NUMBER      = "number",
    USERDATA    = "userdata",
    TABLE       = "table",
    BOOLEAN     = "boolean",
    NIL         = "nil",
}

local id = GetWorkshopIdNumber(PEARL.MODNAME)
PEARL.WORKSHOP_ID   = tonumber(id) ~= nil and tostring(id) or nil
PEARL.IS_WORKSHOP   = PEARL.WORKSHOP_ID ~= nil
PEARL.IS_BACKUP     = (PEARL.BACKUP_ID ~= nil and (PEARL.WORKSHOP_ID == PEARL.BACKUP_ID)) or false
PEARL.IN_UGC_FOLDER = PEARL.IS_WORKSHOP == true

PEARL.VERSION       = PEARL.MOD_INFO.version
PEARL.LUA_VERSION   = _VERSION

PEARL.X32 = APP_ARCHITECTURE == "x32"
PEARL.X64 = APP_ARCHITECTURE == "x64"

--- ../mods/MODNAME/
MODROOT = MODROOT

--------------------------------
-- [[ Server Mod Config ]]
--------------------------------

--- Run this as soon as possible so in case of any error
--- @class ModConfig
PEARL.ModConfig = require("modconfig")

if type(PEARL.ModConfig) ~= "table" then
    return error("Failed to load mod configurations!")
end

if TheNet:GetIsServer() and not TheNet:IsDedicated() or TheNet:IsDedicatedOfflineCluster() then
    -- Make sure we do not leak any internal configurations
    return error("Current version of "..PEARL.MOD_INFO.name.." does only support online dedicated servers.")
end

--------------------------------
-- [[ Banner ]]
--------------------------------

local bf = io.open(MODROOT..""..PEARL.BANNER_PATH, "r")
if bf then
    print("\n"..bf:read("*a"))
end

--------------------------------
-- [[ Configuration Overrides ]]
--------------------------------

PEARL.DEFAULT_CONFIG = {}

local function load_default_config()
    for _, option in ipairs(PEARL.MOD_INFO.configuration_options) do
        if option.name ~= nil and option.default ~= nil then
            PEARL.DEFAULT_CONFIG[option.name] = option.default

            -- Make sure we always have at least the defaults.
            PEARL.CONFIG[option.name] = deepcopy(option.default)
        end
    end
end

load_default_config()

--------------------------------
-- [[ Configuration Overrides ]]
--------------------------------

PEARL.CONFIG_OVERRIDES = {}

local function load_config_overrides()
    for _, option in ipairs(PEARL.MOD_INFO.configuration_options) do
        if option.name ~= nil then
            if option.saved ~= nil then
                PEARL.CONFIG_OVERRIDES[option.name] = option.saved
            end

            -- For frontend we preload the data, but they will be overriden afterwards.
            if option.general == true or (option.public == true and TheNet:GetIsClient()) then
                PEARL.CONFIG[option.name] = PEARL.GetConfigData(option.name)
            end
        end
    end
end

load_config_overrides()

--------------------------------
-- [[ FileLoader ]]
--------------------------------

local loaders = require("libraries/loaders/fileloaders")

--- Check the validity of the loaders
for name, loader in pairs(loaders) do
    if type(loader) ~= "function" then
        return error("Failed to load "..name.."! "..tostring(PEARL.loader))
    end

    if PEARL[name] ~= nil and PEARL.CONFIG.DEBUG_MODE then
        error("Loader "..name.." already exists in the namespace table?!")
    end
end

--- Adding it manually here instead of the loop for autocomplete to be smarter.
PEARL.loadfilefn    = loaders.loadfilefn
PEARL.loadfile      = loaders.loadfile
PEARL.loadlib       = loaders.loadlib

--------------------------------
-- [[ Standard Libs ]]
--------------------------------

PEARL.loadfile("extensions/standard/basic")
PEARL.loadfile("extensions/standard/table")
PEARL.loadfile("extensions/standard/math")
PEARL.loadfile("extensions/standard/io")
PEARL.loadfile("extensions/standard/string")
PEARL.loadfile("extensions/standard/os")
PEARL.loadfile("extensions/standard/debug")

PEARL.loadfile("extensions/json")

--------------------------------
-- [[ Persistance Libs ]]
--------------------------------

--- This has to load this soon because some of the following files use it.
--- @class ClusterPersistance
PEARL.ClusterPersistance = PEARL.loadlib("wrappers/persistance/clusterio")

--- @class ModPersistance
PEARL.ModPersistance = PEARL.loadlib("wrappers/persistance/modio")

--------------------------------
-- [[ Common Config ]]
--------------------------------

-- This has to be loaded before we start to use the configurations.
-- Also it requires ClusterPersistance
if PEARL.CONFIG.COMMON_MOD_CONFIG and TheNet:IsDedicated() then
    local configs = PEARL.ModConfig:LoadCommmonConfig()
    if type(configs) == "table" then
        PEARL.ModConfig:ApplyConfigs(configs)
    end
end

--------------------------------
-- [[ General Mod Constants]]
--------------------------------

PEARL.ASSETS = {}

PEARL.CONSTS = {
    EVENT_PREFIX = "__"..string.lower(PEARL.MODNAME).."__",

    -- If encoded then there is an 'D' at the end.
    -- For non-encoded data there is a space between
    -- the prefix and the actual content
    KLEI_DATA_PREFIX            = "KLEI     1",
    KLEI_ENCODED_DATA_PREFIX    = "KLEI     1D",

    -- We want to match also the controller icons
    UTF_EMOJI_PATTERN = "[\243\238\239][\128-\191][\128-\191][\128-\191]?",
    DISCORD_EMOJI_PATTERN = "<a?:%S+:%d+>",
    DISCORD_EMOJI_ID_PATTERN = "<a?:%S+:(%d+)>",
    HYBRID_EMOJI_PATTERN = ":%S+:",
    UNICODE_EMOJI_PATTERN = "[\240][\159][\128-\191][\128-\191]", -- Used by discord for default emojis.

    DELIMS = {
        SLASH_COMMAND         = "/",
        EMOJI                 = ":",
        KLEI_ID               = "KU_",
        PLAYER_NAME           = "@",
        CONSOLE_COMMAND       = "c_",
        DEBUG_COMMAND         = "d_",
    },

    -- The name should match with the file name in the profile flair .xml file.
    PROFILE_FLAIRS = {
        DISCORD = "discord",
    },

    FPS = 60,

    LT_TYPES = {
        SURVIVAL    = "SURVIVAL",
        LORE        = "LORE",
        CONTROLS    = "CONTROLS",
        CONSOLE     = "CONSOLE",
        NOCONSOLE   = "NOCONSOLE",
        OTHER       = "OTHER",

        --- Custom
        WELCOME     = "WELCOME",
    },
}

local FOLDERS = PEARL.CONFIG.SERVER_FOLDERS
if TheNet:IsDedicated() then
    PEARL.UGC_MODS_FOLDER = "../"..FOLDERS.UGC_MODS_ROOT.."/"..FOLDERS.CLUSTER.."/"..FOLDERS.SHARD.."/content/"..tostring(DONT_STARVE_TOGETHER_APPID).."/"..tostring(PEARL.MODID)
else
    PEARL.UGC_MODS_FOLDER = "../../../workshop/content/"..tostring(DONT_STARVE_TOGETHER_APPID).."/"..tostring(PEARL.MODID)
end

--- No need for any type of such conversion since this is already done by the IO handlers.
-- if PEARL.IS_WORKSHOP then
--     MODROOT = PEARL.UGC_MODS_FOLDER
-- end

--------------------------------
-- [[ Logging ]]
--------------------------------

--- Even logging uses configurations!
PEARL.loadfile("extensions/logging")

----------------------------------
-- [[ Static Scheduler ]]
----------------------------------

-- In frontend, use staticScheduler for background tasks
-- In backend, staticScheduler doesn't work so wallScheduler is what should be used.
PEARL.info("Loading static scheduler...")
--- @type Scheduler
PEARL.StaticScheduler = staticScheduler

--------------------------------
-- [[ Helpers ]]
--------------------------------

PEARL.info("Loading helper functions...")
PEARL.loadfile("utils/helpers")

--------------------------------
-- [[ Mod API ]]
--------------------------------

PEARL.info("Loading custom mod application programming interface...")
PEARL.loadfile("extensions/api")

--------------------------------
-- [[ Global Extensions ]]
--------------------------------
-- Load after API.

PEARL.loadfile("extensions/eventprocessor")

--------------------------------
-- [[ License ]]
--------------------------------

-- Load licences only on servers
if TheNet:GetIsServer() then
    --- We are working with files here so load after the io extension
    PEARL.info("Loading licence...")
    PEARL.loadfile("licence")
end

--------------------------------
-- [[ RPCs ]]
--------------------------------

PEARL.info("Loading RPC handlers...")
PEARL.loadfile("networkrpc")

--------------------------------
-- [[ Custom Error Handler ]]
--------------------------------

-- Requires the RPCs for correct functionality
PEARL.info("Loading mod error handler...")
PEARL.loadfile("error")

--------------------------------
-- [[ Strings & Translations ]]
--------------------------------

PEARL.info("Loading strings...")
-- Store this in the Global string table so we can apply translations more easily.
STRINGS.PEARL = PEARL.loadfile("constants/strings")

local function LoadTranslations(path)
    local ORIGINAL_STRINGS = STRINGS
    PEARL.info("Loading translations...")
    LoadPOFile(path, PEARL.CONFIG.LANGUAGE)

    if PEARL.CONFIG.DEBUG_MODE and TheNet:IsDedicated() then
        local TRANSLATED_STRINGS = LanguageTranslator.languages[PEARL.CONFIG.LANGUAGE]
        PEARL.loadfile("languages/createstringspo")(path, ORIGINAL_STRINGS, TRANSLATED_STRINGS)
    end

    -- Since this mod is loaded first we only load our own translations for now so the strings can be cached.
    TranslateStringTable(ORIGINAL_STRINGS)
end

-- With this implementation we are not limited to a hard coded set of languages
-- but we are able to add our own languages without changing the code instead.
-- Load translations only after strings.lua else they will be overriden.
do
    local path = PEARL.SRCDIR.."languages/"..tostring(PEARL.CONFIG.LANGUAGE)..".po"
    if io.exists(path) then
        LoadTranslations(path)
    elseif PEARL.CONFIG.LANGUAGE ~= PEARL.DEFAULT_LANGUAGE then
        PEARL.error("Language", PEARL.CONFIG.LANGUAGE, "not supported!")
    end
end

--------------------------------
-- [[ Custom Translations ]]
--------------------------------
--- @TODO: Potential conflict with languageserver module

PEARL.AddGlobalFunctionPostCall("TranslateStringTable", function()
    for path, translation in pairs(PEARL.CONFIG.CUSTOM_TRANSLATIONS) do
        table.pathset(GLOBAL, path, translation)
    end
end)

--------------------------------
-- [[ Load ]]
--------------------------------

-- Load emotes before icons
--- @readonly
--- @type EMOJIS table<table<string, string>>
PEARL.EMOJIS = PEARL.loadfile("constants/emotes")

if not PEARL.INIT then

PEARL.RegisterDefaultAnnouncementTypes()

PEARL.AddAnnouncementIcon("ignite", "torch.tex")
PEARL.AddAnnouncementIcon("burn", "fire.tex")
PEARL.AddAnnouncementIcon("take", "backpack.tex")
PEARL.AddAnnouncementIcon("swallow", "faketheeth.tex")
PEARL.AddAnnouncementIcon("hammer", "hammer.tex")
PEARL.AddAnnouncementIcon("kill", "hambat.tex") -- For regular mobs
PEARL.AddAnnouncementIcon("murder", "hambat.tex") -- For loyal mobs
PEARL.AddAnnouncementIcon("defeat", "trophy.tex")
PEARL.AddAnnouncementIcon("deploy", "eyeplant.tex")

--- @TODO: add custom icon for these...
PEARL.AddAnnouncementIcon("activate")
PEARL.AddAnnouncementIcon("teach")
PEARL.AddAnnouncementIcon("read")
PEARL.AddAnnouncementIcon("welcome")
PEARL.AddAnnouncementIcon("extinct")

--- These do not log in-game
PEARL.AddAnnouncementIcon("extinguish")
PEARL.AddAnnouncementIcon("build")
PEARL.AddAnnouncementIcon("craft")
PEARL.AddAnnouncementIcon("plant")
PEARL.AddAnnouncementIcon("give")
PEARL.AddAnnouncementIcon("sleep")
PEARL.AddAnnouncementIcon("cook")
PEARL.AddAnnouncementIcon("eat")
PEARL.AddAnnouncementIcon("propagator")
PEARL.AddAnnouncementIcon("play")
PEARL.AddAnnouncementIcon("chop")
PEARL.AddAnnouncementIcon("fertilize")
PEARL.AddAnnouncementIcon("waste")
PEARL.AddAnnouncementIcon("heal")
PEARL.AddAnnouncementIcon("sew")
PEARL.AddAnnouncementIcon("mine")

end

--------------------------------
-- [[ Global Mod Instance ]]
--------------------------------

PEARL.INST = CreateEntity("MOD_"..tostring(PEARL.MODID).."_GLOBAL_INSTANCE")
PEARL.INST.entity:AddTransform()
PEARL.INST.entity:SetCanSleep(false)
PEARL.INST.persists = false
PEARL.INST:AddTag("CLASSIFIED")

--------------------------------
-- [[ Instance Param Manager ]]
--------------------------------

PEARL.info("Loading game instance parameters manager...")
--- @class GameInstParams
PEARL.GameInstParams = PEARL.loadfile("instanceparams")

--------------------------------
-- [[ Debug Mode ]]
--------------------------------

-- Load the debug mode early so in case of errors we have Ctrl+R.
if PEARL.CONFIG.DEBUG_MODE then
    PEARL.info("Setting up debug mode!")

    --KnownModIndex.modsettings.initdebugprint = true
    -- Do not override this because it attempts to load some
    -- test files that are not provided.
    --PEARL.OverrideGlobal("CONFIGURATION", "dev")

    if TheNet:GetIsServerAdmin() then
        -- Fix for not saving the modindex state properly when in dev mode.
        local original_filename = "boot_"..KnownModIndex:GetModIndexName()
        PEARL.AddClassFunctionPreCall("EndStartupSequence", function(self, ...)
            SavePersistentString(original_filename, "done", false, ...)
        end, KnownModIndex)

        PEARL.OverrideVariable("ENCODE_SAVES", false)
        PEARL.OverrideVariable("BRANCH", "dev")
        PEARL.OverrideVariable("CHEATS_ENABLED", true)
        PEARL.OverrideVariable("VERBOSITY_LEVEL", VERBOSITY.DEBUG)

        --- @NOTE: DoReload doesn't really affect these...
        --- Maybe this would require some further investigation
        local modmain_fp = MODROOT.."modmain.lua"
        local modmain_ft = TheSim:GetFileModificationTime(modmain_fp)
        local worldgenmain_fp = MODROOT.."modworldgenmain.lua"
        local worldgenmain_tp = TheSim:GetFileModificationTime(modmain_fp)
        RequiredFilesForReload[modmain_fp] = modmain_ft
        RequiredFilesForReload[worldgenmain_fp] = worldgenmain_tp

        PEARL.loadfile("debugtools")
    end

    --- A bit spammy
    --PEARL.OverrideVariable("PRINT_SOURCE", true)
end

--------------------------------
-- [[ Post-Initialization ]]
--------------------------------

-- Let's give Frontend access to the HTTP Client as well!
if not PEARL.INIT then
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

    PEARL.info("Loading HTTP client...")

    --- Even the client needs to use some requests from time to time
    --- @type HTTPClient
    PEARL.HTTPClient = PEARL.loadfile("libraries/http/httpclient")
end

--------------------------------
-- [[ Backend ]]
--------------------------------

--- TheNet:GetIsClient return's false when we disconnect.
--- Looks like TheNet:IsDedicated works even without the network!
if TheNet:IsDedicated() and not TheNet:GetIsClient() then
    PEARL.info("Loading mod BE...")
    PEARL.loadfile("backend")
    PEARL.info("Loading mod BE done.")
end

--------------------------------
-- [[ Frontend ]]
--------------------------------

-- In debug mode we want to load sometimes the frontend on servers as well to see if there is
-- any error.
if TheNet:GetIsClient() then --or PEARL.CONFIG.DEBUG_MODE then
    PEARL.info("Loading mod FE...")
    PEARL.loadfile("frontend")
    PEARL.info("Loading mod FE done.")
end

--------------------------------
-- [[ Commmon Modules ]]
--------------------------------
-- Modules loaded on both, Fronted and Backend.

-- local ModuleManager = PEARL.loadfile("libraries/loaders/modulemanager")
-- ModuleManager:SetLoader(PEARL.loadfile)

--------------------------------
-- [[ Custom Lua ]]
--------------------------------

RunInEnvironmentSafe(PEARL.CONFIG.CUSTOM_LUA, PEARL.ENV)

--------------------------------
-- [[ Mod Post-Init ]]
--------------------------------

PEARL.info("Mod loaded successfully on version:", PEARL.MOD_INFO.version,
    PEARL.IS_BACKUP == true and "[Backup]" or ""
)
