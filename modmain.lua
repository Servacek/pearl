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
local function SetupEnvironment()
    local setmetable, rawget, rawset = GLOBAL.setmetatable, GLOBAL.rawget, GLOBAL.rawset

    -- Modify the metatable of the current safe separated mod environment.
    setmetable(ENV, {
        -- Called when lua is not able to find the field in our environment table.
        -- This allows implicit access to fields of the GLOBAL table.
        __index = function(env, index)
            return rawget(GLOBAL, index) or rawget(env, index)
        end,

        -- __newindex = function(env, index, value)
        --     if env[index] ~= nil then
        --         print("[PEARL] [Warn] Overriding Global: "..tostring(index).." = "..tostring(value))
        --     -- else
        --     --     print("[SUB] [Debug] Adding New Global: "..tostring(index).." = "..tostring(value))
        --     end

        --     rawset(env, index, value)
        -- end
    })

    -- _G should already refer to our modified environment
    --_G = GLOBAL
end

--------------------------------
-- [[ Setup ]]
--------------------------------

SetupEnvironment()

-- This is where we store basically all mod specific functions and variables
-- so it doesn't conflict with any ingame or other mod stuff.
--
-- Add this table to the main environment so it's accessible everywhere.
GLOBAL.PEARL = setmetatable({
    -- expose these to all the components
    MODROOT             = MODROOT,
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

    --READY               = false,

    -- Used for sending internal mod events.
    EventProcessor   = EventProcessor()
}, {
    __index = function(tbl, name)
        return rawget(PEARL.ENV, name)
    end
})

--local PEARL = PEARL

if TheNet:GetIsServer() and not (TheNet:IsDedicated() and not TheNet:GetServerIsClientHosted()) then
    print("Current version of "..PEARL.MOD_INFO.name.." does only support dedicated servers.")
    print("Skipping this mod...")
    return
end

--------------------------------
-- [[ Basic Configurations ]]
--------------------------------

PEARL.CONFIG = {
    DEBUG_MODE = PEARL.GetConfigData("DEBUG_MODE"),
    LANGUAGE = PEARL.GetConfigData("LANGUAGE"),
}

PEARL.CONSTS = {}

--------------------------------
-- [[ Logging ]]
--------------------------------

modimport(PEARL.SOURCE_DIR_NAME.."/logging")

--------------------------------
-- [[ Standard Libs ]]
--------------------------------

PEARL.info("Loading extensions for the standard lua libraries...")
modimport(PEARL.SOURCE_DIR_NAME.."/extensions/standard/table")
modimport(PEARL.SOURCE_DIR_NAME.."/extensions/standard/math")
modimport(PEARL.SOURCE_DIR_NAME.."/extensions/standard/string")

--------------------------------
-- [[ Helpers & Logging ]]
--------------------------------

PEARL.info("Loading helper functions...")
modimport(PEARL.SOURCE_DIR_NAME.."/utils/helpers")
modimport(PEARL.SOURCE_DIR_NAME.."/api")

--- @TODO
-- This should be loaded after the webhooks are set up.
PEARL.info("Loading mod error handler...")
modimport(PEARL.SOURCE_DIR_NAME.."/moderror")

--------------------------------
-- [[ License ]]
--------------------------------

PEARL.info("Loading licence...")
modimport(PEARL.SOURCE_DIR_NAME.."/licence")

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
modimport(PEARL.SOURCE_DIR_NAME.."/constants/strings")

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
modimport(PEARL.SOURCE_DIR_NAME.."/networkrpc")

--------------------------------
-- [[ Load ]]
--------------------------------
-->                           name    |    icon
PEARL.AddAnnouncementCategory("ignite", "torch.tex", PEARL.GetConfigData("IGNITE"))
PEARL.AddAnnouncementCategory("burn", "fire.tex", PEARL.GetConfigData("BURNTUP"))
PEARL.AddAnnouncementCategory("take", "backpack.tex", PEARL.GetConfigData("TAKE"))
PEARL.AddAnnouncementCategory("eat", "faketheeth.tex", PEARL.GetConfigData("EATRARE"))
PEARL.AddAnnouncementCategory("hammer", "hammer.tex", PEARL.GetConfigData("DESTROY"))
PEARL.AddAnnouncementCategory("kill", "hambat.tex", PEARL.GetConfigData("KILLFOLLOWER") or PEARL.GetConfigData("KILLMONITORED"))
PEARL.AddAnnouncementCategory("defeat", "trophy.tex", PEARL.GetConfigData("KILLBOSS"))
PEARL.AddAnnouncementCategory("deploy", "eyeplant.tex", PEARL.GetConfigData("DANGER_AT_PORTAL"))

if TheNet:GetIsClient() then
    --------------------------------
    -- [[ Frontend ]]
    --------------------------------

    PEARL.info("Loading mod FE...")
    modimport(PEARL.SOURCE_DIR_NAME.."/frontend")
    PEARL.info("Loading mod FE done.")
else
    --------------------------------
    -- [[ Backend ]]
    --------------------------------

    PEARL.info("Loading mod BE...")
    modimport(PEARL.SOURCE_DIR_NAME.."/backend")

    PEARL.info("Loading mod BE done.")
end

--error("TOTAL FATAL ERROR")

PEARL.info("Mod loaded successfully on version:", PEARL.MOD_INFO.version)
PEARL.READY = true
PEARL.OnModPostInit()

-- PEARL.Scheduler:ExecuteInTime(10, function()
--     error("WALL SCHEDULER CRITICAL ERROR")
-- end)
