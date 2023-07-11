--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local MARKDOWN = PEARL.loadfile("libraries/markdown")
local Webhook = PEARL.loadfile("libraries/discordapi/models/webhook")
local Message = PEARL.loadfile("libraries/discordapi/models/message")
local Embed = PEARL.loadfile("libraries/discordapi/models/embed")

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

    self._embeds = {
        [self.EMBED_TYPES.ABS] = Embed()
            :SetTitle("Zoznam Najlepších Hráčov")
            :SetDescription("The cool leaderboard!"),
        [self.EMBED_TYPES.CUR] = Embed()
            :SetTitle("Zoznam Najlepších Hráčov Mesiaca")
            :SetDescription("The cool monthly leaderboard!")
    }

    --- @type table
    self._message_data = Message()
        :SetContent("")
        :ToTable()
end)

-------------------------------------
-- [[ Static ]]
-------------------------------------

LeaderBoarder.EMBED_TYPES = {
    ABS = 1,
    CUR = 2,
}

-------------------------------------
-- [[ Setters ]]
-------------------------------------

function LeaderBoarder:SetIsDisabled(disabled)
    self._disabled = disabled

    return self
end

function LeaderBoarder:SetEmbed(type, embed)
    self._embeds[type] = embed
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

function LeaderBoarder:UpdateEmbedData()
    self._message_data.embeds = self._message_data.embeds or {}

    for i, embed in ipairs(self._embeds) do
        self._message_data.embeds[i] = embed:ToTable()
    end

    return self._message_data
end

function LeaderBoarder:GetMessageData()
    return self:UpdateEmbedData()
end

-------------------------------------
-- [[ Public Methods ]]
-------------------------------------

function LeaderBoarder:DoUpdate(force)
    if self:IsDisabled() then
        return
    end

    return PEARL.DiscordRestAPI:EditWebhookMessage(
        self._webhook, PEARL.CONFIG.DISCORD.BHOOK.MESSAGE_ID, self:GetMessageData(), force
    )
end

function LeaderBoarder:PostUpdatingMessage()
    return PEARL.HTTPClient.proxy:POST(self._webhook.url, function(message)
            if type(message.id) ~= "string" then
                return
            end

            PEARL.DiscordRestAPI:EditWebhookMessage(self._webhook, message.id, {
                content = MARKDOWN.bold("Add to modoverrides.lua under \"BHOOK\" option:\n")..MARKDOWN.codeblock(
                    "MESSAGE_ID = \""..message.id.."\",", "lua"
                ).."\nAnd restart the server :)"
            })
        end, Message("PLACEHOLDER"):ToTable())
        :SetParameters({ ["wait"] = true })
        :Send()
end

function LeaderBoarder:PostNotification(message)
    local success, json_data = message:ToJson()
    if not success or type(json_data) ~= "string" then
        return PEARL.error("Failed to encode notification message to JSON format!")
    end

    return PEARL.DiscordRestAPI:ExecuteWebhook(self._webhook, json_data)
end

function LeaderBoarder:AnnounceNewPOTM(netid)

end

--------------------------------
-- [[ Return ]]
--------------------------------

return LeaderBoarder
