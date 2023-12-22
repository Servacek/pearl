--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local TheNet = TheNet

local PopupDialogScreen = require("screens/redux/popupdialog")

local UpvalueHacker = PEARL.loadfile("utils/upvaluehacker")

--- @ERRORS:
--- RPC string failed to decode -> You are calling an RPC from an RPC! Add ExecuteInTime(0, ...)

--------------------------
-- Initialization
--------------------------

local function HandleRPCError(err, sender, traceback)
    --- @type string
    local reason = type(err) == "string" and err or STRINGS.PEARL.REPORTS.NO_STACKTRACE
    if traceback then
        reason = StackTrace(err) or reason
    end

    local userid = type(sender) == "table" and sender.userid or sender
    PEARL.DiscordReporter:ReportInvalidClientRPC(userid, reason)
end

local ServerRPCHandler = function(fn)
    return type(fn) == "function" and function(sender, ...)
        local success, err = pcall(fn, sender, ...)
        if success and err == nil then
            return -- The RPC was executed successfully.
        end

        HandleRPCError(err, sender, success)
    end or function() end
end

PEARL.RPC = {
    _size = 0
}

function PEARL.IsRPCSenderListValid(sender_list)
    return type(sender_list) == "string" or (
        type(sender_list) == "table" and not table.empty(sender_list)
    )
end

--- RPCs from the server are trusted if the server is trusted (which it should).
local CLIENT_RPCS = {
    DisplayChatMessage = function(data)
        PEARL.debug("DisplayChatMessage:", data)

        if not ChatHistory then
            return PEARL.error("Chat history not loaded yet!")
        end

        local success, message = pcall(json.decode, data)
        if success == false or type(message) ~= "table" then
            return PEARL.error("Failed to decode the message JSON data!")
        end

        return ChatHistory:AddChatMessage(message)
    end,

    DisplayPopupMessage = function(title, message)
        title = title or STRINGS.PEARL.UI.DEFAULT_POPUP_TITLE

        local popup
        popup = PopupDialogScreen(title, message, {{
            text = STRINGS.UI.TRADESCREEN.OK,
            cb = function()
                TheFrontEnd:PopScreen(popup)
            end
        }})

        TheFrontEnd:PushScreen(popup)
    end,

    Disconnect = function(reason, ...)
        return PEARL.ClientNetwork:Disconnect(reason, true, ...)
    end,

    ConnectionAllowed = function(initial)
        return PEARL.ClientNetwork:OnConnectionAllowed(initial)
    end,
}

--- These handlers should be called only from the server.
--- That means, they should be trusted and we do not need to add any additional checks.
local SHARD_RPCS = {
    ShardResponse = function(shardid, id, response)
        PEARL.EventProcessor:HandleEvent("shardresponse_"..tostring(id), response)
    end,

    -- Used by the VersionChecker for shutting down secondary shards
    -- to synchronize the shutdown process on version mismatch.
    BroadcastLua = function(shardid, luastring, id)
        if tostring(shardid) ~= SHARDID.MASTER then
            return PEARL.error("Got lua chunk from a secondary shard!")
        end

        -- Excecute this the next frame in case the command is calling another RPC.
        -- Calling RPC from an RPC handler is not allowed!
        PEARL.WallScheduler:ExecuteInTime(0, function()
            PEARL.info("Executing arbitrary lua chunk from Master...")
            luastring = tostring(luastring)
            if not luastring:startswith("return ") then
                luastring = "return "..luastring
            end

            local result
            local fn, errmsg = loadstring(luastring)
            if type(fn) == "function" then
                result = {pcall(fn)}
            else
                result = {false, errmsg}
            end

            errmsg = result[2]
            local success = result[1]
            if success == false and result then
                PEARL.error(errmsg)
            end

            if id ~= nil then
                local response
                if result and #result > 0 then
                    response = pcall(json.decode, result)
                end

                PEARL.SendRPCToShard(PEARL.RPC.ShardResponse, shardid, id, response)
            end
        end)
    end,

    BroadcastRPCToShards = function(shardid, client_rpc_id, sender_list, ...)
        PEARL.debug("[RPC] BroadcastRPCToShards", client_rpc_id, sender_list, ...)

        -- Handle sender list being an encoded list of userids.
        local success, data = pcall(json.decode, sender_list)
        if success and type(data) == "table" then
            sender_list = data
        end

        -- It seems like you cannot execute RPC in an RPC...
        PEARL.WallScheduler:ExecuteInTime(
            0, PEARL.BroadcastRPCToShardsGlobal, nil, client_rpc_id, sender_list, ...
        )
    end,

    SendRPCToClient = function(shardid, rpc_id, sender_list, ...)
        PEARL.debug("[RPC] SendRPCToClient", rpc_id, sender_list, ...)

        -- Handle sender list being an encoded list of userids.
        -- Sender list is always either nil or a string
        local _, data = pcall(json.decode, sender_list)
        if type(data) == "table" then
            sender_list = data
        end

        -- It seems like you cannot execute RPC in a RPC...
        PEARL.WallScheduler:ExecuteInTime(
            0, PEARL.SendRPCToClient, nil, rpc_id, sender_list, ...
        )
    end,
}

