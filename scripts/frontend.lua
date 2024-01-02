--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
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
})

local LT_TYPES = PEARL.CONSTS.LT_TYPES
PEARL.CONSTS.LT_TYPE_TABLES = {
    [LT_TYPES.SURVIVAL]    = STRINGS.UI.LOADING_SCREEN_SURVIVAL_TIPS,
    [LT_TYPES.LORE]        = STRINGS.UI.LOADING_SCREEN_LORE_TIPS,
    [LT_TYPES.CONTROLS]     = STRINGS.UI.LOADING_SCREEN_CONTROL_TIPS,
    [LT_TYPES.CONSOLE]     = STRINGS.UI.LOADING_SCREEN_CONTROL_TIPS_CONSOLE,
    [LT_TYPES.NOCONSOLE]   = STRINGS.UI.LOADING_SCREEN_CONTROL_TIPS_NOT_CONSOLE,
    [LT_TYPES.OTHER]       = STRINGS.UI.LOADING_SCREEN_OTHER_TIPS,

    -- Loadings tips for new players.
    [LT_TYPES.WELCOME]     = STRINGS.UI.LOADING_SCREEN_OTHER_TIPS,
}

PEARL.SafeModTableExtend("ASSETS", {
    PROFILE_FLAIRS = {
        TEX   = "images/custom_profile_flairs.tex",
        ATLAS = "images/custom_profile_flairs.xml",

        TEXTURES = {
            DISCORD = "discord.tex"
        }
    },

    ANNOUNCEMENT_ICONS = {
        TEX   = "images/announcement_icons.tex",
        ATLAS = "images/announcement_icons.xml",
    },

    SOCIAL_BUTTONS = {
        TEX   = "images/social_buttons.tex",
        ATLAS = "images/social_buttons.xml",

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
    local success, data = PEARL.SafeRun(TheSim.DecodeAndUnzipString, TheSim, PEARL.GetConfigData(option.name))

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

--- @TODO: Most of this is redundant
PEARL.info("Loading Configuration...")
for _, option in ipairs(PEARL.MOD_INFO.configuration_options) do
    -- Apply server changes to our public options.
    if option.public == true then
        -- No ZIPing in debug mode.
        if option.zip and type(PEARL.CONFIG[option.name]) == "string" and not PEARL.CONFIG.DEBUG_MODE then
            PEARL.CONFIG[option.name] = UnzipConfigData(option)
        else
            PEARL.CONFIG[option.name] = PEARL.GetConfigData(option.name)
        end
    end
end

----------------------------------
-- Game Extensions
----------------------------------

PEARL.info("Loading game extensions...")
PEARL.loadfile("extensions/modindex")
PEARL.loadfile("extensions/chathistory")
PEARL.loadfile("extensions/input")

PEARL.loadfile("extensions/scripts/entityscript")

PEARL.loadfile("extensions/usercommands")
if PEARL.CONFIG.SLASH_COMMANDS then
    PEARL.loadfile("extensions/commands")
end

----------------------------------
-- Agreement Manager
----------------------------------

--- @type AgreementManager
PEARL.AgreementManager = PEARL.loadfile("libraries/agreementmanager")
if PEARL.AgreementManager:FileExists() then
    PEARL.AgreementManager:Load()
end

----------------------------------
-- Client Loader
----------------------------------

PEARL.info("Loading client loader...")

--- @type ClientLoader
PEARL.ClientLoader = PEARL.loadfile("clientloader")

----------------------------------
-- Client Network
----------------------------------

PEARL.info("Loading client network...")

--- @type ClientNetwork
PEARL.ClientNetwork = PEARL.loadfile("clientnetwork")

----------------------------------
-- FrontEnd Debug Mode
----------------------------------

-- if PEARL.CONFIG.DEBUG_MODE then
--     PEARL.OverrideGlobal("CONSOLE_ENABLED", true)
--     PEARL.OverrideGlobal("DEBUG_MENU_ENABLED", true)
--     PEARL.OverrideGlobal("DEBUGRENDER_ENABLED", true)
-- end

----------------------------------
-- Assets
----------------------------------

--- @ISSUES:
--- - If the texture displays as a black rectangle
---  there is probably some issue with the atlas file
---  not having some margin around other textures.
---  For multiple textures in one .tex file,
---  it should have at least one pixel spacing between each image
---  To prevent "bleeding".
---  Also sometimes just updating the file generator fixes this issue.
---
--- - If the texture displays as some grey-ish noisy image
--- - the .TEX file it points do doesn't exist (make sure filename matches the actual name).
---
--- - Most of the time the textures should not start X at 0 but something like 0.009685

PEARL.info("Registering assets...")
PEARL.ENV.Assets = {
    Asset("IMAGE", PEARL.ASSETS.ANNOUNCEMENT_ICONS.TEX),
    Asset("ATLAS", PEARL.ASSETS.ANNOUNCEMENT_ICONS.ATLAS),

    Asset("IMAGE", PEARL.ASSETS.PROFILE_FLAIRS.TEX),
    Asset("ATLAS", PEARL.ASSETS.PROFILE_FLAIRS.ATLAS),

    Asset("IMAGE", PEARL.ASSETS.SOCIAL_BUTTONS.TEX),
    Asset("ATLAS", PEARL.ASSETS.SOCIAL_BUTTONS.ATLAS),
}

PEARL.info("Loading preload assets...")
PEARL.ENV.PreloadAssets = {
    Asset("PKGREF", "images/bg_loading_space.tex"),
    Asset("DYNAMIC_ATLAS", "images/bg_loading_space.xml"),

    --Asset("PKGREF", "movies/test_video.ogv")
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
PEARL.loadfile("extensions/ui/chatinputscreen")

PEARL.loadfile("extensions/ui/loadingwidget")

----------------------------------
-- Mod Fixes
----------------------------------

-- Loaded after frontend so all mods should be initialized and loaded at this point.
PEARL.AddFrontEndPostInit(function()
    local modnames = ModManager:GetEnabledModNames()
    if modnames and #modnames > 1 then
        PEARL.debug("Loading mod fixes...")

        local ExtensionManager = PEARL.loadfile("libraries/extensionmanager")

        -- Auto-Unequip mod fix
        ExtensionManager:FixMods("autounequip", {"1581892848"})
    end
end)

----------------------------------
-- Other Modules
----------------------------------

PEARL.info("Loading modules...")

--- @type ModuleManager
local ModuleManager = PEARL.loadfile("libraries/modulemanager")
ModuleManager:SetLoader(PEARL.loadfile)
ModuleManager:SetModuleDirectory("modules")

ModuleManager:AddModule("healthinfo", PEARL.CONFIG.HEALTH_INFO.ENABLED)
ModuleManager:AddModule("languageserver", PEARL.CONFIG.LANGUAGE_SERVER.ENABLED and PEARL.CONFIG.LANGUAGE_SERVER.URL and PEARL.CONFIG.LANGUAGE_SERVER.LANGUAGE)

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
        "commandblocker", table.empty(PEARL.CONFIG.COMMAND_BLOCKLIST) == false or type(PEARL.CONFIG.MIN_VOTE_AGE) == "number"
    )
end

ModuleManager:LoadAllModules()

PEARL.info("Done")
