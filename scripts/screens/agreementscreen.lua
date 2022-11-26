

local Screen = require "widgets/screen"
local Button = require "widgets/button"
local AnimButton = require "widgets/animbutton"
local ImageButton = require "widgets/imagebutton"
local Text = require "widgets/text"
local Image = require "widgets/image"
local Widget = require "widgets/widget"
local Menu = require "widgets/menu"
local TrueScrollArea = require "widgets/truescrollarea"
local ScrollableList = require("widgets/scrollablelist")
local RadioButtons = require("widgets/radiobuttons")
local TEMPLATES = require "widgets/redux/templates"

-- --------------------------------
-- -- [[ Constants ]]
-- --------------------------------

local SIZE_X = 480
local SIZE_Y = 480

local NORMAL_FONT_SIZE = 21
local TITLE_FONT_SIZE = 25

local DESCRIPTION_MAX_LINES = 200
local DESCRIPTION_MAX_WIDTH = 380
local DESCRIPTION_TEXT_SIZE = 22
-- local CONTINUE_BUTTON_OFFSET = Vector3(250, 50, 0)
-- local AGREEMENT_CHECKBOX_OFFSET = Vector3(250, 70, 0)
-- local DISAGREMENT_CHECKBOX_OFFSET = Vector3(250, 60, 0)
-- local STYLE = "dark"

local SCROLLBAR_X = -225
local SCROLLBAR_Y = 20
local SCROLLBAR_WIDTH = 420
local SCROLLBAR_HEIGHT = 360
local SCROLLBAR_PADDING = 5
local SCROLLBAR_SPEED = 20 * 3

-- Count the lines from text
local AGREEMENT_TEXT = string.rep("text ", 300)

local AGREEMENT_STATES = {
    AGREED = 1,
    DISAGREED = 0,
}
local AGREEMENT_OPTIONS = {
    {text = "Súhlasím", data = AGREEMENT_STATES.AGREED},
    {text = "Nesúhlasím", data = AGREEMENT_STATES.DISAGREED},
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

    -- [[ Popup Window ]]

	--darken everything behind the dialog
    self._bg = self:AddChild(TEMPLATES.BackgroundTint())

    self._root = self:AddChild(TEMPLATES.ScreenRoot())

    local buttons = {
        {text = "Pokračovať", cb = function() self:OnContinue() end}
    }

	self._dialog = self._root:AddChild(TEMPLATES.CurlyWindow(SIZE_X, SIZE_Y, "Pravidlá a Podmienky", buttons))

    self._dialog.continue_button = self._dialog.actions.items[1]
    self._dialog.continue_button:Disable()

    -- [[ Popup Window Body ]]

    self._body = Widget("AgreementDialogBody")

    local character = "wilson"

	local bio = JoinArrays({
						{ title = STRINGS.CHARACTER_TITLES[character], desc = STRINGS.CHARACTER_ABOUTME[character] },
						{ title = STRINGS.CHARACTER_DETAILS.CHARACTER_DESCRIPTION_TITLE, desc = GetCharacterDescription(character) },
						{ title = STRINGS.CHARACTER_DETAILS.CHARACTER_QUOTE_TITLE, desc = STRINGS.CHARACTER_QUOTES[character] },
					},
					STRINGS.CHARACTER_BIOS[character])

	local left = 0
	local height = 0
	local title_space = 5
	local section_space = 22

    -- [[ Sections ]]

	for i, section in ipairs(bio) do
	    local title = self._body:AddChild(Text(HEADERFONT, 25, section.title, UICOLOURS.GOLD_UNIMPORTANT))
		title:SetHAlign(ANCHOR_LEFT)

        local x, y = title:GetRegionSize()
        title:SetPosition(left + 0.5 * x, height - 0.5 * y)
		height = height - y - title_space

		local desc = self._body:AddChild(Text(CHATFONT, 21, nil, UICOLOURS.GREY))
		desc:SetHAlign(ANCHOR_LEFT)
		desc:SetVAlign(ANCHOR_TOP)
        --- @TODO: Calculate the number of lines dinamically
		desc:SetMultilineTruncatedString(section.desc, 1000, DESCRIPTION_MAX_WIDTH)
        x, y = desc:GetRegionSize()
        desc:SetPosition(left + 0.5 * x, height - 0.5 * y)

		height = height - y - section_space
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
            checkbox.checked = not checkbox.checked
            self._body.disagreement_checkbox.checked = not checkbox.checked

            checkbox:Refresh()
            self._body.disagreement_checkbox:Refresh()

            self._dialog.continue_button:Enable()
        -- Keep unchecked by default
        end, false, "Súhlasím so všetkými")
    )
    local w, h = self._body.agreement_checkbox.text:GetRegionSize()
    self._body.agreement_checkbox:SetPosition(left + RADIO_BUTTON_PADDING_LEFT, height - (h / 2) - RADIO_BUTTON_PADDING_TOP)
    height = height - h - RADIO_BUTTON_PADDING_TOP

    self._body.disagreement_checkbox = self._body:AddChild(TEMPLATES.LabelCheckbox(
        function(checkbox)
            checkbox.checked = not checkbox.checked
            self._body.agreement_checkbox.checked = not checkbox.checked

            checkbox:Refresh()
            self._body.agreement_checkbox:Refresh()

            self._dialog.continue_button:Enable()
            -- Keep unchecked by default
        end, false, "Nesúhlasím")
    )
    w, h = self._body.disagreement_checkbox.text:GetRegionSize()
    self._body.disagreement_checkbox:SetPosition(left + RADIO_BUTTON_PADDING_LEFT, height - (h / 2) - RADIO_BUTTON_SPACING)
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

function AgreementScreen:OnContinue()
    TheFrontEnd:PopScreen(self)

    if self._body.disagreement_checkbox.checked then
        return DoRestart(true)
    end
end

return AgreementScreen
