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

--- @class DiscordProxy
local DiscordProxy = PEARL.loadlib("discordapi/discordproxy")

--- @class PlayerStatusScreen
local PlayerStatusScreen = require("screens/playerstatusscreen")

-------------------------------
-- [[ Constants ]]
-------------------------------

local LINK_BUTTON_X = -430
local LINK_BUTTON_Y = 220 -- Move it over the potentially long server description.

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

local SPINNER_CHAR = "."
local MAX_SPINNER_CHARS = 3

local STATE_LABEL_DATA = {
    [DiscordProxy.STATE.FAILED] = {
        textkey = "UNREACHABLE", colour = WEBCOLOURS.RED,
    },
    [DiscordProxy.STATE.STOPPED] = {
        textkey = "OFFLINE", colour = GREY,
    },
    [DiscordProxy.STATE.RUNNING] = {
        textkey = "ONLINE", colour = WEBCOLOURS.GREEN
    },
    [DiscordProxy.STATE.CONNECTING] = {
        textkey = "STARTING", colour = WEBCOLOURS.YELLOW
    }
}

local DEFAULT_STATE_LABEL_DATA = {
    textkey = "UNKNOWN", colour = GREY
}

---------------------------
-- [[ Locals ]]
---------------------------

local function GetProxyStateLabelSpinnerPostfix(elipse_state)
    return string.rep(SPINNER_CHAR, math.max(math.min(elipse_state + 1, MAX_SPINNER_CHARS), 1))
end

local function GetProxyStateLabelData(state)
    return STATE_LABEL_DATA[state] or DEFAULT_STATE_LABEL_DATA
end

local function GetProxyStateLabelText(state_text_key)
    return STRINGS.PEARL.UI.PROXY_STATE:format(STRINGS.PEARL.UI[state_text_key])
end

-- Show the label only if proxy is enabled.
local proxy_state_label, proxy_state
local function OnProxyStateChanged(new)
    if proxy_state_label then
        local data = STATE_LABEL_DATA[new] or DEFAULT_STATE_LABEL_DATA
        proxy_state_label:SetColour(data.colour or WHITE)
        proxy_state_label:SetString(GetProxyStateLabelText(data.textkey))
    end
end

if PEARL.CONFIG.DISCORD_PROXY_ENABLED then
    PEARL.AddWorldNetworkPostInit(function(inst)
        proxy_state = net_tinybyte(inst.GUID, "proxy_state", "proxy_state_changed")
        proxy_state:set_local(DiscordProxy.STATE.STOPPED)

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
        if not proxy_state_label and proxy_state then
            self.step_time = GetStaticTime()

            proxy_state_label = Text(TALKINGFONT, 24)

            OnProxyStateChanged(proxy_state:value() or false)
            PEARL.AddClassFunctionPreCall("OnUpdate", function()
                local state = proxy_state:value()
                if state ~= DiscordProxy.STATE.CONNECTING then
                    return
                end

                local time = GetStaticTime()
                local time_delta = time - self.step_time
                local NEXT_STATE = 1.0
                if time_delta > NEXT_STATE then
                    local data = GetProxyStateLabelData(state)
                    local text = GetProxyStateLabelText(data.textkey)
                    if self.elipse_state == nil then
                        self.elipse_state = 0
                    end

                    proxy_state_label:SetString(
                        text..GetProxyStateLabelSpinnerPostfix(self.elipse_state)
                    )

                    self.elipse_state = self.elipse_state > 1 and 0 or self.elipse_state + 1
                    self.step_time = time
                end
            end, self)
        end

        local host_widget = type(self.player_widgets) == "table" and self.player_widgets[HOST_INDEX]
        if host_widget and proxy_state_label then
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
