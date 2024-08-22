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

local Widget = require("widgets/widget")
local Text = require("widgets/text")

local TEMPLATES = require("widgets/redux/templates")

--- @class DiscordProxy
local DiscordProxy = PEARL.loadfile("libs/discordapi/discordproxy")

--- @class PlayerStatusScreen
local PlayerStatusScreen = require("screens/playerstatusscreen")

-------------------------------
-- [[ Constants ]]
-------------------------------

local LINK_BUTTON_X = -430
local LINK_BUTTON_Y = 220 -- Move it over the potentially long server description.

local SCREEN_BUTTONS_OFFSET = 48

local HOST_NAME = PEARL.CONFIG.HOST.NAME

local PROXY_STATE_LABEL_FONT = TALKINGFONT
local PROXY_STATE_LABEL_FONT_SIZE = 24
local PROXY_STATE_UPDATE_FREQUENCY = 1
local PROXY_STATE_WIDGET_X = -60

local PROXY_LABELS_SPACING = 25

local BLOCKED_BUTTONS = {
    ["toggleservertext_button"] = true, -- Useless, and doesn't fit with the other buttons
}

--- booleans
local CUSTOM_HOST = not TheNet:GetServerIsClientHosted() and type(HOST_NAME) == "string"

local SPINNER_CHAR = "."
local MAX_SPINNER_CHARS = 3
local SPINNER_INTERVAL = 1

local UI_UPDATE_FREQUENCY = math.min(SPINNER_INTERVAL, PROXY_STATE_UPDATE_FREQUENCY)

local STATE_LABEL_DATA = {
    [DiscordProxy.STATE.FAILED] = {
        textkey = "UNREACHABLE", colour = PLAYERCOLOURS.RED,
    },
    [DiscordProxy.STATE.STOPPED] = {
        textkey = "OFFLINE", colour = GREY,
    },
    [DiscordProxy.STATE.RUNNING] = {
        textkey = "ONLINE", colour = PLAYERCOLOURS.GREEN
    },
    [DiscordProxy.STATE.CONNECTING] = {
        textkey = "STARTING", colour = PLAYERCOLOURS.YELLOW
    }
}

local DEFAULT_STATE_LABEL_DATA = {
    textkey = "UNKNOWN", colour = GREY
}

---------------------------
-- [[ Local Variables ]]
---------------------------

local proxy_state

---------------------------
-- [[ Local Functions ]]
---------------------------

local function GetProxyStateLabelSpinnerPostfix(elipse_state)
    return string.rep(SPINNER_CHAR, math.max(math.min(elipse_state + 1, MAX_SPINNER_CHARS), 1))
end

local function GetProxyStateLabelData(state)
    return STATE_LABEL_DATA[state] or DEFAULT_STATE_LABEL_DATA
end

local function GetProxyStateLabelText(state)
    return STRINGS.PEARL.UI.PROXY_SERVER.STATES[
        GetProxyStateLabelData(state).textkey
    ] or STRINGS.PEARL.UI.PROXY_SERVER.STATES.UNKNOWN
end

local function UpdateStateLabel(label, state)
    local data = GetProxyStateLabelData(state)
    label:SetColour(data.colour or WHITE)
    label:SetString(GetProxyStateLabelText(state))
end

---------------------------
-- [[ Event Handlers ]]
---------------------------

local function OnUpdatePlayerListing(listing, client, i)
    if client and client.performance ~= nil then
        if listing.proxy_state_widget then
            listing.proxy_state_widget:Show()
        end
    else
        if listing.proxy_state_widget then
            listing.proxy_state_widget:Hide()
        end
    end
end

local function OnUpdateLimited(self)
    local state = proxy_state:value()
    local host_proxy_state_label
    for _, player_listing in ipairs(self.player_widgets) do
        if player_listing.proxy_state_widget then
            UpdateStateLabel(player_listing.proxy_state_widget.label_state, state)

            if player_listing.ishost == true then
                host_proxy_state_label = player_listing.proxy_state_widget.label_state
            end
        end
    end

    if state == DiscordProxy.STATE.CONNECTING and host_proxy_state_label then
        self.elipse_state = self.elipse_state or 0

        host_proxy_state_label:SetString(
            GetProxyStateLabelText(state)..GetProxyStateLabelSpinnerPostfix(self.elipse_state)
        )

        self.elipse_state = self.elipse_state > 1 and 0 or self.elipse_state + 1
    end
end

local function OnUpdate(self, dt)
    self.step_time = self.step_time or UI_UPDATE_FREQUENCY
    if self.step_time > dt then
        self.step_time = self.step_time - dt
    else
        self.step_time = UI_UPDATE_FREQUENCY
        OnUpdateLimited(self)
    end
end

