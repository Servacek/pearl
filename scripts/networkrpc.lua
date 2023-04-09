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

local UpvalueHacker = PEARL.loadfile("utils/upvaluehacker")

--------------------------
-- Initialization
--------------------------

PEARL.RPC = {}

--- RPCs from the server are trusted if the server is trusted (which it should).
local CLIENT_RPCS = {
    CommandResponse = function(...)
        return ChatHistory and ChatHistory:SendCommandResponse(...)
    end,

    Disconnect = function(reason, ...)
        return PEARL.ClientNetwork:Disconnect(reason, true, ...)
    end,

    ConnectionAllowed = function(...)
        return PEARL.ClientNetwork:OnResponse(true, true, ...)
    end,
}

--- These handlers should be called only from the server.
--- That means, they should be trusted and we do not need to add any additional checks.
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

    ClientCFDRecevied = function(shard_id, userid, data)
        -- Always keep just the newest record
        PEARL.ServerNetwork:CacheClientCFDFor(userid, data)
    end
}

--- These RPCS are called from the clients so additional security checks are needed.
--- userid is being supplied by the game's RPC manager so that should be safe.
local SERVER_USERID_RPCS = {
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
            -- Make sure we close the connection
            --- @TODO: This logs two times.
            PEARL.ServerNetwork:SendUserDisconnectFor(userid, "ID_DST_USER_INACTIVE")

            return PEARL.AnnounceWithType(STRINGS.PEARL.LOGS.USER_INACTIVE_KICKED:format(
                name
            ), PEARL.ANNOUNCEMENT_TYPES.KICKED_FROM_GAME, entity)
        end

        local message = STRINGS.PEARL.LOGS[is_afk and "USER_INACTIVE" or "USER_ACTIVE"]
        local type = PEARL.ANNOUNCEMENT_TYPES[is_afk and "AFK_START" or "AFK_STOP"]
        return PEARL.AnnounceWithType(message:format(name), type, entity)
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

        -- Anounce it so it logs the message and also other players can see it as well.
        PEARL.AnnounceWithType(STRINGS.PEARL.LOGS.STAFF_CALLED)
    end,

    ClientError = function(userid, data, afflicter_modname, was_disabled)
        if not checkstring(data) then --or not optstring(afflicter_modname) or not optbool(was_disabled) then
            return PEARL.ServerNetwork:OnInvalidRPCFromClient("ClientError", userid)
        end

        local traceback = TheSim:DecodeAndUnzipString(data)
        if PEARL.DiscordReporter and PEARL.DiscordReporter:IsEnabled() then
            PEARL.DiscordReporter:ReportUncatchedClientLuaError(userid, traceback)
        end
    end,
}

--------------------------
-- Raw RPCs
--------------------------

local RAW_RPCS = {}

--- @type table<integer, any>
local RPC_HANDLERS = UpvalueHacker:GetUpvalue(HandleRPC, "RPC_HANDLERS")
local USERID_RPCS  = UpvalueHacker:GetUpvalue(HandleRPC, "USERID_RPCS")

function PEARL.SendRawRPCToServer(rpc_id, ...)
    return SendRPCToServer(rpc_id, ...)
end

function PEARL.AddRawServerRPCHandler(name, fn, useridrpc)
    local i = #RPC_HANDLERS + 1
    assert(RPC_HANDLERS[i] == nil)

    RPC_HANDLERS[i] = fn
    PEARL.RPC[name] = i
    RAW_RPCS[i] = fn

    if fn and useridrpc == true then
        USERID_RPCS[fn] = true
    end
end

function PEARL.RegisterRawServerRPC(name)
    local i = #RPC_HANDLERS + 1
    assert(RPC_HANDLERS[i] == nil)

    RPC_HANDLERS[i] = function() end
    PEARL.RPC[name] = i
end

function PEARL.AddRawServerUseridRPCHandler(name, fn)
    PEARL.AddRawServerRPCHandler(name, fn, true)
