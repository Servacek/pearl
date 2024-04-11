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
local UIAnim = require("widgets/uianim")

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

local CLEAR_BUTTON_CONTROLS = "Ctrl + X"

local DIRECTIONS = {MOVE_LEFT = -1, MOVE_RIGHT = 1, MOVE_UP = -1, MOVE_DOWN = 1}

local ATLAS = MODROOT.."images/emoji_menu.xml"

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

    self.loaded = false

    self.onopen = nil
    self.onclose = nil
    self.onclosing = nil

    self.onemojichosen = nil
    self.onemojidisplay = nil
    self.onemojifavoritetoggled = nil

    self.inst:ListenForEvent("emojis_used", function()
        if self.categories ~= nil then
            -- Do not do the reload immediately since we can use emojis even without the menu open.
            emoji_data_cache[self.categories] = nil
        end
    end, PEARL.INST)

    self.widget_data = {} -- All scrollable menu widgets
    self.search_data = {} -- Array of emojis implicitly sorted by priority (every emoji there should be unique)

    self.name_to_category = {} -- Useful for checking if an emoji was already loaded.

    self.last_search_data = nil
    self.last_search_text = nil

    -- Optional table of utf8 chars mapped to a full name (with all aliases and delims)
    self.flnames_map = nil
end)

---------------------------
-- [[ Private Methods ]]
---------------------------