---------------------------
-- [[ Netvars ]]
---------------------------

if PEARL.CONFIG.DISCORD_PROXY_ENABLED then
    PEARL.AddWorldNetworkPostInit(function(inst)
        if proxy_state == nil then
            proxy_state = net_tinybyte(inst.GUID, "proxy_state_client", "proxy_state_changed")
            proxy_state:set_local(DiscordProxy.STATE.STOPPED)
        end
    end)
end

---------------------------
-- [[ Overrides ]]
---------------------------

if CUSTOM_HOST then
    -- Using this since the game uses too much hardcoded weird stuff I do not want to mess with.
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

local function AddCustomButtons(self)
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
end

local function AddProxyStateWidget(self)
    if not proxy_state then
        return
    end

    local state = proxy_state:value()
    for _, player_listing in ipairs(self.player_widgets) do
        -- Every widget can potentionaly display the host client,
        -- but most of the time it's always first widget.
        -- We add this to everyone just in case a mod changes the order or something.
        if player_listing.proxy_state_widget == nil then
            local proxy_state_widget = player_listing:AddChild(Widget("ProxyStateLabel"))
            proxy_state_widget:SetPosition(PROXY_STATE_WIDGET_X, 0)

            proxy_state_widget.label_title = proxy_state_widget:AddChild(Text(PROXY_STATE_LABEL_FONT, PROXY_STATE_LABEL_FONT_SIZE))
            proxy_state_widget.label_title:SetString(STRINGS.PEARL.UI.PROXY_SERVER.STATE_LABEL)

            proxy_state_widget.label_state = proxy_state_widget:AddChild(Text(PROXY_STATE_LABEL_FONT, PROXY_STATE_LABEL_FONT_SIZE))
            proxy_state_widget.label_state:SetString(GetProxyStateLabelText())
            proxy_state_widget.label_state:SetRegionSize(130, 44)
            local w = proxy_state_widget.label_title:GetRegionSize()
            proxy_state_widget.label_state:SetPosition(w + PROXY_LABELS_SPACING, 0)
            proxy_state_widget.label_state:SetHAlign(ANCHOR_LEFT)

            UpdateStateLabel(proxy_state_widget.label_state, state)

            player_listing.proxy_state_widget = proxy_state_widget
            player_listing.proxy_state_widget:Hide()
        end
    end

    if self._OnUpdate == nil then
        self._OnUpdate = PEARL.AddClassFunctionPreCall("OnUpdate", OnUpdate, self)
    end
end

local function GeneralExtensions(self)
    AddCustomButtons(self)

    -- Make background hoverable as well (this way is much more intuitive)
    for i, bg in ipairs(self.bgs) do
        -- This should never be nil, but just in case it is.
        local player_listing = self.player_widgets[i]
        if player_listing then
            bg.focus_forward = player_listing
            player_listing.focus_forward = nil
        end
    end

    -- Removes weird flickering when opened (this is an ancient vanilla bug)
    if self.scroll_list then
        self.scroll_list.focus_children = false
    end
end

-- We have to use DoInit instead of PostConstruct because
-- root is constructed there too.
PEARL.AddClassFunctionPostCall("DoInit", function(self)
    GeneralExtensions(self)

    if self.scroll_list and self.scroll_list.updatefn and PEARL.CONFIG.DISCORD_PROXY_ENABLED then
        AddProxyStateWidget(self)

        local clients = TheNet:GetClientTable() or {}
        for i, player_listing in ipairs(self.player_widgets) do
            OnUpdatePlayerListing(player_listing, clients[i], i)
        end

        if self._updatefn == nil then
            self._updatefn = PEARL.AddFunctionPostCall("updatefn", OnUpdatePlayerListing, self.scroll_list)
        end
    else
        PEARL.error("PlayerStatusScreen: \"scroll_list\" is invalid!")
    end
end, PlayerStatusScreen)

-------------------------------
-- [[ Debugging]]
-------------------------------

--- Hot Reload?
-- if PEARL.CONFIG.DEBUG_MODE then
--     PEARL.AddWorldPostInit(function(world)
--         world:SafeListenForEvent("playeractivated", function(world, player)
--             print("PLAYER ACTIVATED", player.HUD)
--             if player.HUD then
--                 PEARL.AddClassFunctionPreCall("ShowPlayerStatusScreen", function(self)
--                     --- Kill the cached screen to force reload.
--                     if self.playerstatusscreen then
--                         self.playerstatusscreen:Kill()
--                         self.playerstatusscreen = nil
--                     end

--                     --- Reload this file to apply the changes
--                     PEARL.loadfile("extensions/ui/playerstatusscreen", nil, true)
--                 end, player.HUD)
--             end
--         end)
--     end)
-- end
