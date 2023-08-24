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

--- @TODO: Add Icons for AGREEMENT, TWITCH and YOUTUBE
local VIEWDC_BUTTON_TEXT_ATLAS = "images/dcbutton.xml"
local VIEWDC_BUTTON_NORMAL_TEX = "dcbutton.tex"
local VIEWDC_BUTTON_FOCUS_TEX = "dcbutton_hover.tex"

local VIEWAG_BUTTON_OFFSET = 125

local LINK_BUTTON_Y = 18

local LINKS = PEARL.CONFIG.SOCIAL_LINKS or {}

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

    --- Kill those widgets

    if self.title then
        self.title:Kill()
    end

    if self.players_number then
        self.players_number:Kill()
    end

    -- Create the buttons for the freed space

    root.site_buttons = {}
    if LINKS.DISCORD then
        root.site_buttons[#root.site_buttons+1] = root:AddChild(TEMPLATES.LinkButton(
            LINKS.DISCORD, STRINGS.PEARL.UI.SOCIAL_LINK_BUTTON_HOVERS.DISCORD,
            VIEWDC_BUTTON_TEXT_ATLAS, VIEWDC_BUTTON_NORMAL_TEX, VIEWDC_BUTTON_FOCUS_TEX, true
        ))
    end

    if LINKS.YOUTUBE then
        root.site_buttons[#root.site_buttons+1] = root:AddChild(TEMPLATES.LinkButton(
            LINKS.YOUTUBE, STRINGS.PEARL.UI.SOCIAL_LINK_BUTTON_HOVERS.YOUTUBE,
            VIEWDC_BUTTON_TEXT_ATLAS, VIEWDC_BUTTON_NORMAL_TEX, VIEWDC_BUTTON_FOCUS_TEX, true
        ))
    end

    if LINKS.TWITCH then
        root.site_buttons[#root.site_buttons+1] = root:AddChild(TEMPLATES.LinkButton(
            LINKS.TWITCH, STRINGS.PEARL.UI.SOCIAL_LINK_BUTTON_HOVERS.TWITCH,
            VIEWDC_BUTTON_TEXT_ATLAS, VIEWDC_BUTTON_NORMAL_TEX, VIEWDC_BUTTON_FOCUS_TEX, true
        ))
    end

    ---------------------

    -- Do not display the button if we are disabled.
    if PEARL.AgreementManager:IsAgreementScreenEnabled() then
        local button = root:AddChild(TEMPLATES.LinkButton(
            "", STRINGS.PEARL.UI.AGREEMENT_BUTTON_HOVER,
            VIEWDC_BUTTON_TEXT_ATLAS, VIEWDC_BUTTON_NORMAL_TEX, VIEWDC_BUTTON_FOCUS_TEX, true
        ))

        button.__special_offset_x = VIEWAG_BUTTON_OFFSET
        root.site_buttons[#root.site_buttons+1] = button

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
