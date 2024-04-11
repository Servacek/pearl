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

require("frontend")

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

---------------------------
-- [[ Constants ]]
---------------------------

local EMOJI_MENU_BUTTON_SIZE = 35
local EMOJI_MENU_BUTTON_FOCUS_SIZE = 45
local EMOJI_MENU_BUTTON_OFFSET_X = 0
local EMOJI_MENU_BUTTON_OFFSET_Y = 60
local EMOJI_MENU_BUTTON_ALIGN_RIGHT = true

local CONTROL_MODIFIER = "Ctrl"

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
local _OnRawKey, _RunTextUserCommand, _OnControl

---------------------------
-- [[ Handler Extensions ]]
---------------------------

local function ExtendRunTextCommand(input)
    if type(input) == "string" then
        last_slash_command = PEARL.CONSTS.DELIMS.SLASH_COMMAND..input
    end
end

local function ExtendedOnRawKey(self, key, down, ...)
    local active_screen = self:GetActiveScreen()
    if active_screen and ChatInputScreen.is_instance(active_screen) and active_screen.emoji_menu then
        if TheInput:IsKeyDown(KEY_CTRL) then
            if not down and key == KEY_Y and active_screen.emoji_menu_button then
                active_screen.emoji_menu_button.onclick()
            else
                return active_screen.emoji_menu:OnRawKey(key, down, ...)
            end

            return true
        end
    end

    return _OnRawKey(self, key, down, ...)
end

local function ExtendedOnControl(self, control, down, ...)
    local active_screen = self:GetActiveScreen()
    if active_screen and ChatInputScreen.is_instance(active_screen) then
        active_screen.emoji_menu:OnControl(control, down, ...)
    end

    return _OnControl(self, control, down, ...)
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

local last_button_emoji
local followhandler = TheInput:AddMoveHandler(function(x, y) end)
local function AddEmojiMenuButton(menu)
    -- Let's handle the scaling ourselves.
    -- Make the background bigger so it can be clicked on easier.
    local btn = TEMPLATES.EmojiButton(EMOJI_MENU_BUTTON_SIZE, false, 20)
    btn._hovertext = menu.parent:AddChild(Text(UIFONT, 30))
    btn._hovertext:SetString(STRINGS.PEARL.UI.EMOJI_MENU.OPEN_BUTTON_HOVER:format(
        CONTROL_MODIFIER.." + "..GetSayControl()
    ))
    btn._hovertext:SetScaleMode(SCALEMODE_PROPORTIONAL)
    btn._hovertext:Hide()

    btn._time = GetTime()

    btn._hovertext._UpdatePosition = function(self, x, y)
        if not x or y then
            local pos = TheInput:GetScreenPosition()
            x, y = pos.x, pos.y
        end

        self:SetPosition(
            x + EMOJI_MENU_BUTTON_OFFSET_X, y + EMOJI_MENU_BUTTON_OFFSET_Y, 0
        )
    end

    btn._hovertext:_UpdatePosition()

    followhandler.fn = function(x, y)
        if btn._hovertext.inst.widget ~= nil then
            btn._hovertext:_UpdatePosition(x, y)
        end
    end

    btn.ScaleUp = function() btn:SetTextSize(EMOJI_MENU_BUTTON_FOCUS_SIZE)end
    btn.ScaleDown = function() btn:SetTextSize(EMOJI_MENU_BUTTON_SIZE) end

    last_button_emoji = last_button_emoji or ClientEmojis:GetRandomEmoji()
    btn:SetText(last_button_emoji)
    btn:SetOnGainFocus(function()
        btn:ScaleUp()

        if not menu:IsOpen() then
            btn._hovertext:Show()

            -- So this wont flicker in case the cursor is over right from the start.
            if not menu.closing and GetTime() - btn._time > 1 then
                local new_emoji = ClientEmojis:GetRandomEmoji()
                btn:SetText(new_emoji)

                last_button_emoji = new_emoji
            end
        end
    end)
    btn:SetOnLoseFocus(function()
        if not menu:IsOpen() and not menu.closing then
            btn:ScaleDown()
        end

        btn._hovertext:Hide()
    end)
    btn:SetOnClick(function()
        menu:Toggle()

        local pos_x = btn:GetPositionXYZ()
        local w, h = (menu.menu.mid_center or menu.menu):GetSize()
        menu:SetPosition(pos_x + w / 4.5, h)
    end)

    if FrontEnd.OnRawKey ~= ExtendedOnRawKey then
        _OnRawKey = PEARL.OverrideValue(FrontEnd, "OnRawKey", ExtendedOnRawKey)
    end

    if FrontEnd.OnControl ~= ExtendedOnControl then
        _OnControl = PEARL.OverrideValue(FrontEnd, "OnControl", ExtendedOnControl)
    end

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