--- @param category table
--- @param index integer
function EmojiMenu:_LoadEmojiCategory(category, index)
    PEARL.debug("EmojiMenu:_LoadEmojiCategory")

    local remainder = #self.widget_data % SCROLLER_VISIBLE_COLS
    if remainder ~= 0 then -- Fill the remaining space in the last row with empty tiles.
        for _ = 1, SCROLLER_VISIBLE_COLS - remainder do
            self.widget_data[#self.widget_data + 1] = EMPTY_TILE
        end
    end

    self.widget_data[#self.widget_data + 1] = {category = category.name, header = true}

    for _ = 1, SCROLLER_VISIBLE_COLS - 1 do
        self.widget_data[#self.widget_data + 1] = EMPTY_HEADER_TILE
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

        --- @TODO: Add alias support.
        local emoji_char = PEARL.EMOJIS.ALL[emoji_name] or EMOJI_CHARACTER_FALLBACK
        if type(emoji_name) == "table" then
            local emoji_table = emoji_name
            emoji_char = emoji_table.emoji or emoji_char
            emoji_name = emoji_table.name or emoji_table.names and emoji_table.names[1]
        end

        local fullname = emoji_name
        local unlocked
        if category.unlockedfn then
            unlocked = category.unlockedfn(emoji_name)
        end
        local widget_data = {
            emoji = emoji_char,
            display_name = EMOJI_ALIAS_FORMAT:format(fullname),
            search_token = fullname,
            category = category.name,
            category_index = index,
            searchable = category.searchable ~= false,
            name = emoji_name,
            case_sensitive = not fullname:islowercase(),
            unlocked = unlocked,
        }

        self.widget_data[#self.widget_data + 1] = widget_data

        if self.name_to_category[emoji_name] == nil and widget_data.unlocked then
            self.name_to_category[emoji_name] = category

            self.search_data[#self.search_data + 1] = widget_data
        end

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

    searchbox.textbox.OnTextInputted = function()
        searchbox.textbox:_TryUpdateTextPrompt()

        local search_text = searchbox.textbox:GetLineEditString()
        if search_text ~= nil and search_text ~= self.last_search_text then
            self:RefreshSearching(search_text)
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

    -- Just do nothing - Also an option but then cause the input to not be fetched
    -- So... let's just keep it the Discord way and lose focus.
    --searchbox.textbox.OnStopForceProcessTextInput = function() end

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
    searchbox.button_clear:SetHoverText(STRINGS.PEARL.UI.EMOJI_MENU.CLEAR_BUTTON_HOVER:format(
        CLEAR_BUTTON_CONTROLS
    ), {offset_y = 50})
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

    -- When shift is down, keep the window open so emojis can be spammed.
    if not TheInput:IsKeyDown(KEY_SHIFT) then
        self:Close()
    end
end

function EmojiMenu:_CreateEmojiScrollList()
    local function ScrollWidgetsCtor(context, index)
        local w = Widget("emoji_item"..tostring(index))

        w.button = w:AddChild(TEMPLATES.EmojiButton(ITEM_SIZE, false, SCROLLER_ITEM_MARGIN))
        w.button:AddHoverText()
        w.button.AllowOnControlWhenSelected = true -- So we handle clicks even when selected
        w.focus_forward = w.button

        w.button.anim = w.button:AddChild(UIAnim())
        w.button.anim:SetScale(.8)
        w.button.anim:MoveToBack()
        w.button.anim:SetPosition(-22, -19)

        if self.onemojifavoritetoggled then
            w.button.fav_button = w.button:AddChild(ImageButton(ATLAS, "star_uncheck.tex", "star_uncheck.tex", nil, "star_checked.tex"))
            w.button.fav_button:SetFocusScale(.6, .6)
            w.button.fav_button:SetNormalScale(.5, .5)
            w.button.fav_button:SetPosition(15, 20)
            w.button.fav_button:Hide()
            w.button.fav_button:SetOnClick(function()
                if not w.data.emoji then
                    return
                end

                w.data.favorite = not w.data.favorite
                if not w.data.favorite then
                    w.button.fav_button:SetTextures(ATLAS, "star_uncheck.tex", "star_uncheck.tex", nil, "star_checked.tex")
                else
                    w.button.fav_button:SetTextures(ATLAS, "star_checked.tex", "star_checked.tex", nil, "star_uncheck.tex")
                end

                self.onemojifavoritetoggled(w.data.emoji, w.data.favorite)
            end)
        end

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
            if is_emoji(w) then
                if w.button:IsEnabled() then
                    w.button.fav_button:Show()
                end

                if self.selected_widget ~= w then
                    self:SelectEmojiWidget(w, true)
                end
            end
        end)

        w.button:SetOnLoseFocus(function()
            w.button.fav_button:Hide()
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
            w.button.fav_button:Hide()
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
            widget.button:SetHoverText(data.display_name)
            widget.button:Show()

            if self.onemojidisplay and self.scroll_list and self.scroll_list:IsVisible() then
                self.onemojidisplay(data.id)
            end

            if data.name == "vibing_cat" then
                --- @TODO: Fix frames when scrolling using AnimState:SetFrame
                --- Store the frame in some emoji specific data.
                widget.button.text:Hide()
                widget.button.anim:Show()
                widget.button.anim:GetAnimState():SetBuild("vibing_cat")
                widget.button.anim:GetAnimState():SetBank("vibing_cat")
                widget.button.anim:GetAnimState():PlayAnimation("default", true)
            else
                widget.button.anim:Hide()
                widget.button.text:Show()
            end

            if data.unlocked == false then
                widget.button:Lock()
                widget.button.new_tag_image:Hide()
                widget.button.fav_button:Hide()
            else
                widget.button:Unlock()
                widget.button.new_tag_image:Show()
            end

            if (self:IsEmojiSelected(data.emoji, data.category) or widget.focus) and not widget:IsSelected() then
                self:SelectEmojiWidget(widget)
            elseif not self:IsEmojiSelected(data.emoji, data.category) and widget:IsSelected() and not widget.focus then
                self:UnselectEmojiWidget(widget)
            end
        end

        if not widget:IsVisible() then
            widget:Show()
        end
    end

	local scroll_list, colums, height, rows = TEMPLATES.ScrollingGrid(self.widget_data, {
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
        scroll_per_click        = 1,
        scrollbar_offset        = SCROLLBAR_OFFSET, -- Offset of the scrollbar from the grid
        apply_fn                = ApplyDataToWidget,
        --allow_bottom_empty_row  = false,
    })

    local atlas = resolvefilepath(CRAFTING_ATLAS)
	scroll_list.up_button:SetTextures(atlas, "scrollbar_arrow_up.tex", "scrollbar_arrow_up_hl.tex")
    scroll_list.up_button:SetScale(0.4)

	scroll_list.down_button:SetTextures(atlas, "scrollbar_arrow_down.tex", "scrollbar_arrow_down_hl.tex")
    scroll_list.down_button:SetScale(0.4)

	scroll_list.scroll_bar_line:SetTexture(atlas, "scrollbar_bar.tex")
    scroll_list.scroll_bar_line:ScaleToSize(11, scroll_list.scrollbar_height - 15)

	scroll_list.position_marker:SetTextures(atlas, "scrollbar_handle.tex")
	scroll_list.position_marker.image:SetTexture(atlas, "scrollbar_handle.tex")
    scroll_list.position_marker:SetScale(.3)

    scroll_list.no_emojis_msg = scroll_list:AddChild(Text(UIFONT, 26, STRINGS.PEARL.UI.EMOJI_MENU.NO_EMOJIS_FOUND, UICOLOURS.GOLD_UNIMPORTANT))
	scroll_list.no_emojis_msg:SetPosition(SCROLLBAR_OFFSET, 0)
	scroll_list.no_emojis_msg:Hide()

	scroll_list.custom_focus_check = function() return self.focus end
    -- scroll_list.OnEmojiWidgetSelected = scroll_list.OnWidgetFocus
    -- scroll_list.OnWidgetFocus = function() end
    -- --- @TODO: Add support for arrow keys and controlers.
    -- scroll_list.OnFocusMove = function(_self, dir, down)
    --     local index = 1
    --     for i = 1, _self.items_per_view do
    --         if _self.widgets_to_update[i] == self.selected_widget then
    --             index = i
    --         end
    --     end

    --     if dir == MOVE_RIGHT or dir == MOVE_LEFT and self.searchbox.textbox:IsEditing() and self.searchbox:HasAnyInput() then
    --         return -- Leave those for the textbox.
    --     end

    --     --- 3x3
    --     --- ... [1, 1] = 1 * 3 + 1
    --     --- ... [2, 2] =
    --     --- ...
    --     local i = index - 1
    --     local row = (math.floor(i / SCROLLER_VISIBLE_COLS))
    --     local col = i - (row * SCROLLER_VISIBLE_COLS) + 1

    --     print(row, col)

    --     if dir == MOVE_LEFT then
    --         local new_index = index - 1
    --         print(new_index % SCROLLER_VISIBLE_COLS, index % SCROLLER_VISIBLE_COLS)
    --         if new_index % SCROLLER_VISIBLE_COLS ~= index % SCROLLER_VISIBLE_COLS then
    --             print("CIRCULAR")
    --             new_index = (index % SCROLLER_VISIBLE_COLS) * SCROLLER_VISIBLE_COLS + SCROLLER_VISIBLE_COLS
    --         end
    --         self:SelectEmojiWidget(_self.widgets_to_update[new_index])
    --     else

    --     end
    -- end

	return scroll_list
end

-- Clears the state of the emoji menu, useful when reloading.
function EmojiMenu:_Clear()
    self.widget_data = {} -- Create a new table since the old one is cached.

    table.iclear(self.search_data)
    table.clear(self.name_to_category)

    self.last_search_data = nil
    self.last_search_text = ""

    self.selected_category = nil
    self.selected_widget = nil
    self.selected_emoji = nil
end

function EmojiMenu:_GetSearchedEmojis(search_prompt, narrow)
    local search_prompt_normalized = search_prompt:lower()
    local search_results = {}

    local search_data = narrow and self.last_search_data or self.search_data
    for i = 1, #search_data do
        local data = search_data[i]

        data._search_i = data.search_token:find(search_prompt_normalized, 1, true)
        if data._search_i then
            search_results[#search_results + 1] = data
        end
    end

    table.sort(search_results, function(a, b) --- a<b
        if a.category_index ~= b.category_index then
            return a.category_index < b.category_index -- Sort by category first
        -- elseif a._case_sensitive_match ~= b._case_sensitive_match then
        --     return a._case_sensitive_match -- Sort by case sensitivity?
        elseif a._search_i ~= b._search_i then
            return a._search_i < b._search_i -- Better matches are closer to the start
        else
            return a.name < b.name -- Sort alphabetically at least.
        end
    end)

    return search_results
end

function EmojiMenu:_BuildExplorer()
    local bg_color = UICOLOURS.BROWN_DARK
    self.menu = self:AddChild(TEMPLATES.RectangleWindow(MENU_WIDTH, MENU_HEIGHT))
    -- This is the default colour for these windows but we have a custom alpha channel.
    self.menu:SetBackgroundTint(bg_color[1], bg_color[2], bg_color[3], .7)

    self.scroll_list = self.menu:InsertWidget(self:_CreateEmojiScrollList())
    self.scroll_list:SetPosition(SCROLLIST_PADDING_X, SCROLLIST_PADDING_Y)

    local _, y = self.menu.top:GetPositionXYZ()
    self.searchbox = self.menu:InsertWidget(self:_CreateSearchBox(SEARCHBOX_WIDTH, SEARCHBOX_HEIGHT))
    self.searchbox:SetPosition(SEARCHBOX_PADDING_X, y + SEARCHBOX_PADDING_Y)
    self.searchbox:MoveToFront()

    self.default_focus = self.searchbox

    return self.menu
end

--- @return Widget? emoji
function EmojiMenu:GetFirstEmojiWidget()
    if self.scroll_list and self.scroll_list.widgets_to_update then
        for i = 1, #self.scroll_list.widgets_to_update do
            local widget = self.scroll_list.widgets_to_update[i]
            if is_emoji(widget) and widget:IsVisible() then
                return widget
            end
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
    PEARL.debug("EmojiMenu:SelectEmojiWidget", widget and widget.data and widget.data.display_name)
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
        self.searchbox.textbox.prompt:SetString(widget.data.display_name)
    end

    self.selected_emoji = emoji
    self.selected_widget = widget
    self.selected_category = category

    --self.scroll_list:OnEmojiWidgetSelected(widget)

    if widget then
        widget.button:Select()
    end
end

--- @param search_text string?
function EmojiMenu:RefreshSearching(search_text)
    PEARL.debug("EmojiMenu:RefreshSearching", CalledFrom())
    self.scroll_list.no_emojis_msg:Hide()
    self.scroll_list:ResetScroll()

    local search_result_data
    if not search_text or search_text == "" then
        search_result_data = self.widget_data
        self.last_search_data = nil
    else
        local narrower_search = search_text:len() > (self.last_search_text and self.last_search_text:len() or 0)
        search_result_data = self:_GetSearchedEmojis(search_text, narrower_search)
        self.last_search_data = search_result_data -- Only save data from the search function here!
    end

    self.scroll_list:SetItemsData(search_result_data)

    self.last_search_text = search_text

    if table.empty(self.scroll_list.items) ~= false then
        self.scroll_list.no_emojis_msg:Show()
    end

    --- Searching has more priority that the focused widget.
    self:SelectEmojiWidget(self:GetFirstEmojiWidget()) -- Accept even nil - representing no results
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

--- Optional map to support name aliases.
--- To each emoji symbol a full name should be mapped in a format like ":name1: :name2:"
function EmojiMenu:SetCategorySearchPriorities(priorities)
    self.cat_priorities = priorities
end

--- @param categories table<number, table> Array of emoji categories. Order is kept.
function EmojiMenu:LoadEmojiCategories(categories)
    self.categories = categories

    PEARL.debug("EmojiMenu:LoadEmojisCategories")
    if emoji_data_cache[self.categories] ~= nil then
        self.widget_data = emoji_data_cache[self.categories]
        return
    end

    self:_Clear()
    emoji_data_cache[self.categories] = self.widget_data -- Cache the table right away to prevent dupes

    self.loaded = false
    StartStaticThread(function()
        _last_check = os.clock()

        for index, category in ipairs(categories) do
            if table.empty(category.emojis) == false then
                self:_LoadEmojiCategory(category, index)

                check_and_yield()
            end
        end

        self.loaded = true
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

    -- if self.loaded then
    --     self:RefreshSearching()
    -- end

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

        if type(self.onclose) == "function" then
            self.onclose()
        end
    end)

    self.searchbox.textbox:SetEditing(false)
    self.searchbox.textbox:SetString("")

    if type(self.onclosing) == "function" then
        self.onclosing()
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

    if down then
        if control == CONTROL_FOCUS_DOWN then
            self.scroll_list:OnFocusMove(MOVE_DOWN, true)
        elseif control == CONTROL_FOCUS_UP then
            self.scroll_list:OnFocusMove(MOVE_UP, true)
        elseif control == CONTROL_FOCUS_LEFT then
            self.scroll_list:OnFocusMove(MOVE_LEFT, true)
        elseif control == CONTROL_FOCUS_RIGHT then
            self.scroll_list:OnFocusMove(MOVE_RIGHT, true)
        end
    end

    -- if self.scroll_list then
    --     return self.scroll_list:OnControl(control, down, ...)
    -- end
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
