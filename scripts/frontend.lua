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

PEARL.SafeModTableExtend("CONSTS", {
    -- Create the file in game's data directory which is more persistent on clients
    AGREEMENT_FILE_PATH = "AGREEMENT",

    LT_TYPES = {
        SURVIVAL    = "survival",
        LORE        = "lore",
        CONTROL     = "control",
        CONSOLE     = "console",
        NOCONSOLE   = "noconsole",
        OTHER       = "other",
        WELCOME     = "welcome",
    },
})

local LT_TYPES = PEARL.CONSTS.LT_TYPES
PEARL.CONSTS.LT_TYPE_TABLES = {
    [LT_TYPES.SURVIVAL]    = STRINGS.UI.LOADING_SCREEN_SURVIVAL_TIPS,
    [LT_TYPES.LORE]        = STRINGS.UI.LOADING_SCREEN_LORE_TIPS,
    [LT_TYPES.CONTROL]     = STRINGS.UI.LOADING_SCREEN_CONTROL_TIPS,
    [LT_TYPES.CONSOLE]     = STRINGS.UI.LOADING_SCREEN_CONTROL_TIPS_CONSOLE,
    [LT_TYPES.NOCONSOLE]   = STRINGS.UI.LOADING_SCREEN_CONTROL_TIPS_NOT_CONSOLE,
    [LT_TYPES.OTHER]       = STRINGS.UI.LOADING_SCREEN_OTHER_TIPS,
    -- Loadings tips for new players.
    [LT_TYPES.WELCOME]     = STRINGS.UI.LOADING_SCREEN_OTHER_TIPS,
}

----------------------------------
-- Config
----------------------------------

local function UnzipConfigData(option)
    local success, data = PEARL.SafeRun(TheSim.DecodeAndUnzipString, TheSim, PEARL.CONFIG[option.name])

    if not success or type(data) ~= "string" then
        return PEARL.error("Decoding configuration option", option.name "failed!")
    end

    -- JSON decoding for table strings.
    if option.type and option.type:startswith("table") then
        local s, tbl = RunInSandbox(data)
        if s == true then
            return tbl
        end
    end

    -- Else return just the raw unzipped string
    return data
end

PEARL.info("Loading Configuration...")
for _, option in ipairs(PEARL.MOD_INFO.configuration_options) do
    if option.public and PEARL.CONFIG[option.name] == nil then
        PEARL.CONFIG[option.name] = PEARL.GetConfigData(option.name) or option.default

        -- In case the data were for whatever reason not ZIPped even if they should be.
        if option.zip and type(PEARL.CONFIG[option.name]) == "string" then
            -- This will be set to nil if unzipping fails
            PEARL.CONFIG[option.name] = UnzipConfigData(option)
        end
    end
end

PEARL.SafeModTableExtend("CONTROLS", {
    TOGGLE_CHAT = KEY_F1 -- 282
})

----------------------------------
-- Game Extensions
----------------------------------

PEARL.info("Loading game extensions...")
PEARL.loadfile("extensions/modindex")
PEARL.loadfile("extensions/chathistory")

PEARL.loadfile("extensions/scripts/entityscript")

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
--- @unexpected end of data - Check these when this error hapens.
--- The XML files may be wrongly formatted
PEARL.info("Loading assets...")
Assets = {
    Asset("IMAGE", "images/dcbutton.tex"),
    Asset("ATLAS", "images/dcbutton.xml"),

    Asset("IMAGE", "images/announcements.tex"),
    Asset("ATLAS", "images/announcements.xml"),

    Asset("IMAGE", "images/dft_flairs.tex"),
    Asset("ATLAS", "images/dft_flairs.xml"),
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
if type(PEARL.CONFIG.CUSTOM_LOADING_TIPS_DATA) == "table" and #PEARL.CONFIG.CUSTOM_LOADING_TIPS_DATA > 0 then
    local default_removed = false
    local function RemoveDefaultLoadingTips()
        if PEARL.CONFIG.CUSTOM_LOADING_TIPS_DATA.override ~= true then
            return
        end

        if not default_removed then
            PEARL.info("Removing default loading tips...")
            PEARL.RemoveAllLoadingTips()
        end

        default_removed = true
    end

    local novice = PEARL.ClientNetwork:IsNovice()
    local function OptionalAddLoadingTip(name, lt)
        local type = PEARL.CONSTS.LT_TYPE_TABLES[lt.type] or PEARL.CONSTS.LT_TYPE_TABLES[LT_TYPES.OTHER]

        if novice then
            if lt.type ~= LT_TYPES.WELCOME then
                return
            else
                -- For novices keep default loading tips
                -- until some welcome tip is found.
                -- So when no welcome tips are set,
                -- the default ones will stay.
                RemoveDefaultLoadingTips()
                type = PEARL.CONSTS.LT_TYPE_TABLES["survival"]
            end
        end

        AddLoadingTip(type, name, lt.text, lt.data)
    end

    if not novice then
        RemoveDefaultLoadingTips()
    end

    PEARL.info("Loading custom loading tips ("..tostring(#PEARL.CONFIG.CUSTOM_LOADING_TIPS_DATA)..")...")

    for i, lt in ipairs(PEARL.CONFIG.CUSTOM_LOADING_TIPS_DATA) do
        local name = string.upper(lt.name or PEARL.MODNAME.."_TIP_"..tostring(i))
        OptionalAddLoadingTip(name, lt)
    end
end

----------------------------------
-- UI Extensions
----------------------------------

PEARL.info("Loading user interface extensions...")
PEARL.loadfile("extensions/ui/templates")

PEARL.loadfile("extensions/ui/playerlist")
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
ModuleManager:AddModule("healthinfo", PEARL.CONFIG.HEALTH_INFO.ENABLED)

if PEARL.CONFIG.DEBUG_MODE or not TheNet:GetIsServerAdmin() then
    ModuleManager:AddModule(
        -- Only load the modblocker if we have any mods enabled.
        "modblocker", PEARL.CONFIG.MOD_BLOCKER.ENABLED and KnownModIndex:GetAllEnabledModsCount() > 1
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
