--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



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

    - TheSim:QueueDownloadTempMod(<MODNAME>, <MODVERSION>) is client only
    - TheNet:LoadPermissionLists() loads adminlist.txt, blocklist.txt and adminlist.txt

    - Theoretically, worldsaves can be loaded with something like:
        TheNet:DeleteSession(TheNet:GetSessionIdentifier())
        TheNet:CleanupSessionCache()
        TheNet:BeginSession("{sessionid}")
        TheWorld.meta.session_identifier = "{sessionid}"
        - But in reality, these functions have a lot of undefined behaviour (none is actually defined anywhere)
          and work really unintuitivelly.

    - Do not try to implement any dynamic .tex image downloading from server system, trust me.

    - gcinfo() = math.floor(collectgarbage("count"))
    - json_settings - Similiar to Settings be they are defined in the engine.

    - Built-in utf8 library:
        string.utf8char = utf8char -- decode a codepoint
        string.utf8sub = utf8substr -- "byte-aware" string.sub
        string.utf8len = utf8strlen -- "byte-awate" string.len
        string.utf8upper = utf8strtoupper
        string.utf8lower = utf8strtolower

    - table.sort({"string", 1}) -> attempt to compare number with string

    - module and package.seeall are deprecated methods of implementing
      the modern require behaviour. In original Lua 5.1 require didn't
      return the results of the file so you would have to call:
        module("MODULENAME")
      at the top of the file in order to create an separate environment.
      The old require("MODULENAME") function would then basically just extend the environment
      it is called in with the module specific functions. The only example
      of the game using this is the "json.lua" file. That's why it seems to appear
      as a weird global out of nowhere.

      The package.seeall was used in combination with the module function
      to enable the environment to use the actual global environment. It basically
      just sets a metatable with the __index function pointing to the global environment.

    - package.loadlib "dynamic libraries not enabled: check your Lua installation"
        - how unexpected...

    - package.cpath = ""
--]]

--- @TODO: perhaps TheSim:GetModDirectoryNames() could be used to detect local mods?

--- @TODO: Implement a way to modify the configuration files by using a command.

GLOBAL.assert(GLOBAL.rawget(GLOBAL, "PEARL") == nil, "Multiple instances of the "..modname.." mod loaded!")

local GLOBAL = GLOBAL
local setmetatable, rawget = GLOBAL.setmetatable, GLOBAL.rawget

--------------------------------
-- [[ Dependencies ]]
--------------------------------

require("events")
require("modindex")
require("mainfunctions")

--------------------------------
-- [[ Local Constants ]]
--------------------------------

local WORLDGEN_THREAD = WORLDGEN_MAIN == 1
local MAIN_THREAD = not WORLDGEN_THREAD

local ENV = GLOBAL.getfenv()
local MT = {
    -- Called when lua is not able to find the field in our environment table.
    -- This allows implicit access to fields of the GLOBAL table.
    -- This is beign called... a lot.
    __index = function(env, index)
        --- We have to use "rawget" in order to bypass strict.lua
        return rawget(GLOBAL, index)
    end,
}

--------------------------------
-- [[ Setup ]]
--------------------------------

-- Setup the enviroment so we do not have to type GLOBAL
-- everytime we access something from that table.
-- Modify the metatable of the current safe separated mod environment.
setmetatable(ENV, MT)