local function AddEmojiMenu(self)
    local _bg = self.chat_edit:AddChild(ImageButton("images/global.xml", "square.tex"))
    _bg.image:SetVRegPoint(ANCHOR_MIDDLE)
    _bg.image:SetHRegPoint(ANCHOR_MIDDLE)
    _bg.image:SetVAnchor(ANCHOR_MIDDLE)
    _bg.image:SetHAnchor(ANCHOR_MIDDLE)
    _bg.image:SetScaleMode(SCALEMODE_FILLSCREEN)
    _bg.image:SetTint(0,0,0,0)
    _bg:SetHelpTextMessage("")
    _bg:MoveToFront()
    _bg:Select() -- So no hover sound
    _bg.AllowOnControlWhenSelected = true
    _bg:Hide()

    self.emoji_menu = self.screen_root:AddChild(EmojiMenu())
    self.emoji_menu:LoadEmojiCategories(ClientEmojis.CATEGORIES_ORDERED)
    self.emoji_menu:MoveToFront()

    _bg:SetOnClick(function()
        if self.emoji_menu:IsOpen() then
            self.emoji_menu:Close()
        end
    end)

    _bg.focus_forward = function()
        if self.emoji_menu:IsOpen() then
            return self.emoji_menu
        end
    end

    self.emoji_menu_button = self.chat_edit:AddChild(AddEmojiMenuButton(self.emoji_menu))
    local x = 0
    if EMOJI_MENU_BUTTON_ALIGN_RIGHT then
        x = (self.chat_edit:GetRegionSize() / 2) + 50
    else
        x = -465
        if self.chat_type then
            x = x - self.chat_type:GetString():len() * self.chat_type:GetSize() / 3.5
        end
    end
    self.emoji_menu_button:SetPosition(x, 0)
    self.emoji_menu_button:MoveToFront()

    local insert_index = 1
    self.emoji_menu.onopen = function()
        self.chat_edit:SetEditing(false)
        self.chat_edit:ClearFocus()

        if self.emoji_menu_button.hovertext_root then
            self.emoji_menu_button.hovertext_root:Hide()
        end

        insert_index = self.chat_edit.inst.TextEditWidget:GetEditCursorPos() or 1
        _bg:Show()

        if not self.emoji_menu_button.focus then
            self.emoji_menu_button:OnGainFocus()
        end
    end

    self.emoji_menu.onclosing = function()
        self.chat_edit:SetEditing(true)
        self.chat_edit.inst.TextEditWidget:SetEditCursorPos(insert_index)

        _bg:Hide()
        _bg:SetFocus()
    end

    self.emoji_menu.onclose = function()
        -- The button is in it's focused state until the menu is closed.
        if not self.emoji_menu_button.focus then
            self.emoji_menu_button:OnLoseFocus()
        end
    end

    self.emoji_menu.onemojichosen = function(emoji)
        local str = self.chat_edit:GetString()
        local add_str = emoji.." "
        local new_str = str:sub(1, insert_index)..add_str..str:sub(insert_index + 1)

        -- Only append if the
        if new_str:utf8len() < (self.chat_edit.limit or MAX_CHAT_INPUT_LENGTH) then
            self.chat_edit:SetString(new_str)
            insert_index = insert_index + add_str:len()
        end
    end

    self.emoji_menu.onemojifavoritetoggled = function(emoji, favorite)
        --print("On EMOJI FAVORITE TOGGLED!!", emoji, favorite)
    end

    self.emoji_menu.onemojidisplay = function(emoji)
        --print("On EMOJI DISPLAYED!", emoji)
    end

    PEARL.AddClassFunctionPreCall("ValidateChar", function()
        return not TheInput:IsKeyDown(KEY_CTRL)
    end, self.chat_edit)
end

---------------------------
-- [[ Overrides ]]
---------------------------

AddClassPostConstruct("screens/chatinputscreen", function(self, whisper)
    if whisper == true and PEARL.CONFIG.WHISPER_WARNING == true then
        AddWhisperWarning(self)
    end

    if PEARL.CONFIG.EMOJI_MENU and ClientEmojis:HasAnyEmojis() then
        if PEARL.CONFIG.DEBUG_MODE then
            PEARL.loadfile("extensions/ui/templates", nil, true)

            -- Hot reload for faster testing
            EmojiMenu = PEARL.loadfile("widgets/emojimenu", nil, true)
        end

        AddEmojiMenu(self)
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
