--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local ImageButton = require("widgets/imagebutton")

--- @class ChatSidebar
local ChatSidebar = require("widgets/redux/chatsidebar")

local EmojiMenu = PEARL.loadfile("widgets/emojimenu")
local ClientEmojis = PEARL.loadfile("libs/clientemojimanager")

local AddEmojiMenu

local function AddEmojiMenuButton(self, menu)
    if self.chatbox and self.chatbox.gobutton then
        self.chatbox.emoji_menu_button = self.chatbox.gobutton
        self.chatbox.emoji_menu_button.icon:Kill()
        self.chatbox.emoji_menu_button:SetText(PEARL.EMOJIS.GAME.WAVE)
        self.chatbox.emoji_menu_button:SetOnClick(function()
            if PEARL.CONFIG.DEBUG_MODE then
                PEARL.loadfile("extensions/ui/templates", nil, true)

                -- Hot reload for faster testing
                EmojiMenu = PEARL.loadfile("widgets/emojimenu", nil, true)
                menu = AddEmojiMenu(self)
            end

            menu:Toggle()

            local pos_x, pos_y = self.chatbox.emoji_menu_button:GetPositionXYZ()
            local _, h = (menu.menu.mid_center or menu.menu.bg or menu.menu):GetSize()
            menu:SetPosition(pos_x + 57, pos_y + h)
        end)

        return self.chatbox.emoji_menu_button
    end
end

AddEmojiMenu = function(self)
    if self.emoji_menu then
        self:RemoveChild(self.emoji_menu)
        self.emoji_menu:Kill()
    end

    self.emoji_menu = self:AddChild(EmojiMenu())
    self.emoji_menu:LoadEmojiCategories(ClientEmojis.CATEGORIES_ORDERED)

    if self.chatbox.emoji_menu_button == nil then
        AddEmojiMenuButton(self, self.emoji_menu)
    end

    if self._bg == nil then
        self._bg = ChatSidebar._base.AddChild(self, ImageButton("images/global.xml", "square.tex"))
        self._bg.image:SetVRegPoint(ANCHOR_MIDDLE)
        self._bg.image:SetHRegPoint(ANCHOR_MIDDLE)
        self._bg.image:SetVAnchor(ANCHOR_MIDDLE)
        self._bg.image:SetHAnchor(ANCHOR_MIDDLE)
        self._bg.image:SetScaleMode(SCALEMODE_FILLSCREEN)
        self._bg.image:SetTint(0,0,0,0)
        self._bg:SetHelpTextMessage("")
        self._bg:MoveToFront()
        self._bg:Select() -- So no hover sound
        self._bg.AllowOnControlWhenSelected = true
        self._bg:Hide()

        self._bg:SetOnClick(function()
            if self.emoji_menu:IsOpen() then
                self.emoji_menu:Close()
            end
        end)

        self._bg.focus_forward = function()
            if self.emoji_menu:IsOpen() then
                return self.emoji_menu
            end
        end
    end

    local textedit = self.chatbox.textbox
    local insert_index = 1
    self.emoji_menu.onopen = function()
        textedit:SetEditing(false)
        textedit:ClearFocus()

        insert_index = textedit.inst.TextEditWidget:GetEditCursorPos() or 1
        self._bg:Show()

        self._bg:MoveToFront()
        self.emoji_menu:MoveToFront()
    end

    self.emoji_menu.onclosing = function()
        textedit:SetEditing(true)
        textedit.inst.TextEditWidget:SetEditCursorPos(insert_index)

        self._bg:Hide()
    end

    self.emoji_menu.onemojichosen = function(emoji_id)
        local emoji_data = PEARL.EMOJIS.DATA[emoji_id]
        local str = textedit:GetString()
        local add_str = emoji_data.utf8_str.." "
        local new_str = str:sub(1, insert_index)..add_str..str:sub(insert_index + 1)

        -- Only append if the
        if new_str:utf8len() < (textedit.limit or MAX_CHAT_INPUT_LENGTH) then
            textedit:SetString(new_str)
            insert_index = insert_index + add_str:len()
        end
    end

    if textedit.ValidateChar ~= textedit._ValidateChar and textedit.ValidateChar ~= nil then
        textedit._ValidateChar = PEARL.AddClassFunctionPreCall("ValidateChar", function()
            return not TheInput:IsKeyDown(KEY_CTRL)
        end, textedit)
    end

    return self.emoji_menu
end

PEARL.AddClassPostConstruct("widgets/redux/chatsidebar", function(self)
    if PEARL.CONFIG.EMOJI_MENU then
        AddEmojiMenu(self)
    end
end)
