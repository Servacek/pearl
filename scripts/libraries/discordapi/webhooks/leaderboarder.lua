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
local LeaderBoarder = Class(function(self)
    self._disabled = not PEARL.CONFIG.DISCORD.BHOOK.ENABLED
    if self._disabled then
        return
    end

    self._webhook = Webhook(PEARL.CONFIG.DISCORD.BHOOK.ID, PEARL.CONFIG.DISCORD.BHOOK.TOKEN)

    self._embeds = {}

    --- @type string
    self._message_id = nil
end)

-------------------------------------
-- [[ Setters ]]
-------------------------------------

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

function LeaderBoarder:IsDisabled()
    return self._disabled
end

function LeaderBoarder:IsEnabled()
    return not self._disabled
end

-------------------------------------
-- [[ Public Methods ]]
-------------------------------------

function LeaderBoarder:DoUpdate(force)
    if self:IsDisabled() then
        return
    end

    return self._webhook:EditMessage(
        self._message_id, Message():AddEmbeds(self._embeds), force
    )
end

--- @return Request? request
function LeaderBoarder:PostUpdatingMessage(cb)
    if self:IsDisabled() or not PEARL.HTTPClient.proxy or not PEARL.HTTPClient.proxy:IsEnabled() then
        return
    end

    local request = PEARL.HTTPClient.proxy:POST(self._webhook.url, cb, self:GetMessageData())
    if request then
        -- We need the ID of this message to keep it updated so use the wait parameter.
        request:SetParameters({ ["wait"] = true })
        request:Send()
    end

    return request
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
