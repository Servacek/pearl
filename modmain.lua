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

    - 'moderror' function is being called when the mod crashes. Sadly when
      this function is called it's too late for use
      to send that information to discord.

        local _moderror = _G.moderror
        _G.moderror = function(...)
            SUB.error("MOD ERROR!!!")

            SUB.Rhook:SendErrorReport("ERROR")

            return _moderror(...)
        end

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

    - Try to not push in-game events.

    - Use raw tables for singleton non-inherited classes.

    - For singletons use locals as private variables and functions without the '_' prefix.

    - Do not use raw RPCs! Use the built-in mod API. They are being registered
      after TheFrontEnd.
--]]

local GLOBAL = GLOBAL
local setmetable, rawget = GLOBAL.setmetatable, GLOBAL.rawget

--------------------------------
-- [[ Local Constants ]]
--------------------------------

local ENV = GLOBAL.getfenv(1)

--------------------------------
-- [[ Local Functions ]]
--------------------------------

-- Setup the enviroment so we do not have to type GLOBAL
-- everytime we access something from that table.
--- @return table
local function setupenv()
    -- Modify the metatable of the current safe separated mod environment.
    return setmetable(ENV, {
        -- Called when lua is not able to find the field in our environment table.
        -- This allows implicit access to fields of the GLOBAL table.
        __index = function(env, index)
            return rawget(GLOBAL, index) or rawget(env, index)
        end,
    })
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

    ROOTDIR             = MODROOT,
    SRCDIR              = MODROOT.."scripts/",

    -- Used for accessing environment specific functions outside modmain.lua
    ENV                 = ENV,
    MODNAME             = modname,
    MOD_INFO            = KnownModIndex:GetModInfo(modname),
    RPC_NAME            = modname.."_rpc",

    GetConfigData       = function(opt_name, no_supp, ...)
        local data = ENV.GetModConfigData(opt_name, ...)
        if type(data) ~= "table" or no_supp then
            return data
        end

        local function supplement(level)
            for k, v in pairs(level) do
                if data[k] == nil then
                    data[k] = v
                elseif type(data[k]) == "table" then
                    supplement(data[k])
                end
            end
        end

        for _, option in ipairs(PEARL.MOD_INFO.configuration_options) do
            if option.name == opt_name then
                if type(option.default) == "table" then
                    supplement(option.default)
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

    DEFAULT_LANGUAGE    = "english",

    -- Used for sending internal mod events.
    EventProcessor   = EventProcessor(),
}, {
    __index = function(tbl, name)
        return rawget(PEARL.ENV, name)
    end
})

PEARL = GLOBAL.PEARL

--------------------------------
-- [[ General Configurations ]]
--------------------------------

PEARL.CONFIG = {}

local function load_general_config()
    for _, option in ipairs(PEARL.MOD_INFO.configuration_options) do
        if option.general == true then
            PEARL.CONFIG[option.name] = PEARL.GetConfigData(option.name)
        end
    end
end

load_general_config()

--------------------------------
-- [[ General Mod Constants]]
--------------------------------

PEARL.CONSTS = {
    EVENT_PREFIX = "__"..string.lower(PEARL.MODNAME).."__",

    -- If encoded then there is an 'D' at the end.
    -- For non-encoded data there is a space between
    -- the prefix and the actual content
    KLEI_DATA_PREFIX            = "KLEI     1",
    KLEI_ENCODED_DATA_PREFIX    = "KLEI     1D",
}

--------------------------------
-- [[ Server Mod Config ]]
--------------------------------

require("servermodconfig")

if TheNet:GetIsServer() and not TheNet:IsDedicated() or TheNet:IsDedicatedOfflineCluster() then
    -- Make sure we do not leak any internal configurations
    return error("Current version of "..PEARL.MOD_INFO.name.." does only support online dedicated servers.")
end

-- Backend needs to be loaded even on the first launch because of some configurations.
-- if not TheSim or TheSim:GetNumLaunches() == 1 then
--     return -- Do not load much on the first launch.
-- end

--------------------------------
-- [[ FileLoader ]]
--------------------------------

PEARL.loadfile = require("libraries/fileloader")
if type(PEARL.loadfile) ~= "function" then
    return error("Failed to load the file loader!", tostring(PEARL.loadfile))
end

--------------------------------
-- [[ Logging ]]
--------------------------------

