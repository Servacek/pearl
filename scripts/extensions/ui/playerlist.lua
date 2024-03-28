--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
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

local LAST_BUTTON_OFFSET_X = 125
local FIRST_BUTTON_HOVER_OFFSET_X = 65

local LINK_BUTTON_Y = 18

local LINKS = PEARL.CONFIG.SOCIAL_LINKS or {}

---------------------------
-- [[ Init ]]
---------------------------

if table.empty(LINKS) and not PEARL.AgreementManager:IsAgreementScreenEnabled()then
    return -- Nothing to be displayed.
end

-- This one is always rebuilt so we do not have to worry about duplication.
PEARL.AddClassPostConstruct("widgets/redux/playerlist", function(self)
    local root = self.player_list
    if not root then
        return
    end

    if self._buttons == nil then
        self._buttons = TEMPLATES.GetSocialLinkButtons(root, true)

        local btn1 = self._buttons[1]
        if btn1 ~= nil and btn1.hover_data then
            -- So the hover is visible even in fullscreen.
            btn1.hover_data.offset_x = btn1.hover_data.offset_x + FIRST_BUTTON_HOVER_OFFSET_X
        end
    end

    -- Free up the space for the buttons
    if table.empty(self._buttons) == false and self.title then
        self.title:Hide() -- Use hide here instead of Kill to prevent stale reference
    end

    ---------------------

    -- Do not display the button if we are disabled.
    if PEARL.AgreementManager:IsAgreementScreenEnabled() then
        local button = TEMPLATES.AddSocialButton(root,
            "", STRINGS.PEARL.UI.AGREEMENT_BUTTON_HOVER,
            PEARL.ASSETS.SOCIAL_BUTTONS.TEXTURES.AGREEMENT, nil, true
        )

        button.__special_offset_x = LAST_BUTTON_OFFSET_X
        self._buttons[#self._buttons+1] = button

        if self.players_number then
            self.players_number:Hide() -- Use hide here instead of Kill to prevent stale reference
        end

        -- Override the default callback
        self._buttons[#self._buttons]:SetOnClick(function()
            -- Create a readonly agreement screen
            TheFrontEnd:PushScreen(AgreementScreen(true))
        end)
    end

    ----------------------------------------------------

    -- Dynamically calculate button postions.
    for i = 1, #self._buttons do
        local button = self._buttons[i]

        -- Apply special offset for the X axis for buttons that require it.
        local x = SCREEN_BUTTON_OFFSET + (SCREEN_BUTTON_SIZE + SCREEN_BUTTON_SPACING) * i
        if type(button.__special_offset_x) == "number" then
            x = x + button.__special_offset_x
        end

        button:SetPosition(x, LINK_BUTTON_Y)
    end
end)
