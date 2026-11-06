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
    Extends the chatinput screen by adding:
        - A warning for whisper messages so new players do not get confused.
        - Autocomplete for custom slash commands.
        - Autocomplete for player names and user ids in commands.
        - Slash command history for the last command typed in.
--]]


--- @class ChatInputScreen
local ChatInputScreen = require("screens/chatinputscreen")

require("frontend")

local Text = require("widgets/text")

--- @type UserCommands
local UserCommands = require("usercommands")

local Colour = PEARL.loadfile("libraries/datastructures/colour")

---------------------------
-- [[ Constants ]]
---------------------------

local WARN_TEXT_SIZE = 20
local WARN_TEXT_COLOUR = Colour.FromRGBA(255, 114, 118)

-- Usually, we want the autocompletion to be shown right after the delimeter was typed in.
local COMMAND_PREDICTION_CHARS = 0 -- Commands do not have usually under 2 characters.
local NAME_PREDICTION_CHARS = 0
local USERID_PREDICTION_CHARS = 0

---------------------------
-- [[ Local Variables ]]
---------------------------

local last_slash_command, _
local _RunTextUserCommand

---------------------------
-- [[ Handler Extensions ]]
---------------------------

local function ExtendRunTextCommand(input)
    if type(input) == "string" then
        last_slash_command = PEARL.CONSTS.DELIMS.SLASH_COMMAND..input
    end
end

---------------------------
-- [[ Local Functions ]]
---------------------------

local function GetSayControl()
    local control = CONTROL_TOGGLE_SAY
    local controllerid = TheInput:GetControllerID()
    local controltocheck = TheInput:ControllerAttached() and LOADING_SCREEN_CONTROLLER_ID_LOOKUP[control] or control
    return TheInput:GetLocalizedControl(controllerid, controltocheck)
end

local function AddWhisperWarning(self)
    local whisper_warn_label = self.root:AddChild(Text(TALKINGFONT, WARN_TEXT_SIZE))
    whisper_warn_label:SetPosition(-200, -30, 0)
    whisper_warn_label:SetHAlign(ANCHOR_RIGHT)
    whisper_warn_label:SetString(STRINGS.PEARL.UI.WHISPER_WARN_TEXT:format(GetSayControl()))
    whisper_warn_label:SetColour(WARN_TEXT_COLOUR)
end

local function ExpandWordPredictorWithCustomCommands(predictor, commands)
    local permission = UserCommands.GetPermissionLevel(
        TheNet:GetIsServerAdmin() and COMMAND_PERMISSION.ADMIN or COMMAND_PERMISSION.USER
    )

    for _, v in pairs(predictor.dictionaries) do
        if v.delim == PEARL.CONSTS.DELIMS.SLASH_COMMAND then
            v.num_chars = COMMAND_PREDICTION_CHARS

            for name, command in pairs(commands) do
                local commandpermission = UserCommands.GetPermissionLevel(command.permission)

                -- Only autocomplete the commands we have permission to.
                if permission >= commandpermission and not table.contains(v.words, name) then
                    table.insert(v.words, name)
                end
            end

            break -- Extend only once
        end
    end
end

local function AutocompletePlayersForCommands(chat_edit)
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
    chat_edit:AddWordPredictionDictionary({
        delim = PEARL.CONSTS.DELIMS.KLEI_ID,
        words = userids,
        num_chars = USERID_PREDICTION_CHARS,
    })

    -- Auto-complete for player names
    chat_edit:AddWordPredictionDictionary({
        delim = PEARL.CONSTS.DELIMS.PLAYER_NAME,
        words = names,
        num_chars = NAME_PREDICTION_CHARS,
    })
end

local function AutocompleteCustomCommands(chat_edit)
    -- Setup prediction for our custom slash commands
    local prediction_widget = chat_edit.prediction_widget
    local predictor = prediction_widget and prediction_widget.word_predictor
    if prediction_widget and predictor and predictor.dictionaries then
        local expandfn = prediction_widget.expand_btn and prediction_widget.expand_btn.onclick
        if prediction_widget.expanded == true and type(expandfn) == "function" then
            expandfn() -- Minimize the expand widget by default.
        end

        local commands = UserCommands.GetCustomCommandsWithFlag(UserCommands.FLAG.SLASH)
        ExpandWordPredictorWithCustomCommands(predictor, commands)
    end
end

local function AddSlashCommandHistory(chat_edit)
    local _OnRawKey = chat_edit.OnRawKey
    chat_edit.OnRawKey = function(self, key, down)
        if key == KEY_UP and chat_edit:IsEditing() then
            if down and chat_edit:GetString() == "" then
                chat_edit:SetString(last_slash_command)
            end

            return true
        end

        return _OnRawKey(chat_edit, key, down)
    end

    if _RunTextUserCommand == nil then
        _, _RunTextUserCommand = PEARL.AddFunctionPostCall(
            "RunTextUserCommand", ExtendRunTextCommand, UserCommands
        )
    end
end

---------------------------
-- [[ Overrides ]]
---------------------------

AddClassPostConstruct("screens/chatinputscreen", function(self, whisper)
    if whisper == true and PEARL.CONFIG.WHISPER_WARNING == true then
        AddWhisperWarning(self)
    end

    -- Setup prediction for our custom slash commands
    AutocompleteCustomCommands(self.chat_edit)

    if PEARL.CONFIG.CUSTOM_CHAT_AUTOCOMPLETE then
        AutocompletePlayersForCommands(self.chat_edit)
    end

    if PEARL.CONFIG.SLASH_COMMAND_HISTORY then
        AddSlashCommandHistory(self.chat_edit)
    end
end)
