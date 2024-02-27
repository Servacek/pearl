--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local Widget = require("widgets/widget")
local Screen = require("widgets/screen")
local Text = require("widgets/text")
local Button = require("widgets/button")
-- local ImageButton = require "widgets/imagebutton"
local TEMPLATES = require("widgets/redux/templates")

local START_BUTTON_SIZE = 35
local START_BUTTON_FOCUS_SIZE = 45

local emoji_data_cache = nil

local function is_item_data(data)
    return data and next(data) and not data.is_title
end

local EmojiMenu = Class(Widget, function(self, emojis, chat_edit)
    Widget._ctor(self, "Nitro Emoji Menu")

    self.chat_edit = chat_edit

    self.scroller_rows = 6
    self.scroller_cols = 6

    self.insert_index = 1

    self.emoji_sets = emojis
    if emoji_data_cache then
        self.emojis_data = emoji_data_cache
    else
        self:CreateEmojiData(self.emoji_sets)
    end
end)

-- Inspired by Geometric Placement (rezecib)
local TIMEBUDGET = FRAMES * 0.1
local CHECK_FREQUENCY = 50
local i = CHECK_FREQUENCY
local last_check = 0
local function check_and_yield()
    i = i - 1
    if i == 0 then
        if os.clock() - last_check > TIMEBUDGET then
            Yield()
            last_check = os.clock()
        end
        i = CHECK_FREQUENCY
    end
end

local EMPTY_GRID = {}
local TITLE_GRID = { is_title = true }
function EmojiMenu:CreateEmojiData(emoji_sets)
    self.emojis_data = {}
    StartStaticThread(function()
        last_check = os.clock()
        local need_divider = false
        for _, emojis in pairs(emoji_sets) do
            if need_divider then
                local remainder = #self.emojis_data % self.scroller_cols
                if remainder ~= 0 then
                    for i = 1, self.scroller_cols - remainder do
                        table.insert(self.emojis_data, EMPTY_GRID)
                    end
                end
                table.insert(self.emojis_data, TITLE_GRID)
                for i = 1, self.scroller_cols - 1 do
                    table.insert(self.emojis_data, EMPTY_GRID)
                end
            end
            local emoji_aliases = {}
            for alias, emoji in pairs(emojis) do
                if not emoji_aliases[emoji] then
                    emoji_aliases[emoji] = {}
                end
                table.insert(emoji_aliases[emoji], alias)
                check_and_yield()
            end
            for emoji, aliases in pairs(emoji_aliases) do
                table.insert(self.emojis_data, {emoji = emoji, aliases = aliases})
                check_and_yield()
                -- Maybe try refresh the scrollist here?
            end
            need_divider = next(emoji_aliases)
        end
        if self.scroll_list then
            self:RefreshScrollingItems()
        end
        emoji_data_cache = self.emojis_data
    end, self.inst.GUID)
end

function EmojiMenu:ClearEmojiDataCache()
    emoji_data_cache = nil
end

function EmojiMenu:CreateEmojiButton(size, override_bg_size)
    local btn = Button()
    -- local btn = self:AddChild(ImageButton(
    --     "images/global_redux.xml",
    --     "button_carny_square_normal.tex",
    --     "button_carny_square_hover.tex",
    --     "button_carny_square_disabled.tex",
    --     "button_carny_square_down.tex"
    -- ))

    btn.bg = btn:AddChild(Image("images/ui.xml", "blank.tex"))
    btn.bg:SetPosition(0, 0)
    btn.bg:MoveToBack()

    if override_bg_size then
        btn.bg:ScaleToSize(override_bg_size, override_bg_size)
    else
        local SetText = btn.SetText
        btn.SetText = function(...)
            SetText(...)
            local w, h = btn.text:GetRegionSize()
            btn.bg:ScaleToSize(w, h)
        end
    end

    btn:SetTextSize(size)
    btn:SetControl(CONTROL_PRIMARY)

    btn.ongainfocus = function()
        btn:Select()
        btn:SetTextSize(size + 5)
    end
    btn.onlosefocus = function()
        btn:SetTextSize(size)
    end
    btn.AllowOnControlWhenSelected = true
    return btn
end

