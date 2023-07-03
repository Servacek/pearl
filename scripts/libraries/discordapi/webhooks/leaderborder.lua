--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local Webhook = PEARL.loadfile("libraries/discordapi/models/webhook")
local Message = PEARL.loadfile("libraries/discordapi/models/message")

--------------------------------
-- [[ Class Initialization ]]
--------------------------------

--- @class LeaderBorder
local LeaderBorder = Class(function(self)
    self._disabled = not PEARL.CONFIG.DISCORD.BHOOK.ENABLED
    if self._disabled then
        return
    end

    self._webhook = Webhook(PEARL.CONFIG.DISCORD.BHOOK.ID, PEARL.CONFIG.DISCORD.BHOOK.TOKEN)

    --- @type Embed?
    self._embed = nil
end)

-------------------------------------
-- [[ Setters ]]
-------------------------------------

function LeaderBorder:SetIsDisabled(disabled)
    self._disabled = disabled

    return self
end

-------------------------------------
-- [[ Getters ]]
-------------------------------------

function LeaderBorder:IsDisabled()
    return self._disabled
end

function LeaderBorder:IsEnabled()
    return not self._disabled
end

function LeaderBorder:GetUpdateJSONData()
    return '{"embeds":[..'..self._embed:ToJson()..'..]}'
end

-------------------------------------
-- [[ Public Methods ]]
-------------------------------------

function LeaderBorder:DoUpdate(force)
    if not self._embed then
        return
    end

    return PEARL.DiscordRestAPI:EditWebhookMessage(
        self._webhook, PEARL.CONFIG.DISCORD.BHOOK.MESSAGE_ID, self:GetUpdateJSONData(), force
    )
end

--------------------------------
-- [[ Return ]]
--------------------------------

return LeaderBorder
