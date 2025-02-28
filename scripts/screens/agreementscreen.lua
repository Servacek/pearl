--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local Screen = require("widgets/screen")
local Text = require("widgets/text")
local Widget = require("widgets/widget")
local TrueScrollArea = require("widgets/truescrollarea")
local TEMPLATES = require("widgets/redux/templates")

-- --------------------------------
-- -- [[ Constants ]]
-- --------------------------------

local SIZE_X = 840
local SIZE_Y = 620

local DESCRIPTION_MAX_LINES = 1000
local DESCRIPTION_PADDING_LEFT = 60
local DESCRIPTION_MAX_WIDTH = SIZE_X - DESCRIPTION_PADDING_LEFT
local DESCRIPTION_FONT = CHATFONT
local DESCRIPTION_FONT_SIZE = 24
local DESCRIPTION_COLOR = UICOLOURS.GOLD_UNIMPORTANT

local DIALOG_BUTTONS_FONT = HEADERFONT
local DIALOG_BUTTONS_TEXT_SIZE = 28
local DIALOG_BUTTONS_TEXT_WIDTH = 250
local DIALOG_BUTTONS_TEXT_OFFSET_X = 80
local DIALOG_BUTTONS_TEXT_COLOUR = UICOLOURS.GOLD_UNIMPORTANT
local DIALOG_BUTTONS_PADDING_TOP  = 130
local DIALOG_BUTTONS_SPACING = 300
local DIALOG_BUTTONS_PADDING_RIGHT = 30
local DIALOG_BUTTONS_PADDING_LEFT = (DESCRIPTION_MAX_WIDTH - (DIALOG_BUTTONS_TEXT_WIDTH * 2) + DIALOG_BUTTONS_SPACING) / 2 - DIALOG_BUTTONS_PADDING_RIGHT
local DIALOG_BUTTONS_PADDING_BOTTOM = 100 -- increasing this will move the buttons up!

local CHECKBOX_TEXT_SIZE = 20
local CHECKBOX_PADDING_LEFT = 25
local CHECKBOX_PADDING_TOP = 40
local CHECKBOX_TEXT_OFFSET = 25

local FOOTER_LABELS_TEXT_SIZE = 18
local FOOTER_LABELS_TEXT_FONT = CHATFONT
local FOOTER_LABELS_SPACING = 20

local BODY_LABELS_TEXT_SIZE = 24
local BODY_LABELS_TEXT_FONT = CHATFONT
local BODY_LABELS_TEXT_COLOUR = UICOLOURS.GOLD
local BODY_LABELS_SPACING = 29

local TITLE_FONT_SIZE = 68
local TITLE_FONT = TITLEFONT
local TITLE_COLOUR = UICOLOURS.GOLD
local TITLE_PADDING_X = 0
local TITLE_PADDING_Y = -50

local SUBTITLE_FONT_SIZE = 32
local SUBTITLE_FONT = TITLEFONT
local SUBTITLE_COLOR = UICOLOURS.GOLD
local SUBTITLE_SPACING_BOTTOM = 5

local SECTION_SPACING = 30

local SCROLLABLE_PADDING_TOP = -20

local SCROLLBAR_PADDING_LEFT = 10
local SCROLLBAR_PADDING_RIGHT = 10
local SCROLLBAR_PADDING_BOTTOM = 120
local SCROLLBAR_PADDING_TOP = TITLE_FONT_SIZE - 20
local SCROLLBAR_WIDTH = DESCRIPTION_MAX_WIDTH + SCROLLBAR_PADDING_RIGHT
local SCROLLBAR_HEIGHT = SIZE_Y - SCROLLBAR_PADDING_BOTTOM - SCROLLBAR_PADDING_TOP
local SCROLLBAR_X = -(SIZE_X / 2 - SCROLLBAR_PADDING_LEFT)
local SCROLLBAR_Y = -100 - SCROLLBAR_PADDING_TOP
local SCROLLBAR_SPEED = 25 * 3

local SEP_OFFSET_TOP = 105 -- ~ (a bit lower here because of the shadow)
local SEP_OFFSETB_BOTTOM = 107 -- ~

--------------------------------
-- [[ Local Functions ]]
--------------------------------

