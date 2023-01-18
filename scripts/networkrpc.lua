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

local Message = PEARL.loadfile("libraries/discordapi/models/message")
local MARKDOWN = PEARL.loadfile("libraries/markdown")

--------------------------
-- Initialization
--------------------------

PEARL.RPCS = {}

--- RPCs from the server are trusted if the server is trusted (which it should).
local CLIENT_RPCS = {
    --- @TODOv2.1: Make this more generic.
    CommandResponse = function(...)
        return ChatHistory:SendCommandResponse(...)
    end,

    Disconnect = function(...)
        PEARL.EventProcessor:HandleEvent("force_disconnected", ...)
        PEARL.ClientNetwork:Disconnect(..., true)
    end,

    -- SendLocalizationRequest = function()
    --     PEARL.EventProcessor:HandleEvent("localization_request_received")
    -- end,

    LocaleAllowed = function()
        PEARL.EventProcessor:HandleEvent("connection_allowed")
    end,

    ConnectionAllowed = function()
        PEARL.ClientNetwork:SetIsWaitingForResponse(false)
        PEARL.EventProcessor:HandleEvent("connection_allowed")
    end,
}

--- These handlers should be called only from the server.
local SHARD_RPCS = {
    -- Used by the VersionChecker for shutting down secondary shards
    -- to synchronize the shutdown process on version mismatch.
    BroadcastLua = function(shard_id, luastring)
        PEARL.info("Executing lua chunk from Master...")

        local status, err = pcall(loadstring(luastring))
        if not status then
            PEARL.error(err)
        end
    end,
}

--- These RPCS are called from the clients so additional security checks are needed.
--- userid is being supplied by the game's RPC manager so that should be safe.
local SERVER_USERID_RPCS = {
    -- ClientLocalizationCompleted = function(userid, locale)
    --     if type(userid) ~= "string"
    --     PEARL.debug("RPC: ClientLocalizationCompleted")

    --     PEARL.EventProcessor:HandleEvent("ms_clientlocalizationcomplete", userid, locale)
    -- end,

    ConnectionFilterData = function(userid, data)
        if not checkstring(data) then
            return PEARL.ServerNetwork:OnInvalidRPCFromClient("ConnectionFilterData", userid)
        end

        local data_tbl = DecodeAndUnzipString(data)
        PEARL.debug("Received CFD from server:", DataDumper(data_tbl))

        PEARL.ServerNetwork:OnClientFilterDataReceived(userid, data_tbl)
    end,

    ClientDisconnected = function(userid, reason, force)
        if not (optstring(reason) and optbool(force)) then
            return PEARL.ServerNetwork:OnInvalidRPCFromClient("ClientDisconnected", userid)
        end

        PEARL.debug("RPC: ClientDisconnected", reason, force)
        PEARL.EventProcessor:HandleEvent("clientconnectionclosed", userid, reason)
    end,

    AFKStateChanged = function(userid, is_afk, kicked)
        if not (optbool(is_afk) and optbool(kicked)) then
            return PEARL.ServerNetwork:OnInvalidRPCFromClient("AFKStateChanged", userid)
        end

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
        if not optstring(message) then
            return PEARL.ServerNetwork:OnInvalidRPCFromClient("PlayerReportMessage", userid)
        end

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
        )):SetAllowedMentionTypes({
            Message.MENTION_TYPES.EVERYONE
        }))
    end,

    ClientError = function(userid, data)
        if not checkstring(data) then
            return PEARL.ServerNetwork:OnInvalidRPCFromClient("ClientError", userid)
        end

        local traceback = TheSim:DecodeAndUnzipString(data)
        if PEARL.DiscordReporter and PEARL.DiscordReporter:IsEnabled() then
            PEARL.DiscordReporter:ReportUncatchedClientLuaError(userid, traceback)
        end
    end,
}

--------------------------
-- Wrappers
--------------------------
-- Note: Handle all shard RPCs in the backend
--- @TODO: Maybe move these to servernetwork.lua and clientnetwork.lua

function PEARL.GetClientRPC(name)
    return GetClientModRPC(PEARL.RPC_NAME, name)
end

function PEARL.GetShardRPC(name)
    return GetShardModRPC(PEARL.RPC_NAME, name)
end

function PEARL.GetServerRPC(name)
    return GetModRPC(PEARL.RPC_NAME, name)
end

--- @param rpc_id number The identifier of the RPC, these can be found in the mod's RPCS table.
--- @param sender_list? table|string|number
--- @param ... any Any additional data provided to the rpc handler.
--- if sender_list is nil, all clients connected to the current shard will execute the RPC.
--- if sender_list is a table, it will be iterated upon and send it to every client that is connected to the current shard thats UserID is in the table.
--- if sender_list is a string, it will send the RPC to the specific client with that UserID, as long as they are connected to that shard.
function PEARL.SendRPCToClient(rpc_id, sender_list, ...)
    -- print("SEND TO CLIENT", name, ...)
    --PEARL.debug("Sending rpc", CLIENT_RPCS_TO_NAME[name], "to the client")
    return SendModRPCToClient(PEARL.GetClientRPC(rpc_id), sender_list, ...)
end

--- @param rpc_id number The identifier of the RPC, these can be found in the mod's RPCS table.
--- @param sender_list? table|string|number
--- @param ... any Any additional data provided to the rpc handler.
--- if sender_list is nil, all connected shards(including the one this is called on) will have this RPC executed.
--- if sender_list is a table, it will be iterated upon and send it to every shard that's ID is in the table.
--- if sender_list is either a string or a number, it will send that RPC to the specific shard with that ID.
function PEARL.SendRPCToShard(rpc_id, sender_list, ...)
    return SendModRPCToShard(PEARL.GetShardRPC(rpc_id), sender_list, ...)
end

--- @param rpc_id number The identifier of the RPC, these can be found in the mod's RPCS table.
--- @param ... any Any additional data provided to the rpc handler.
function PEARL.SendRPCToServer(rpc_id, ...)
    if not PEARL.ClientNetwork or PEARL.ClientNetwork:IsDisconnected() then
        return
    end

    -- print("SEND RPC TO SERVER", name, ...)
    --PEARL.debug("Sending rpc", SERVER_RPCS_TO_NAME[name], "to the server")
    return SendModRPCToServer(PEARL.GetServerRPC(rpc_id), ...)
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