-- This is where we store basically all mod specific functions and variables
-- so it doesn't conflict with any ingame or other mod stuff.
--
-- Add this table to the main environment so it's accessible everywhere.
GLOBAL.PEARL = setmetatable({
    -- We use this instead of calling "GetConfigData" everytime
    -- because of our complicated custom configuration structure and also
    -- because there are some custom config files as well (commonconfig.lua) and some configurations (implicit)
    -- are loaded directly from the code at runtime.
    CONFIG = {},

    SRCDIR              = MODROOT.."scripts/",
    DATADIR             = MODROOT.."data/",

    BANNER_PATH         = "banner.txt",
    COMMONCONFIG_PATH   = "../../commonconfig.lua",
    MOUNTABLE_SCRIPTS_PATH = "../../mountable.lua",

    -- Used for accessing environment specific functions outside modmain.lua
    ENV                 = ENV,
    ENV_MT              = MT,
    MODID               = GetWorkshopIdNumber(modname),
    MODINFO             = KnownModIndex:GetModInfo(modname),
    MODNAME             = modname,
    MODFANCYNAME        = GetModFancyName(modname),
    MOD_DATA            = KnownModIndex.savedata.known_mods[modname],
    RPC_NAME            = modname.."_rpc",
    WORLDGEN_THREAD     = WORLDGEN_THREAD,
    MAIN_THREAD         = MAIN_THREAD,

    LOADING_STATE       = LoadingStates.None,

    BOOT_TIME           = os.time() - ((GetTimeRealSeconds and GetTimeRealSeconds() or 0) + 1),

    SOURCE_DIR_NAME     = "scripts",
    DATA_DIR_NAME       = "data",
    LANG_DIR_NAME       = "languages",
    MODULES_DIR_NAME    = "modules",
    FILTERS_DIR_NAME    = "filters",
    IMAGES_DIR_NAME     = "images",
    LIBRARY_DIR_NAME    = "libs",

    DEFAULT_LANGUAGE    = "english",
    LANGUAGES = {
        SK = "slovak",
        EN = "english",
    },

    INSTANCE_PARAMS     = {
        PERMISSIVE_MODE = "CONFIG.PERMISSIVE_MODE",
    },

    --- There are eight basic types in Lua: nil, boolean, number, string, userdata, function, thread, and table.
    --- The type function gives the type name of a given value:
    LUATYPES = {
        STRING      = "string",
        FUNCTION    = "function",
        NUMBER      = "number",
        USERDATA    = "userdata",
        TABLE       = "table",
        BOOLEAN     = "boolean",
        THREAD      = "thread",
        NIL         = "nil",
    },

    CLIENT_SIDE         = TheNet and (TheNet:GetIsClient() and not TheNet:IsDedicated()) or false,
    SERVER_SIDE         = TheNet and (not TheNet:GetIsClient() or TheNet:GetIsServer()) or false,
    OFFLINE             = TheNet and ((TheNet:GetIsClient() == false and TheNet:GetIsServer() == false) or TheNet:IsDedicatedOfflineCluster()) or false,

    -- Whether this is the initial launch of the mod or not.
    -- We only care about this on dedicated servers.
    INITIAL_LAUNCH      = TheSim and TheSim:GetNumLaunches() == 1 or false, -- i.e. First launch of the game (partial)
    INITIAL_FULL_LAUNCH = TheSim and TheSim:GetNumLaunches() == 2 or false, -- First launch where the game fully loads
    SUBSEQUENT_LAUNCH   = TheSim and TheSim:GetNumLaunches() > 1 or false,  -- Subsequent launches are always "full".
    LAUNCH_COUNT        = TheSim and TheSim:GetNumLaunches() or 0,      -- The number of total launches from boot.

    PREFAB              = "MOD_"..modname,

    BACKUP_ID           = "2924921999",
    UNIQUE_IDENTIFIER   = "3122299418", -- Unique identifier for this mod.

    --- @type string?
    SHARDID             = TheNet and TheNet:IsDedicated() and tostring(TheShard:GetShardId()) or nil,

    --- @type EventProcessor
    EventProcessor      = EventProcessor(), -- Used for sending internal events within the mod.
}, {
    __index = function(tbl, name)
        return rawget(PEARL.ENV, name)
    end
})

local id = GetWorkshopIdNumber(PEARL.MODNAME)
PEARL.WORKSHOP_ID   = tonumber(id) ~= nil and tostring(id) or nil
PEARL.IS_WORKSHOP   = PEARL.WORKSHOP_ID ~= nil
PEARL.IS_BACKUP     = (PEARL.BACKUP_ID ~= nil and (PEARL.WORKSHOP_ID == PEARL.BACKUP_ID)) or false
PEARL.IN_UGC_FOLDER = PEARL.IS_WORKSHOP == true

PEARL.LICENCE_FILE  = PEARL.SRCDIR..".licence"

PEARL.VERSION       = PEARL.MODINFO.version
PEARL.FANCY_VERSION = FirstToUpper(PEARL.MODINFO.branch).." "..PEARL.VERSION
PEARL.LUA_VERSION   = _VERSION

PEARL.X32 = APP_ARCHITECTURE == "x32"
PEARL.X64 = APP_ARCHITECTURE == "x64"

--- ../mods/MODNAME/
--- Works even with UGC mods since the paths are translated automatically by the engine.
MODROOT = MODROOT

--- ../mods/
MODS_ROOT = MODS_ROOT

--------------------------------
-- [[ Server Mod Config ]]
--------------------------------

--- Run this as soon as possible so in case of any error we won't expose any sensitive data.
--- @class ModConfig
PEARL.ModConfig = require("modconfig")

if type(PEARL.ModConfig) ~= "table" then
    return error("Failed to load mod configurations!")
end

