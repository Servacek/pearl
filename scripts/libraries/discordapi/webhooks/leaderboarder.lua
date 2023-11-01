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
    For now, leaderboarder for correct functioning requires a proxy allowing it to use the PATCH method.
--]]


local Webhook = PEARL.loadfile("libraries/discordapi/models/webhook")
local Message = PEARL.loadfile("libraries/discordapi/models/message")

--------------------------------
-- [[ Class Initialization ]]
--------------------------------

--- @class LeaderBorder
local LeaderBoarder = Class(function(self)
    self._disabled = not PEARL.CONFIG.DISCORD.BHOOK.ENABLED
    if self._disabled then
        return
    end

    --- @type Webhook
    self._webhook = Webhook(PEARL.CONFIG.DISCORD.BHOOK.ID, PEARL.CONFIG.DISCORD.BHOOK.TOKEN)

    self._embeds = {}

    --- @type string
    self._message_id = nil

    --- @type integer
    self._mode = self.MODE.STACK
end)

-------------------------------------
-- [[ Modes ]]
-------------------------------------

LeaderBoarder.MODE = {
    STACK   = 1, -- New message on each update
    UPDATE  = 2, -- Keeps the original message by updating only it's content (requires proxy)
}

-------------------------------------
-- [[ Setters ]]
-------------------------------------

function LeaderBoarder:SetMode(mode)
    PEARL.debug("LeaderBoarder:SetMode", mode)

    mode = tonumber(mode)
    if mode == nil or not table.contains(self.MODE, mode) then
        return PEARL.error("Attempted to set an invalid mode for the leaderboard webhook!")
    end

    self._mode = mode
end

function LeaderBoarder:SetIsDisabled(disabled)
    self._disabled = disabled

    return self
end

function LeaderBoarder:SetEmbed(pos, embed)
    if pos then
        self._embeds[pos] = embed
    else
        self._embeds[#self._embeds+1] = embed
    end

    return embed
end

function LeaderBoarder:SetUpdateMessageID(message_id)
    self._message_id = tostring(message_id)

    return self
end

-------------------------------------
-- [[ Getters ]]
-------------------------------------

function LeaderBoarder:GetMode()
    return self._mode
end

function LeaderBoarder:IsDisabled()
    return self._disabled
end

function LeaderBoarder:IsEnabled()
    return not self._disabled
end

function LeaderBoarder:GetMessage()
    return Message():AddEmbeds(self._embeds)
end

-------------------------------------
-- [[ Public Methods ]]
-------------------------------------

--- @return Request? request The request for this action or nil if disabled.
function LeaderBoarder:DoUpdate(force)
    PEARL.debug("DoUpdate", force)

    if self:IsDisabled() then
        return
    end

    local message = self:GetMessage()
    if self._mode == self.MODE.UPDATE then
        return self._webhook:EditMessage(
            self._message_id, message, force
        )
    end

    return self._webhook:PostMessage(message, force)
end

--- @return Request? request The request for this action or nil if disabled.
function LeaderBoarder:PostUpdatingMessage(cb)
    PEARL.info("PostUpdatingMessage")

    if self:IsDisabled() then
        return
    end

    local request
    local message = self:GetMessage()
    if not message:IsValid() then
        return PEARL.error("No leaderboard embeds were added!")
    end

    if self._mode == LeaderBoarder.MODE.UPDATE and PEARL.HTTPClient:IsProxyEnabled() then
        request = PEARL.HTTPClient.proxy:POST(self._webhook.url, cb, message:ToTable())
        request:SetParameters({ ["wait"] = true })
    else -- Defaults to STACK mode
        request = self._webhook:PostMessage(message)
    end

    return (request:Send())
end

function LeaderBoarder:PostNotification(message, ...)
    if self:IsDisabled() then
        return
    end

    return self._webhook:PostMessage(message, ...)
end

function LeaderBoarder:Announce(text)
    if self:IsDisabled() then
        return
    end

    return self:PostNotification(Message(text))
end

--------------------------------
-- [[ Return ]]
--------------------------------

return LeaderBoarder
