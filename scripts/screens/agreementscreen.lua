--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local Screen = require("widgets/screen")
local Button = require "widgets/button"
-- local AnimButton = require "widgets/animbutton"
-- local ImageButton = require "widgets/imagebutton"
local Text = require("widgets/text")
-- local Image = require "widgets/image"
local Widget = require("widgets/widget")
-- local Menu = require "widgets/menu"
local TrueScrollArea = require("widgets/truescrollarea")
-- local ScrollableList = require("widgets/scrollablelist")
local RadioButtons = require("widgets/radiobuttons")
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
local DIALOG_BUTTONS_PADDING_TOP  = -30
local DIALOG_BUTTONS_SPACING = 300
local DIALOG_BUTTONS_PADDING_RIGHT = 30
local DIALOG_BUTTONS_PADDING_LEFT = (DESCRIPTION_MAX_WIDTH - (DIALOG_BUTTONS_TEXT_WIDTH * 2) + DIALOG_BUTTONS_SPACING) / 2 - DIALOG_BUTTONS_PADDING_RIGHT
local DIALOG_BUTTONS_PADDING_BOTTOM = 10

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
local SCROLLBAR_SPEED = 20 * 3

local SEP_OFFSET_TOP = 104 -- ~ (a bit lower here because of the shadow)
local SEP_OFFSETB_BOTTOM = 107 -- ~

local AGREEMENT_STATES = {
    AGREED = 1,
    DISAGREED = 0,
}
local AGREEMENT_OPTIONS = {
    { text = STRINGS.PEARL.UI.AGREEMENT_SCREEN_BUTTON_AGREE, data = AGREEMENT_STATES.AGREED },
    { text = STRINGS.PEARL.UI.AGREEMENT_SCREEN_BUTTON_DISAGREE, data = AGREEMENT_STATES.DISAGREED },
}

local AGREEMENT_BUTTON_SETTINGS = {
    width = 140,
    height = 40,
    font = NEWFONT,
    font_size = DESCRIPTION_FONT_SIZE,
    image_scale = 0.7,
    atlas = "images/ui.xml",
    on_image = "radiobutton_on.tex",
    off_image = "radiobutton_off.tex",
}

local RADIO_BUTTON_WIDTH = #AGREEMENT_OPTIONS * 145
local RADIO_BUTTON_HEIGHT = 50

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