local blink_task
local function BlinkButton(button, blink_colour)
    if blink_task and blink_task.limit ~= 0 then
        return
    end

    blink_colour = blink_colour or button.textfocuscolour

    local on = false
    local origin_colour = button.text and button.text.colour
    blink_task = PEARL.StaticScheduler:ExecutePeriodic(0.1, function()
        if on then
            on = false

            if button.text then
                button:SetTextColour(origin_colour)
            end
        else
            on = true

            if button.text then
                button:SetTextColour(blink_colour)
            end
        end

        button:Refresh()
    end, 6)
end

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

local AgreementScreen = Class(Screen, function(self, readonly)
    Screen._ctor(self, "AgreementScreen")

    --TheInputProxy:SetCursorVisible(true)

    self._on_continue_fn = nil

    -- [[ Popup Window ]]

    --darken everything behind the dialog
    self._bg = self:AddChild(TEMPLATES.BackgroundTint())

    self._root = self:AddChild(TEMPLATES.ScreenRoot())

    local bottom_buttons
    if readonly then
        bottom_buttons = {
            {
                text = STRINGS.PEARL.UI.AGREEMENT_SCREEN_BUTTON_CLOSE,
                cb = function() self:DoClose() end,
            },
        }
    end

    -- [[ Dialog Window Setup ]]
    self._dialog = self._root:AddChild(TEMPLATES.RectangleWindow(SIZE_X, SIZE_Y,
        PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT[1].title, bottom_buttons
    ))
    self._dialog:SetBackgroundTint(unpack(UICOLOURS.BROWN_DARK))

    -- [[ Dialog Title ]]
    self._dialog.title:SetFont(TITLE_FONT)
    self._dialog.title:SetColour(TITLE_COLOUR)
    self._dialog.title:SetSize(TITLE_FONT_SIZE)
    -- Apply padding
    local x, y = self._dialog.title:GetPositionXYZ()
    self._dialog.title:SetPosition(x + TITLE_PADDING_X, y + TITLE_PADDING_Y)
    -- Adjust the region size to support very long titles.
    self._dialog.title:SetRegionSize(SIZE_X, TITLE_FONT_SIZE)

    -- [[ Popup Window Body ]]

    self._scrollable = Widget("AgreementScrollArea")

    local height = 0

    -- [[ Header Description ]]

    local header = PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT[1]
    if type(header.description) == "string" and #header.description:strip() > 0 then
        self._scrollable.body = self._scrollable:AddChild(Text(
            DESCRIPTION_FONT, DESCRIPTION_FONT_SIZE, nil, DESCRIPTION_COLOR
        ))
        self._scrollable.body:SetHAlign(ANCHOR_LEFT)
        self._scrollable.body:SetVAlign(ANCHOR_TOP)
        self._scrollable.body:SetMultilineTruncatedString(header.description, DESCRIPTION_MAX_LINES, DESCRIPTION_MAX_WIDTH)
        x, y = self._scrollable.body:GetRegionSize()
        self._scrollable.body:SetPosition(0.5 * x, height - 0.5 * y)

        height = height - y - SECTION_SPACING
    end

    -- [[ Sections ]]

    local desc_pos_x = 0

    -- Skip the first index since that's the title
    for i = 2, #PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT do
        local section = PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT[i]
        local title = self._scrollable:AddChild(Text(
            SUBTITLE_FONT, SUBTITLE_FONT_SIZE, section.title, SUBTITLE_COLOR
        ))
        title:SetHAlign(ANCHOR_LEFT)

        x, y = title:GetRegionSize()
        title:SetPosition(0.5 * x, height - 0.5 * y)
        height = height - y - SUBTITLE_SPACING_BOTTOM

        local desc = self._scrollable:AddChild(Text(
            DESCRIPTION_FONT, DESCRIPTION_FONT_SIZE, nil, DESCRIPTION_COLOR
        ))
        desc:SetHAlign(ANCHOR_LEFT)
        desc:SetVAlign(ANCHOR_TOP)
        desc:SetMultilineTruncatedString(section.description, DESCRIPTION_MAX_LINES, DESCRIPTION_MAX_WIDTH)
        x, y = desc:GetRegionSize()
        desc_pos_x = desc:GetPositionXYZ()
        desc:SetPosition(0.5 * x, height - 0.5 * y)

        height = height - y - SECTION_SPACING
    end

    -- [[ Data Collection Checkbox ]]
    local dc_checkbox_widget = self._scrollable:AddChild(Widget("DataCollectionCheckbox"))
    self._scrollable.dc_checkbox_button = dc_checkbox_widget:AddChild(TEMPLATES.LabelCheckbox(
        function(checkbox)
            checkbox.checked = not checkbox.checked
            checkbox:Refresh()
        end,
        true, -- Keep checked for default, but the user can opt out.
        "" -- This needs to be here in order for the text widget to work correctly.
    ))

    local dc_button_width = self._scrollable.dc_checkbox_button:GetSize()
    self._scrollable.dc_checkbox_button:SetTextSize(CHECKBOX_TEXT_SIZE)
    self._scrollable.dc_checkbox_button.text:SetMultilineTruncatedString(STRINGS.PEARL.UI.AGREEMENT_DC_CHECKBOX_TEXT, 3, DESCRIPTION_MAX_WIDTH - dc_button_width)

    -- Re-adjust the text's position
    local text_width = self._scrollable.dc_checkbox_button.text:GetRegionSize()
    self._scrollable.dc_checkbox_button.text:SetPosition(CHECKBOX_TEXT_OFFSET + text_width/2, 0)

    dc_checkbox_widget:SetPosition(desc_pos_x + CHECKBOX_PADDING_LEFT, height - CHECKBOX_PADDING_TOP)
    dc_checkbox_widget.focus_forward = self._scrollable.dc_checkbox_button

    if readonly then
        self._scrollable.dc_checkbox_button.checked = true
        self._scrollable.dc_checkbox_button:Disable()
        self._scrollable.dc_checkbox_button:Refresh()
    end

    -------------------------------
    -- [[ Accept/Decline Buttons ]]
    -------------------------------

    self._scrollable.decline_button = self._scrollable:AddChild(TEMPLATES.MenuButton(
        STRINGS.PEARL.UI.AGREEMENT_SCREEN_BUTTON_DECLINE, function()
            self:OnContinue(false)
        end
    ))
    local text_region_width = 250
    local text_len = string.utf8len(STRINGS.PEARL.UI.AGREEMENT_SCREEN_BUTTON_DECLINE)
    local text_middle = (text_region_width - text_len) / 4
    self._scrollable.decline_button.text:SetPosition(text_middle, 0)
    self._scrollable.decline_button.text_shadow:SetPosition(text_middle, 0)
    self._scrollable.decline_button:SetPosition(
        DIALOG_BUTTONS_PADDING_LEFT, height - DIALOG_BUTTONS_PADDING_TOP
    )

    self._scrollable.accept_button = self._scrollable:AddChild(TEMPLATES.MenuButton(
        STRINGS.PEARL.UI.AGREEMENT_SCREEN_BUTTON_ACCEPT, function()
            if self._scrollable.dc_checkbox_button.checked == true then
                return self:OnContinue(true)
            end

            -- Warn the user that this button needs to be checked before continuing...
            BlinkButton(self._scrollable.dc_checkbox_button, WHITE)
        end
    ))
    self._scrollable.accept_button.text:SetPosition(DIALOG_BUTTONS_TEXT_OFFSET_X, 0)
    self._scrollable.accept_button.text_shadow:SetPosition(DIALOG_BUTTONS_TEXT_OFFSET_X, 0)
    local _, h = self._scrollable.accept_button.text:GetRegionSize()
    self._scrollable.accept_button:SetPosition(
        DIALOG_BUTTONS_PADDING_LEFT + DIALOG_BUTTONS_SPACING, height - DIALOG_BUTTONS_PADDING_TOP
    )

    if readonly then
        self._scrollable.accept_button:Hide()
        self._scrollable.decline_button:Hide()

        local label_x = DESCRIPTION_MAX_WIDTH / 2 + 25
        self._scrollable.nomodif_label = self._scrollable:AddChild(Text(BODY_LABELS_TEXT_FONT, BODY_LABELS_TEXT_SIZE))
        self._scrollable.nomodif_label:SetString(STRINGS.PEARL.UI.AGREEMENT_NO_MODIFICATION_LABEL)
        self._scrollable.nomodif_label:SetColour(BODY_LABELS_TEXT_COLOUR)
        self._scrollable.nomodif_label:SetPosition(
            label_x, height - DIALOG_BUTTONS_PADDING_TOP
        )

        local tm = PEARL.AgreementManager:GetLocalLastAgreeTime()
        if (type(tm) == "string" and #tm > 1) or type(tm) == "number" then
            self._scrollable.accept_time_label = self._scrollable:AddChild(Text(BODY_LABELS_TEXT_FONT, BODY_LABELS_TEXT_SIZE))
            self._scrollable.accept_time_label:SetColour(BODY_LABELS_TEXT_COLOUR)
            self._scrollable.accept_time_label:SetString(STRINGS.PEARL.UI.AGREEMENT_LAST_AGREE_LABEL:format(
                PEARL.TimestampToFancyDateString(tm)
            ))
            self._scrollable.accept_time_label:SetPosition(
                label_x, height - DIALOG_BUTTONS_PADDING_TOP - BODY_LABELS_SPACING
            )
        end
    end

    height = math.abs(height - h - DIALOG_BUTTONS_SPACING - DIALOG_BUTTONS_PADDING_BOTTOM)

    -------------------------------
    -- [[ Scrollable Area ]]
    -------------------------------

    -- Scrolling configurations.
    local scissor_data = {
        x = 0,
        y = -(SCROLLBAR_HEIGHT / 2) + SCROLLBAR_PADDING_BOTTOM,
        width = SCROLLBAR_WIDTH,
        height = SCROLLBAR_HEIGHT,
    }
    -- Scrollable widget configurations
    local context = {
        widget = self._scrollable,
        -- Controls the scrollable area
        offset = { x = 0, y = math.min(height, SCROLLBAR_HEIGHT) / 2 - SCROLLBAR_PADDING_TOP - SCROLLABLE_PADDING_TOP + SCROLLBAR_PADDING_BOTTOM},
        size = { w = SCROLLBAR_WIDTH, height = height - SCROLLBAR_PADDING_BOTTOM }
    }
    local scrollbar = { scroll_per_click = SCROLLBAR_SPEED }
    self._scroll_area = self._dialog:AddChild(TrueScrollArea(context, scissor_data, scrollbar))
    self._scroll_area:SetPosition(SCROLLBAR_X, SCROLLBAR_Y)

    self._dialog.top_hline = self._dialog:AddChild(Image("images/ui.xml", "line_horizontal_6.tex"))
	self._dialog.top_hline:SetScale(2.4, .5)
    self._dialog.top_hline:SetPosition(-10, SCROLLBAR_Y + SCROLLBAR_HEIGHT - SEP_OFFSET_TOP, 0)

    self._dialog.bot_hline = self._dialog:AddChild(Image("images/ui.xml", "line_horizontal_6.tex"))
	self._dialog.bot_hline:SetScale(2.4, .5)
    self._dialog.bot_hline:SetPosition(-10, SCROLLBAR_Y - SEP_OFFSETB_BOTTOM, 0)

    self._dialog.version_label = self._dialog:AddChild(Text(FOOTER_LABELS_TEXT_FONT, FOOTER_LABELS_TEXT_SIZE))
    self._dialog.version_label:SetString(STRINGS.PEARL.UI.AGREEMENT_VERSION_LABEL:format(
        PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT.version or "1.0"
    ))
    self._dialog.version_label:SetPosition(desc_pos_x, SCROLLBAR_Y - SEP_OFFSETB_BOTTOM - 20 - FOOTER_LABELS_SPACING, 0)

    if PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT.lmt then
        self._dialog.last_update_label = self._dialog:AddChild(Text(FOOTER_LABELS_TEXT_FONT, FOOTER_LABELS_TEXT_SIZE))
        self._dialog.last_update_label:SetString(STRINGS.PEARL.UI.AGREEMENT_LAST_UPDATE_LABEL:format(
            PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT.lmt or "1.0"
        ))
        self._dialog.last_update_label:SetPosition(desc_pos_x, SCROLLBAR_Y - SEP_OFFSETB_BOTTOM - FOOTER_LABELS_SPACING, 0)
    end

    -- [[ Focus Setup ]]
    self.default_focus = self._scrollable.accept_button
    self.focus_forward = self._scrollable.accept_button
end)

--- @param fn fun(self: AgreementScreen, data: table<string, any>)
function AgreementScreen:SetOnContinue(fn)
    self._on_continue_fn = fn
end

function AgreementScreen:OnContinue(agreed)
    if self._on_continue_fn then
        local data = {
            agreed = agreed or false,
            datacollection = self._scrollable.dc_checkbox_button.checked
        }

        return self._on_continue_fn(self, data)
    end

    -- If there is no special handler just close the screen
    self:DoClose()
end

function AgreementScreen:DoClose()
    TheFrontEnd:PopScreen(self)

    -- Make sure we try to enable the screen behind this
    -- local screen = TheFrontEnd:GetActiveScreen()
    -- if screen then
    --     screen:Enable()
    -- end
end

-------------------------------------
-- [[ Return ]]
-------------------------------------

return AgreementScreen
