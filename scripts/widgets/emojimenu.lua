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
local Text = require("widgets/text")

--- @type TEMPLATES
local TEMPLATES = require("widgets/redux/templates")

---------------------------
-- [[ Constants ]]
---------------------------

local MENU_WIDTH = 200
local MENU_HEIGHT = 300

local ITEM_SIZE = 35
local SCROLLER_ITEM_SPACING = 0
local SCROLLER_ITEM_MARGIN = 10
local SCROLLIST_WIDGET_WIDTH = ITEM_SIZE + SCROLLER_ITEM_SPACING + SCROLLER_ITEM_MARGIN -- 50
local SCROLLIST_WIDGET_HEIGHT = SCROLLIST_WIDGET_WIDTH -- We want it to be a square

local SCROLLIST_MARGIN_X = 10
local SCROLLIST_PAD = 0
-- scissor_width = opts.widget_width * opts.num_columns + scissor_pad
local SCROLLIST_WIDTH = math.floor((MENU_WIDTH - SCROLLIST_MARGIN_X) / SCROLLIST_WIDGET_WIDTH) * SCROLLIST_WIDGET_WIDTH + SCROLLIST_WIDGET_WIDTH --(MENU_WIDTH * 1.8) - SCROLLIST_WIDGET_WIDTH -- SCROLLIST_MARGIN_X

local SEARCHBOX_PADDING_X = 0 -- 10
local SEARCHBOX_PADDING_Y = -33
local SEARCHBOX_MARGIN_X = 22
local SEARCHBOX_MARGIN_Y = -25
local SEARCHBOX_WIDTH = SCROLLIST_WIDTH + SEARCHBOX_MARGIN_X
local SEARCHBOX_HEIGHT = 40
local SEARCHBOX_FONT_SIZE = nil --35 -- Let it fallback to the default value
local SEARCHBOX_VALID_CHARS = [[ abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_ ]]

local SCROLLIST_PADDING_Y = -(SEARCHBOX_HEIGHT + SEARCHBOX_MARGIN_Y) - 7
local SCROLLIST_PEAK_PERCENT = .75 -- Number of percent the last row is visible Can be used for adjusting the size of the scrolling grid
local SCROLLIST_MARGIN_Y = 0
-- opts.widget_height * opts.peek_percent
local SCROLLIST_PEAK_HEIGHT = SCROLLIST_WIDGET_HEIGHT * SCROLLIST_PEAK_PERCENT
-- scissor_height = opts.widget_height * opts.num_visible_rows + peek_height
local SCROLLIST_HEIGHT = math.floor((MENU_HEIGHT - SCROLLIST_MARGIN_Y + SCROLLIST_PADDING_Y) / SCROLLIST_WIDGET_HEIGHT) * SCROLLIST_WIDGET_HEIGHT - SCROLLIST_WIDGET_HEIGHT
local SCROLLIST_PADDING_X = -10

-- These have to be unsigned integers.
local SCROLLER_VISIBLE_ROWS = math.floor(SCROLLIST_HEIGHT / SCROLLIST_WIDGET_HEIGHT)
local SCROLLER_VISIBLE_COLS = math.floor((SCROLLIST_WIDTH - SCROLLIST_PAD) / SCROLLIST_WIDGET_WIDTH)

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

local function format_string(str)
    return TrimString(str):gsub(" ", ""):lower()
end

---------------------------
-- [[ Class Declaration ]]
---------------------------

