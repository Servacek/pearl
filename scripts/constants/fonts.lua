--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--------------------------------
-- [[ Custom Fonts ]]
--------------------------------

local CUSTOM_FONT_NAMES = {
    DISCORD_EMOJIS = "discord_emojis"
}

local FONTS = {
    VANILLA = {
        ASSETS = GLOBAL.FONTS,
        NAMES = {},
    },

    CUSTOM = {
        ASSETS = {
            {filename = resolvefilepath("fonts/discord_emojis.zip"), alias = CUSTOM_FONT_NAMES.DISCORD_EMOJIS, disable_colour = true}
        },
        NAMES = CUSTOM_FONT_NAMES,
    },

    NAMES = {},
    ASSETS = {},
}

FONTS.NAMES = MergeMaps(FONTS.VANILLA.NAMES, FONTS.CUSTOM.NAMES)
FONTS.ASSETS = MergeMaps(FONTS.VANILLA.ASSETS, FONTS.CUSTOM.ASSETS)

--------------------------------
-- [[ Vanilla Fonts ]]
--------------------------------

local fn = loadfile("fonts")
local env = setmetatable({}, PEARL.ENV_MT)
RunInEnvironmentSafe(fn, env)

for k, v in pairs(env) do
    if type(v) == "string" and type(k) == "string" and k:find("FONT") then
        FONTS.VANILLA.NAMES[k] = v
    end
end

--------------------------------
-- [[ Overrides ]]
--------------------------------

--- Credits to Aly and Whaskalmanik
--- https://steamcommunity.com/sharedfiles/filedetails/?id=3033694168
local BETTER_WORMWOOD_FONT_MODNAME = "workshop-3033694168"

-- We have to actually wait until all mods are loaded to see if it is enabled or not.
PEARL.AddFrontEndPreInit(function()
    local BETTER_WORMWOOD_FONT_DISABLED = not KnownModIndex:IsModEnabled(BETTER_WORMWOOD_FONT_MODNAME) or KnownModIndex:IsModTempDisabled(BETTER_WORMWOOD_FONT_MODNAME)
    if PEARL.CONFIG.BETTER_WORMWOOD_FONT and BETTER_WORMWOOD_FONT_DISABLED then
        local font = table.find(_G.FONTS, function(index, font) return font.alias == TALKINGFONT_WORMWOOD end)
        if font then
            PEARL.info("Overriding default wormwood talking font to a fixed version...")
            font.filename = MODROOT.."fonts/talkingfont_wormwood__0.zip"
            font.alias = "better_"..TALKINGFONT_WORMWOOD
            table.insert(PEARL.ENV.Assets, Asset("FONT", font.filename))

            --AddSimPostInit(LoadFonts)

            _G.TALKINGFONT_WORMWOOD = font.alias
        else
            PEARL.error("Wormwood talking font not found!")
        end
    end
end)

--------------------------------
-- [[ Return ]]
--------------------------------

return FONTS
