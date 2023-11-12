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

--- @type UserCommands
local UserCommands = require("usercommands")

local Colour = PEARL.loadfile("libraries/colour")

---------------------------
-- [[ Constants ]]
---------------------------

local WARN_TEXT_SIZE = 20
local WARN_TEXT_COLOUR = Colour.FromRGBA(255, 114, 118)

---------------------------
-- [[ Local Functions ]]
---------------------------

local function AddWhisperWarning(self)
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

---------------------------
-- [[ Overrides ]]
---------------------------

--- @DEBUG
AddClassPostConstruct("screens/chatinputscreen", function(self, whisper)
    if whisper == true and PEARL.CONFIG.WHISPER_WARNING == true then
        AddWhisperWarning(self)
    end

    local permission = COMMAND_PERMISSION.USER
    if TheNet:GetIsServerAdmin() then
        permission = COMMAND_PERMISSION.ADMIN
    end

    -- Setup prediction for our custom slash commands
    local slash_commands = UserCommands.GetCustomCommandsWithFlag("slash")
    for _, v in pairs(self.chat_edit.prediction_widget.word_predictor.dictionaries) do
        if v.delim == PEARL.CONSTS.DELIMS.SLASH_COMMAND then
            for name, command in pairs(slash_commands) do
                -- Only autocomplete the commands we have permission to.
                if command.permission == nil or command.permission == permission then
                    table.insert(v.words, name)
                end
            end
        end
    end

    local userids = {}
    local names = {}
    for _, v in ipairs(AllPlayers) do
        if v and v.userid then
            -- Remove the delim from the userid
            table.insert(userids, v.userid:sub(#PEARL.CONSTS.DELIMS.KLEI_ID + 1))
            table.insert(names, v.name)
        end
    end

    -- Auto-complete for user ids
    self.chat_edit:AddWordPredictionDictionary({
        delim = PEARL.CONSTS.DELIMS.KLEI_ID,
        words = userids,
    })

    -- Auto-complete for player names
    self.chat_edit:AddWordPredictionDictionary({
        delim = PEARL.CONSTS.DELIMS.PLAYER_NAME,
        words = names,
    })
end)