--- These RPCS are called from the clients so additional security checks are needed.
--- userid is being supplied by the game's RPC manager so that should be safe.
local SERVER_USERID_RPCS = {
    AFKStateChanged = function(userid, is_afk, kicked)
        if not (optbool(is_afk) and optbool(kicked)) then
            return PEARL.ServerNetwork:OnInvalidRPCFromClient("AFKStateChanged", userid)
        end

        if kicked then
            TheNet:Kick(userid, 0) -- Make sure the user can immediately re-join
            PEARL.EventProcessor:HandleEvent("afk_kicked", userid)
        else
            PEARL.EventProcessor:HandleEvent("afk_statechanged", userid, is_afk)
        end
    end,

    --- @TODO: Maybe move this somewhere else?
    PlayerReportMessage = function(userid, message)
        if not optstring(message) then
            return PEARL.ServerNetwork:OnInvalidRPCFromClient("PlayerReportMessage", userid)
        end

        -- In case the webhook reporter was disabled during runtime
        if not PEARL.DiscordReporter or PEARL.DiscordReporter:IsDisabled() then
            return PEARL.ServerNetwork:SendCommandResponse(userid, STRINGS.PEARL.UI.CMD_ERRORS.NO_RHOOK)
        end

        PEARL.DiscordReporter:SendPlayerReportMessage(userid, message)

        -- Anounce it so it logs the message and also other players can see it as well.
        PEARL.AnnounceWithType(STRINGS.PEARL.LOGS.STAFF_CALLED, "default")
    end,

    AgreementDataReceived = function(userid, agreed, datacollection, agreedintime, agreed_version)
        PEARL.debug("AgreementDataReceived", userid, agreed, datacollection, type(agreedintime), agreed_version)

        if not optbool(agreed) or not optbool(datacollection) or not optnumber(agreedintime) or not optstring(agreed_version) then
            return PEARL.ServerNetwork:OnInvalidRPCFromClient("AgreementDataReceived", userid)
        end

        PEARL.EventProcessor:HandleEvent("clientagreementdatareceived", {
            userid = userid,
            agreed = agreed,
            datacollection = datacollection,
            agreedintime = agreedintime,
            version = agreed_version,
        })
    end
}

--------------------------
-- Raw RPCs
--------------------------

local RAW_RPCS = {}

--- @type table<integer, any>
local RPC_HANDLERS = UpvalueHacker:GetUpvalue(HandleRPC, "RPC_HANDLERS")
local USERID_RPCS  = UpvalueHacker:GetUpvalue(HandleRPC, "USERID_RPCS")
assert(type(RPC_HANDLERS) == "table" and type(USERID_RPCS) == "table")

---------------

function PEARL.SendRawRPCToServer(rpc_id, ...)
    return SendRPCToServer(rpc_id, ...)
