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
    For now, leaderboarder for correct functioning requires a proxy allowing it to use the PATCH method.
--]]


local Webhook = PEARL.loadfile("libraries/discordapi/models/webhook")
local Message = PEARL.loadfile("libraries/discordapi/models/message")

local Library = PEARL.loadfile("models/library")

--------------------------------
-- [[ Constants ]]
--------------------------------

local FILE_EXTENSION = ".txt"
local ROOT = PEARL.ModPersistance:GetRootDirectoryPath()
local ID_FILE_PATH = ROOT.."/"..PEARL.CONFIG.LEADERBOARD.DIRECTORY.."/discord_id"..FILE_EXTENSION

local MAX_MESSAGE_POST_RETRIES = 3
local MAX_MESSAGE_UPDATE_RETRIES = 3
local MAX_MESSAGE_VERIFY_RETRIES = 2

local POST_MESSAGE_PARAMS = { ["wait"] = true }

--------------------------------
-- [[ Class Initialization ]]
--------------------------------

--- @class (exact) LeaderBorder: Library
--- @field _webhook Webhook The webhook API
--- @field _message Message? The message for displaying leaderboards on discord.
local LeaderBoarder = Class(Library, function(self)
    -- self:SetIsDisabled(PEARL.CONFIG.DISCORD.BHOOK.ENABLED)
    -- if self:IsDisabled() then
    --     return
    -- end

    self._webhook = Webhook(PEARL.CONFIG.DISCORD.BHOOK.URL)
    self._message = Message()
    self._message:SetID(nil)

    self:LoadIdentifier()
end)

-------------------------------------
-- [[ Setters ]]
-------------------------------------

--- @param message_id string?
--- @return LeaderBorder
function LeaderBoarder:SetUpdatingMessageID(message_id)
    PEARL.debug("LeaderBoarder:SetUpdatingMessageID", message_id)
    if message_id ~= self._message:GetID() then
        self._message:SetID(message_id)

        self:SaveIdentifier()
    end

    return self
end

-------------------------------------
-- [[ Getters ]]
-------------------------------------

function LeaderBoarder:GetMessage()
    return self._message
end

function LeaderBoarder:GetUpdatingMessageID()
    return self._message:GetID()
end

function LeaderBoarder:HasUpdatingMessage()
    return self:GetUpdatingMessageID() ~= nil
end

-------------------------------------
-- [[ Public Methods ]]
-------------------------------------

--- @return Request? request The request for this action or nil if disabled.
function LeaderBoarder:UpdateMessage()
    PEARL.debug("DoUpdate")

    local request = self._webhook:EditMessage(self:GetUpdatingMessageID(), self:GetMessage())
    if request ~= nil then
        request:SetMaxRetries(MAX_MESSAGE_UPDATE_RETRIES)
        request:AddStatusCodeHandle(404, function()
            self:SetUpdatingMessageID(nil)
        end)
    end

    return request
end

--- @return Request? request The request for this action or nil if disabled.
function LeaderBoarder:PostUpdatingMessage()
    PEARL.info("PostUpdatingMessage")

    local message = self:GetMessage()
    if not message:IsValid() then
        return PEARL.error("No leaderboard embeds were added!")
    end

    if not PEARL.HTTPClient:IsProxyEnabled() then
        return PEARL.error("In order to post updatable messages you need to enable the proxy!")
    end

    self:SetUpdatingMessageID(nil)

    local request = PEARL.HTTPClient.proxy:POST(self._webhook.url, nil, message:ToTable())
    if request then
        request:SetParameters(POST_MESSAGE_PARAMS)
        request:AddOnSuccess(function(message_data)
            if type(message_data) == "table" then
                self:SetUpdatingMessageID(message_data.id)
            end
        end)

        request:SetMaxRetries(MAX_MESSAGE_POST_RETRIES)
    end

    return (request:Send())
end

function LeaderBoarder:VerifyUpdatingMessageExists()
    local request = self._webhook:GetMessage(self:GetUpdatingMessageID())
    if request ~= nil then
        request:SetMaxRetries(MAX_MESSAGE_VERIFY_RETRIES)
        request:AddStatusCodeHandle(404, function()
            self:SetUpdatingMessageID(nil)
        end)
    end

    return request
end

function LeaderBoarder:Announce(text)
    return self._webhook:PostMessage(Message(text))
end

function LeaderBoarder:SaveIdentifier()
    local message_id = self:GetUpdatingMessageID()
    if message_id ~= nil then
        PEARL.info("Saving the updating message identifier", message_id)

        local success, errmsg = PEARL.ModPersistance:WriteToFile(ID_FILE_PATH, message_id)
        if not success or errmsg then
            PEARL.error("Saving identifier failed!", errmsg)
        end
    end
end

function LeaderBoarder:LoadIdentifier()
    local success, str = PEARL.ModPersistance:ReadFromFile(ID_FILE_PATH)
    if success and str then
        self:SetUpdatingMessageID(str:strip())
    end
end

--------------------------------
-- [[ Return ]]
--------------------------------

return LeaderBoarder
