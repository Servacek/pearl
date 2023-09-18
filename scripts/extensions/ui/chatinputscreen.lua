--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]





--- @class ChatInputScreen
local ChatInputScreen = require("screens/chatinputscreen")
local Text = require("widgets/text")

local Colour = PEARL.loadfile("libraries/colour")

---------------------------
-- [[ Constants ]]
---------------------------

local WARN_TEXT_SIZE = 20
local WARN_TEXT_COLOUR = Colour.FromRGBA(255, 114, 118)

---------------------------
-- [[ Local Functions ]]
---------------------------

local function AddWhisperWarning()
    PEARL.AddClassPostConstruct("screens/chatinputscreen", function(self, whisper)
        if whisper and PEARL.CONFIG.WHISPER_WARNING then
            local control = CONTROL_TOGGLE_SAY
            local controllerid = TheInput:GetControllerID()
            local controltocheck = TheInput:ControllerAttached() and LOADING_SCREEN_CONTROLLER_ID_LOOKUP[control] or control
            local controlstring = TheInput:GetLocalizedControl(controllerid, controltocheck)

            local whisper_warn_label = self.root:AddChild(Text(TALKINGFONT, WARN_TEXT_SIZE))
            whisper_warn_label:SetPosition(-200, -30, 0)
            whisper_warn_label:SetHAlign(ANCHOR_RIGHT)
            whisper_warn_label:SetString(STRINGS.PEARL.UI.WHISPER_WARN_TEXT:format(controlstring))
            whisper_warn_label:SetColour(WARN_TEXT_COLOUR)
        end
    end)
end

---------------------------
-- [[ Setup ]]
---------------------------

if PEARL.CONFIG.WHISPER_WARNING == true then
    AddWhisperWarning()
end