end

--- @param name string
--- @param fn function
--- @param useridrpc boolean?
function PEARL.AddRawServerRPCHandler(name, fn, useridrpc)
    assert(type(fn) == "function")
    assert(type(name) == "string")

    fn = useridrpc == true and fn or ServerRPCHandler(fn)
    PEARL.RegisterRawServerRPC(name, fn, useridrpc)
end

--- @param name string
--- @param fn function?
--- @param useridrpc boolean?
function PEARL.RegisterRawServerRPC(name, fn, useridrpc)
    assert(type(name) == "string")

    local i = #RPC_HANDLERS + 1
    assert(RPC_HANDLERS[i] == nil)

    PEARL.debug("Registering raw RPC", name, i, useridrpc)

    fn = type(fn) == "function" and fn or function() end
    PEARL.RPC[name] = i
    RPC_HANDLERS[i] = fn
    RAW_RPCS[i] = fn

    if useridrpc == true then
        USERID_RPCS[fn] = true
    end
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

-- Getters

--- @param name string|number
--- @return table?
function PEARL.GetClientRPC(name)
    return GetClientModRPC(PEARL.RPC_NAME, name)
end

--- @param name string|number
--- @return table?
function PEARL.GetShardRPC(name)
    return GetShardModRPC(PEARL.RPC_NAME, name)
end

--- @param name string|number
--- @return table?
function PEARL.GetServerRPC(name)
    return GetModRPC(PEARL.RPC_NAME, name)
end

--- Senders

--- Server (Client -> Shard)

--- Sends the RPC to the shard the client is connected to.
--- @param rpc_id string The identifier of the RPC, these can be found in the mod's RPCS table.
--- @param ... any Any additional data provided to the rpc handler.
function PEARL.SendRPCToServer(rpc_id, ...)
    return SendModRPCToServer(PEARL.GetServerRPC(rpc_id), ...)
end

--- Shards (Shard -> Shard)

--- Sends the RPC to the Master shard from any connected shard.
--- @param rpc_id string The identifier of the RPC, these can be found in the mod's RPCS table.
--- @param ... any Any additional data provided to the rpc handler.
function PEARL.SendRPCToMaster(rpc_id, ...)
    PEARL.debug("PEARL.SendRPCToMaster", rpc_id, ...)

    return PEARL.SendRPCToShard(rpc_id, SHARDID.MASTER, ...)
end

--- @param rpc_id string The identifier of the RPC, these can be found in the mod's RPCS table.
--- @param sender_list? table|number|string
--- @param ... any Any additional data provided to the rpc handler.
--- if sender_list is nil, all connected shards(including the one this is called on) will have this RPC executed.
--- if sender_list is a table, it will be iterated upon and send it to every shard that's ID is in the table.
--- if sender_list is either a string or a number, it will send that RPC to the specific shard with that ID.
function PEARL.SendRPCToShard(rpc_id, sender_list, ...)
    PEARL.debug("SendRPCToShard", rpc_id, sender_list, ...)

    return SendModRPCToShard(PEARL.GetShardRPC(rpc_id), sender_list, ...)
end

--- Broadcasts the given client RPC to the specified shards accross the server.
--- @param rpc_id string The identifier of the RPC, these can be found in the mod's RPCS table.
--- @param shards? table|string
--- @param ... any Any additional data provided to the rpc handler.
function PEARL.BroadcastRPCToShardsGlobal(rpc_id, shards, ...)
    PEARL.debug("BroadcastRPCToShards", rpc_id, shards, ...)
    if TheShard:IsMaster() then
        -- On master we can send the RPC directly since all shards are accessible.
        return PEARL.SendRPCToShard(rpc_id, shards, ...)
    end

    -- Handle sender_list being a table since tables are not supported by the RPC API
    -- No zipping here since the tables are relatively small.
    if type(shards) == "table" then
        local _, encoded = pcall(json.encode, shards)
        if type(encoded) == "string" then
            shards = encoded
        end
    end

    -- On a secondary shard we have to route the broadcast RPC to Master first.
    return PEARL.SendRPCToMaster(PEARL.RPC.BroadcastRPCToShards, rpc_id, shards, ...)
