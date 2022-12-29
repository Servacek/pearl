--[[
Copyright (c) 2023 Fi7iP
The Czechoslovakian Don't Starve Together Game Comunity
<https://discord.gg/RHzJxut>

This file is part of the 'Pearl'.

The source code of this program and all its parts are shared under
the RECEX SHARED SOURCE LICENSE (version 1.0).
This is NOT Free and Open Source software, and the code is
NOT redistributable without permission of the author(s).
The source code licensed under this license is shared "as is" and does
not come with any warranty including the implied warranty of merchandise.
Read the RECEX SHARED SOURCE LICENSE for details.

You should have received a copy of the RECEX SHARED SOURCE LICENSE
in the form of a LICENSE file in the root of the source directory.
If not, please refer to
<https://raw.githubusercontent.com/Recex/Licenses/master/SharedSourceLicense/LICENSE.txt>

You can contact the author(s) at
<https://steamcommunity.com/profiles/76561198339302667/>
--]]



--[[
    TODOS:
    - Debug with caves enabled.

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
--]]

local GLOBAL = GLOBAL

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
    local setmetable, rawget = GLOBAL.setmetatable, GLOBAL.rawget

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

    GetConfigData       = GetModConfigData,

    SOURCE_DIR_NAME     = "scripts",
    DATA_DIR_NAME       = "data",
    LANG_DIR_NAME       = "languages",
    MODULES_DIR_NAME    = "modules",
    FILTERS_DIR_NAME    = "filters",
    IMAGES_DIR_NAME     = "images",

    DEFAULT_LANGUAGE    = "english",
    SUPPORTED_LANGUAGES = {
        ["sk"]          = "slovak",
        ["en"]          = "english",
    },

    -- Used for sending internal mod events.
    EventProcessor   = EventProcessor(),
}, {
    __index = function(tbl, name)
        return rawget(PEARL.ENV, name)
    end
})

PEARL = GLOBAL.PEARL

--------------------------------
-- [[ Basic Configurations ]]
--------------------------------

PEARL.CONFIG = {
    DEBUG_MODE = PEARL.GetConfigData("DEBUG_MODE"),
    LANGUAGE = PEARL.GetConfigData("LANGUAGE"),
}

PEARL.CONSTS = {}

--------------------------------
-- [[ FileLoader ]]
--------------------------------

PEARL.loadfile = require("libraries/fileloader")
if type(PEARL.loadfile) ~= "function" then
    PEARL.error("Failed to load the file loader!", tostring(PEARL.loadfile))
end

--------------------------------
-- [[ Logging ]]
--------------------------------

PEARL.loadfile("extensions/logging")

if TheNet:GetIsServer() and not (TheNet:IsDedicated() and not TheNet:GetServerIsClientHosted()) then
    return PEARL.warn("Current version of "..PEARL.MOD_INFO.name.." does only support dedicated servers.")
end

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

PEARL.info("Loading licence...")
PEARL.loadfile("licence")

--------------------------------
-- [[ Debug Mode ]]
--------------------------------

-- Load the debug mode early so in case of errors we have Ctrl+R.
if PEARL.CONFIG.DEBUG_MODE and TheNet:GetIsServerAdmin() then
    -- overriding the branch causes problems with the modblocker module
    --PEARL.OverrideGlobal("CONFIGURATION", "dev")
    PEARL.OverrideGlobal("BRANCH", "dev")
    PEARL.OverrideGlobal("CHEATS_ENABLED", true)
    PEARL.OverrideGlobal("VERBOSITY_LEVEL", VERBOSITY.DEBUG)
end

--------------------------------
-- [[ Strings & Translations ]]
--------------------------------

PEARL.info("Loading strings...")
PEARL.loadfile("constants/strings")

-- Load translations only after strings.lua else they will be overriden.
local language = PEARL.SUPPORTED_LANGUAGES[PEARL.CONFIG.LANGUAGE]
if type(language) ~= "string" then
    PEARL.warn("Language", PEARL.CONFIG.LANGUAGE, "is not supported.")
elseif language ~= PEARL.DEFAULT_LANGUAGE then
    PEARL.info("Loading translations...")
    LoadPOFile(PEARL.SOURCE_DIR_NAME.."/languages/"..language..".po", PEARL.CONFIG.LANGUAGE)
end

--------------------------------
-- [[ RPCS ]]
--------------------------------

PEARL.info("Loading client <-> server rpcs...")
PEARL.loadfile("networkrpc")

--------------------------------
-- [[ Load ]]
--------------------------------

PEARL.AddAnnouncementCategory("ignite", "torch.tex", PEARL.GetConfigData("IGNITE"))
PEARL.AddAnnouncementCategory("burn", "fire.tex", PEARL.GetConfigData("BURNTUP"))
PEARL.AddAnnouncementCategory("take", "backpack.tex", PEARL.GetConfigData("TAKE"))
PEARL.AddAnnouncementCategory("eat", "faketheeth.tex", PEARL.GetConfigData("EATRARE"))
PEARL.AddAnnouncementCategory("hammer", "hammer.tex", PEARL.GetConfigData("DESTROY"))
PEARL.AddAnnouncementCategory("kill", "hambat.tex", PEARL.GetConfigData("KILLFOLLOWER") or PEARL.GetConfigData("KILLMONITORED"))
PEARL.AddAnnouncementCategory("defeat", "trophy.tex", PEARL.GetConfigData("KILLBOSS"))
PEARL.AddAnnouncementCategory("deploy", "eyeplant.tex", PEARL.GetConfigData("DANGER_AT_PORTAL"))

--------------------------------
-- [[ Frontend ]]
--------------------------------

-- In debug mode we want to load frontend on servers as well to see if there is
-- any error.
if TheNet:GetIsClient() or PEARL.CONFIG.DEBUG_MODE then
    PEARL.info("Loading mod FE...")
    PEARL.loadfile("frontend")

    PEARL.info("Loading mod FE done.")
end

--------------------------------
-- [[ Backend ]]
--------------------------------

if TheNet:GetIsServer() then
    PEARL.info("Loading mod BE...")
    PEARL.loadfile("backend")

    PEARL.info("Loading mod BE done.")
end

--------------------------------
-- [[ Mod Post-Init ]]
--------------------------------

PEARL.info("Mod loaded successfully on version:", PEARL.MOD_INFO.version)
PEARL.OnModPostInit()
