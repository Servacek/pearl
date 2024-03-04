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

local ImageButton = require("widgets/imagebutton")
local Text = require("widgets/text")
--- @type TEMPLATES
local TEMPLATES = require("widgets/redux/templates")

--- @type UserCommands
local UserCommands = require("usercommands")

--- @type EmojiMenu
local EmojiMenu = PEARL.loadfile("widgets/emojimenu")

local Colour = PEARL.loadfile("libraries/datastructures/colour")

local ClientEmojis = PEARL.loadfile("libraries/clientemojimanager")

local HoverText = require("widgets/hoverer")

---------------------------
-- [[ Constants ]]
---------------------------

local START_BUTTON_SIZE = 35
local START_BUTTON_FOCUS_SIZE = 45

local WARN_TEXT_SIZE = 20
local WARN_TEXT_COLOUR = Colour.FromRGBA(255, 114, 118)

-- Usually, we want the autocompletion to be shown right after the delimeter was typed in.
local COMMAND_PREDICTION_CHARS = 0 -- Commands do not have usually under 2 characters.
local NAME_PREDICTION_CHARS = 0
local USERID_PREDICTION_CHARS = 0

local last_slash_command = nil

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

local function AddEmojiMenuButton(menu)
    -- Let's handle the scaling ourselves.
    -- Make the background bigger so it can be clicked on easier.
    local btn = TEMPLATES.EmojiButton(START_BUTTON_SIZE, false, 20)
    --- @TODO: Add a nice hover text we have control over.
    btn.hover = btn:AddChild(HoverText(ThePlayer))
    btn.hover.text:SetString("View Emojis\n".."(CTRL + Y)")
    --btn:SetHoverText("View Emojis\n".."(CTRL + Y)",{font = NEWFONT_OUTLINE, offset_y = 60, colour = {1,1,1,1}})
    btn:SetText(ClientEmojis:GetRandomEmoji())
    btn:SetOnGainFocus(function()
        if not menu:IsOpen() then
            btn:SetTextSize(START_BUTTON_FOCUS_SIZE)
            btn:SetText(ClientEmojis:GetRandomEmoji())
        end
    end)
    btn:SetOnLoseFocus(function()
        if not menu:IsOpen() then
            btn:SetTextSize(START_BUTTON_SIZE)
        end
    end)
    btn:SetOnClick(function()
        menu:Toggle()

        local pos_x = btn:GetPositionXYZ()
        local w, h = menu.menu.mid_center:GetSize()
        menu:SetPosition(pos_x + w / 2.5, h - 25)
    end)

    return btn
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

AddClassPostConstruct("screens/chatinputscreen", function(self, whisper)
    if whisper == true and PEARL.CONFIG.WHISPER_WARNING == true then
        AddWhisperWarning(self)
    end

    if PEARL.CONFIG.EMOJI_MENU and ClientEmojis:HasAnyEmojis() then
        local _bg = self.chat_edit:AddChild(ImageButton("images/global.xml", "square.tex"))
        _bg.image:SetVRegPoint(ANCHOR_MIDDLE)
        _bg.image:SetHRegPoint(ANCHOR_MIDDLE)
        _bg.image:SetVAnchor(ANCHOR_MIDDLE)
        _bg.image:SetHAnchor(ANCHOR_MIDDLE)
        _bg.image:SetScaleMode(SCALEMODE_FILLSCREEN)
        _bg.image:SetTint(0,0,0,0)
        _bg:SetHelpTextMessage("")
        _bg:MoveToFront()
        _bg:Hide()

        self.emoji_menu = self.screen_root:AddChild(EmojiMenu())
        self.emoji_menu:LoadEmojiCategories(ClientEmojis.CATEGORIES_ORDERED)
        self.emoji_menu:MoveToFront()

        _bg:SetOnClick(function()
            if self.emoji_menu:IsOpen() then
                self.emoji_menu:Close()
            end
        end)

        self.focus_forward = function()
            if self.emoji_menu:IsOpen() then
                return self.emoji_menu
            end
        end

        self.emoji_menu_button = self.chat_edit:AddChild(AddEmojiMenuButton(self.emoji_menu))
        local x = -465
        if self.chat_type then
            x = x - self.chat_type:GetString():len() * self.chat_type:GetSize() / 3.5
        end
        self.emoji_menu_button:SetPosition(x, 0)
        self.emoji_menu_button:MoveToFront()

        self.chat_edit._insert_index = 1
        self.emoji_menu.onopen = function()
            self.chat_edit:SetEditing(false)
            self.chat_edit:ClearFocus()

            if self.emoji_menu_button.hovertext_root then
                self.emoji_menu_button.hovertext_root:Hide()
            end

            self.chat_edit._insert_index = self.chat_edit.inst.TextEditWidget:GetEditCursorPos() or 1
            _bg:Show()
        end

        self.emoji_menu.onclose = function()
            self.chat_edit:SetEditing(true)
            self.chat_edit.inst.TextEditWidget:SetEditCursorPos(self.chat_edit._insert_index)

            _bg:Hide()

            -- The button is in it's focused state until the menu is closed.
            if not self.emoji_menu_button.focus then
                self.emoji_menu_button:OnLoseFocus()
            end

            if self.emoji_menu_button.hovertext_root and self.emoji_menu_button.focus then
                self.emoji_menu_button.hovertext_root:Show()
            end
        end

        self.emoji_menu.onemojichosen = function(emoji)
            local str = self.chat_edit:GetString()
            self.chat_edit:SetString(str:sub(1, self.chat_edit._insert_index)..emoji.." "..str:sub(self.chat_edit._insert_index + 1))
            self.chat_edit._insert_index = self.chat_edit._insert_index + emoji:len() + 1
        end

        if TheInput:IsKeyDown(KEY_CTRL) then
            -- Make sure this widget is completely initialized.
            PEARL.StaticScheduler:ExecuteInTime(0, self.emoji_menu_button.onclick)
        end
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

PEARL.EventProcessor:AddSafeEventHandler("emojis_used", function(emojis)
    local emoji_data_cache = EmojiMenu.GetCachedData()
    local target_cache = emoji_data_cache[ClientEmojis.CATEGORIES_ORDERED]
    if target_cache then
        EmojiMenu.UpdateEmojiCategory(ClientEmojis.BASIC_CATEGORY.FREQUENTLY_USED, target_cache)
    end
end)
