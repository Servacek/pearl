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

PEARL.RPC = {
    _size = 0
}

--- RPCs from the server are trusted if the server is trusted (which it should).
local CLIENT_RPCS = {
    CommandResponse = function(...)
        return ChatHistory and ChatHistory:SendCommandResponse(...)
    end,

    AddToChatHistory = function(dec_m_color, tp, userid, netid, name, message, dec_s_color, ...)
        PEARL.debug("AddToChatHistory:", dec_m_color, tp, userid, netid, name, message, dec_s_color, ...)

        local color = PEARL.GetColorFromDecimal(dec_s_color)
        color.message = PEARL.GetColorFromDecimal(dec_m_color, SAY_COLOR)

        return ChatHistory and ChatHistory:AddToHistory(tp, userid, netid, name, message, color, ...)
    end,

    Disconnect = function(reason, ...)
        return PEARL.ClientNetwork:Disconnect(reason, true, ...)
    end,

    ConnectionAllowed = function(...)
        return PEARL.ClientNetwork:OnResponse(true, true, ...)
    end,

    CLIENT = function(...)
        print("CLIENT RPC TEST EXECUTED!!", ...)
    end
}

--- These handlers should be called only from the server.
--- That means, they should be trusted and we do not need to add any additional checks.
local SHARD_RPCS = {
    -- Used by the VersionChecker for shutting down secondary shards
    -- to synchronize the shutdown process on version mismatch.
    BroadcastLua = function(shard_id, luastring)
        if tostring(shard_id) ~= SHARDID.MASTER or TheShard:IsMaster() then
            return PEARL.error("Got lua chunk from a secondary shard!")
        end

        PEARL.info("Executing arbitrary lua chunk from Master...")
        PEARL.SafeRun(function()
            loadstring(luastring)()
        end)
    end,

    BroadcastRPC = function(shardid, client_rpc_id, ...)
        print("BroadcastRPC")
        return PEARL.BroadcastRPCToConnectedShards(client_rpc_id, ...)
    end,

    BroadcastClientRPC = function(shardid, client_rpc_id, sender_list, ...)
        print("BroadcastClientRPC", client_rpc_id, sender_list, ...)

        -- It seems like you cannot execute RPC in an RPC...
        PEARL.WallScheduler:ExecuteInTime(
            0, PEARL.SendRPCToClient, nil, client_rpc_id, sender_list, ...
        )
    end,

    ClientCFDRecevied = function(shardid, userid, data)
        -- Always keep just the newest record
        PEARL.ServerNetwork:HandleRawConnectionData(userid, data, shardid)
    end,

    TEST = function(...)
        print("SHARD RPC TEST EXECUTED!!", ...)
    end,
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
            ), PEARL.CONSTS.ANNOUNCEMENT_TYPES.KICKED_FROM_GAME, entity)
        end

        local message = STRINGS.PEARL.LOGS[is_afk and "USER_INACTIVE" or "USER_ACTIVE"]
        local type = PEARL.CONSTS.ANNOUNCEMENT_TYPES[is_afk and "AFK_START" or "AFK_STOP"]
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

    AgreementFinished = function(userid, agreed, datacollection, agreedintime, agreed_version)
        PEARL.debug("AgreementFinished", userid, agreed, datacollection, agreedintime, agreed_version)

        if not optbool(agreed) or not optbool(datacollection) or not optnumber(agreedintime) or not optstring(agreed_version) then
            return PEARL.ServerNetwork:OnInvalidRPCFromClient("AgreementFinished", userid)
        end

        PEARL.EventProcessor:HandleEvent("clientagreementfinished", {
            userid = userid,
            agreed = agreed,
            datacollection = datacollection,
            agreedintime = agreedintime,
            version = agreed_version,
        })

        if not agreed then
            return
        end

        local client = userid and TheNet:GetClientTableForUser(userid)
        if not client and client.name then
            return
        end

        local cfd = PEARL.ServerNetwork:GetCachedCFDFor(userid)
        if not cfd or cfd.novice ~= true then
            return
        end

        -- Send a nice welcome message for novices.
        local welcome_msg_template = STRINGS.PEARL.NOVICE_ANNOUNCEMENTS[math.random(1, #STRINGS.PEARL.NOVICE_ANNOUNCEMENTS)]
        local welcome_msg = welcome_msg_template:format(client.name)
        if PEARL.ServerNetwork:GetConnectedClientsCount() > 1 then
            -- Only announce it if there are more people on the server.
            return PEARL.AnnounceWithType(welcome_msg, PEARL.CONSTS.ANNOUNCEMENT_TYPES.WELCOME)
        end

        return PEARL.DiscordLogger:LogString(
            welcome_msg, PEARL.ICONS.ANNOUNCEMENTS[PEARL.CONSTS.ANNOUNCEMENT_TYPES.WELCOME]
        )
    end
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

function PEARL.GetDefaultRPCHandlers()
    return RPC_HANDLERS
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

--- @param rpc_id number The identifier of the RPC, these can be found in the mod's RPCS table.
--- @param ... any Any additional data provided to the rpc handler.
function PEARL.SendRPCToMaster(rpc_id, ...)
    return PEARL.SendRPCToShard(rpc_id, SHARDID.MASTER, ...)
end

--- If called on Master, sends the given RPC to all connected shards.
--- Otherwise it will send the BroadcastRPC to shard Master and broadcast from there again.
--- @param rpc_id number The identifier of the RPC, these can be found in the mod's RPCS table.
--- @param ... any Any additional data provided to the rpc handler.
function PEARL.BroadcastRPCToAllShards(rpc_id, ...)
    if TheShard:IsMaster() then
        -- Send RPC to all connected shards including this one.
        return PEARL.SendRPCToShard(rpc_id, nil, ...)
    end

    return PEARL.SendRPCToMaster(PEARL.RPC.BroadcastRPC, rpc_id, ...)
end

--- Sends the given RPC to all connected shards except the current one.
--- @param rpc_id number The identifier of the RPC, these can be found in the mod's RPCS table.
--- @param ... any Any additional data provided to the rpc handler.
function PEARL.BroadcastRPCToConnectedShards(rpc_id, ...)
    local connected_shards = PEARL.ServerNetwork:GetConnectedShardIDs()
    if IsTableEmpty(connected_shards) then
        return
    end

    return PEARL.SendRPCToShard(rpc_id, connected_shards, ...)
end

--- Sends the given RPC to all connected shards except the current one and the one provided.
--- @param rpc_id number The identifier of the RPC, these can be found in the mod's RPCS table.
--- @param ... any Any additional data provided to the rpc handler.
function PEARL.BroadcastRPCToShardsExcept(rpc_id, except, ...)
    local target_shards = PEARL.ServerNetwork:GetConnectedShardIDs()
    if IsTableEmpty(target_shards) then
        return
    end

    if except then
        except = tonumber(except)
    end

    for i, shardid in ipairs(target_shards) do
        if tonumber(shardid) == except then
            table.remove(target_shards, i)
        end
    end

    return PEARL.SendRPCToShard(rpc_id, target_shards, ...)
end

--- @param rpc_id number The identifier of the RPC, these can be found in the mod's RPCS table.
--- @param ... any Any additional data provided to the rpc handler.
function PEARL.BroadcastRPCToShardClients(rpc_id, ...)
    return PEARL.SendRPCToClient(rpc_id, nil, ...)
end

function PEARL.BroadcastRPCToAllClients(rpc_id, ...)
    return PEARL.SendRPCToShard(PEARL.RPC.BroadcastClientRPC, nil, rpc_id, nil, ...)
end

------------------------------------

function PEARL.AddRPC(name)
    PEARL.RPC._size = PEARL.RPC._size + 1
    PEARL.RPC[name] = PEARL.RPC._size

    return PEARL.RPC._size
end

function PEARL.AddServerUseridRPCHandler(name, handler)
    local id = PEARL.AddRPC(name)

    AddModRPCHandler(PEARL.RPC_NAME, id, handler)
    MarkUserIDRPC(PEARL.RPC_NAME, id)
end

function PEARL.AddServerRPCHandler(name, handler)
    return AddModRPCHandler(
        PEARL.RPC_NAME, PEARL.AddRPC(name), handler
    )
end

function PEARL.AddShardRPCHandler(name, handler)
    return AddShardModRPCHandler(
        PEARL.RPC_NAME, PEARL.AddRPC(name), handler
    )
end

function PEARL.AddClientRPCHandler(name, handler)
    PEARL.AddRPC(name)
    return AddClientModRPCHandler(
        PEARL.RPC_NAME, PEARL.AddRPC(name), handler
    )
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
        PEARL.AddClientRPCHandler(name, cb)
        i = i + 1
    end
end

--------------------------
-- Server RPCs
--------------------------

do
    local i = 1
    for name, cb in orderedPairs(SERVER_USERID_RPCS) do
        PEARL.AddServerUseridRPCHandler(name, cb)
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
-- Function Overrides
--------------------------

-- This is redundant on the client because there the staticUpdate works even when
-- the simulation is paused on the server because of the UI.
if not TheNet:IsDedicated() then
    return
end

-- Custom handler for server RPCs since the built-in one does only work when staticUpdate
-- gets called, and that is only when the simulation is running.

local RPC_QUEUE_RATE_LIMIT = UpvalueHacker:GetUpvalue(HandleModRPC, "RPC_QUEUE_RATE_LIMIT")
local RPC_Queue_Limiter = UpvalueHacker:GetUpvalue(HandleModRPC, "RPC_Queue_Limiter")

local function CustomHandleRPC(sender, tick, code, data, namespace)
    -- This is not our RPC so we do not care. How selfish...
    if namespace ~= PEARL.RPC_NAME and RAW_RPCS[code] == nil then
        return -- Leave the game handle it.
    end

    local ns_handlers = namespace and MOD_RPC_HANDLERS[namespace] or nil
    local handler = ns_handlers and ns_handlers[code] or RAW_RPCS[code]
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
end

local function CustomHandleModRPC(sender, tick, namespace, code, data)
    return CustomHandleRPC(sender, tick, code, data, namespace)
end

--- There are two main aproaches to this. One is using a PreCall, where
--- we handle the server mod rpcs all ourselves. The second one is using a PostCall
--- and if the rpc handled was ours, call TickRPCQueue afterwards. This however, can how
--- some side effects since the tick will not just call our RPCs but also the game's.

-- These two is only called on the server.
-- Also we need to handle rate limits here because these are not trusted.

PEARL.AddGlobalFunctionPreCall("HandleRPC", CustomHandleRPC)

PEARL.AddGlobalFunctionPreCall("HandleModRPC", CustomHandleModRPC)

-----------------------------------------------------------------------------------------

PEARL.AddGlobalFunctionPreCall("HandleShardModRPC", function(sender, tick, namespace, code, data)
    if not SHARD_MOD_RPC_HANDLERS[namespace] then
        return -- Leave the game handle it.
    end

    local ns_handlers = SHARD_MOD_RPC_HANDLERS[namespace]
    local handler = ns_handlers and ns_handlers[code]
    if not handler then
        return -- Leave the game handle it.
    end

    PEARL.SafeRun(TheNet.CallShardRPC, TheNet, handler, sender, data)

    return false
end)

PEARL.AddGlobalFunctionPreCall("HandleClientRPC", function(sender, tick, namespace, code, data)
    if not CLIENT_MOD_RPC_HANDLERS[namespace] then
        return -- Leave the game handle it.
    end

    local ns_handlers = CLIENT_MOD_RPC_HANDLERS[namespace]
    local handler = ns_handlers and ns_handlers[code]
    if not handler then
        return -- Leave the game handle it.
    end

    PEARL.SafeRun(TheNet.CallClientRPC, TheNet, handler, sender, data)

    return false
end)

-- Disable RPC disabling
PEARL.AddGlobalFunctionPreCall("DisableRPCSending", function() end)