end

--- If called on Master, sends the given RPC to all connected shards.
--- Otherwise it will send the BroadcastRPC to shard Master and broadcast from there again.
--- Finally the RPC should be executed on all shards the server has including Master and source shard.
--- @param rpc_id string The identifier of the RPC, these can be found in the mod's RPCS table.
--- @param ... any Any additional data provided to the rpc handler.
function PEARL.BroadcastRPCToAllShards(rpc_id, ...)
    PEARL.debug("BroadcastRPCToAllShards", rpc_id, ...)

    return PEARL.BroadcastRPCToShardsGlobal(rpc_id, nil, ...)
end

--- Sends the given RPC to all connected shards except the current one.
--- @param rpc_id string The identifier of the RPC, these can be found in the mod's RPCS table.
--- @param ... any Any additional data provided to the rpc handler.
function PEARL.BroadcastRPCToConnectedShards(rpc_id, ...)
     PEARL.debug("BroadcastRPCToConnectedShards", rpc_id, ...)

    local connected_shards = PEARL.ServerNetwork:GetConnectedShardIDs()
    if table.empty(connected_shards) then
        return PEARL.debug("RPC.BroadcastRPCToConnectedShards: No shards connected!")
    end

    return PEARL.SendRPCToShard(rpc_id, connected_shards, ...)
end

--- Client Broadcasting (Shard -> Client) ---

--- Sends the given RPC to the specified client within the current shard.
--- @param rpc_id string The identifier of the RPC, these can be found in the mod's RPCS table.
--- @param sender_list? table|string
--- @param ... any Any additional data provided to the rpc handler.
--- if sender_list is nil, all clients connected to the current shard will execute the RPC.
--- if sender_list is a table, it will be iterated upon and send it to every client that is connected to the current shard thats UserID is in the table.
--- if sender_list is a string, it will send the RPC to the specific client with that UserID, as long as they are connected to that shard.
function PEARL.SendRPCToClient(rpc_id, sender_list, ...)
    PEARL.debug("SendRPCToClient", rpc_id, ...)

    return SendModRPCToClient(PEARL.GetClientRPC(rpc_id), sender_list, ...)
end

