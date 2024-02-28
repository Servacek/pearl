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
local SCROLLIST_HEIGHT = SCROLLER_GRID_SIZE + 5

local BOX_SIZE = 300
local BOX_HEIGHT = 40
local INPUTBOX_FONT_SIZE = 35

local TIMEBUDGET = FRAMES * 0.1
local CHECK_FREQUENCY = 50

local EMPTY_TILE = {} -- So we do not create a dummy table each time as a fillament

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

---------------------------
-- [[ Class Declaration ]]
---------------------------

--- @class EmojiMenu
local EmojiMenu = Class(Widget, function(self, emojis, chat_edit)
    Widget._ctor(self, "Nitro Emoji Menu")

    self.chat_edit = chat_edit

    self.scroller_cols = 5
    self.scroller_rows = 5

    print(self.scroller_cols, self.scroller_rows)
    self.insert_index = 1

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
            local remainder = #self.emojis_data % self.scroller_cols
            if remainder ~= 0 then
                for _ = 1, self.scroller_cols - remainder do
                    table.insert(self.emojis_data, EMPTY_TILE)
                end
            end

            self.emojis_data[#self.emojis_data+1] = {category = category, header = true}

            for _ = 1, self.scroller_cols - 1 do
                table.insert(self.emojis_data, EMPTY_TILE)
            end

            local emoji_aliases = {}
            for alias, emoji in pairs(emojis) do
                emoji_aliases[emoji] = emoji_aliases[emoji] or {}
                table.insert(emoji_aliases[emoji], alias)
                check_and_yield()
            end

            for emoji, aliases in pairs(emoji_aliases) do
                table.insert(self.emojis_data, {
                    category = category,
                    emoji = emoji,
                    aliases = aliases
                })

                check_and_yield()
                -- Maybe try refresh the scrollist here?
            end
        end

        if self.scroll_list then
            self:RefreshScrollingItems()
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
        local string = searchbox.textbox:GetLineEditString()
        if string ~= last_string then
            last_string = string
            self:RefreshScrollingItems()
        end
    end

    searchbox.textbox.OnTextEntered = function()
        print("TEXT ENTERED")
        if self.selected_emoji then
            self:InsertEmoji(self.selected_emoji)
            self:Close()
        end
    end

    searchbox.textbox.OnStopForceEdit = function()
        print("StopForceEdit")
        if not self.menu.focus then
            self:Close()
        end
    end

    searchbox.focus_forward = searchbox.textbox

    return searchbox
end

function EmojiMenu:_CreateEmojiList(width, height)
    local function ScrollWidgetsCtor(context, index)
        local w = TEMPLATES.EmojiButton(ITEM_SIZE)
        w.bg:ScaleToSize(width, width)

		----------------
        w.category_label = w:AddChild(Text(TITLEFONT, 45))
        w.category_label:SetRegionSize(1000, 50)
        w.category_label:SetPosition(0, 0)
        w.category_label:SetHAlign(ANCHOR_MIDDLE)

        w:SetOnGainFocus(function()
            if w.data and self.selected_emoji ~= w.data.emoji then
                self:SetSelectedEmoji(w.data.emoji, w.data.aliases)
            end
        end)

        w:SetOnLoseFocus(function()
            if w.data and self.selected_emoji == w.data.emoji then
                self:SetSelectedEmoji(nil)
            end
        end)

        w:SetOnClick(function()
            if w.data and type(w.data.emoji) == "string" then
                self:InsertEmoji(w.data.emoji)
            end
        end)

        -- w:SetOnControl(function(self, control, down, ...)
        --     if not self.focus then
        --         return false
        --     end

        --     if control == CONTROL_SECONDARY then
        --         if down then
        --             if not self.rmb_down then
        --                 TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
        --                 self.o_pos = self:GetLocalPosition()
        --                 self:SetPosition(self.o_pos + self.clickoffset)
        --                 self.rmb_down = true
        --                 if self.whiledown then
        --                     self:StartUpdating()
        --                 end
        --             end
        --         else
        --             if self.rmb_down then
        --                 self.rmb_down = false
        --                 self:ResetPreClickPosition()
        --                 self.onrightclick()
        --                 self:StopUpdating()
        --             end
        --         end
        --         return true
        --     end
        -- end)

		----------------
		return w
    end

    local function ApplyDataToWidget(context, widget, data, index)
        widget.data = data
        if table.empty(data) ~= false then
            return widget:Hide()
        end

        if data.header then
            widget.text:Hide()
            widget.bg:Hide()

            widget.category_label:SetString(data.category)
            widget.category_label:Show()
        else
            widget.category_label:Hide()
            widget:SetText(data.emoji)
            widget:Show()
        end

        widget:Show()
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

	--grid.custom_focus_check = function() return self.focus end

	return grid
end

function EmojiMenu:_BuildExplorer()
    local bg_color = UICOLOURS.BROWN_DARK
    self.menu = self:AddChild(TEMPLATES.RectangleWindow(MENU_WIDTH, MENU_HEIGHT))
    self.menu:SetBackgroundTint(bg_color[1], bg_color[2], bg_color[3], .7) -- A bit of transparency
    self.menu:SetPosition(0, 250)

    self.search_box = self.menu.top:AddChild(self:_CreateSearchBox())
    self.search_box:SetPosition(0, -35)

    self.aliases_text = self.menu.bottom:AddChild(Text(BODYTEXTFONT, 30))
    self.aliases_text:SetPosition(0, 25)

    self.scroll_list = self.search_box.textbox:AddChild(self:_CreateEmojiList(SCROLLIST_WIDTH, SCROLLIST_HEIGHT))
    self.scroll_list:SetPosition(-10, -155 - BOX_HEIGHT)

    self.default_focus = self.search_box
    self.focus_forward = self.search_box

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
            if table.empty(data) == false and data.header == nil then
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

    local focused_widget = self.scroll_list:GetFocusChild()
    self:SetSelectedEmoji(focused_widget and focused_widget.data and focused_widget.emoji or nil)
end

function EmojiMenu:Open()
    self.menu = self.menu or self:_BuildExplorer()

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
    self.search_box.textbox:SetString("")
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
        print("CLOSING!!!!!")
        self:Close()
        return true
    end
end

---------------------------
-- [[ Return ]]
---------------------------

return EmojiMenu
