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

local VIEWDC_BUTTON_TEXT_ATLAS = "images/dcbutton.xml"
local VIEWDC_BUTTON_NORMAL_TEX = "dcbutton.tex"
local VIEWDC_BUTTON_FOCUS_TEX = "dcbutton_hover.tex"

local VIEWAG_BUTTON_OFFSET = 125

local LINK_BUTTON_Y = 18

local PLAYERLIST_PADDING_TOP = -5

---------------------------
-- [[ Init ]]
---------------------------

PEARL.AddClassPostConstruct("widgets/redux/playerlist", function(self)
    local root = self.player_list
    if not root then
        return
    end

    --- Kill those widgets

    if self.title then
        self.title:Kill()
    end

    if self.players_number then
        self.players_number:Kill()
    end

    -- Create the buttons for the freed space

    root.site_buttons = {}
    if not self.viewdiscord_button then
        root.site_buttons[#root.site_buttons+1] = root:AddChild(TEMPLATES.LinkButton(
            PEARL.CONFIG.DISCORD.INVITE, STRINGS.PEARL.UI.DISCORD_BUTTON_HOVER,
            VIEWDC_BUTTON_TEXT_ATLAS, VIEWDC_BUTTON_NORMAL_TEX, VIEWDC_BUTTON_FOCUS_TEX, true
        ))
    end

    if not self.viewyoutube_button then
        root.site_buttons[#root.site_buttons+1] = root:AddChild(TEMPLATES.LinkButton(
            PEARL.CONFIG.DISCORD.INVITE, STRINGS.PEARL.UI.DISCORD_BUTTON_HOVER,
            VIEWDC_BUTTON_TEXT_ATLAS, VIEWDC_BUTTON_NORMAL_TEX, VIEWDC_BUTTON_FOCUS_TEX, true
        ))
    end

    if not self.viewtwitchbutton then
        root.site_buttons[#root.site_buttons+1] = root:AddChild(TEMPLATES.LinkButton(
            PEARL.CONFIG.DISCORD.INVITE, STRINGS.PEARL.UI.DISCORD_BUTTON_HOVER,
            VIEWDC_BUTTON_TEXT_ATLAS, VIEWDC_BUTTON_NORMAL_TEX, VIEWDC_BUTTON_FOCUS_TEX, true
        ))
    end

    if not self.viewagreement_button then
        root.site_buttons[#root.site_buttons+1] = root:AddChild(TEMPLATES.LinkButton(
            PEARL.CONFIG.DISCORD.INVITE, STRINGS.PEARL.UI.DISCORD_BUTTON_HOVER,
            VIEWDC_BUTTON_TEXT_ATLAS, VIEWDC_BUTTON_NORMAL_TEX, VIEWDC_BUTTON_FOCUS_TEX, true
        ))

        -- Override the default callback
        root.site_buttons[#root.site_buttons]:SetOnClick(function()
            -- Create a readonly agreement screen
            TheFrontEnd:PushScreen(AgreementScreen(true))
        end)
    end

    for i = 1, #root.site_buttons do
        local x = SCREEN_BUTTON_OFFSET + (SCREEN_BUTTON_SIZE + SCREEN_BUTTON_SPACING) * i

        -- Add some additional offset for the last button - The Agreement Button
        if i == #root.site_buttons then
            x = x + VIEWAG_BUTTON_OFFSET
        end

        local button = root.site_buttons[i]

        button:SetPosition(
            x, LINK_BUTTON_Y
        )

        -- Make the hover text display underneath the button because we are too high
        -- if button.hovertext then
        --     local hovertext_string = button.hovertext:GetString()
        --     button.hovertext:Kill()
        --     button.hovertext = nil

        --     button:SetHoverText(hovertext_string, {
        --         offset_y = -SCREEN_BUTTON_SIZE - 26
        --     })
        -- end
    end
end)
