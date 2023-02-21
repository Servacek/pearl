--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



-- [[ FrontEnd ]]
-- Should be loaded only on the client's side.

PEARL.info("Loading Mod FE...")

PEARL.SafeModTableExtend("CONSTS", {
    -- Create the file in game's data directory which is more persistent on clients
    AGREEMENT_FILE_PATH = "AGREEMENT",
})

----------------------------------
-- Config
----------------------------------

PEARL.info("Loading Configuration...")
for _, option in ipairs(PEARL.MOD_INFO.configuration_options) do
    if option.public and PEARL.CONFIG[option.name] == nil then
        PEARL.CONFIG[option.name] = PEARL.GetConfigData(option.name)
    end
end

PEARL.SafeModTableExtend("CONTROLS", {
    TOGGLE_CHAT = KEY_F1 -- 282
})

----------------------------------
-- Agreement Manager
----------------------------------

--- @type AgreementManager
PEARL.AgreementManager = PEARL.loadfile("libraries/agreementmanager")
PEARL.AgreementManager:Load()

----------------------------------
-- Client Network
----------------------------------

PEARL.info("Loading client network...")

--- @type ClientNetwork
PEARL.ClientNetwork = PEARL.loadfile("clientnetwork")
PEARL.ClientNetwork:LoadDefaultCFD()

----------------------------------
-- FrontEnd Debug Mode
----------------------------------

-- if PEARL.CONFIG.DEBUG_MODE and TheNet:GetIsServerAdmin() then
--     PEARL.OverrideGlobal("CONSOLE_ENABLED", true)
--     PEARL.OverrideGlobal("DEBUG_MENU_ENABLED", true)
--     PEARL.OverrideGlobal("DEBUGRENDER_ENABLED", true)
-- end

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

PEARL.info("Loading UI and strings...")

PEARL.POPUPS = {}

PEARL.loadfile("constants/strings")

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
if PEARL.CONFIG.CUSTOM_LOADING_TIPS then
    PEARL.AddLoadingTip(
        STRINGS.UI.LOADING_SCREEN_CONTROL_TIPS, "TIP_TOGGLE_CHAT",
        STRINGS.PEARL.UI.TIP_TOGGLE_CHAT, {toggle = PEARL.CONTROLS.TOGGLE_CHAT}
    )
end

----------------------------------
-- Game Extensions
----------------------------------

PEARL.info("Loading game extensions...")
PEARL.loadfile("extensions/modindex")

----------------------------------
-- UI Extensions
----------------------------------

PEARL.info("Loading user interface extensions...")
PEARL.loadfile("extensions/ui/consolescreen")
PEARL.loadfile("extensions/ui/playerstatusscreen")

----------------------------------
-- Other Modules
----------------------------------

PEARL.info("Loading modules...")

--- @type ModuleManager
local ModuleManager = PEARL.loadfile("libraries/modulemanager")
ModuleManager:SetLoader(PEARL.loadfile)
ModuleManager:SetModuleDirectory("modules")

ModuleManager:AddModule("slashcommands", PEARL.CONFIG.SLASH_COMMANDS)
if PEARL.CONFIG.DEBUG_MODE or not TheNet:GetIsServerAdmin() then
    ModuleManager:AddModule(
        "modblocker", PEARL.CONFIG.MOD_BLOCKER.ENABLED
    )
    ModuleManager:AddModule(
        "afk", (PEARL.CONFIG.AFK_TIME > 0) or (PEARL.CONFIG.AFK_TIME_KICK > 0)
    )
    ModuleManager:AddModule(
        "agreement", type(PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT) == "table" or type(PEARL.CONFIG.WELCOME_POPUP_CONTENT) == "table"
    )
    ModuleManager:AddModule(
        "commandblocker", not IsTableEmpty(PEARL.CONFIG.COMMAND_BLOCKLIST or {}) or type(PEARL.CONFIG.MIN_VOTE_AGE) == "number"
    )
end

ModuleManager:LoadAllModules()

PEARL.info("Done")