local BOX_SIZE = 300
local BOX_HEIGHT = 50
function EmojiMenu:CreateSearchBox()
    local searchbox = Widget("search")

    searchbox.textbox_root = searchbox:AddChild(TEMPLATES.StandardSingleLineTextEntry(nil, BOX_SIZE, BOX_HEIGHT, nil, START_BUTTON_SIZE))
    searchbox.textbox = searchbox.textbox_root.textbox
    searchbox.textbox:SetTextLengthLimit(50)
    searchbox.textbox:EnableWordWrap(false)
    searchbox.textbox:EnableScrollEditWindow(true)
    searchbox.textbox:SetHelpTextEdit("")
    searchbox.textbox:SetHelpTextApply(STRINGS.UI.SERVERCREATIONSCREEN.SEARCH)
    searchbox.textbox:SetPassControlToScreen(CONTROL_CANCEL, true)
    searchbox.textbox:SetPassControlToScreen(CONTROL_SCROLLBACK, true)
    searchbox.textbox:SetPassControlToScreen(CONTROL_SCROLLFWD, true)

    local last_string = ""
    searchbox.textbox.OnTextInputted = function()
        local string = searchbox.textbox:GetLineEditString()
        if string ~= last_string then
            last_string = string
            self:RefreshScrollingItems()
        end
    end

    searchbox.textbox.OnTextEntered = function()
        if self.selected_emoji then
            self:InsertEmoji(self.selected_emoji)
        end
        self:Close()
    end

    local function OnStopForceEdit()
        self:Close()
    end
    searchbox.textbox.OnStopForceEdit = function()
        searchbox.textbox.inst:DoTaskInTime(0, OnStopForceEdit)
    end
    return searchbox
end

local ITEM_SIZE = 45
local SCROLLER_ITEM_PADDING = 15
local SCROLLER_GRID_SIZE = ITEM_SIZE + SCROLLER_ITEM_PADDING
function EmojiMenu:CreateScrollingGridItem()

    local root = Widget()

    root.divider = root:AddChild(Image("images/global_redux.xml", "item_divider.tex"))
    -- local w = SCROLLER_GRID_SIZE * self.scroller_cols
    -- root.divider:SetSize(w, SCROLLER_GRID_SIZE)
    -- root.divider:SetPosition(w / 2, 0)

    root.btn = root:AddChild(TEMPLATES.EmojiButton(ITEM_SIZE, SCROLLER_GRID_SIZE))

    local OnControl = root.btn.OnControl
    root.btn.OnControl = function(self, control, down, ...)
        if OnControl(self, control, down, ...) then return true end
        if control == CONTROL_SECONDARY then
            if down then
                if not self.rmb_down then
                    TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
                    self.o_pos = self:GetLocalPosition()
                    self:SetPosition(self.o_pos + self.clickoffset)
                    self.rmb_down = true
                    if self.whiledown then
                        self:StartUpdating()
                    end
                end
            else
                if self.rmb_down then
                    self.rmb_down = false
                    self:ResetPreClickPosition()
                    self.onrightclick()
                    self:StopUpdating()
                end
            end
            return true
        end
    end

    root.btn:SetOnSelect(function()
        self:SetSelectedEmoji(root.data.emoji, root.data.aliases)
    end)

    root.btn:SetOnUnselect(function()
        if self.selected_emoji == root.data.emoji then
		    self:SetSelectedEmoji(nil)
        end
	end)

    root.btn:SetOnClick(function()
        self:InsertEmoji(root.data.emoji)
    end)

    return root
end

local function ApplyDataToWidget(context, widget, data, index)
    widget.data = data
    if data and next(data) then
        if data.is_title then
            widget.divider:Show()
            widget.btn:Hide()
        else
            widget.btn:SetText(data.emoji)
            widget.btn:Show()
            widget.divider:Hide()
        end
        widget:Show()
    else
        widget:Hide()
    end
end