--- @class EmojiMenu
local EmojiMenu = Class(Widget, function(self, emojis, chat_edit)
    Widget._ctor(self, "Nitro Emoji Menu")

    self.chat_edit = chat_edit

    self.insert_index = 1

    self.selected_widget = nil
    self.selected_emoji = nil

    self.onopen = nil
    self.onclose = nil

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

function EmojiMenu:_LoadEmojiCategory(category, emojis)
    if table.empty(emojis) ~= false then
        return -- Category is empty or non-existent.
    end

    local remainder = #self.emojis_data % SCROLLER_VISIBLE_COLS
    if remainder ~= 0 then
        for _ = 1, SCROLLER_VISIBLE_COLS - remainder do
            table.insert(self.emojis_data, EMPTY_TILE)
        end
    end

    self.emojis_data[#self.emojis_data+1] = {category = category, header = true}

    for _ = 1, SCROLLER_VISIBLE_COLS - 1 do
        table.insert(self.emojis_data, EMPTY_TILE)
    end

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

function EmojiMenu:_CreateEmojiData(emoji_sets)
    self.emojis_data = {}
    StartStaticThread(function()
        last_check = os.clock()
        for category, emojis in pairs(emoji_sets) do
            self:_LoadEmojiCategory(category, emojis)
        end

        if self.scroll_list then
            self:SearchFor()
        end

        -- So each set has it's own cached value.
        emoji_data_cache[emoji_sets] = self.emojis_data
    end, self.inst.GUID)
end

function EmojiMenu:_CreateSearchBox(width, height)
    local searchbox = Widget("emoji_menu_searchbox")

    searchbox.textbox_root = searchbox:AddChild(TEMPLATES.StandardSingleLineTextEntry(nil, width, height, nil, SEARCHBOX_FONT_SIZE))
    searchbox.textbox = searchbox.textbox_root.textbox
    searchbox.textbox:SetForceEdit(true)
    searchbox.textbox:SetTextLengthLimit(25)
    searchbox.textbox:SetCharacterFilter(SEARCHBOX_VALID_CHARS)
    searchbox.textbox:EnableWordWrap(false)
    searchbox.textbox:SetAllowNewline(false)
    searchbox.textbox:EnableScrollEditWindow(true)
    searchbox.textbox:SetHelpTextEdit("")
    searchbox.textbox:SetTextPrompt("", UICOLOURS.GREY)
    searchbox.textbox:SetPassControlToScreen(CONTROL_CANCEL, true)
    searchbox.textbox:SetPassControlToScreen(CONTROL_SCROLLBACK, true)
    searchbox.textbox:SetPassControlToScreen(CONTROL_SCROLLFWD, true)
    searchbox.textbox._TryUpdateTextPrompt = function(_self)
        if _self.prompt then
            if _self:GetString():len() > 0 then
                _self.prompt:Hide()
            else
                _self.prompt:Show()
            end
        end
    end

    local last_string = ""
    searchbox.textbox.OnTextInputted = function()
        print("OnTextInputted")
        local string = searchbox.textbox:GetLineEditString()
        if string ~= last_string then
            last_string = string
            searchbox.textbox:_TryUpdateTextPrompt()

            self:SearchFor()
        end
    end

    searchbox.textbox.OnTextEntered = function()
        print("TEXT ENTERED", self.editing_enter_down)
        -- Only allow ENTER key for entering emojis
        if self.selected_emoji and self.editing_enter_down then
            self:InsertEmoji(self.selected_emoji)
            self:Close()
        else
            -- No matches, so keep the editing state
            searchbox.textbox:SetEditing(true)
        end
    end

    searchbox.focus_forward = searchbox.textbox

    return searchbox
end

function EmojiMenu:_CreateEmojiList(width, height)
    local function ScrollWidgetsCtor(context, index)
        local w = Widget("emoji_item"..tostring(index))

        w.button = w:AddChild(TEMPLATES.EmojiButton(ITEM_SIZE, false, SCROLLER_ITEM_MARGIN))
        w.button.AllowOnControlWhenSelected = true -- So we handle clicks even when selected
        w.focus_forward = w.button

        ----------------
        w.category_label = w:AddChild(Text(TITLEFONT, 28))
        --w.category_label:SetRegionSize(1000, 50)
            -- Push right to centre across all columns.
        w.category_label:SetPosition(SCROLLIST_WIDGET_WIDTH * (SCROLLER_VISIBLE_COLS-1)/2, 0)
        w.category_label:SetHAlign(ANCHOR_MIDDLE)
        w.category_label:SetRegionSize(SCROLLIST_WIDGET_WIDTH * SCROLLER_VISIBLE_COLS, SCROLLIST_WIDGET_HEIGHT)
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
                self:Close()
            end
        end)

        w.IsSelected = function()
            return w.button:IsSelected()
        end

		----------------
		return w
    end

    local function ApplyDataToWidget(context, widget, data, index)
        if self.searchbox then
            print(self.searchbox.textbox.enable_accept_control)
        end

        widget.data = data
        if table.empty(data) ~= false then
            return widget:Hide()
        end

        if data.header then
            widget.button:Hide()

            widget.category_label:SetString(data.category)
            widget.category_label:Show()
        elseif type(data.emoji) == "string" then
            local aliases_string = ""
            if table.empty(data.aliases) == false then
                local len = 0
                for _, alias_name in ipairs(data.aliases) do
                    local alias = EMOJI_ALIAS_FORMAT:format(alias_name)
                    len = len + alias:len() + 2
                    if len < MAX_ALIAS_LEN then
                        aliases_string = aliases_string..alias.." "
                    end
                end
            end

            widget.category_label:Hide()
            widget.button:SetText(data.emoji)
            widget.button:Show()

            if self.selected_emoji == data.emoji and not widget:IsSelected() then
                self:SelectEmojiWidget(widget)
            end

            if self.selected_emoji ~= data.emoji and widget:IsSelected() then
                widget.button:Unselect()
            end

            if self.searchbox and not self.searchbox.textbox.prompt:IsVisible() then
                widget.button:SetHoverText(aliases_string, {offset_y = 30, attach_to_parent = self.searchbox})
            end
        end

        if not widget:IsVisible() then
            widget:Show()
        end
    end

	local grid = TEMPLATES.ScrollingGrid(self.emojis_data, {
        scroll_context          = nil,  -- Used for custom arguments for ScrollWidgetsCtor
        --- @NOTE: This doesn't need to be true. If you need the scrolling widget to be bigger/smaller
        --- Just change the spacing.
        widget_width            = SCROLLIST_WIDGET_WIDTH, -- width of one of the widgets in the grid
        widget_height           = SCROLLIST_WIDGET_HEIGHT, -- height of one of the widgets in the grid
        peek_height             = SCROLLIST_PEAK_HEIGHT, -- how much of row to see at the bottom.
        peek_percent            = SCROLLIST_PEAK_PERCENT,
        item_ctor_fn            = ScrollWidgetsCtor,
        scissor_pad             = SCROLLIST_PAD,
        scrollbar_height_offset = -50, -- Height of the scrollbar itself
        num_visible_rows        = SCROLLER_VISIBLE_ROWS,
        num_columns             = SCROLLER_VISIBLE_COLS,
        scroll_per_click        = 2,
        scrollbar_offset        = 15, -- Offset of the scrollbar from the grid
        apply_fn                = ApplyDataToWidget,
        --allow_bottom_empty_row  = false,
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

    grid.no_emojis_msg = grid:AddChild(Text(UIFONT, 30, STRINGS.UI.CRAFTING_MENU.NO_ITEMS, UICOLOURS.GOLD_UNIMPORTANT))
	grid.no_emojis_msg:SetPosition(0, 0)
	grid.no_emojis_msg:Hide()

	grid.custom_focus_check = function() return self.focus end

	return grid
end

--- @TODO: Handle enter control to push the selected emoji to the chat bar.
--- @TODO: There should be always a selected_emoji (by default it's the first one in the visible list)
--- @TODO: Our menu should be closed when we click outside it.
function EmojiMenu:_BuildExplorer()
    local bg_color = UICOLOURS.BROWN_DARK
    self.menu = self:AddChild(TEMPLATES.RectangleWindow(MENU_WIDTH, MENU_HEIGHT))
    -- This is the default colour for these windows but we have a custom alpha channel.
    self.menu:SetBackgroundTint(bg_color[1], bg_color[2], bg_color[3], .8)

    self.scroll_list = self.menu:InsertWidget(self:_CreateEmojiList(SCROLLIST_WIDTH, SCROLLIST_HEIGHT))
    self.scroll_list:SetPosition(SCROLLIST_PADDING_X, SCROLLIST_PADDING_Y)

    local _, y = self.menu.top:GetPositionXYZ()
    self.searchbox = self.menu:InsertWidget(self:_CreateSearchBox(SEARCHBOX_WIDTH, SEARCHBOX_HEIGHT))
    self.searchbox:SetPosition(SEARCHBOX_PADDING_X, y + SEARCHBOX_PADDING_Y) -- SEARCHBOX_PADDING_X - SEARCHBOX_HEIGHT)
    self.searchbox:MoveToFront()

    self.default_focus = self.searchbox

    return self.menu
end

--- @return Widget? emoji
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

--- @param widget Widget?
function EmojiMenu:SelectEmojiWidget(widget)
    if widget ~= nil and not is_emoji(widget) then
        return
    end

    local data = widget and widget.data
    local emoji = data and data.emoji
    local aliases = data and data.aliases
    if self.selected_emoji == emoji and (widget and widget:IsSelected()) then
        return
    end

    local aliases_string = ""
    if aliases ~= nil and table.empty(aliases) == false then
        local len = 0
        for _, alias_name in ipairs(aliases) do
            local alias = EMOJI_ALIAS_FORMAT:format(alias_name)
            len = len + alias:len() + 2
            if len < MAX_ALIAS_LEN then
                aliases_string = aliases_string..alias.." "
            end
        end
    end

    if self.selected_widget then
        self.selected_widget.button:Unselect()
    end

    if self.searchbox.textbox:GetString():len() <= 0 and self.selected_emoji ~= emoji then
        self.searchbox.textbox.prompt:SetString(aliases_string)
    end

    self.selected_emoji = emoji
    self.selected_widget = widget

    if widget then
        widget.button:Select()
    end
end

function EmojiMenu:SearchFor(prompt)
    self.scroll_list.no_emojis_msg:Hide()

    local search_str = self.searchbox.textbox:GetLineEditString()
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

        if table.empty(emojis_data) ~= false then
            self.scroll_list.no_emojis_msg:Show()

            return self:SelectEmojiWidget(nil)
        end

        self.scroll_list:SetItemsData(emojis_data)
    end

    -- If no widget has focus (the cursor is outside the grid) select the first widget.
    local focused_widget = self.scroll_list:GetFocusChild() or self:GetFirstEmojiWidget()
    self:SelectEmojiWidget(focused_widget) -- Accept even nil - representing no results
end

---------------------------
-- [[ Public Methods ]]
---------------------------

function EmojiMenu:Open()
    PEARL.debug("EmojiMenu:Open")

    self.menu = self.menu or self:_BuildExplorer()
    self.menu:Show()
    self.menu:MoveToFront()

    self.insert_index = self.chat_edit.inst.TextEditWidget:GetEditCursorPos() or 1

    self.chat_edit:SetEditing(false)
    self.chat_edit:ClearFocus()
    --self.chat_edit.focus_forward = self

    self.searchbox.textbox:SetString("")
    self.searchbox.textbox:SetEditing(true)

    self:SearchFor()

    self.searchbox.textbox.prompt:SetString(STRINGS.UI.SERVERCREATIONSCREEN.SEARCH)

    if type(self.onopen) == "function" then
        self.onopen()
    end
end

function EmojiMenu:Close()
    PEARL.debug("EmojiMenu:Close")

    self.menu:Hide()

    self.searchbox.textbox:SetEditing(false)
    self.searchbox.textbox:SetString("")

    self.chat_edit:SetEditing(true)
    self.chat_edit.inst.TextEditWidget:SetEditCursorPos(self.insert_index)

    if type(self.onclose) == "function" then
        self.onclose()
    end
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

function EmojiMenu:OnControl(control, down, ...)
    if EmojiMenu._base.OnControl(self, control, down, ...) then return true end

    if not self:IsOpen() then
        return
    end

    if not down and control == CONTROL_CANCEL then -- Pressing ESC
        self:Close()
        return true
    end
end

function EmojiMenu:OnRawKey(key, down, ...)
    print("ON KEY DOWN")
    if EmojiMenu._base.OnRawKey(self, key, down, ...) then return true end

    if not self:IsOpen() then
        return
    end

    print("On RAW KEY", key, down)

    if down and key == KEY_ENTER and self.selected_emoji then
        self:InsertEmoji(self.selected_emoji)
        return true
    end
end

---------------------------
-- [[ Return ]]
---------------------------

return EmojiMenu
