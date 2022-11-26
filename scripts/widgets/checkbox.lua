
local Widget = require "widgets/widget"
local Text = require("widgets/text")
local Image = require("widgets/image")
local ImageButton = require("widgets/imagebutton")

--------------------------------
-- [[ Constants ]]
--------------------------------

local TEXT_SIZE = 30
-- local TEXT_COLOR = {1,}
local TEXT_REGION_X = 600
local TEXT_REGION_Y = 50
local TEXT_POS_Y = -10

local BUTTON_POS_Y = 0

local BACKGROUND_POS_X = -75
local BACKGROUND_POS_Y = 2
local BACKGROUND_WIDTH_OFFSET = 40
local BACKGROUND_HEIGHT = 50

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

local CheckBox = Class(Widget, function(self)
    Widget._ctor(self, "CheckBox")

    self._is_checked = false
    self._onclick = nil

    self._text = self:AddChild(Text(CHATFONT, TEXT_SIZE))

    -- Unchecked by default
    self._button = self:AddChild(ImageButton(
        "images/ui.xml",
        "checkbox_off.tex",
        "checkbox_off_highlight.tex",
        "checkbox_off_disabled.tex", nil, nil, {1,1}, {0,0}
    ))
    local textW, textH = self._text:GetRegionSize()
    local buttonW, buttonH = self._button:GetSize()
    local checkbox_x = -(textW / 2) - (buttonW * 2)

    self._button:SetPosition(checkbox_x, BUTTON_POS_Y)
    self._button:SetOnClick(function()
        self:OnClick()
    end)

    self._text:SetVAlign(ANCHOR_LEFT)
    self._text:SetRegionSize(TEXT_REGION_X, TEXT_REGION_Y)
    self._text:SetPosition(checkbox_x + (textW / 2) + (buttonW / 2), BACKGROUND_POS_Y)

    self._bg = self:AddChild(Image("images/ui.xml", "single_option_bg.tex"))
    self._bg:MoveToBack()
    self._bg:SetClickable(false)
    self._bg:ScaleToSize(textW + buttonW + BACKGROUND_WIDTH_OFFSET, BACKGROUND_HEIGHT)
    self._bg:SetPosition(BACKGROUND_POS_X, BACKGROUND_POS_Y)

    self.default_focus = self._button
end)

--------------------------------
-- [[ Public Functions ]]
--------------------------------

function CheckBox:IsChecked()
    return self._is_checked
end

function CheckBox:SetIsChecked(checked)
    self._is_checked = checked
    if self._is_checked then
        self._button:SetTextures("images/ui.xml", "checkbox_off.tex", "checkbox_off_highlight.tex", "checkbox_off_disabled.tex", nil, nil, {1,1}, {0,0})
    else
        self._button:SetTextures("images/ui.xml", "checkbox_on.tex", "checkbox_on_highlight.tex", "checkbox_on_disabled.tex", nil, nil, {1,1}, {0,0})
    end
end

function CheckBox:SetText(text)
    self._text:SetString(text)
end

function CheckBox:SetOnClick(fn)
    self._onclick = fn
end

function CheckBox:OnClick()
    self:SetIsChecked(not self._is_checked)

    if type(self._onclick) == "function" then
        self._onclick(self)
    end
end

--------------------------------

return CheckBox
