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
-- local Button = require "widgets/button"
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
-- From screens/redux/popupdialog.lua:27's dark_wide mode.
local SIZE_X = 750
local SIZE_Y = 480

local NORMAL_FONT_SIZE = 21
local TITLE_FONT_SIZE = 25

--- @TODO: Calculate the number of lines dinamically
local DESCRIPTION_MAX_LINES = 1000
local DESCRIPTION_PADDING_LEFT = 100
local DESCRIPTION_MAX_WIDTH = SIZE_X - DESCRIPTION_PADDING_LEFT
local DESCRIPTION_TEXT_SIZE = 22

local TITLE_SPACING_BOTTOM = 5

local SECTION_SPACING = 30

local SCROLLBAR_PADDING_LEFT = 20
local SCROLLBAR_X = -(SIZE_X / 2 - SCROLLBAR_PADDING_LEFT)
local SCROLLBAR_Y = 20
local SCROLLBAR_PADDING_RIGHT = 40
local SCROLLBAR_PADDING_BOTTOM = 100
local SCROLLBAR_WIDTH = DESCRIPTION_MAX_WIDTH + SCROLLBAR_PADDING_RIGHT
local SCROLLBAR_HEIGHT = SIZE_Y - SCROLLBAR_PADDING_BOTTOM
local SCROLLBAR_PADDING = 5
local SCROLLBAR_SPEED = 20 * 3

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
    font_size = NORMAL_FONT_SIZE,
    image_scale = 0.7,
    atlas = "images/ui.xml",
    on_image = "radiobutton_on.tex",
    off_image = "radiobutton_off.tex",
}

local RADIO_BUTTON_WIDTH = #AGREEMENT_OPTIONS * 145
local RADIO_BUTTON_HEIGHT = 50
local RADIO_BUTTON_PADDING_TOP = 25
local RADIO_BUTTON_SPACING = 25
local RADIO_BUTTON_PADDING_LEFT = 25
local RADIO_BUTTON_PADDING_BOTTOM = 30

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

    local buttons = {
        { text = STRINGS.PEARL.UI.AGREEMENT_SCREEN_BUTTON_FINISH, cb = function()
            self:OnContinue()
        end }
    }

    self._dialog = self._root:AddChild(TEMPLATES.CurlyWindow(SIZE_X, SIZE_Y,
        PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT[1].title, buttons))

    self._dialog.continue_button = self._dialog.actions.items[1]
    self._dialog.continue_button:Disable()

    -- [[ Popup Window Body ]]

    self._body = Widget("AgreementDialogBody")

    local left = 0
    local height = 0

    -- [[ Header Description ]]

    local header = PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT[1]
    if type(header.description) == "string" and #header.description:strip() > 0 then
        local desc = self._body:AddChild(Text(CHATFONT, NORMAL_FONT_SIZE, nil, UICOLOURS.GREY))
        desc:SetHAlign(ANCHOR_LEFT)
        desc:SetVAlign(ANCHOR_TOP)
        desc:SetMultilineTruncatedString(header.description, DESCRIPTION_MAX_LINES, DESCRIPTION_MAX_WIDTH)
        local x, y = desc:GetRegionSize()
        desc:SetPosition(left + 0.5 * x, height - 0.5 * y)

        height = height - y - SECTION_SPACING
    end

    -- [[ Sections ]]

    -- Skip the first index since that's the title
    for i = 2, #PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT do
        local section = PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT[i]
        local title = self._body:AddChild(Text(HEADERFONT, TITLE_FONT_SIZE, section.title, UICOLOURS.GOLD_UNIMPORTANT))
        title:SetHAlign(ANCHOR_LEFT)

        local x, y = title:GetRegionSize()
        title:SetPosition(left + 0.5 * x, height - 0.5 * y)
        height = height - y - TITLE_SPACING_BOTTOM

        local desc = self._body:AddChild(Text(CHATFONT, NORMAL_FONT_SIZE, nil, UICOLOURS.GREY))
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

    self._body.agreement_checkbox = self._body:AddChild(TEMPLATES.LabelCheckbox(
        function(checkbox)
            if self._body.disagreement_checkbox.checked then
                self._body.disagreement_checkbox.checked = false
            end

            checkbox.checked = not checkbox.checked
            self._body.disagreement_checkbox:Refresh()
            checkbox:Refresh()

            if checkbox.checked then
                self._dialog.continue_button:Enable()
            else
                self._dialog.continue_button:Disable()
            end
            -- Keep unchecked by default
        end, false, STRINGS.PEARL.UI.AGREEMENT_SCREEN_BUTTON_AGREE)
    )
    local w, h = self._body.agreement_checkbox.text:GetRegionSize()
    self._body.agreement_checkbox:SetPosition(left + RADIO_BUTTON_PADDING_LEFT,
        height - (h / 2) - RADIO_BUTTON_PADDING_TOP)
    height = height - h - RADIO_BUTTON_PADDING_TOP

    self._body.disagreement_checkbox = self._body:AddChild(TEMPLATES.LabelCheckbox(
        function(checkbox)
            if self._body.agreement_checkbox.checked then
                self._body.agreement_checkbox.checked = false
            end

            checkbox.checked = not checkbox.checked
            self._body.agreement_checkbox:Refresh()
            checkbox:Refresh()

            if checkbox.checked then
                self._dialog.continue_button:Enable()
            else
                self._dialog.continue_button:Disable()
            end
            -- Keep unchecked by default
        end, false, STRINGS.PEARL.UI.AGREEMENT_SCREEN_BUTTON_DISAGREE)
    )
    w, h = self._body.disagreement_checkbox.text:GetRegionSize()
    self._body.disagreement_checkbox:SetPosition(left + RADIO_BUTTON_PADDING_LEFT,
        height - (h / 2) - RADIO_BUTTON_SPACING)
    height = height - h - RADIO_BUTTON_SPACING - RADIO_BUTTON_PADDING_BOTTOM

    -- [[ Scroll Area ]]

    height = math.abs(height)

    local scissor_data = {
        x = 0,
        y = -(SCROLLBAR_HEIGHT / 2),
        width = SCROLLBAR_WIDTH,
        height = SCROLLBAR_HEIGHT
    }
    local context = {
        widget = self._body,
        offset = { x = 0, y = math.min(height, SCROLLBAR_HEIGHT) / 2 - SCROLLBAR_PADDING },
        size = { w = SCROLLBAR_WIDTH, height = height + SCROLLBAR_PADDING }
    }
    local scrollbar = { scroll_per_click = SCROLLBAR_SPEED }
    self._scroll_area = self._dialog:AddChild(TrueScrollArea(context, scissor_data, scrollbar))
    self._scroll_area:SetPosition(SCROLLBAR_X, SCROLLBAR_Y)

    -- [[ Focus Setup ]]

    self.default_focus = self._scroll_area
    self.focus_forward = self._scroll_area
end)

function AgreementScreen:SetOnContinue(fn)
    self._on_continue_fn = fn
end

function AgreementScreen:OnContinue()
    if self._on_continue_fn then
        return self._on_continue_fn(self, self._body.agreement_checkbox.checked)
    end

    -- If there is no special handler just close the screen
    self:Close()
end

function AgreementScreen:Close()
    TheFrontEnd:PopScreen(self)
end

return AgreementScreen
