--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--[[
    Extends the player status screen by adding a new discord link button to it.
]]

local PEARL = PEARL

local TextButton  = require("widgets/textbutton")
local Text = require("widgets/text")

local TEMPLATES = require("widgets/redux/templates")

--- @class PlayerStatusScreen
local PlayerStatusScreen = require("screens/playerstatusscreen")

-------------------------------
-- [[ Constants ]]
-------------------------------

local LINK_BUTTON_X = -420
local LINK_BUTTON_Y = 200

local SCREEN_BUTTONS_OFFSET = 48

local UNDERLINE_CHAR = "_"
local UNDERLINE_PADDING_Y = -4
local UNDERLINE_PADDING_X = 0

local HOVER_OFFSET_X = 0
local HOVER_OFFSET_Y = 38

local DEFAULT_FONT = UIFONT
local DEFAULT_COLOUR = WHITE

local HOST_INDEX = 1
local HOST_NAME = PEARL.CONFIG.HOST.NAME
local HOST_URL = PEARL.CONFIG.HOST.URL

local BLOCKED_BUTTONS = {
    ["toggleservertext_button"] = true, -- Useless, and doesn't fit with the other buttons
}

--- booleans
local CUSTOM_HOST_BUTTON = not TheNet:GetServerIsClientHosted() and type(HOST_NAME) == "string"
local VALID_HOST_URL = type(HOST_URL) == "string" and #HOST_URL > 1

---------------------------
-- [[ Locals ]]
---------------------------

-- Show the label only if proxy is enabled.
local proxy_state_label, proxy_state
local function OnProxyStateChanged(new)
    if proxy_state_label then
        proxy_state_label:SetColour(new and WEBCOLOURS.GREEN or WEBCOLOURS.RED)
        proxy_state_label:SetString(STRINGS.PEARL.UI.PROXY_STATE:format(
            new == true and STRINGS.PEARL.UI.ONLINE or STRINGS.PEARL.UI.OFFLINE
        ))
    end
end

if PEARL.CONFIG.DISCORD_PROXY_ENABLED then
    PEARL.AddPlayerPostInit(function(inst)
        proxy_state = net_bool(inst.GUID, "proxy_state", "proxy_state_changed")
        proxy_state:set_local(false)

        inst:ListenForEvent("proxy_state_changed", function()
            OnProxyStateChanged(proxy_state:value())
        end)
    end)
end

---------------------------
-- [[ Overrides ]]
---------------------------

if CUSTOM_HOST_BUTTON then
    PEARL.OverrideMethodReturnValue(PlayerStatusScreen, "GetDisplayName", function(name, self, client)
         -- Return custom name for Hosts.
        if client.performance ~= nil then
            return tostring(HOST_NAME)
        end

        return name
    end)
end

-------------------------------
-- [[ Function Extensions ]]
-------------------------------

-- We have to use DoInit instead of PostConstruct because
-- root is constructed there too.
PEARL.AddClassFunctionPostCall("DoInit", function(self)
    self.servermenunumbtns = tonumber(self.servermenunumbtns) or 0

    self._index = self._index or 0
    if self._buttons == nil then
        -- Assigned to the instance to prevent duplication
        self._buttons = TEMPLATES.GetSocialLinkButtons(self.root)

        self._index = #self._buttons
        self.servermenunumbtns = self.servermenunumbtns + self._index
    end

    local cur_index = self._index
    for name, value in pairs(self) do
        if BLOCKED_BUTTONS[name] ~= nil then
            self[name]:Hide()
        elseif name:endswith("_button") then
            cur_index = cur_index + 1
            self._buttons[cur_index] = value
        end
    end

    -- Always recalculate the position in case some of the buttons were removed.
    for i = 1, #self._buttons do
        self._buttons[i]:SetPosition(
            LINK_BUTTON_X + (i * SCREEN_BUTTONS_OFFSET), LINK_BUTTON_Y
        )
    end

    if PEARL.CONFIG.DISCORD_PROXY_ENABLED then
        if not proxy_state_label then
            proxy_state_label = Text(TALKINGFONT, 24)
            proxy_state_label:SetHAlign(ANCHOR_MIDDLE)
            proxy_state_label:SetVAlign(ANCHOR_MIDDLE)

            OnProxyStateChanged(proxy_state and proxy_state:value() or false)
        end

        local host_widget = type(self.player_widgets) == "table" and self.player_widgets[HOST_INDEX]
        if host_widget then
            host_widget:AddChild(proxy_state_label)
            proxy_state_label:SetPosition(0, 0, 0)
        end
    end

    if CUSTOM_HOST_BUTTON and VALID_HOST_URL then
        local host_widget =  type(self.player_widgets) == "table" and self.player_widgets[HOST_INDEX]
        local host_bg = type(self.bgs) == "table" and self.bgs[HOST_INDEX]
        if host_bg and host_widget and host_widget.name then
            local text = host_widget.name:GetString()
            local text_colour = host_widget.name:GetColour() or DEFAULT_COLOUR
            local text_font = host_widget.name.font or DEFAULT_FONT
            local host_name_button = host_widget.name:AddChild(TextButton())
            host_name_button.image:SetSize(host_widget.name:GetRegionSize())
            host_name_button:SetHoverText(STRINGS.PEARL.UI.SOCIAL_LINK_BUTTON_HOVERS.HOST, {
                offset_y = HOVER_OFFSET_Y,
                offset_x = HOVER_OFFSET_X,
            })
            host_name_button:SetOnClick(function() VisitURL(HOST_URL) end)

            local underline = host_widget.name:AddChild(Text(text_font, host_widget.name:GetSize()))
            underline:SetString(string.rep(UNDERLINE_CHAR, #text))
            underline:SetColour(text_colour)
            underline:SetRegionSize(host_widget.name:GetRegionSize())
            underline:Hide()

            underline:SetPosition(UNDERLINE_PADDING_X, UNDERLINE_PADDING_Y)

            host_name_button.ongainfocus = function() underline:Show() end
            host_name_button.onlosefocus = function() underline:Hide() end
        end
    end
end, PlayerStatusScreen)
