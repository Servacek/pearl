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
    Adds a bunch of link buttons above the player list on the left side of the lobby screen.
--]]

---------------------------

local TEMPLATES = require("widgets/redux/templates")
local AgreementScreen = PEARL.loadfile("screens/agreementscreen")

--- @class PlayerList
local PlayerList = require("widgets/redux/playerlist")

---------------------------
-- [[ Constants ]]
---------------------------

local SCREEN_BUTTON_SIZE = 40
local SCREEN_BUTTON_SPACING = 5
local SCREEN_BUTTON_OFFSET = -190

local ATLAS = PEARL.ASSETS.SOCIAL_BUTTONS.ATLAS

local VIEWAG_BUTTON_OFFSET = 125

local LINK_BUTTON_Y = 18

local LINKS = PEARL.CONFIG.SOCIAL_LINKS or {}

local SHOW_HOVER_BELOW = true

-- Default to discord if texture not found.
-- Weird but still better than just crashing...
local DEFAULT_TEXTURE = PEARL.ASSETS.SOCIAL_BUTTONS.TEXTURES.DISCORD

---------------------------
-- [[ Local Functions ]]
---------------------------

local function AddSocialButton(root, link, hover, normal, focus)
    normal = normal or DEFAULT_TEXTURE
    focus = focus or io.noext(normal).."_hover.tex"

    return root:AddChild(TEMPLATES.LinkButton(
        link, hover, ATLAS, normal, focus, SHOW_HOVER_BELOW
    ))
end

---------------------------
-- [[ Init ]]
---------------------------

if table.empty(LINKS) and not PEARL.AgreementManager:IsAgreementScreenEnabled()then
    return -- Nothing to be displayed.
end

PEARL.AddClassPostConstruct("widgets/redux/playerlist", function(self)
    local root = self.player_list
    if not root then
        return
    end

    -- Create the buttons for the freed space

    root.site_buttons = {}
    if LINKS.DISCORD then
        root.site_buttons[#root.site_buttons+1] = AddSocialButton(root,
            LINKS.DISCORD, STRINGS.PEARL.UI.SOCIAL_LINK_BUTTON_HOVERS.DISCORD,
            PEARL.ASSETS.SOCIAL_BUTTONS.TEXTURES.DISCORD
        )
    end

    if LINKS.YOUTUBE then
        root.site_buttons[#root.site_buttons+1] = AddSocialButton(root,
            LINKS.YOUTUBE, STRINGS.PEARL.UI.SOCIAL_LINK_BUTTON_HOVERS.YOUTUBE,
            PEARL.ASSETS.SOCIAL_BUTTONS.TEXTURES.YOUTUBE
        )
    end

    if LINKS.TWITCH then
        root.site_buttons[#root.site_buttons+1] = AddSocialButton(root,
            LINKS.TWITCH, STRINGS.PEARL.UI.SOCIAL_LINK_BUTTON_HOVERS.TWITCH,
            PEARL.ASSETS.SOCIAL_BUTTONS.TEXTURES.TWITCH
        )
    end

    -- Free up the space for the buttons
    if #root.site_buttons > 0 and self.title then
        self.title:Kill()
    end

    ---------------------

    -- Do not display the button if we are disabled.
    if PEARL.AgreementManager:IsAgreementScreenEnabled() then
        local button = AddSocialButton(root,
            "", STRINGS.PEARL.UI.AGREEMENT_BUTTON_HOVER,
            PEARL.ASSETS.SOCIAL_BUTTONS.TEXTURES.AGREEMENT
        )

        button.__special_offset_x = VIEWAG_BUTTON_OFFSET
        root.site_buttons[#root.site_buttons+1] = button

        if self.players_number then
            self.players_number:Kill()
        end

        -- Override the default callback
        root.site_buttons[#root.site_buttons]:SetOnClick(function()
            -- Create a readonly agreement screen
            TheFrontEnd:PushScreen(AgreementScreen(true))
        end)
    end

    ----------------------------------------------------

    -- Dynamically calculate button postions.
    for i = 1, #root.site_buttons do
        local button = root.site_buttons[i]

        -- Apply special offset for the X axis for buttons that require it.
        local x = SCREEN_BUTTON_OFFSET + (SCREEN_BUTTON_SIZE + SCREEN_BUTTON_SPACING) * i
        if type(button.__special_offset_x) == "number" then
            x = x + button.__special_offset_x
        end

        button:SetPosition(
            x, LINK_BUTTON_Y
        )
    end
end)
