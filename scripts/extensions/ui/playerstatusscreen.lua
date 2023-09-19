--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--[[
    Extends the player status screen by adding a new discord link button to it.
]]

local PEARL = PEARL
local TEMPLATES = require("widgets/redux/templates")

--- @class PlayerStatusScreen
local PlayerStatusScreen = require("screens/playerstatusscreen")

-------------------------------
-- [[ Constants ]]
-------------------------------

local DISCORD_BUTTON_X = -329
local DISCORD_BUTTON_Y = 200

local SCREEN_BUTTONS_OFFSET = 24

---------------------------
-- [[ Overrides ]]
---------------------------

if not TheNet:GetServerIsClientHosted() and PEARL.CONFIG.HOST_NAME ~= nil then
    PEARL.OverrideMethodReturnValue(PlayerStatusScreen, "GetDisplayName", function(name, self, client)
        print("PlayerList:GetDisplayName")
         -- Return custom name for Hosts.
        if client.performance ~= nil then
            return tostring(PEARL.CONFIG.HOST_NAME)
        end

        return name
    end)
end

-------------------------------
-- [[ Function Extensions ]]
-------------------------------

if PEARL.CONFIG.SOCIAL_LINKS and type(PEARL.CONFIG.SOCIAL_LINKS.DISCORD) == "string" and #PEARL.CONFIG.SOCIAL_LINKS.DISCORD > 3 then

-- We have to use DoInit instead of PostConstruct because
-- root is constructed there too.
PEARL.AddClassFunctionPostCall("DoInit", function(self)
    -- This button already exists and was added by something...strange
    if self.viewdiscord_button ~= nil or not self.root then
        return
    end

    self.servermenunumbtns = tonumber(self.servermenunumbtns) or 0
    self.servermenunumbtns = self.servermenunumbtns + 1

    self.viewdiscord_button = self.root:AddChild(TEMPLATES.LinkButton(
        PEARL.CONFIG.SOCIAL_LINKS.DISCORD, STRINGS.PEARL.UI.SOCIAL_LINK_BUTTON_HOVERS.DISCORD,
        PEARL.ASSETS.SOCIAL_BUTTONS.ATLAS,
        PEARL.ASSETS.SOCIAL_BUTTONS.TEXTURES.DISCORD,
        PEARL.ASSETS.SOCIAL_BUTTONS.TEXTURES.DISCORD_FOCUS
    ))
    self.viewdiscord_button:SetPosition(DISCORD_BUTTON_X + (self.servermenunumbtns > 1 and self.servermenunumbtns * SCREEN_BUTTONS_OFFSET or 0), DISCORD_BUTTON_Y)
end, PlayerStatusScreen)

end
