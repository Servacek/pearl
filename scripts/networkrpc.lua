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
    Here we handle all the client RPCs. Therefore, this is loaded only
    client side. So we do not have access to the SUB table here.
--]]

local TheNet = TheNet

local Message = require("libraries/discordapi/models/message")
local MARKDOWN = require("libraries/markdown")

--------------------------
-- Initialization
--------------------------

PEARL.RPCS = {}

local CLIENT_RPCS = {
    SendDirectMessage = function(message, ...)
        if not (ChatHistory and type(message) == "string") then
            return
        end

        ChatHistory:SendCommandResponse(message)
    end,

    Disconnect = function(...)
        PEARL.EventProcessor:HandleEvent("force_disconnected", ...)
        PEARL.ClientNetwork:Disconnect(..., true)
    end,

    -- SendLocalizationRequest = function()
    --     PEARL.EventProcessor:HandleEvent("localization_request_received")
    -- end,

    LocaleAllowed = function()
        PEARL.EventProcessor:HandleEvent("locale_allowed")
    end
}

local SHARD_RPCS = {
    -- Used by the VersionChecker for shutting down secondary shards
    -- to synchronize the shutdown process on version mismatch.
    ExecuteBroadcast = function(shard_id, ...)
        return ExecuteConsoleCommand(...)
    end,
}

-- local SERVER_RPCS = {}

local SERVER_USERID_RPCS = {
    ClientLocalizationCompleted = function(userid, locale)
        PEARL.debug("RPC: ClientLocalizationCompleted")

        PEARL.EventProcessor:HandleEvent("ms_clientlocalizationcomplete", userid, locale)
    end,

    ClientForceDisconnected = function(userid, reason)
        PEARL.debug("RPC: ClientForceDisconnected")

        PEARL.ServerNetwork:SendUserDisconnectFor(userid, reason)
    end,

    AFKStateChanged = function(userid, is_afk, kicked, ...)
        local player = LookupPlayerInstByUserID(userid)
        local client = userid and TheNet:GetClientTableForUser(userid)
        if not (player or client) then
            return
        end

        local name = player and player:GetDisplayName() or client.name
        local entity = player and player.entity or nil
        if kicked then
            return TheNet:Announce(STRINGS.PEARL.LOGS.USER_INACTIVE_KICKED:format(
                name
            ), entity, nil, "kicked_from_game")
        end

        -- Since it's an announcement,
        -- it will be logged to discord automatically.
        TheNet:Announce((is_afk and STRINGS.PEARL.LOGS.USER_INACTIVE or STRINGS.PEARL.LOGS.USER_ACTIVE):format(
            name
        ), entity, nil, is_afk and "afk_start" or "afk_stop")
    end,

    --- @TODO: Maybe move this somewhere else?
    PlayerReportMessage = function(userid, message)
        local client = userid and TheNet:GetClientTableForUser(userid)
        if not client then
            return
        end

        -- In case the webhook reporter was disabled during runtime
        if not PEARL.DiscordReporter or PEARL.DiscordReporter:IsDisabled() then
            return PEARL.ServerNetwork:SendCommandResponse(userid, STRINGS.PEARL.UI.CMD_ERRORS.NO_RHOOK)
        end

        --- @TODO: Maybe use an embed instead.
        PEARL.DiscordReporter:SendRawReportMessage(Message(STRINGS.PEARL.LOGS.PLAYER_REPORT:format(
            PEARL.ICONS.ANNOUNCEMENTS["default"], userid, MARKDOWN.escape(client.name), MARKDOWN.escape(message or "")
        )):AllowMentionsForType(Message.MENTION_TYPES.EVERYONE))
    end
}

-- For Debug
-- local CLIENT_RPCS_TO_NAME = {
--     [1] = "SendDirectMessage",
--     [2] = "Disconnect",
--     [3] = "SendLocalizationRequest",
--     [4] = "LocaleAllowed",
-- }

-- -- For Debug
-- local SERVER_RPCS_TO_NAME = {
--     -- [1] = "ClientModReady",
--     [2] = "ClientModNetworkReady",
--     [3] = "ClientLocalizationCompleted",
--     [4] = "AfkStateChanged",
-- }

--------------------------
-- Helpers
--------------------------
-- Note: Handle all shard RPCs in the backend

function PEARL.GetClientRPC(name)
    return GetClientModRPC(PEARL.RPC_NAME, name)
end

function PEARL.GetShardRPC(name)
    return GetShardModRPC(PEARL.RPC_NAME, name)
end

function PEARL.GetServerRPC(name)
    return GetModRPC(PEARL.RPC_NAME, name)
end

function PEARL.SendRPCToClient(name, ...)
    -- print("SEND TO CLIENT", name, ...)
    --PEARL.debug("Sending rpc", CLIENT_RPCS_TO_NAME[name], "to the client")
    return SendModRPCToClient(PEARL.GetClientRPC(name), ...)
end

function PEARL.SendRPCToShard(name, ...)
    return SendModRPCToShard(PEARL.GetShardRPC(name), ...)
end

function PEARL.SendRPCToServer(name, ...)
    -- print("SEND RPC TO SERVER", name, ...)
    --PEARL.debug("Sending rpc", SERVER_RPCS_TO_NAME[name], "to the server")
    return SendModRPCToServer(PEARL.GetServerRPC(name), ...)
end

-- Note: All of these RPCs needs to be loaded
-- on the server and client as well.
--------------------------
-- Client RPCs
--------------------------

do
    local i = 1
    for name, cb in pairs(CLIENT_RPCS) do
        AddClientModRPCHandler(PEARL.RPC_NAME, i, cb)

        PEARL.RPCS[name] = i
        i = i + 1
    end
end

--------------------------
-- Server RPCs
--------------------------

do
    local i = 1
    -- for name, cb in pairs(SERVER_RPCS) do
    --     AddModRPCHandler(PEARL.RPC_NAME, i, cb)

    --     PEARL.RPCS[name] = i
    --     i = i + 1
    -- end

    for name, cb in pairs(SERVER_USERID_RPCS) do
        AddModRPCHandler(PEARL.RPC_NAME, i, cb)
        MarkUserIDRPC(PEARL.RPC_NAME, i)

        PEARL.RPCS[name] = i
        i = i + 1
    end
end
--------------------------
-- Shard RPCs
--------------------------

do
    local i = 0
    for name, cb in pairs(SHARD_RPCS) do
        AddShardModRPCHandler(PEARL.RPC_NAME, i, cb)

        PEARL.RPCS[name] = i
        i = i + 1
    end
end