local r, g, b = unpack(UICOLOURS.BROWN_DARK)
function EmojiMenu:BuildExplorer()
    self.menu = self:AddChild(TEMPLATES.RectangleWindow(250, 400))
    self.menu:SetBackgroundTint(r, g, b, 0.8) -- A bit of transparency
    self.menu:SetPosition(0, 250)

    self.search_box = self.menu.top:AddChild(self:CreateSearchBox())
    self.search_box:SetPosition(0, -50)

    self.aliases_text = self.menu.bottom:AddChild(Text(BODYTEXTFONT, 30))
    self.aliases_text:SetPosition(0, 50)

    self.scroll_list = self.search_box.textbox:AddChild(TEMPLATES.ScrollingGrid(self.emojis_data, {
        item_ctor_fn = function()
            return self:CreateScrollingGridItem()
        end,
        widget_width = SCROLLER_GRID_SIZE,
        widget_height = SCROLLER_GRID_SIZE,
        num_visible_rows = self.scroller_rows,
        num_columns = self.scroller_cols,
        scroll_per_click = 2.5,
        scrollbar_offset = 20,
        apply_fn = ApplyDataToWidget,
    }))
    self.scroll_list:SetPosition(0, -250)
    --self:SetSelectedEmojiWidget(self.scroll_list.widgets_to_update[1])

    return self.menu
end

function EmojiMenu:InsertEmoji(emoji)
    local str = self.chat_edit:GetString()
    self.chat_edit:SetString(str:sub(1, self.insert_index) .. emoji .. " " .. str:sub(self.insert_index + 1))
    self.insert_index = self.insert_index + emoji:len() + 1
end

local MAX_ALIAS_LEN = 15
function EmojiMenu:SetSelectedEmoji(emoji, aliases)
    local str_t
    if emoji then
        str_t = {}
        table.insert(str_t, emoji)
        local len = 0
        for _, alias in ipairs(aliases) do
            if len < MAX_ALIAS_LEN then
                table.insert(str_t, ":" .. alias .. ":")
            end
            len = len + alias:len() + 2
        end
    end

    self.aliases_text:SetString(emoji and table.concat(str_t, " ") or "")
    self.selected_emoji = emoji
end

local function format_string(str)
    return TrimString(str):gsub(" ", ""):lower()
end

function EmojiMenu:RefreshScrollingItems()
    local search_str = self.search_box.textbox:GetLineEditString()
    if not search_str or search_str == "" then
        self.scroll_list:SetItemsData(self.emojis_data)
    else
        search_str = format_string(search_str)
        local emojis_data = {}
        for _, data in ipairs(self.emojis_data) do
            if is_item_data(data) then
                for _, alias in ipairs(data.aliases) do
                    if alias:find(search_str) then
                        table.insert(emojis_data, data)
                        break
                    end
                end
            end
        end
        -- if IsTableEmpty(emojis_data) then
        --     self:SetSelectedEmojiWidget(nil)
        -- end
        self.scroll_list:SetItemsData(emojis_data)
    end
    --self:SetSelectedEmojiWidget(self.scroll_list.widgets_to_update[1])
end

function EmojiMenu:Open()
    self.menu = self.menu or self:BuildExplorer()

    self.isopen = true
    self.insert_index = self.chat_edit.inst.TextEditWidget:GetEditCursorPos() or 1
    self.menu:Show()
    self.menu:MoveToFront()
    self.chat_edit:SetEditing(false)
    self.search_box.textbox:SetEditing(true)
end

function EmojiMenu:Close()
    self.isopen = false
    self.menu:Hide()
    self.search_box.textbox:SetEditing(false)
    self.chat_edit:SetEditing(true)
    self.chat_edit.inst.TextEditWidget:SetEditCursorPos(self.insert_index)
    -- if not self.start_button.focus then
    --     self.start_button.onlosefocus()
    -- end
end

function EmojiMenu:Toggle()
    if self.isopen then
        self:Close()
    else
        self:Open()
    end
end

function EmojiMenu:IsOpen()
    return self.isopen == true
end

---------------------------
-- [[ Event Handlers ]]
---------------------------

function EmojiMenu:OnControl(control, down)
    if EmojiMenu._base.OnControl(self, control, down) then return true end

    if not down and control == CONTROL_CANCEL and self:IsOpen() then
        self:Close()
        return true
    end
end

---------------------------
-- [[ Return ]]
---------------------------

return EmojiMenu