local AgreementScreen = Class(Screen, function(self)
    Screen._ctor(self, "AgreementScreen")

    self._on_continue_fn = nil

    -- [[ Popup Window ]]

    --darken everything behind the dialog
    self._bg = self:AddChild(TEMPLATES.BackgroundTint())

    self._root = self:AddChild(TEMPLATES.ScreenRoot())

    -- [[ Dialog Window Setup ]]
    self._dialog = self._root:AddChild(TEMPLATES.RectangleWindow(SIZE_X, SIZE_Y,
        PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT[1].title
    ))
    self._dialog:SetBackgroundTint(unpack(UICOLOURS.BROWN_DARK))

    -- [[ Dialog Title ]]
    self._dialog.title:SetFont(TITLE_FONT)
    self._dialog.title:SetColour(TITLE_COLOUR)
    self._dialog.title:SetSize(TITLE_FONT_SIZE)
    --self._dialog.title:SetHorizontalSqueeze(0)
    -- Apply padding
    local x, y = self._dialog.title:GetPositionXYZ()
    self._dialog.title:SetPosition(x + TITLE_PADDING_X, y + TITLE_PADDING_Y)
    -- Adjust the region size to support very long titles.
    local _, h = self._dialog.title:GetRegionSize()
    self._dialog.title:SetRegionSize(SIZE_X, TITLE_FONT_SIZE)


    -- [[ Continue Button ]]
    -- self._dialog.continue_button = self._dialog.actions.items[1]
    -- self._dialog.continue_button:SetFont(DIALOG_BUTTONS_FONT)
    -- -- Set the font as the disabled one as well to keep consistency.
    -- self._dialog.continue_button:SetDisabledFont(DIALOG_BUTTONS_FONT)
    -- self._dialog.continue_button:Disable() -- Disabled by default

    -- [[ Popup Window Body ]]

    self._scrollable = Widget("AgreementScrollArea")

    local left = 0
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
        local x, y = self._scrollable.body:GetRegionSize()
        self._scrollable.body:SetPosition(left + 0.5 * x, height - 0.5 * y)

        height = height - y - SECTION_SPACING
    end

    -- [[ Sections ]]

    -- Skip the first index since that's the title
    for i = 2, #PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT do
        local section = PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT[i]
        local title = self._scrollable:AddChild(Text(
            SUBTITLE_FONT, SUBTITLE_FONT_SIZE, section.title, SUBTITLE_COLOR
        ))
        title:SetHAlign(ANCHOR_LEFT)

        local x, y = title:GetRegionSize()
        title:SetPosition(left + 0.5 * x, height - 0.5 * y)
        height = height - y - SUBTITLE_SPACING_BOTTOM

        local desc = self._scrollable:AddChild(Text(
            DESCRIPTION_FONT, DESCRIPTION_FONT_SIZE, nil, DESCRIPTION_COLOR
        ))
        desc:SetHAlign(ANCHOR_LEFT)
        desc:SetVAlign(ANCHOR_TOP)
        desc:SetMultilineTruncatedString(section.description, DESCRIPTION_MAX_LINES, DESCRIPTION_MAX_WIDTH)
        x, y = desc:GetRegionSize()
        desc:SetPosition(left + 0.5 * x, height - 0.5 * y)

        height = height - y - SECTION_SPACING
    end

    -- [[ Agree/Disagree Checkboxes ]]

    -- Possible better alternative?
    -- self._body.buttons = self._body:AddChild(RadioButtons(AGREEMENT_OPTIONS, RADIO_BUTTON_HEIGHT, RADIO_BUTTON_WIDTH, AGREEMENT_BUTTON_SETTINGS))
    -- self._body.buttons:SetOnChangedFn(function(data)
    --     self._dialog.continue_button:Enable()
    -- end)
    -- self._body.buttons:SetPosition(left + 0.5 * RADIO_BUTTON_WIDTH, height - 0.5 * RADIO_BUTTON_HEIGHT)

    -- height = height - RADIO_BUTTON_HEIGHT

    self._scrollable.decline_button = self._scrollable:AddChild(TEMPLATES.MenuButton(
        "Decline", function()
            self:OnContinue(false)
        end
    ))
    self._scrollable.decline_button.text:SetPosition(DIALOG_BUTTONS_TEXT_OFFSET_X, 0)
    self._scrollable.decline_button.text_shadow:SetPosition(DIALOG_BUTTONS_TEXT_OFFSET_X, 0)
    local w, h = self._scrollable.decline_button.text:GetRegionSize()
    self._scrollable.decline_button:SetPosition(
        left + DIALOG_BUTTONS_PADDING_LEFT, height + DIALOG_BUTTONS_PADDING_TOP
    )

    self._scrollable.agree_button = self._scrollable:AddChild(TEMPLATES.MenuButton(
        "Accept", function()
            self:OnContinue(true)
        end
    ))
    self._scrollable.agree_button.text:SetPosition(DIALOG_BUTTONS_TEXT_OFFSET_X, 0)
    self._scrollable.agree_button.text_shadow:SetPosition(DIALOG_BUTTONS_TEXT_OFFSET_X, 0)
    -- self._scrollable.agree_button:SetText("Accept")
    -- self._scrollable.agree_button:SetTextSize(DIALOG_BUTTONS_TEXT_SIZE)
    -- self._scrollable.agree_button:SetTextColour(unpack(DIALOG_BUTTONS_TEXT_COLOUR))
    -- self._scrollable.agree_button:SetFont(DIALOG_BUTTONS_FONT)
    -- self._scrollable.agree_button:SetDisabledFont(DIALOG_BUTTONS_FONT)
    w, h = self._scrollable.agree_button.text:GetRegionSize()
    self._scrollable.agree_button:SetPosition(
        left + DIALOG_BUTTONS_PADDING_LEFT + DIALOG_BUTTONS_SPACING, height + DIALOG_BUTTONS_PADDING_TOP)
    height = height - h - DIALOG_BUTTONS_SPACING + DIALOG_BUTTONS_PADDING_BOTTOM

    -- self._scrollable.agreement_checkbox = self._scrollable:AddChild(TEMPLATES.LabelCheckbox(
    --     function(checkbox)
    --         if self._scrollable.disagreement_checkbox.checked then
    --             self._scrollable.disagreement_checkbox.checked = false
    --         end

    --         checkbox.checked = not checkbox.checked
    --         self._scrollable.disagreement_checkbox:Refresh()
    --         checkbox:Refresh()

    --         if checkbox.checked then
    --             self._dialog.continue_button:Enable()
    --         else
    --             self._dialog.continue_button:Disable()
    --         end
    --         -- Keep unchecked by default
    --     end, false, STRINGS.PEARL.UI.AGREEMENT_SCREEN_BUTTON_AGREE)
    -- )
    -- local w, h = self._scrollable.agreement_checkbox.text:GetRegionSize()
    -- self._scrollable.agreement_checkbox:SetPosition(left + RADIO_BUTTON_PADDING_LEFT,
    --     height - (h / 2) - RADIO_BUTTON_PADDING_TOP)
    -- height = height - h - RADIO_BUTTON_PADDING_TOP

    -- self._scrollable.disagreement_checkbox = self._scrollable:AddChild(TEMPLATES.LabelCheckbox(
    --     function(checkbox)
    --         if self._scrollable.agreement_checkbox.checked then
    --             self._scrollable.agreement_checkbox.checked = false
    --         end

    --         checkbox.checked = not checkbox.checked
    --         self._scrollable.agreement_checkbox:Refresh()
    --         checkbox:Refresh()

    --         if checkbox.checked then
    --             self._dialog.continue_button:Enable()
    --         else
    --             self._dialog.continue_button:Disable()
    --         end
    --         -- Keep unchecked by default
    --     end, false, STRINGS.PEARL.UI.AGREEMENT_SCREEN_BUTTON_DISAGREE)
    -- )
    -- w, h = self._scrollable.disagreement_checkbox.text:GetRegionSize()
    -- self._scrollable.disagreement_checkbox:SetPosition(left + RADIO_BUTTON_PADDING_LEFT,
    --     height - (h / 2) - RADIO_BUTTON_SPACING)
    -- height = height - h - RADIO_BUTTON_SPACING - RADIO_BUTTON_PADDING_BOTTOM

    -- [[ Scroll Area ]]

    height = math.abs(height)

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
    self._dialog.top_hline:SetPosition(-10, SCROLLBAR_Y + SCROLLBAR_HEIGHT - SEP_OFFSETB_BOTTOM, 0)

    self._dialog.bot_hline = self._dialog:AddChild(Image("images/ui.xml", "line_horizontal_6.tex"))
	self._dialog.bot_hline:SetScale(2.4, .5)
    self._dialog.bot_hline:SetPosition(-10, SCROLLBAR_Y - SEP_OFFSETB_BOTTOM, 0)

    -- [[ Focus Setup ]]
    self.default_focus = self._scrollable.decline_button
    self.focus_forward = self._scrollable.decline_button
end)

function AgreementScreen:SetOnContinue(fn)
    self._on_continue_fn = fn
end

function AgreementScreen:OnContinue(agreed)
    if self._on_continue_fn then
        return self._on_continue_fn(self, agreed or false)
    end

    -- If there is no special handler just close the screen
    self:Close()
end

function AgreementScreen:Close()
    TheFrontEnd:PopScreen(self)
end

return AgreementScreen
