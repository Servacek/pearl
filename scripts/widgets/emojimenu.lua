--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local ImageButton = require("widgets/imagebutton")
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
local SEARCHBOX_VALID_CHARS = [[abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_]]

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

local SCROLLBAR_OFFSET = 15

local TIMEBUDGET = FRAMES * 0.1
local CHECK_FREQUENCY = 50

--local MAX_ALIAS_LEN = 32

local EMPTY_TILE = {} -- So we do not create a dummy table each time as a fillament
local EMPTY_HEADER_TILE = {header = true}

local DELIM = PEARL.CONSTS.DELIMS.EMOJI
local EMOJI_ALIAS_FORMAT = DELIM.."%s"..DELIM

local EMOJI_CHARACTER_FALLBACK = "?"

---------------------------
-- [[ Local Variables ]]
---------------------------

local emoji_data_cache = {}

local _i = CHECK_FREQUENCY
local _last_check = 0

---------------------------
-- [[ Local Functions ]]
---------------------------

-- Inspired by Geometric Placement (rezecib)
local function check_and_yield()
    _i = _i - 1
    if _i == 0 then
        if os.clock() - _last_check > TIMEBUDGET then
            Yield()
            _last_check = os.clock()
        end
        _i = CHECK_FREQUENCY
    end
end

local function is_emoji(widget, emoji)
    return widget and widget.data and (
        (emoji and widget.data.emoji == emoji) or (emoji == nil and widget.data.emoji ~= nil)
    )
end

---------------------------
-- [[ Class Declaration ]]
---------------------------

--- @class EmojiMenu
local EmojiMenu = Class(Widget, function(self)
    Widget._ctor(self, "EmojiMenu")

    self.selected_widget = nil
    self.selected_emoji = nil
    self.selected_category = nil

    self.onopen = nil
    self.onclose = nil
    self.onemojichosen = nil

    self.inst:ListenForEvent("emojis_used", function()
        if self.categories ~= nil then
            -- Do not do the reload immediately since we can use emojis even without the menu open.
            emoji_data_cache[self.categories] = nil
        end
    end, PEARL.INST)

    self.loaded_data = {}
    -- Optional table of utf8 chars mapped to a full name (with all aliases and delims)
    self.flnames_map = nil
end)

---------------------------
-- [[ Private Methods ]]
---------------------------

