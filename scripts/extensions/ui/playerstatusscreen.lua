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
    Extends the player status screen by adding a new discord link button to it.
]]

local PEARL = PEARL
if type(PEARL.CONFIG.DISCORD.INVITE) ~= "string" or #PEARL.CONFIG.DISCORD.INVITE < 3 then
    return
end

local TEMPLATES = require("widgets/redux/templates")

--- @class PlayerStatusScreen
local PlayerStatusScreen = require("screens/playerstatusscreen")

-------------------------------
-- [[ Constants ]]
-------------------------------

local VIEWDC_BUTTON_OFFSET_Y = 2
local VIEWDC_BUTTON_X = -330
local VIEWDC_BUTTON_Y = 200 - VIEWDC_BUTTON_OFFSET_Y

local SCREEN_BUTTONS_OFFSET = 24

local VIEWDC_BUTTON_TEXT_ATLAS = "images/dcbutton.xml"
local VIEWDC_BUTTON_NORMAL_TEX = "dcbutton.tex"
local VIEWDC_BUTTON_FOCUS_TEX = "dcbutton_hover.tex"

-------------------------------
-- [[ Function Extensions ]]
-------------------------------

PEARL.AddClassFunctionPostCall("DoInit", function(self)
    -- This button already exists and was added by something...strange
    if self.viewdiscord_button or not self.root then
        return
    end

    self.servermenunumbtns = (self.servermenunumbtns or 0) + 1

    self.viewdiscord_button = self.root:AddChild(TEMPLATES.LinkButton(
        PEARL.CONFIG.DISCORD.INVITE, STRINGS.PEARL.UI.DISCORD_BUTTON_HOVER,
        VIEWDC_BUTTON_TEXT_ATLAS, VIEWDC_BUTTON_NORMAL_TEX, VIEWDC_BUTTON_FOCUS_TEX
    ))
    self.viewdiscord_button:SetPosition(VIEWDC_BUTTON_X + (self.servermenunumbtns * SCREEN_BUTTONS_OFFSET), VIEWDC_BUTTON_Y)
end, PlayerStatusScreen)
