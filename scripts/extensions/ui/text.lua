--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--- @class Text
local Text = require("widgets/text")
local TextEdit = require("widgets/textedit")
local UIAnim = require("widgets/uianim")
local Button = require("widgets/button")

local TEMPLATES = require("widgets/redux/templates")

-------------------------------
-- [[ Constants ]]
-------------------------------

local ANIMATED_EMOJI_WIDTH = 50
local ANIMATED_EMOJI_HEIGHT = ANIMATED_EMOJI_WIDTH

local TEXT_WIDGET_MARGIN_H = -2
local TEXT_WIDGET_MARGIN_V = -2

-------------------------------
-- [[ Locals ]]
-------------------------------

--- Using static instance, so we do not have to recreate it on simple calculations.
local _text_widget
local _inserted_widgets = {}
local _parents = setmetatable({},{
    __mode = "kv", -- Do not let the tables stored inside to hide from the Garbage Collector!
})

--- @type function, function
local _TextEditWidget_SetString, _TextWidget_SetString = TextEditWidget.SetString, TextWidget.SetString
assert(_TextEditWidget_SetString and _TextWidget_SetString)

-------------------------------
-- [[ Public Functions ]]
-------------------------------

local function GetStringSize(self, s, font, size)
    if s == "" then
        return 0, 0
    end

    if not _text_widget then
        _text_widget = Text(font or self.font, size or self.size).inst.TextWidget
    end

    --- All these can have an effect on the region size
    _text_widget:SetFont(font or self.font)
    _text_widget:SetSize(size or self.size)
    _TextWidget_SetString(_text_widget, s)

    local w, h = _text_widget:GetRegionSize()
    return w and w + TEXT_WIDGET_MARGIN_H or 0, h and h + TEXT_WIDGET_MARGIN_V or 0
end

--- @TODO: This needs some adusting.
local function AdjustWidget(lua_widget, widget)
    local s = lua_widget:GetString()
    local prefix = s:sub(1, widget._first_index - 1)
    local proxy_str = s:sub(widget._first_index, widget._last_index)
    local prefix_width = GetStringSize(lua_widget, prefix)
    if prefix_width > 0 then
        prefix_width = prefix_width + 4
    end
    local region_w = lua_widget:GetRegionSize()
    local char_w, char_h = GetStringSize(lua_widget, proxy_str)
    local x = prefix_width - region_w / 2

    local widget_w, widget_h
    if widget.GetRegionSize then
        widget_w, widget_h = widget:GetRegionSize()
    end

    widget:SetPosition(x, -15)
    if widget_w ~= nil and widget_h ~= nil then
        widget:SetScale(char_w / widget_w, char_h / widget_h, 1)
    end
end

local function AdjustAllInsertedWidgets(lua_widget)
    if lua_widget.inserted_widgets then
        for _, widget in pairs(lua_widget.inserted_widgets) do
            AdjustWidget(lua_widget, widget)
        end
    end
end

--- @param widget Widget
--- @param first integer?
--- @param last integer?
local function InsertWidgetAtPosition(lua_widget, widget, first, last)
    PEARL.debug("Text:InsertWidgetAtPosition", widget, first, last)

    first = first or 1
    last = last or first

    if widget._first_index and widget._last_index then
        lua_widget:RemoveWidget(widget) -- If the widget was already inserted, remove it.
    end
    lua_widget:AddChild(widget)
    lua_widget:MoveToFront() -- Keep in the front in case the text has some background.

    local proxy_str = lua_widget:GetString():sub(first, last)
    widget._first_index, widget._last_index, widget._proxy_str = first, last, proxy_str

    lua_widget.inserted_widgets = lua_widget.inserted_widgets or {}
    lua_widget.inserted_widgets[first] = widget


    AdjustWidget(lua_widget, widget)
end

--- @param widget Widget
local function RemoveWidget(lua_widget, widget)
    PEARL.debug("Text:RemoveWidget", widget)

    if not lua_widget.inserted_widgets or not lua_widget.inserted_widgets[widget._first_index] then
        return
    end

    lua_widget.inserted_widgets[widget._first_index] = nil
    _inserted_widgets[widget._first_index] = nil
    widget._first_index, widget._last_index, widget._proxy_str = nil, nil, nil
    lua_widget:RemoveChild(widget)
end

-------------------------------
-- [[ Local Functions ]]
-------------------------------

local function GetAnimatedEmojiSize()
    return ANIMATED_EMOJI_WIDTH, ANIMATED_EMOJI_HEIGHT
end

local function GetParent(c_widget)
    return _parents[c_widget]
end

