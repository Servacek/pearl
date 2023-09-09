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

PEARL.SafeModTableExtend("ASSETS", {
    SOCIAL_BUTTONS = {
        TEX = "images/social_buttons.tex",
        ATLAS = "images/social_buttons.atlas",

        TEXTURES = {
            DISCORD         = "discord_button.tex",
            DISCORD_FOCUS   = "discord_button_hover.tex",

            YOUTUBE         = "youtube_button.tex",
            YOUTUBE_FOCUS   = "youtube_button_hover.tex",

            TWITCH          = "twitch_button.tex",
            TWITCH_FOCUS    = "twitch_button_hover.tex",

            AGREEMENT       = "agreement_button.tex",
            AGREEMENT_FOCUS = "agreement_button_hover.tex",
        }
    }
})

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
        if option.zip and type(PEARL.CONFIG[option.name]) == "string" and not PEARL.CONFIG.DEBUG_MODE then
            -- This will be set to nil if unzipping fails
            PEARL.CONFIG[option.name] = UnzipConfigData(option)
        end
    end
end

-- Deprecated
-- PEARL.SafeModTableExtend("CONTROLS", {
--     TOGGLE_CHAT = KEY_F1 -- 282
-- })

----------------------------------
-- Game Extensions
----------------------------------

PEARL.info("Loading game extensions...")
PEARL.loadfile("extensions/modindex")
PEARL.loadfile("extensions/chathistory")

PEARL.loadfile("extensions/scripts/entityscript")

if PEARL.CONFIG.SLASH_COMMANDS then
    PEARL.loadfile("extensions/commands")
end

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

--if PEARL.CONFIG.DEBUG_MODE then
    -- PEARL.OverrideGlobal("CONSOLE_ENABLED", true)
    -- PEARL.OverrideGlobal("DEBUG_MENU_ENABLED", true)
    -- PEARL.OverrideGlobal("DEBUGRENDER_ENABLED", true)
--end

----------------------------------
-- Assets
----------------------------------¨

PEARL.info("Registering assets...")
PEARL.ENV.Assets = {
    Asset("IMAGE", "images/announcement_icons.tex"),
    Asset("ATLAS", "images/announcement_icons.xml"),

    Asset("IMAGE", "images/custom_profile_flairs.tex"),
    Asset("ATLAS", "images/custom_profile_flairs.xml"),

    Asset("IMAGE", "images/social_buttons.tex"),
    Asset("ATLAS", "images/social_buttons.xml"),
}

PEARL.info("Loading preload assets...")
PEARL.ENV.PreloadAssets = {
    Asset("PKGREF", "images/bg_loading_space.tex"),
    Asset("DYNAMIC_ATLAS", "images/bg_loading_space.xml"),
}

PEARL.ENV.ReloadPreloadAssets()

----------------------------------
-- User Interface
----------------------------------

PEARL.info("Loading UI and strings...")

PEARL.POPUPS = {}

PEARL.loadfile("constants/strings")

----------------------------------
-- UI Extensions
----------------------------------

PEARL.info("Loading user interface extensions...")
PEARL.loadfile("extensions/ui/templates")

PEARL.loadfile("extensions/ui/playerlist")
PEARL.loadfile("extensions/ui/consolescreen")
PEARL.loadfile("extensions/ui/playerstatusscreen")

PEARL.loadfile("extensions/ui/loadingwidget")

----------------------------------
-- Other Modules
----------------------------------

PEARL.info("Loading modules...")

--- @type ModuleManager
local ModuleManager = PEARL.loadfile("libraries/modulemanager")
ModuleManager:SetLoader(PEARL.loadfile)
ModuleManager:SetModuleDirectory("modules")

ModuleManager:AddModule("healthinfo", PEARL.CONFIG.HEALTH_INFO.ENABLED)

if PEARL.CONFIG.DEBUG_MODE or not TheNet:GetIsServerAdmin() then
    ModuleManager:AddModule(
        -- Only load the modblocker if we have any mods enabled.
        "modblocker", PEARL.CONFIG.MOD_BLOCKER.ENABLED and KnownModIndex:GetAllEnabledModsCount() > 1
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