end

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
    return SendModRPCToServer(PEARL.GetServerRPC(rpc_id), ...)
end

function PEARL.AddServerRPCHandler(name, handler)
    PEARL.RPC[name] = name
    return AddModRPCHandler(PEARL.RPC_NAME, name, handler)
end

function PEARL.AddShardRPCHandler(name, handler)
    PEARL.RPC[name] = name
    return AddShardModRPCHandler(PEARL.RPC_NAME, name, handler)
end

function PEARL.AddClientRPCHandler(name, handler)
    PEARL.RPC[name] = name
    return AddClientModRPCHandler(PEARL.RPC_NAME, name, handler)
end

-- Note: All of these RPCs needs to be loaded
-- on the server and client as well.

-- WARNING: Use 'orderedPairs' for RPC ID assignment
-- because the order of 'pairs' may be different on other platforms,
-- which would cause some very annoying RPC desynchronization issues.
--------------------------
-- Client RPCs
--------------------------

do
    local i = 1
    for name, cb in orderedPairs(CLIENT_RPCS) do
        AddClientModRPCHandler(PEARL.RPC_NAME, i, cb)

        PEARL.RPC[name] = i
        i = i + 1
    end
end

--------------------------
-- Server RPCs
--------------------------

do
    local i = 1
    for name, cb in orderedPairs(SERVER_USERID_RPCS) do
        AddModRPCHandler(PEARL.RPC_NAME, i, cb)
        MarkUserIDRPC(PEARL.RPC_NAME, i)

        PEARL.RPC[name] = i
        i = i + 1
    end
end

--------------------------
-- Shard RPCs
--------------------------

do
    local i = 0
    for name, cb in orderedPairs(SHARD_RPCS) do
        AddShardModRPCHandler(PEARL.RPC_NAME, i, cb)

        PEARL.RPC[name] = i
        i = i + 1
    end
end

--------------------------
-- Handler
--------------------------

-- This is redundant on the client because there the staticUpdate works even when
-- the simulation is paused on the server because of the UI.
if not TheNet:GetIsServer() then
    return
end

-- Custom handler for server RPCs since the built-in one does only work when staticUpdate
-- gets called, and that is only when the simulation is running.

local RPC_QUEUE_RATE_LIMIT = UpvalueHacker:GetUpvalue(HandleModRPC, "RPC_QUEUE_RATE_LIMIT")
local RPC_Queue_Limiter = UpvalueHacker:GetUpvalue(HandleModRPC, "RPC_Queue_Limiter")

--- @TODO: There are two main aproaches to this. One is using a PreCall, where
--- we handle the server mod rpcs all ourselves. The second one is using a PostCall
--- and if the rpc handled was ours, call TickRPCQueue afterwards. This however, can how
--- some side effects since the tick will not just call our RPCs but also the game's.

-- This one is only called on the server.
PEARL.AddGlobalFunctionPreCall("HandleModRPC", function(sender, tick, namespace, code, data)
    -- This is not our RPC so we do not care. How selfish...
    if namespace ~= PEARL.RPC_NAME or RAW_RPCS[code] ~= nil then
        return -- Leave the game handle it.
    end

    local ns_handlers = MOD_RPC_HANDLERS[namespace]
    local handler = ns_handlers[code] or RAW_RPCS[code]
    if type(handler) ~= "function" then
        return
    end

    local userid = type(sender) == "table" and sender.userid or sender
    if type(userid) ~= "string" then
        return
    end

    local limit = (RPC_Queue_Limiter[userid] or 0) + 1
    RPC_Queue_Limiter[userid] = limit
    if limit >= RPC_QUEUE_RATE_LIMIT then
        return -- Let the game handle Rate limits
    end

    PEARL.SafeRun(TheNet.CallRPC, TheNet, handler, userid, data)

    return false
end)