local function InsertAnimatedEmoji(lua_widget, first, last, emoji_utf8_str)
    PEARL.debug("InsertAnimatedEmoji", lua_widget, first, last)

    local emoji_name = PEARL.EMOJIS.UTF_TO_NAME[emoji_utf8_str]
    local emoji_animation = UIAnim()
    emoji_animation:GetAnimState():SetBuild(emoji_name)
    emoji_animation:GetAnimState():SetBank(emoji_name)
    emoji_animation:GetAnimState():PlayAnimation("default", true)
    emoji_animation.GetRegionSize = GetAnimatedEmojiSize

    InsertWidgetAtPosition(lua_widget, emoji_animation, first, last)
end

---------------------------
-- [[ Event Handlers ]]
---------------------------

local function OnCWidgetUpdated(c_widget)
    local parent = c_widget:GetParent()
    if parent then
        AdjustAllInsertedWidgets(parent)
    end
end

--- Called after the actual change, so self:GetString() does return the current string.
local function OnTextUpdated(lua_widget)
    local first = 1    --- @type integer?
    local last = first --- @type integer?
    local s = lua_widget:GetString()
    while first ~= nil do
        first, last = s:find(PEARL.CONSTS.UTF_EMOJI_PATTERN, first)
        if first ~= nil then
            local emoji_utf8_str = s:sub(first, last)
            if emoji_utf8_str and PEARL.EMOJIS.IsEmojiAnimated(emoji_utf8_str) and (
                not lua_widget.inserted_widgets or lua_widget.inserted_widgets[first] == nil
            ) then
                InsertAnimatedEmoji(lua_widget, first, last, emoji_utf8_str)
            end

            first = last + 1
        end
    end

    if lua_widget.inserted_widgets then
        for _, widget in pairs(lua_widget.inserted_widgets) do
            if s:sub(widget._first_index, widget._last_index) ~= widget._proxy_str then
                RemoveWidget(lua_widget, widget)
                widget:Kill()
            end
        end
    end
end

local function OnSetString(c_widget, s)
    local lua_widget = c_widget:GetParent()
    if not lua_widget or s == lua_widget.last_str then
        return
    end

    lua_widget.last_str = s
    if type(s) ~= "string" then
        return
    end

    OnTextUpdated(lua_widget)
end

local function OnSetColour(c_widget, r, g, b, a)
    local parent = c_widget:GetParent()
    if parent and parent.inserted_widgets then
        for _, widget in pairs(parent.inserted_widgets) do
            if widget.inst and widget.inst.AnimState then
                widget.inst.AnimState:SetMultColour(1, 1, 1, a)
            end
        end
    end
end

local function OnKeyDown(c_widget, key)
    if key == KEY_BACKSPACE or key == KEY_DELETE then
        local parent = c_widget:GetParent()
        if parent then
            OnTextUpdated(parent)
        end
    end
end

local function OnTextInput(c_widget, char)
    local parent = c_widget:GetParent()
    if parent then
        OnSetString(c_widget, parent:GetString())
    end
end

local function OnTextPostConstruct(lua_widget)
    --- Make sure the C-side TextWidget has reference to our Lua object.
    if lua_widget.inst.TextWidget then
        _parents[lua_widget.inst.TextWidget] = lua_widget
    end

    if lua_widget.inst.TextEditWidget then
        _parents[lua_widget.inst.TextEditWidget] = lua_widget
    end

    PEARL.AddClassFunctionPostCall("SetFont", AdjustAllInsertedWidgets, lua_widget)
    PEARL.AddClassFunctionPostCall("SetSize", AdjustAllInsertedWidgets, lua_widget)
end

function PEARL.ShowDebugData()
    print("NUMBER OF INSERTED WIDGETS", table.size(_inserted_widgets))
end

---------------------------
-- [[ Post-Callbacks ]]
---------------------------

if PEARL.CONFIG.ANIMATED_EMOJIS then
    TextWidget.GetParent, TextEditWidget.GetParent = GetParent, GetParent

    PEARL.AddClassFunctionPostCall("SetString", OnSetString, TextWidget)
    PEARL.AddClassFunctionPostCall("SetColour", OnSetColour, TextWidget)
    PEARL.AddClassFunctionPostCall("SetVAnchor", OnCWidgetUpdated, TextWidget)
    PEARL.AddClassFunctionPostCall("SetHAnchor", OnCWidgetUpdated, TextWidget)
    PEARL.AddClassFunctionPostCall("SetRegionSize", OnCWidgetUpdated, TextWidget)
    PEARL.AddClassFunctionPostCall("ResetRegionSize", OnCWidgetUpdated, TextWidget)

    PEARL.AddClassFunctionPostCall("SetString", OnSetString, TextEditWidget)
    PEARL.AddClassFunctionPostCall("OnKeyDown", OnKeyDown, TextEditWidget)
    PEARL.AddClassFunctionPostCall("OnTextInput", OnTextInput, TextEditWidget)

    PEARL.AddClassPostConstruct("widgets/text", OnTextPostConstruct)
    PEARL.AddClassPostConstruct("widgets/textedit", OnTextPostConstruct)
end
