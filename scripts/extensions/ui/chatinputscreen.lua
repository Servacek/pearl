--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--- @class ChatInputScreen
local ChatInputScreen = require("screens/chatinputscreen")
local Text = require("widgets/text")
local TEMPLATES = require("widgets/redux/templates")

--- @type UserCommands
local UserCommands = require("usercommands")

local EmojiMenu = PEARL.loadfile("widgets/emojimenu")

local Colour = PEARL.loadfile("libraries/datastructures/colour")

---------------------------
-- [[ Constants ]]
---------------------------

local START_BUTTON_SIZE = 35
local START_BUTTON_FOCUS_SIZE = 45

local WARN_TEXT_SIZE = 20
local WARN_TEXT_COLOUR = Colour.FromRGBA(255, 114, 118)

local EMOJI_SET = {
    ["Vanilla"] = PEARL.EMOTES.GetOwnedVanillaEmojis(TheNet:GetUserID()),
    ["Discord"] = PEARL.EMOTES.CUSTOM_GAME,
}

-- Usually, we want the autocompletion to be shown right after the delimeter was typed in.
local COMMAND_PREDICTION_CHARS = 0 -- Commands do not have usually under 2 characters.
local NAME_PREDICTION_CHARS = 0
local USERID_PREDICTION_CHARS = 0

local last_slash_command = nil

---------------------------
-- [[ Local Functions ]]
---------------------------

local function GetRandomEmoji(set)
    return GetRandomItem(GetRandomItem(set))
end

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

local function AddEmojiMenuButton(self)
    local btn = self.chat_edit:AddChild(TEMPLATES.EmojiButton(START_BUTTON_SIZE))
    local x = -465
    if self.chat_type then
        x = x - self.chat_type:GetString():len() * self.chat_type:GetSize() / 3.5
    end
    btn:SetText(GetRandomEmoji(self.emoji_menu.emoji_sets))
    btn:MoveToFront()
    btn:SetPosition(x, 0)
    btn.ongainfocus = function()
        if not self.emoji_menu:IsOpen() then
            btn:SetTextSize(START_BUTTON_FOCUS_SIZE)
            btn:SetText(GetRandomEmoji(self.emoji_menu.emoji_sets))
        end
    end
    btn.onlosefocus = function()
        if not self.emoji_menu:IsOpen() then
            btn:SetTextSize(START_BUTTON_SIZE)
        end
    end
    btn:SetOnClick(function()
        self.emoji_menu:Toggle()
        self.emoji_menu:SetPosition(x + 100, 100)
    end)
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

---------------------------
-- [[ Overrides ]]
---------------------------

local emoji_menu
AddClassPostConstruct("screens/chatinputscreen", function(self, whisper)
    if whisper == true and PEARL.CONFIG.WHISPER_WARNING == true then
        AddWhisperWarning(self)
    end

    if PEARL.CONFIG.EMOJI_MENU then
        self.emoji_menu = self.screen_root:AddChild(EmojiMenu(EMOJI_SET, self.chat_edit))
        self.focus_forward = function()
            if self.emoji_menu:IsOpen() then
                return self.emoji_menu
            end
        end

        AddEmojiMenuButton(self)
    end

    -- Setup prediction for our custom slash commands
    local prediction_widget = self.chat_edit and self.chat_edit.prediction_widget
    local predictor = prediction_widget and prediction_widget.word_predictor
    if prediction_widget and predictor and predictor.dictionaries then
        local expandfn = prediction_widget.expand_btn and prediction_widget.expand_btn.onclick
        if prediction_widget.expanded == true and type(expandfn) == "function" then
            expandfn() -- Minimize the expand widget by default.
        end

        local commands = UserCommands.GetCustomCommandsWithFlag("slash")
        ExpandWordPredictorWithCustomCommands(predictor, commands)
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
        num_chars = USERID_PREDICTION_CHARS,
    })

    -- Auto-complete for player names
    self.chat_edit:AddWordPredictionDictionary({
        delim = PEARL.CONSTS.DELIMS.PLAYER_NAME,
        words = names,
        num_chars = NAME_PREDICTION_CHARS,
    })

    PEARL.AddClassFunctionPreCall("OnRawKey", function(self, key, down)
        if key == KEY_UP then
            if down and self:GetString() == "" then
                self:SetString(last_slash_command)
            end
            return true
        end
    end, self.chat_edit)
end)

PEARL.AddFunctionPostCall("RunTextUserCommand", function(input)
    if input then
        last_slash_command = PEARL.CONSTS.DELIMS.SLASH_COMMAND..tostring(input)
    end
end, UserCommands)