if not TheNet:GetIsClient() and TheNet:GetIsServer() and not TheNet:IsDedicated() or TheNet:IsDedicatedOfflineCluster() then
    return error("Current version of "..PEARL.MODINFO.name.." does only support online dedicated servers.")
end

--------------------------------
-- [[ Banner ]]
--------------------------------

local bf = io.open(MODROOT..""..PEARL.BANNER_PATH, "r")
if bf then
    local banner = bf:read("*a")
    local line = banner:match("([^\n]+)\n")
    print("FIRST LINE", line)
    local modname = TheNet:IsDedicated() and PEARL.MODINFO.server_side_name or PEARL.MODFANCYNAME
    local name_part, version_part = " :: "..modname.." ::", "(v"..PEARL.VERSION..")"

    print("\n\n "..banner:gsub("\n", "\n "):gsub("^%s*\n", ""):gsub("\n%s*$", "")
        .."\n"..name_part..string.rep(" ", #line - #name_part - #version_part)..version_part
    .."\n\n")
end

--------------------------------
-- [[ FileLoader ]]
--------------------------------

local loaders = require("libs/loaders/fileloaders")
for name, loader in pairs(loaders) do
    if type(loader) ~= "function" then
        return error("Failed to load "..name.."! "..tostring(loader))
    end

    if PEARL[name] ~= nil then
        error("Loader "..name.." already exists in the namespace table?!")
    end
end

--- Adding it manually here instead of the loop for autocomplete to be smarter.
PEARL.loadfilefn    = loaders.loadfilefn
PEARL.loadfile      = loaders.loadfile

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
-- [[ Engine Extensions ]]
--------------------------------

PEARL.loadfile("extensions/engine/net")

--------------------------------
-- [[ Configuration ]]
--------------------------------

--[[
    Zipping Configurations:
    - We ZIP configuration options to save some bytes when saving
      the data to a file (e.g. modoverrides.lua) or when sending them
      over the network.

    - This only applies to option fields like "saved" not to the "default" field.
--]]

-- Stores all the overrides of the default values for configuration options.
-- These can come from either the config files or they can be downloaded from a server (in case of clients).
PEARL.CONFIG_OVERRIDES = {}
PEARL.DEFAULT_CONFIG = {}
for _, option in ipairs(PEARL.MODINFO.configuration_options) do
    if option.name ~= nil then
        -- Make sure we always have at least the defaults.
        PEARL.CONFIG[option.name] = option.default
        PEARL.DEFAULT_CONFIG[option.name] = option.default

        local override = PEARL.ModConfig:TryUnzipAndDecodeOption(option)
        print(option.name, override)
        if override ~= option.default then
            PEARL.CONFIG_OVERRIDES[option.name] = override
        end

        PEARL.ModConfig:ApplyConfig(option.name, override)
    end
end

-- --- @TODO: The temp config is not.
-- if PEARL.CLIENT_SIDE then
--     print("--------- CLIENT SIDE", PEARL.CLIENT_SIDE)
--     table.foreach(PEARL.MOD_DATA.temp_config_options, print)
-- end

--------------------------------
-- [[ Persistence Libs ]]
--------------------------------

--- This has to load this soon because some of the following files use it.
--- @class ClusterPersistence
PEARL.ClusterPersistence = PEARL.loadfile("libs/wrappers/persistence/clusterio")

--- @class ModPersistence
PEARL.ModPersistence = PEARL.loadfile("libs/wrappers/persistence/modio")

--------------------------------
-- [[ Common Config ]]
--------------------------------

-- This has to be loaded before we start to use the configurations.
-- Also it requires ClusterPersistence
if PEARL.CONFIG.COMMON_MOD_CONFIG and PEARL.SERVER_SIDE then
    local configs = PEARL.ModConfig:LoadCommmonConfig()
    if type(configs) == "table" then
        PEARL.ModConfig:ApplyConfigs(configs)
    end
end

PEARL.EventProcessor:HandleEvent("mod_configuration_loaded")

--------------------------------
-- [[ Uncompatible Mods ]]
--------------------------------

if table.empty(PEARL.CONFIG.UNCOMPATIBLE_MODS) == false then
    ConcatArrays(PEARL.MODINFO.uncompatible_mods, PEARL.CONFIG.UNCOMPATIBLE_MODS)
end

--------------------------------
-- [[ General Mod Constants ]]
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
    HYBRID_EMOJI_PATTERN = ":(%S+):",
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
PEARL.CONSTS.GAME_EMOJI_ALIAS_MATCH = PEARL.CONSTS.DELIMS.EMOJI.."(%S+)"..PEARL.CONSTS.DELIMS.EMOJI

local FOLDERS = PEARL.CONFIG.SERVER_FOLDERS
if TheNet and TheNet:IsDedicated() then
    PEARL.UGC_MODS_FOLDER = "../"..FOLDERS.UGC_MODS_ROOT.."/"..FOLDERS.CLUSTER.."/"..FOLDERS.SHARD.."/content/"..tostring(DONT_STARVE_TOGETHER_APPID).."/"..tostring(PEARL.MODID)
else
    PEARL.UGC_MODS_FOLDER = "../../../workshop/content/"..tostring(DONT_STARVE_TOGETHER_APPID).."/"..tostring(PEARL.MODID)
end

PEARL.LoadingState = LoadingStates
PEARL.LoadingStateName = table.invert(PEARL.LoadingState)

--------------------------------
-- [[ Logging ]]
--------------------------------

--- Even logging uses configurations!
PEARL.loadfile("extensions/logging")

--------------------------------
-- [[ Persistent Data ]]
--------------------------------

PEARL.info("Loading persistent data...")

PEARL.STORAGE = PEARL.loadfile("persistentstorage")
PEARL.STORAGE.Load()

-- No need to load any further when in the world generation thread.
--*************************************************************************************************--
if PEARL.WORLDGEN_THREAD then ----------------------------------------------------------------------------------
    return ------------------------------------------------------------------------------------------
end -------------------------------------------------------------------------------------------------
--*************************************************************************************************--

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

----------------------------------
-- [[ Static Scheduler ]]
----------------------------------

-- On clients, use staticScheduler for background tasks
-- On servers, staticScheduler doesn't work when sim is paused so wallScheduler is what should be used.
PEARL.info("Loading static scheduler...")
require("scheduler")
--- @type Scheduler
PEARL.StaticScheduler = staticScheduler

--------------------------------
-- [[ Global Extensions ]]
--------------------------------
-- Load after API.

PEARL.info("Loading Event Processor extensions...")
PEARL.loadfile("extensions/eventprocessor")

--------------------------------
-- [[ Byte Code Interpreter ]]
--------------------------------

PEARL.info("Loading custom Lua interpreter...")
--- @class LuaInterpreter
PEARL.LuaInterpreter = PEARL.loadfile("libs/interpreter")

--------------------------------
-- [[ License ]]
--------------------------------

-- Load licences only on servers
if TheNet:GetIsServer() then
    --- We are working with files here so load after the io extension
    PEARL.info("Loading licence...")
    PEARL.LuaInterpreter:LoadLuacFile(PEARL.LICENCE_FILE)()
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
--- @type EMOJIS table<table<string, string>>
PEARL.EMOJIS = PEARL.loadfile("constants/emojis")

if not PEARL.INITIAL_LAUNCH then

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

    -- Better c_reset
    PEARL.AddGlobalFunctionPreCall("c_reset", function()
        TheSim:ResetError()
    end)

    if TheNet:GetIsServer() then
        PEARL.loadfile("utils/emojidatagenerator", nil, true)
    end

    --- A bit spammy
    --PEARL.OverrideVariable("PRINT_SOURCE", true)


    --- @CONFIGURATION (so we do not have to restart the whole server)
    PEARL.CONFIG.CUSTOM_EMOJI_PACKS = {
        ["discord_emojis"] = true,
        ["discord_emojis_animated"] = true
    }
    --PEARL.CONFIG.EMOJI_MENU = false
end


--------------------------------
-- [[ Post-Initialization ]]
--------------------------------

-- Let's give Frontend access to the HTTP Client as well!
if not PEARL.INITIAL_LAUNCH then
    --------------------------------
    -- [[ Wall Scheduler ]]
    --------------------------------
    --- There is not much point in having the WallScheduler on for the first tick
    --- since it's the initial launch and it's all in one tick.

    PEARL.info("Setting up the wall-scheduler...")

    --- @type WallScheduler
    PEARL.WallScheduler = PEARL.loadfile("libs/wallscheduler")
    PEARL.WallScheduler:StartWallUpdate()

    --------------------------------
    -- [[ Network ]]
    --------------------------------

    PEARL.info("Loading HTTP client...")

    --- Even the client needs to use some requests from time to time
    --- @type HTTPClient
    PEARL.HTTPClient = PEARL.loadfile("libs/http/httpclient")
end

--------------------------------
-- [[ Server Side ]]
--------------------------------

--- TheNet:GetIsClient return's false when we disconnect.
--- Looks like TheNet:IsDedicated works even without the network!
if TheNet:IsDedicated() and not TheNet:GetIsClient() then
    PEARL.info("Loading server side...")
    PEARL.loadfile("serverside")
    PEARL.info("Loading server side done.")
end

--------------------------------
-- [[ Client-Side ]]
--------------------------------

local function LoadExtensionMods()
    for workshop_id, data in pairs(PEARL.CONFIG.APPLICATIONS) do
        if data.ENABLED == true then
            local app_modname = "workshop-"..workshop_id
            local initenv = KnownModIndex:GetModInfo(modname)
            local env = CreateEnvironment(app_modname, PEARL.WORLDGEN_THREAD, false)
            env.modinfo = initenv
            env.EXTENSION = data

            package.path = MODS_ROOT..app_modname.."\\scripts\\?.lua;"..package.path
            local manifest
            --manifests are on by default for workshop mods, off by default for local mods.
            --manifests can be toggled on and off in modinfo with forcemanifest = false or forcemanifest = true
            if((initenv.forcemanifest == nil and IsWorkshopMod(env.modname)) or
                (initenv.forcemanifest ~= nil and initenv.forcemanifest)) then
                ManifestManager:LoadModManifest(app_modname, initenv.version)
                manifest = env.modname
            end
            table.insert(package.assetpath, {path = MODS_ROOT..app_modname.."\\", manifest = manifest})

            print(string.rep("-s", 50))
            print(env.GetModConfigData("SHOWMOON"))
            PEARL.info("Loading extension mod", app_modname)
            local function errcb(reason)
                PEARL.error("Failed to load app", app_modname, "Reason:", reason)
            end

            --- @TODO: Handle the environment with the extension specific configurations correctly.
            local fn = PEARL.loadfilefn(MODS_ROOT..app_modname.."/".."modmain.lua", errcb)
            if fn then
                xpcall(fn, errcb)
            end

            -- ModManager:InitializeModMain(
            --     app_modname, setmetatable(env, getmetatable(PEARL)), "modmain.lua", true
            -- )
        end
    end
end

-- In debug mode we want to load sometimes the client-side code on servers
-- to see if there is any error.
if TheNet:GetIsClient() then-- or PEARL.CONFIG.DEBUG_MODE then
    PEARL.info("Loading client side...")
    PEARL.loadfile("clientside")
    PEARL.info("Loading client side done.")

    PEARL.info("Verifying extension mods...")
    local download_count = 0
    for workshop_id, data in pairs(PEARL.CONFIG.APPLICATIONS) do
        local app_modname = "workshop-"..workshop_id
        if not KnownModIndex:DoesModExist(app_modname, data.VERSION) then
            if TheSim:QueueDownloadTempMod(app_modname, data.VERSION) then
                download_count = download_count + 1
            end
        end
    end

    if download_count > 0 then
        PEARL.ClientLoader:AddDeferant("extension_download")

        PEARL.info("Missing", download_count, "extension mods! Downloading them right now...")
        TheSim:StartDownloadTempMods(function(success, msg)
            print("TheSim:StartDownloadTempMods", success, msg, download_count)
            --- Called when all the mods are downloaded.
            download_count = download_count -1

            -- For the love of God, let the framebuffer complete!
            PEARL.WallScheduler:ExecuteInTime(0, function()
                PEARL.info("Extension mods downloaded!")
                LoadExtensionMods()

                -- Continue loading the game normally.
                PEARL.ClientLoader:RemoveDeferant("extension_download")
            end)
        end)
    else
        PEARL.info("All extension mods seem to loaded correctly.")
        LoadExtensionMods()
    end
end

--------------------------------
-- [[ Commmon Modules ]]
--------------------------------
-- Modules loaded on both, clients and servers.

-- local ModuleManager = PEARL.loadfile("libs/loaders/modulemanager")
-- ModuleManager:SetLoader(PEARL.loadfile)

--------------------------------
-- [[ Mountable Lua ]]
--------------------------------

if type(PEARL.CONFIG.MOUNTABLE_LUA) == "string" then
    PEARL.info("Mounting extension scripts...")

    local fn, error_message = loadstring(PEARL.CONFIG.MOUNTABLE_LUA)
    if type(fn) == "function" and RunInEnvironmentSafe(fn, PEARL.ENV) then
        PEARL.info("Success! Scripts were mounted.")
    else
        PEARL.error("Invalid mountable lua scripts provided! Error:", error_message)
    end
end

--------------------------------
-- [[ Mod Post-Init ]]
--------------------------------

PEARL.info("Mod loaded successfully on version:", PEARL.FANCY_VERSION,
    PEARL.IS_BACKUP == true and "[Backup]" or ""
)
