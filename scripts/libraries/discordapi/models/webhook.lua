--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


-------------------------------------
-- [[ Private ]]
-------------------------------------

local function OnWebhookDataFetched(data, request, webhook)
    webhook.avatar = data.avatar
    webhook.channel_id = data.channel_id
    webhook.guild_id = data.guild_id
    webhook.name = data.name
    webhook.type = data.type

    PEARL.info("Retrieved webhook data for webhook", webhook.name or "UNKNOWN")
end

-------------------------------------
-- [[ Class Declarations ]]
-------------------------------------

--- @class Webhook Dataclass representing a discord webhook object
local Webhook = Class(function(self, id, token)
    self._id = id
    self._token = token

    self.url = PEARL.CONSTS.DISCORD.WEBHOOK_URL_TEMPLATE:format(
        PEARL.CONSTS.DISCORD.API_VERSION, self._id, self._token
    )

    -- Webhook info
    self.avatar = nil
    self.channel_id = nil
    self.guild_id = nil
    self.name = nil
    self.type = self.TYPES.INCOMING
end)

-------------------------------------
-- [[ Static ]]
-------------------------------------

Webhook.TYPES = {
    INCOMING = 1,
    CHANNEL_FOLLOWER = 2,
    APPLICATION = 3,
}

-------------------------------------
-- [[ Getters ]]
-------------------------------------

function Webhook:GetID()
    return self._id
end

function Webhook:GetToken()
    return self._token
end

function Webhook:GetURL()
    return self.url
end

function Webhook:IsValid()
    return (
        type(self._token) == "string" and #self._token > 0 and
        type(self._id) == "string" and #self._id > 0
    )
end

-------------------------------------
-- [[ Public Methods ]]
-------------------------------------

--- @param message Message The message to be posted by this webhook.
function Webhook:PostMessage(message)
    return PEARL.DiscordRestAPI:PostWebhookMessage(self.url, message)
end

--- @param message_id string The ID of webhook's message to be edited.
--- @param edited Message The message to replace the original.
function Webhook:EditMessage(message_id, edited)
    return PEARL.DiscordRestAPI:EditWebhookMessage(self.url, message_id, edited)
end

--- @param message_id string The ID of webhook's message to be edited.
function Webhook:DeleteMessage(message_id)
    return PEARL.DiscordRestAPI:DeleteWebhookMessage(self.url, message_id)
end

--- Retrive webhook information.
function Webhook:FetchData()
    PEARL.info("Retrieving webhook data...")

    local request = PEARL.DiscordRestAPI:FetchWebhookData(self.url)
    if not request then
        PEARL.error("Failed to send the webhook data fetch request!")
        return
    end

    request:SetOnSuccess(OnWebhookDataFetched, self)

    return request
end

-------------------------------------
-- [[ Return ]]
-------------------------------------

return Webhook
