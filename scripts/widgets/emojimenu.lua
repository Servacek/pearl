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
local Grid = require "widgets/grid"
local Button = require("widgets/button")
local ImageButton = require "widgets/imagebutton"

--- @type TEMPLATES
local TEMPLATES = require("widgets/redux/templates")

---------------------------
-- [[ Constants ]]
---------------------------

local MENU_WIDTH = 150
local MENU_HEIGHT = 300

local ITEM_SIZE = 45
local SCROLLER_ITEM_SPACING = 7
local SCROLLER_GRID_SIZE = ITEM_SIZE + SCROLLER_ITEM_SPACING * 1.5

local SCROLLIST_WIDTH = SCROLLER_GRID_SIZE
local SCROLLIST_HEIGHT = SCROLLER_GRID_SIZE - 4

local BOX_SIZE = 300
local BOX_HEIGHT = 40
local INPUTBOX_FONT_SIZE = 35

local TIMEBUDGET = FRAMES * 0.1
local CHECK_FREQUENCY = 50

local MAX_ALIAS_LEN = 15

local EMPTY_TILE = {} -- So we do not create a dummy table each time as a fillament

local DELIM = PEARL.CONSTS.DELIMS.EMOJI
local EMOJI_ALIAS_FORMAT = DELIM.."%s"..DELIM

---------------------------
-- [[ Local Variables ]]
---------------------------

local emoji_data_cache = {}
local i = CHECK_FREQUENCY
local last_check = 0

---------------------------
-- [[ Local Functions ]]
---------------------------

-- Inspired by Geometric Placement (rezecib)
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

local function is_emoji(widget, emoji)
    return widget.data and (
        (emoji and widget.data.emoji == emoji) or (emoji == nil and widget.data.emoji ~= nil)
    )
end

---------------------------
-- [[ Class Declaration ]]
---------------------------

--- @class EmojiMenu
local EmojiMenu = Class(Widget, function(self, emojis, chat_edit)
    Widget._ctor(self, "Nitro Emoji Menu")

    self.chat_edit = chat_edit

    self.scroller_cols = 5
    self.scroller_rows = 7

    self.insert_index = 1

    self.selected_widget = nil
    self.selected_emoji = nil

    self.emoji_sets = emojis
    if emoji_data_cache[emojis] then
        self.emojis_data = emoji_data_cache[emojis]
    else
        self:_CreateEmojiData(self.emoji_sets)
    end
end)

---------------------------
-- [[ Private Methods ]]
---------------------------

