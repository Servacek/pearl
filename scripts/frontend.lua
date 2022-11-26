-- [[ FrontEnd ]]
-- Should be loaded only on the client's side.

local PEARL = PEARL

PEARL.info("Loading Mod FE...")

----------------------------------
-- Config
----------------------------------

PEARL.info("Loading Configuration...")
PEARL.ModTableSafeAppend("CONFIG", {
    DISCORD_INVITE      = PEARL.GetConfigData("DISCORD_INVITE"),
    MOD_BLACKLIST       = PEARL.GetConfigData("MOD_BLACKLIST"),
    KICK_AFK_PLAYERS    = PEARL.GetConfigData("KICK_AFK_PLAYERS"),
    CZSK_ONLY           = PEARL.GetConfigData("CZSK_ONLY"),
    DEBUG_MODE          = PEARL.GetConfigData("DEBUG_MODE"),
})

PEARL.ModTableSafeAppend("CONTROLS", {
    TOGGLE_CHAT = KEY_F1 -- 282
})

----------------------------------
-- FrontEnd Debug Mode
----------------------------------

if PEARL.CONFIG.DEBUG_MODE and TheNet:GetIsServerAdmin() then
    -- PEARL.OverrideGlobal("CONSOLE_ENABLED", true)
    -- PEARL.OverrideGlobal("DEBUG_MENU_ENABLED", true)
    -- PEARL.OverrideGlobal("DEBUGRENDER_ENABLED", true)
end

----------------------------------
-- Assets
----------------------------------
PEARL.info("Loading assets...")
Assets = {
    Asset("IMAGE", "images/announcements.tex"),
    Asset("IMAGE", "images/dcbutton.tex"),

    Asset("ATLAS", "images/dcbutton.xml"),
    Asset("ATLAS", "images/announcements.xml"),
}

----------------------------------
-- User Interface
----------------------------------

PEARL.info("Loading UI...")

PEARL.POPUPS = {}

modimport(PEARL.SOURCE_DIR_NAME.."/constants/strings")

--[[
    <string_table> can be one of the following:
    LOADING_SCREEN_SURVIVAL_TIPS
    LOADING_SCREEN_LORE_TIPS
    LOADING_SCREEN_CONTROL_TIPS
    LOADING_SCREEN_CONTROL_TIPS_CONSOLE
    LOADING_SCREEN_CONTROL_TIPS_NOT_CONSOLE
    STRINGS.UI.LOADING_SCREEN_OTHER_TIPS (It is recommended to use this table as it is reserved for custom loading tips.)
    <tip_id> must be a unique ID name.
    <tip_string> is the actual tip string to be displayed.
    <controltipdata> is a table containing input control bindings to be used in the tip string. Refer to LOADING_SCREEN_CONTROL_TIP_KEYS in constants.lua and LOADING_SCREEN_CONTROL_TIPS in strings.lua for an example usage.
]]
-- Loading screen tips setup
AddLoadingTip(
    STRINGS.UI.LOADING_SCREEN_CONTROL_TIPS, "TIP_TOGGLE_CHAT",
    STRINGS.PEARL.UI.TIP_TOGGLE_CHAT, {toggle = PEARL.CONTROLS.TOGGLE_CHAT}
)

----------------------------------
-- Widgets
----------------------------------

PEARL.info("Loading user interface extensions...")
modimport(PEARL.SOURCE_DIR_NAME.."/extensions/ui/consolescreen")
modimport(PEARL.SOURCE_DIR_NAME.."/extensions/ui/chatqueue")

PEARL.info("Loading widgets...")
modimport(PEARL.SOURCE_DIR_NAME.."/widgets/discordbutton")

----------------------------------
-- Client Network
----------------------------------

PEARL.info("Loading client network...")
modimport(PEARL.SOURCE_DIR_NAME.."/clientnetwork")

----------------------------------
-- Other Modules
----------------------------------

PEARL.info("Loading modules...")
local ModuleManager = require("libraries/modulemanager")

ModuleManager.AddModule("keybinds", true)
ModuleManager.AddModule("slashcommands", true)
if PEARL.CONFIG.DEBUG_MODE or not TheNet:GetIsServerAdmin() then
    ModuleManager.AddModule(
        "localizer", PEARL.CONFIG.CZSK_ONLY
    )
    -- ModuleManager.AddModule(
    --     "modblocker", not IsTableEmpty(PEARL.CONFIG.MOD_BLACKLIST or {})
    -- )
    ModuleManager.AddModule(
        "afk", PEARL.CONFIG.KICK_AFK_PLAYERS
    )
    ModuleManager.AddModule(
        "agreement", true
    )
end

ModuleManager:LoadAllModules()

PEARL.info("Done")

-- Only load this after everything that controls the client's loading state in anyway
modimport(PEARL.SOURCE_DIR_NAME.."/clientloader")