--- Sends the given RPC to the specified client within the whole server.
--- @param rpc_id string The identifier of the RPC, these can be found in the mod's RPCS table.
--- @param sender_list? table|string
--- @param ... any Any additional data provided to the rpc handler.
--- if sender_list is nil, all clients connected to the current shard will execute the RPC.
--- if sender_list is a table, it will be iterated upon and send it to every client that is connected to the current shard thats UserID is in the table.
--- if sender_list is a string, it will send the RPC to the specific client with that UserID, as long as they are connected to that shard.
function PEARL.SendRPCToClientGlobal(rpc_id, sender_list, ...)
    PEARL.debug("SendRPCToClientGlobal", rpc_id, sender_list, ...)

    if sender_list ~= nil and type(sender_list) ~= "table" then
        sender_list = {sender_list}
    end

    local l_receivers, r_receivers
    if type(sender_list) == "table" then
        for _, userid in ipairs(sender_list) do
            if PEARL.ServerNetwork:IsClientConnected(userid) then
                if not l_receivers then
                    l_receivers = {}
                end

                l_receivers[#l_receivers + 1] = userid
            else
                if not r_receivers then
                    r_receivers = {}
                end

                r_receivers[#r_receivers + 1] = userid
            end
        end
    end

    if l_receivers or sender_list == nil then
        PEARL.SendRPCToClient(rpc_id, l_receivers, ...)
    end

    if r_receivers or sender_list == nil then
        PEARL.BroadcastRPCToConnectedShards(PEARL.RPC.SendRPCToClient, rpc_id, r_receivers, ...)
    end
end

--- Sends the RPC to all clients connected to the current shard.
--- @param rpc_id string The identifier of the RPC, these can be found in the mod's RPCS table.
--- @param ... any Any additional data provided to the rpc handler.
function PEARL.BroadcastRPCToShardClients(rpc_id, ...)
    if not TheNet:GetIsServer() then
        return PEARL.error("Can only be called from a server.")
    end

    return PEARL.SendRPCToClient(rpc_id, nil, ...)
end

--- Sends the RPC to all clients connected to the server (for every player on every shard).
--- @param rpc_id string The identifier of the RPC, these can be found in the mod's RPCS table.
--- @param ... any Any additional data provided to the rpc handler.
function PEARL.BroadcastRPCToAllClients(rpc_id, ...)
    if not TheNet:GetIsServer() then
        return PEARL.error("Can only be called from a server.")
    end

    PEARL.BroadcastRPCToClientsGlobal(rpc_id, nil, ...)
end

--- Sends the RPC to the selected clients accross the server.
--- @param rpc_id string The identifier of the RPC, these can be found in the mod's RPCS table.
--- @param sender_list? table|string
--- @param ... any Any additional data provided to the rpc handler.
function PEARL.BroadcastRPCToClientsGlobal(rpc_id, sender_list, ...)
    if not TheNet:GetIsServer() then
        return PEARL.error("Can only be called from a server.")
    end

    -- Handle sender_list being a table since tables are not supported by the RPC API
    -- No zipping here since the tables are relatively small.
    if type(sender_list) == "table" then
        local success, encoded = pcall(json.encode, sender_list)
        if success and type(encoded) == "string" then
            sender_list = encoded
        end
    end

    PEARL.BroadcastRPCToAllShards(PEARL.RPC.SendRPCToClient, rpc_id, sender_list, ...)
end

------------------------------------

function PEARL.RegisterRPC(name)
    if type(PEARL.RPC[name]) == "number" then
        return PEARL.RPC[name] -- Already registered
    end

    PEARL.RPC._size = PEARL.RPC._size + 1
    PEARL.RPC[name] = PEARL.RPC._size

    return PEARL.RPC._size
end

function PEARL.AddServerUseridRPCHandler(name, handler)
    PEARL.AddServerRPCHandler(name, handler)
    PEARL.MarkServerUseridRPC(name)
end

function PEARL.MarkServerUseridRPC(name)
    local rpc = PEARL.RPC[name]
    assert(rpc, "Attempted to mark a non-registered RPC!")

    MarkUserIDRPC(PEARL.RPC_NAME, rpc)
end

function PEARL.AddServerRPCHandler(name, handler)
    return AddModRPCHandler(
        PEARL.RPC_NAME, PEARL.RegisterRPC(name), ServerRPCHandler(handler)
    )
end

function PEARL.AddShardRPCHandler(name, handler)
    return AddShardModRPCHandler(
        PEARL.RPC_NAME, PEARL.RegisterRPC(name), handler
    )
end

function PEARL.AddClientRPCHandler(name, handler)
    return AddClientModRPCHandler(
        PEARL.RPC_NAME, PEARL.RegisterRPC(name), handler
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

    PEARL.debug("Received Raw Mod RPC", code, "from", sender)

    local success, err = PEARL.SafeRun(TheNet.CallRPC, TheNet, handler, userid, data)
    if not success or type(err) == "string" then
        HandleRPCError(err, userid, success)
    end

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
    local ns_handlers = CLIENT_MOD_RPC_HANDLERS[namespace]
    local handler = ns_handlers and ns_handlers[code]
    if not handler then
        return -- Leave the game handle it.
    end

    PEARL.debug("Received Raw Mod RPC", code, "from", sender)

    PEARL.SafeRun(TheNet.CallClientRPC, TheNet, handler, sender, data)

    return false
end)

-- Disable RPC disabling
-- PEARL.AddGlobalFunctionPreCall("DisableRPCSending", function() end)