function EmojiMenu:_CreateEmojiData(emoji_sets)
    self.emojis_data = {}
    StartStaticThread(function()
        last_check = os.clock()
        for category, emojis in pairs(emoji_sets) do
            -- local remainder = #self.emojis_data % self.scroller_cols
            -- if remainder ~= 0 then
            --     for _ = 1, self.scroller_cols - remainder do
            --         table.insert(self.emojis_data, EMPTY_TILE)
            --     end
            -- end

            -- self.emojis_data[#self.emojis_data+1] = {category = category, header = true}

            -- for _ = 1, self.scroller_cols - 1 do
            --     table.insert(self.emojis_data, EMPTY_TILE)
            -- end

            local emoji_aliases = {}
            for alias, emoji in pairs(emojis) do
                emoji_aliases[emoji] = emoji_aliases[emoji] or {}
                table.insert(emoji_aliases[emoji], alias)
                check_and_yield()
            end

            for emoji, aliases in pairs(emoji_aliases) do
                table.insert(self.emojis_data, {emoji = emoji, aliases = aliases})
                check_and_yield()
            end
        end

        if self.scroll_list then
            self:SearchFor()
        end

        -- So each set has it's own cached value.
        emoji_data_cache[emoji_sets] = self.emojis_data
    end, self.inst.GUID)
end

function EmojiMenu:_CreateSearchBox()
    local searchbox = Widget("emoji_menu_searchbox")

    searchbox.textbox_root = searchbox:AddChild(TEMPLATES.StandardSingleLineTextEntry(nil, BOX_SIZE, BOX_HEIGHT, nil, INPUTBOX_FONT_SIZE))
    searchbox.textbox = searchbox.textbox_root.textbox
    searchbox.textbox:SetForceEdit(false)
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
        print("OnTextInputted")
        local string = searchbox.textbox:GetLineEditString()
        if string ~= last_string then
            last_string = string
            self:SearchFor()
        end
    end

    -- searchbox.textbox.OnTextEntered = function()
    --     print("TEXT ENTERED")
    --     if self.selected_emoji then
    --         self:InsertEmoji(self.selected_emoji)
    --         self:Close()
    --     end
    -- end

    searchbox.textbox.OnStopForceEdit = function()
        print("StopForceEdit")
        if not self.focus then
            self:Close()
        end
    end

    searchbox.focus_forward = searchbox.textbox

    return searchbox
end

function EmojiMenu:_CreateEmojiList(width, height)
    local function ScrollWidgetsCtor(context, index)
        local w = Widget("emoji_item"..tostring(index))

        w.button = w:AddChild(TEMPLATES.EmojiButton(ITEM_SIZE, false, SCROLLER_ITEM_SPACING))
        w.button.bg:ScaleToSize(width, width)

        w.focus_forward = w.button

        ----------------
        w.category_label = w:AddChild(Text(TITLEFONT, 45))
        --w.category_label:SetRegionSize(1000, 50)
        w.category_label:SetPosition(100, 0)
        w.category_label:SetHAlign(ANCHOR_MIDDLE)
        ----------------

        w.button:SetOnGainFocus(function()
            if is_emoji(w) and self.selected_widget ~= w then
                self:SelectEmojiWidget(w)
            end
        end)

        w.button:SetOnSelect(function()
            w.button.bg:SetTint(.4, .4, .4, .5)
        end)

        w.button:SetOnUnselect(function()
            w.button.bg:SetTint(0, 0, 0, 0)
        end)

        w.button:SetOnClick(function()
            print("CLICK")
            if is_emoji(w) then
                self:InsertEmoji(w.data.emoji)
            end
        end)

        w.IsSelected = function()
            return w.button:IsSelected()
        end

		----------------
		return w
    end

    local function ApplyDataToWidget(context, widget, data, index)
        widget.data = data
        if table.empty(data) ~= false then
            return widget:Hide()
        end

        if data.header then
            widget.button:Hide()

            widget.category_label:SetString(data.category)
            widget.category_label:Show()
        else
            local aliases_string = data.emoji
            if type(aliases_string) == "string" and table.empty(data.aliases) == false then
                local len = 0
                for _, alias_name in ipairs(data.aliases) do
                    local alias = EMOJI_ALIAS_FORMAT:format(alias_name)
                    len = len + alias:len() + 2
                    if len < MAX_ALIAS_LEN then
                        aliases_string = aliases_string.." "..alias
                    end
                end
            end

            widget.category_label:Hide()
            widget.button:SetHoverText(aliases_string, {offset_y = 30, attach_to_parent = self })
            widget.button:SetText(data.emoji)
            widget.button:Show()
        end

        widget:Show()

        if self.selected_emoji == data.emoji and not widget:IsSelected() then
            self:SelectEmojiWidget(widget)
        end

        if self.selected_emoji ~= data.emoji and widget:IsSelected() then
            widget.button:Unselect()
        end
    end

	local grid = TEMPLATES.ScrollingGrid(self.emojis_data, {
        widget_width            = width,
        widget_height           = height,
        peek_percent            = 0.5,
        item_ctor_fn            = ScrollWidgetsCtor,
        scrollbar_height_offset = -50,
        num_visible_rows        = self.scroller_rows,
        num_columns             = self.scroller_cols,
        scroll_per_click        = 2,
        scrollbar_offset        = 10, -- Offset of the scrollbar from the grid
        apply_fn                = ApplyDataToWidget,
    })

    local atlas = resolvefilepath(CRAFTING_ATLAS)
	grid.up_button:SetTextures(atlas, "scrollbar_arrow_up.tex", "scrollbar_arrow_up_hl.tex")
    grid.up_button:SetScale(0.4)

	grid.down_button:SetTextures(atlas, "scrollbar_arrow_down.tex", "scrollbar_arrow_down_hl.tex")
    grid.down_button:SetScale(0.4)

	grid.scroll_bar_line:SetTexture(atlas, "scrollbar_bar.tex")
    grid.scroll_bar_line:ScaleToSize(11, grid.scrollbar_height - 15)

	grid.position_marker:SetTextures(atlas, "scrollbar_handle.tex")
	grid.position_marker.image:SetTexture(atlas, "scrollbar_handle.tex")
    grid.position_marker:SetScale(.3)

	grid.custom_focus_check = function() return self.focus end

	return grid
end

--- @TODO: Handle enter control to push the selected emoji to the chat bar.
--- @TODO: There should be always a selected_emoji (by default it's the first one in the visible list)
--- @TODO: Our menu should be closed when we click outside it.
function EmojiMenu:_BuildExplorer()
    local bg_color = UICOLOURS.BROWN_DARK
    self.menu = self:AddChild(TEMPLATES.RectangleWindow(MENU_WIDTH, MENU_HEIGHT))
    self.menu:SetBackgroundTint(bg_color[1], bg_color[2], bg_color[3], .7) -- A bit of transparency
    self.menu:SetPosition(0, 250)
    -- self.menu.OnControl = function(self, control, down, ...)
    --     print(control, ...)
    -- end

    self.search_box = self.menu.top:AddChild(self:_CreateSearchBox())
    self.search_box:SetPosition(0, -35)
    self.search_box:MoveToFront()

    -- self.aliases_text = self.menu.bottom:AddChild(Text(BODYTEXTFONT, 30))
    -- self.aliases_text:SetPosition(0, 25)

    self.scroll_list = self.menu.top:AddChild(self:_CreateEmojiList(SCROLLIST_WIDTH, SCROLLIST_HEIGHT))
    self.scroll_list:SetPosition(-10, -201 - BOX_HEIGHT)
    self.scroll_list:MoveToBack()

    self.menu.bottom:MoveToFront()

    self.default_focus = self.search_box
    self.focus_forward = self.search_box

    return self.menu
end

--- @return Button? emoji
function EmojiMenu:GetFirstEmojiWidget()
    if self.scroll_list and self.scroll_list.widgets_to_update then
        for _, widget in ipairs(self.scroll_list.widgets_to_update) do
            if is_emoji(widget) then
                return widget
            end
        end
    end
end

function EmojiMenu:InsertEmoji(emoji)
    local str = self.chat_edit:GetString()
    self.chat_edit:SetString(str:sub(1, self.insert_index)..emoji.." "..str:sub(self.insert_index + 1))
    self.insert_index = self.insert_index + emoji:len() + 1
end

function EmojiMenu:SelectEmojiWidget(widget)
    if not is_emoji(widget) then
        return
    end

    local data = widget and widget.data
    local emoji = data and data.emoji
    local aliases = data and data.aliases
    if self.selected_emoji == emoji and widget:IsSelected() then
        return
    end

    local aliases_string = emoji
    if type(aliases_string) == "string" and table.empty(aliases) == false then
        local len = 0
        for _, alias_name in ipairs(aliases) do
            local alias = EMOJI_ALIAS_FORMAT:format(alias_name)
            len = len + alias:len() + 2
            if len < MAX_ALIAS_LEN then
                aliases_string = aliases_string.." "..alias
            end
        end
    end

    if self.selected_widget then
        self.selected_widget.button:Unselect()
    end

    self.selected_emoji = emoji
    self.selected_widget = widget
    widget.button:Select()
end

local function format_string(str)
    return TrimString(str):gsub(" ", ""):lower()
end

function EmojiMenu:SearchFor(prompt)
    local search_str = self.search_box.textbox:GetLineEditString()
    if not search_str or search_str == "" then
        self.scroll_list:SetItemsData(self.emojis_data)
    else
        search_str = format_string(search_str)
        local emojis_data = {}
        for _, data in ipairs(self.emojis_data) do
            if table.empty(data) == false and data.header == nil then
                for _, alias in ipairs(data.aliases) do
                    if alias:find(search_str) then
                        table.insert(emojis_data, data)
                        break
                    end
                end
            end
        end

        self.scroll_list:SetItemsData(emojis_data)
    end

    -- If no widget has focus (the cursor is outside the grid) select the first widget.
    local focused_widget = self.scroll_list:GetFocusChild() or self.scroll_list.widgets_to_update[1]
    if focused_widget then
        self:SelectEmojiWidget(focused_widget)
    end
end

function EmojiMenu:Open()
    self.menu = self.menu or self:_BuildExplorer()
    self.menu:Show()
    self.menu:MoveToFront()

    self.insert_index = self.chat_edit.inst.TextEditWidget:GetEditCursorPos() or 1

    self.chat_edit:SetEditing(false)
    self.chat_edit:ClearFocus()
    self.chat_edit.focus_forward = self

    self.search_box.textbox:SetEditing(true)

    local first = self:GetFirstEmojiWidget()
    if first then
        self:SelectEmojiWidget(first)
    end

    self.menu:SetFocus()
    self:SetFocus()
    self.search_box:SetFocus()
end

function EmojiMenu:Close()
    self.menu:Hide()

    self.search_box.textbox:SetEditing(false)
    self.search_box.textbox:SetString("")

    self.chat_edit:SetEditing(true)
    self.chat_edit.inst.TextEditWidget:SetEditCursorPos(self.insert_index)

    --- @TODO: Make sure we reset the button after the menu is closed.
    -- if not self.start_button.focus then
    --     self.start_button.onlosefocus()
    -- end
end

function EmojiMenu:Toggle()
    if self:IsOpen() then
        self:Close()
    else
        self:Open()
    end
end

function EmojiMenu:IsOpen()
    return self.menu and self.menu:IsVisible()
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