PEARL.loadfile("extensions/logging")

--------------------------------
-- [[ Standard Libs ]]
--------------------------------

PEARL.info("Loading extensions for the standard lua libraries...")
PEARL.loadfile("extensions/standard/table")
PEARL.loadfile("extensions/standard/math")
PEARL.loadfile("extensions/standard/io")
PEARL.loadfile("extensions/standard/string")

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
-- [[ License ]]
--------------------------------

-- Load licences only on servers
if TheNet:GetIsServer() then
    --- We are working with files here so load after the io extension
    PEARL.info("Loading licence...")
    PEARL.loadfile("licence")
end

--------------------------------
-- [[ Debug Mode ]]
--------------------------------

-- Load the debug mode early so in case of errors we have Ctrl+R.
if PEARL.CONFIG.DEBUG_MODE and TheNet:GetIsServerAdmin() then
    PEARL.info("Setting up debug mode!")

    KnownModIndex.modsettings.initdebugprint = true
    -- Do not override this because it attempts to load some
    -- test files that are not provided.
    --PEARL.OverrideGlobal("CONFIGURATION", "dev")

    PEARL.OverrideVariable("ENCODE_SAVES", false)
    PEARL.OverrideVariable("BRANCH", "dev")
    PEARL.OverrideVariable("CHEATS_ENABLED", true)
    PEARL.OverrideVariable("VERBOSITY_LEVEL", VERBOSITY.DEBUG)

    --- @NOTE: DoReload doesn't really affect these...
    --- Maybe this would require some further investigation
    local modmain_fp = PEARL.ROOTDIR.."modmain.lua"
    local modmain_ft = TheSim:GetFileModificationTime(modmain_fp)
    local worldgenmain_fp = PEARL.ROOTDIR.."modworldgenmain.lua"
    local worldgenmain_tp = TheSim:GetFileModificationTime(modmain_fp)
    RequiredFilesForReload[modmain_fp] = modmain_ft
    RequiredFilesForReload[worldgenmain_fp] = worldgenmain_tp
end

--------------------------------
-- [[ Strings & Translations ]]
--------------------------------

PEARL.info("Loading strings...")
PEARL.loadfile("constants/strings")

-- With this implementation we are not limited to a hard coded set of languages
-- but we are able to add our own languages without changing the code instead.
-- Load translations only after strings.lua else they will be overriden.
local path = PEARL.SRCDIR.."languages/"..tostring(PEARL.CONFIG.LANGUAGE)..".po"
if PEARL.CONFIG.LANGUAGE ~= PEARL.DEFAULT_LANGUAGE and io.exists(path) then
    PEARL.info("Loading translations...")
    LoadPOFile(path, PEARL.CONFIG.LANGUAGE)
else
    PEARL.error("Language", PEARL.CONFIG.LANGUAGE, "not supported!")
end

--------------------------------
-- [[ RPCS ]]
--------------------------------

PEARL.info("Loading RPC handlers...")
PEARL.loadfile("networkrpc")

--------------------------------
-- [[ Load ]]
--------------------------------

PEARL.AddAnnouncementCategory("ignite", "torch.tex")
PEARL.AddAnnouncementCategory("burn", "fire.tex")
PEARL.AddAnnouncementCategory("take", "backpack.tex")
PEARL.AddAnnouncementCategory("eat", "faketheeth.tex")
PEARL.AddAnnouncementCategory("hammer", "hammer.tex")
PEARL.AddAnnouncementCategory("kill", "hambat.tex")
PEARL.AddAnnouncementCategory("defeat", "trophy.tex")
PEARL.AddAnnouncementCategory("deploy", "eyeplant.tex")

--- @TODO: add custom icon for these...
PEARL.AddAnnouncementCategory("activate")
PEARL.AddAnnouncementCategory("teach")
PEARL.AddAnnouncementCategory("read")

--------------------------------
-- [[ Custom Error Handler ]]
--------------------------------

PEARL.info("Loading mod error handler...")
PEARL.loadfile("error")

--------------------------------
-- [[ Backend ]]
--------------------------------

--- TheNet:GetIsClient return's false when the we disconnect.
if not TheNet:GetIsClient() then
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
-- [[ Mod Post-Init ]]
--------------------------------

PEARL.OnModPostInit()
PEARL.info("Mod loaded successfully on version:", PEARL.MOD_INFO.version)