function EmojiMenu:_LoadEmojiCategory(category)
    PEARL.debug("EmojiMenu:_LoadEmojiCategory")

    local remainder = #self.loaded_data % SCROLLER_VISIBLE_COLS
    if remainder ~= 0 then -- Fill the remaining space in the last row with empty tiles.
        for _ = 1, SCROLLER_VISIBLE_COLS - remainder do
            self.loaded_data[#self.loaded_data + 1] = EMPTY_TILE
        end
    end

    self.loaded_data[#self.loaded_data + 1] = {category = category.name, header = true}

    for _ = 1, SCROLLER_VISIBLE_COLS - 1 do
        self.loaded_data[#self.loaded_data + 1] = EMPTY_HEADER_TILE
    end

    -- We cannot skip any emojis from category.emojis since the indexes need to be "synced"
    local rows, cols = 1, 0
    for _, emoji_name in ipairs(category.emojis) do
        cols = cols + 1
        if cols > SCROLLER_VISIBLE_COLS then
            rows, cols = rows + 1, 1
        end

        if category.maxrows and rows > category.maxrows then
            break
        end

        local emoji_char = PEARL.EMOJIS.ALL[emoji_name] or EMOJI_CHARACTER_FALLBACK
        if type(emoji_name) == "table" then
            local emoji_table = emoji_name
            emoji_char = emoji_table.emoji or emoji_char
            emoji_name = emoji_table.name or emoji_table.names and emoji_table.names[1]
        end

        self.loaded_data[#self.loaded_data + 1] = {
            emoji = emoji_char,
            name_full = self.flnames_map and self.flnames_map[emoji_char] or EMOJI_ALIAS_FORMAT:format(emoji_name),
            category = category.name,
            searchable = category.searchable ~= false
        }

        check_and_yield()
    end
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
    searchbox.textbox:SetPassControlToScreen(CONTROL_SCROLLFWD, true)
    searchbox.textbox._TryUpdateTextPrompt = function(_self)
        if _self.prompt then
            local visible = _self.prompt:IsVisible()
            if searchbox.HasAnyInput() then
                _self.prompt:Hide()
            else
                _self.prompt:Show()
            end

            if visible ~= _self.prompt:IsVisible() then
                self:OnSearchPromptUpdated(_self.prompt)
            end
        end
    end

    local last_string = ""
    searchbox.textbox.OnTextInputted = function()
        local string = searchbox.textbox:GetLineEditString()
        if string ~= last_string then
            last_string = string
            searchbox.textbox:_TryUpdateTextPrompt()

            self:RefreshSearching()
        end
    end

    searchbox.textbox.OnTextEntered = function()
        -- Only allow ENTER key for entering emojis
        if self.selected_emoji and TheInput:IsKeyDown(KEY_ENTER) then
            self:_ChooseEmoji(self.selected_emoji)
        else
            -- No matches, so keep the editing state
            searchbox.textbox:SetEditing(true)
        end
    end

    searchbox.HasAnyInput = function()
        return searchbox.textbox:GetString():len() > 0
    end

    searchbox.Clear = function()
        searchbox.button_clear:Hide()

        searchbox.textbox:SetString("")
        searchbox.textbox:OnTextInputted()

        searchbox.textbox.prompt:SetString(STRINGS.PEARL.UI.EMOJI_MENU.SEARCH)
    end

    local atlas = resolvefilepath(CRAFTING_ATLAS)
    searchbox.button_clear = searchbox.textbox:AddChild(ImageButton(atlas, "pinslot_unpin_button.tex"))
    searchbox.button_clear:SetScale(0.2)
    searchbox.button_clear:SetHoverText(STRINGS.PEARL.UI.EMOJI_MENU.CLEAR_BUTTON_HOVER, {offset_y = 50})
    searchbox.button_clear:SetPosition(SEARCHBOX_WIDTH / 2 - 20, 0)
    searchbox.button_clear:Hide()

    searchbox.button_clear:SetOnClick(searchbox.Clear)

    searchbox.focus_forward = searchbox.textbox

    return searchbox
end

function EmojiMenu:_ChooseEmoji(emoji)
    PEARL.debug("EmojiMenu:_ChooseEmoji", emoji)

    if type(self.onemojichosen) == "function" then
        self.onemojichosen(emoji)
    end

    self:Close()
end

function EmojiMenu:_DoFocusHookups()
    ---
end

function EmojiMenu:_CreateEmojiList()
    local function ScrollWidgetsCtor(context, index)
        local w = Widget("emoji_item"..tostring(index))

        w.button = w:AddChild(TEMPLATES.EmojiButton(ITEM_SIZE, false, SCROLLER_ITEM_MARGIN))
        w.button:AddHoverText()
        w.button.AllowOnControlWhenSelected = true -- So we handle clicks even when selected
        w.focus_forward = w.button

        ----------------
        w.category_label = w:AddChild(Text(TITLEFONT, 28))
        -- Push right to centre across all columns.
        w.category_label:SetPosition(SCROLLIST_WIDGET_WIDTH * (SCROLLER_VISIBLE_COLS-1)/2, 0)
        w.category_label:SetHAlign(ANCHOR_MIDDLE)
        w.category_label:SetRegionSize(SCROLLIST_WIDGET_WIDTH * SCROLLER_VISIBLE_COLS, SCROLLIST_WIDGET_HEIGHT)
        ----------------

        w.button.hovertext_root.OnShow = function()
            if self.searchbox.textbox.prompt:IsVisible() then
                w.button:HideHover()
            end
        end

        w.button:SetOnGainFocus(function()
            if is_emoji(w) and self.selected_widget ~= w then
                self:SelectEmojiWidget(w, true)
            end
        end)

        w.button:SetOnSelect(function()
            w.button.bg:SetTint(.4, .4, .4, .5)

            if not self.searchbox.textbox.prompt:IsVisible() and w.focus then
                w.button:ShowHover()
            end
        end)

        w.button:SetOnUnselect(function()
            w.button.bg:SetTint(0, 0, 0, 0)

            w.button:HideHover()
        end)

        w.button:SetOnClick(function()
            if is_emoji(w) then
                self:_ChooseEmoji(w.data.emoji)
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

            if type(data.category) == "string" then
                widget.category_label:SetString(data.category)
                widget.category_label:Show()
            end
        elseif type(data.emoji) == "string" then
            widget.category_label:Hide()
            widget.button:SetText(data.emoji)
            widget.button:SetHoverText(data.name_full)
            widget.button:Show()

            if self:IsEmojiSelected(data.emoji, data.category) and not widget:IsSelected() then
                self:SelectEmojiWidget(widget)
            elseif not self:IsEmojiSelected(data.emoji, data.category) and widget:IsSelected() and not widget.focus then
                self:UnselectEmojiWidget(widget)
            end
        end

        if not widget:IsVisible() then
            widget:Show()
        end
    end

	local grid = TEMPLATES.ScrollingGrid(self.loaded_data, {
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
        scrollbar_offset        = SCROLLBAR_OFFSET, -- Offset of the scrollbar from the grid
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

    grid.no_emojis_msg = grid:AddChild(Text(UIFONT, 26, STRINGS.PEARL.UI.EMOJI_MENU.NO_EMOJIS_FOUND, UICOLOURS.GOLD_UNIMPORTANT))
	grid.no_emojis_msg:SetPosition(SCROLLBAR_OFFSET, 0)
	grid.no_emojis_msg:Hide()

	grid.custom_focus_check = function() return self.focus end
    --- @TODO: Add support for arrow keys and controlers.
    grid.OnFocusMove = function() end

	return grid
end

function EmojiMenu:_BuildExplorer()
    local bg_color = UICOLOURS.BROWN_DARK
    self.menu = self:AddChild(TEMPLATES.RectangleWindow(MENU_WIDTH, MENU_HEIGHT))
    -- This is the default colour for these windows but we have a custom alpha channel.
    self.menu:SetBackgroundTint(bg_color[1], bg_color[2], bg_color[3], .85)

    self.scroll_list = self.menu:InsertWidget(self:_CreateEmojiList())
    self.scroll_list:SetPosition(SCROLLIST_PADDING_X, SCROLLIST_PADDING_Y)

    local _, y = self.menu.top:GetPositionXYZ()
    self.searchbox = self.menu:InsertWidget(self:_CreateSearchBox(SEARCHBOX_WIDTH, SEARCHBOX_HEIGHT))
    self.searchbox:SetPosition(SEARCHBOX_PADDING_X, y + SEARCHBOX_PADDING_Y)
    self.searchbox:MoveToFront()

    self.default_focus = self.searchbox

    self:_DoFocusHookups()

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

function EmojiMenu:GetFocusedEmojiWidget()
    for _, widget in pairs(self.scroll_list:GetListWidgets()) do
        if widget.focus then
            return widget
        end
    end
end

function EmojiMenu:UnselectEmojiWidget(widget)
    if widget ~= nil and not is_emoji(widget) then
        return
    end

    widget.button:Unselect()
end

--- @param widget Widget?
function EmojiMenu:SelectEmojiWidget(widget, focus)
    PEARL.debug("EmojiMenu:SelectEmojiWidget", widget and widget.data and widget.data.name_full)
    if widget ~= nil and not is_emoji(widget) then
        return
    end

    local data = widget and widget.data
    local emoji = data and data.emoji
    local category = data and data.category
    if self.selected_emoji == emoji and (widget and widget:IsSelected()) then
        return
    end

    if self.selected_widget then
        self.selected_widget.button:Unselect()
    end

    if not self.searchbox:HasAnyInput() and self.selected_emoji ~= emoji and widget and focus then
        self.searchbox.textbox.prompt:SetString(widget.data.name_full)
    end

    self.selected_emoji = emoji
    self.selected_widget = widget
    self.selected_category = category

    if widget then
        widget.button:Select()
    end
end

function EmojiMenu:RefreshSearching()
    PEARL.debug("EmojiMenu:RefreshSearching")
    self.scroll_list.no_emojis_msg:Hide()
    self.scroll_list:ResetScroll()

    local search_str = self.searchbox.textbox:GetLineEditString()
    if not search_str or search_str == "" then
        self.scroll_list:SetItemsData(self.loaded_data)
    else
        local emojis_data = {}
        for _, data in ipairs(self.loaded_data) do
            if data.searchable == true and data.emoji ~= nil and data.name_full ~= nil and data.name_full:find(search_str, 1, true) then
                emojis_data[#emojis_data + 1] = data
            end
        end

        self.scroll_list:SetItemsData(emojis_data)

        if table.empty(emojis_data) ~= false then
            self.scroll_list.no_emojis_msg:Show()

            return self:SelectEmojiWidget(nil)
        end
    end

    -- If no widget has focus (the cursor is outside the grid) select the first widget.
    local focused_widget = self:GetFirstEmojiWidget() --self:GetFocusedEmojiWidget() or self:GetFirstEmojiWidget()
    self:SelectEmojiWidget(focused_widget) -- Accept even nil - representing no results
end

---------------------------
-- [[ Public Methods ]]
---------------------------

--- There can be dupes between categories but not within one.
function EmojiMenu:IsEmojiSelected(emoji, category)
    return self.selected_emoji == emoji and self.selected_category == category
end

--- Optional map to support name aliases.
--- To each emoji symbol a full name should be mapped in a format like ":name1: :name2:"
function EmojiMenu:SetEmojiNamesMap(map)
    self.flnames_map = map
end

--- @param categories table<number, table> Array of emoji categories. Order is kept.
function EmojiMenu:LoadEmojiCategories(categories)
    self.categories = categories

    PEARL.debug("EmojiMenu:LoadEmojisCategories")
    if emoji_data_cache[self.categories] ~= nil then
        self.loaded_data = emoji_data_cache[self.categories]
        return
    end

    self.loaded_data = {} -- Create a new table, since the old one is cached.
    emoji_data_cache[self.categories] = self.loaded_data -- Cache the table right away to prevent dupes
    StartStaticThread(function()
        _last_check = os.clock()

        for _, category in ipairs(categories) do
            if table.empty(category.emojis) == false then
                self:_LoadEmojiCategory(category)

                check_and_yield()
            end
        end

        if self.scroll_list and self:IsOpen() then
            self:RefreshSearching()
        end
    end, self.inst.GUID)
end

function EmojiMenu:ReloadData()
    PEARL.debug("EmojiMenu:ReloadData")

    self:LoadEmojiCategories(self.categories)
end

function EmojiMenu:Open()
    PEARL.debug("EmojiMenu:Open")

    if emoji_data_cache[self.categories] == nil then
        self:ReloadData()
    end

    self.menu = self.menu or self:_BuildExplorer()
    self.menu:Show()
    self.menu:MoveToFront()

    if type(self.onopen) == "function" then
        self.onopen()
    end

    self:RefreshSearching()

    self.searchbox:Clear()
    self.searchbox.textbox:SetFocus(true)
    self.searchbox.textbox:SetEditing(true)
end

function EmojiMenu:Close()
    PEARL.debug("EmojiMenu:Close")

    self.menu:Hide()

    self.closing = true
    self.inst:DoStaticTaskInTime(0, function()
        self.closing = false
    end)

    self.searchbox.textbox:SetEditing(false)
    self.searchbox.textbox:SetString("")

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

function EmojiMenu:OnSearchPromptUpdated(prompt)
    if not self.selected_widget or not self.selected_widget.button or not self.selected_widget.button.hovertext_root then
        return
    end

    if prompt:IsVisible() then
        self.selected_widget.button:HideHover()
        self.searchbox.button_clear:Hide()
    else
        self.selected_widget.button:ShowHover()
        self.searchbox.button_clear:Show()
    end
end

function EmojiMenu:OnControl(control, down, ...)
    PEARL.debug("EmojiMenu:OnControl", control, down)
    if EmojiMenu._base.OnControl(self, control, down, ...) then return true end

    if not self:IsOpen() then
        return
    end

    if not down and control == CONTROL_CANCEL then -- Pressing ESC
        self:Close()

        return true
    end

    if self.scroll_list then
        return self.scroll_list:OnControl(control, down, ...)
    end
end

function EmojiMenu:OnRawKey(key, down, ...)
    PEARL.debug("EmojiMenu:OnRawKey", key, down)

    if EmojiMenu._base.OnRawKey(self, key, down, ...) then return true end

    if not self:IsOpen() then
        return
    end

    -- This is here for cases where the searchbox is not focused.
    if down and key == KEY_ENTER and self.selected_emoji then
        self:_ChooseEmoji(self.selected_emoji)

        return true
    end

    if not down and key == KEY_X and self.searchbox then
        self.searchbox:Clear()

        return true
    end
end

---------------------------
-- [[ Return ]]
---------------------------

return EmojiMenu
