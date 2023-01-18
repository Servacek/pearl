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
    Mod server-side network.
--]]

local Ents = Ents
local TheNet, TheInput = TheNet, TheInput

----------------------------------
-- Declaration
----------------------------------

local conn_filters = {}
local conn_data_cache = {}
local client_cache = {}

--- @class ServerNetwork
local ServerNetwork = {}

----------------------------------
-- Public Functions
----------------------------------

--- @TODOv2.1
-- function ServerNetwork:BroadcastLuaToShards()

-- end

-- Called from server-side user command handlers.
-- Sends a RPC to the client with the given userid.
-- Note: This works only if the player is connected to the local shard.
function ServerNetwork:SendCommandResponse(userid, message, ...)
    if not (message and userid) then
        return
    end

    PEARL.info("ServerNetwork:SendCommandResponse<"..userid..">", message)
    return PEARL.SendRPCToClient(PEARL.RPCS.CommandResponse, userid, message)
end

function ServerNetwork:SendUserDisconnectFor(userid, reason, ...)
    PEARL.info("ServerNetwork:SendUserDisconnectFor", userid, reason)

    PEARL.SendRPCToClient(PEARL.RPCS.Disconnect, userid, reason, ...)
    if TheWorld ~= nil then
        TheWorld:PushModEvent("clientconnectionclosed", {
            userid = userid, reason = reason
        })
    end

    -- Give a tick to the RPC queue to handle the Disconnect RPC first
    -- This makes sure that the connection is removed in case of errors.
    PEARL.Scheduler:ExecuteInTime(0, function()
        -- Kick out the connection from this user,
        -- so it doesn't block other incoming connections.
        --
        -- Note: This doesn't work for admins.
        PEARL.debug("Kicking player from the server...")
        TheNet:Kick(userid)--, PEARL.CONSTS.DISCONNECT_KICK_TIME)
    end)
end

function ServerNetwork:SendUserConnectionAllowedFor(userid, ...)
    PEARL.debug("ServerNetwork:SendUserConnectionAllowedFor", userid, ...)
    return PEARL.SendRPCToClient(PEARL.RPCS.ConnectionAllowed, userid, ...)
end

----------------------------------
-- Getters
----------------------------------

function ServerNetwork:GetCachedCFDFor(userid)
    return conn_data_cache[userid]
end

function ServerNetwork:GetCachedClientTableFor(userid)
    return client_cache[userid]
end

----------------------------------
-- Setters
----------------------------------

function ServerNetwork:AddClientConnectionFilter(filter)
    PEARL.debug("ServerNetwork:AddClientConnectionFilter", filter)
    if TheShard:IsSecondary() then
        -- Only master does handle the external connections
        return PEARL.error("Attempted to add a client connection filter on a secondary shard!")
    end

    self:SetServerRequiresCFD(true)

    return table.insert(conn_filters, filter)
end

function ServerNetwork:SetServerRequiresCFD(requires)
    PEARL.CONFIG.SERVER_REQUIRE_CFD = requires
end

----------------------------------
-- Handlers
----------------------------------

function ServerNetwork:OnInvalidRPCFromClient(rpc_name, userid)
    PEARL.warn("Invalid Mod RPC", rpc_name, "from client", userid)

    PEARL.EventProcessor:HandleEvent("invalidrpc", rpc_name, userid)
end

function ServerNetwork:OnClientFilterDataReceived(userid, cfd)
    PEARL.debug("ServerNetwork:OnClientFilterDataReceived")

    -- Always keep the newest record since this can change quite frequently.
    conn_data_cache[userid] = cfd

    for _, filter in ipairs(conn_filters) do
        local success, reason = filter(userid, cfd)
        if success == false then -- Check for explicit false
            return self:SendUserDisconnectFor(userid, reason)
        end
    end

    PEARL.EventProcessor:HandleEvent("clientdatareceived", userid, cfd)

    -- If all the filters have successfully passed, then the connection should be allowed.
    self:SendUserConnectionAllowedFor(userid)
end

----------------------------------
-- Network Callbacks
----------------------------------

-- Used by the engine to notify lua on the master shard
-- that a secondary shard has changed it's state. This also notifies the shard itself.
PEARL.AddGlobalFunctionPreCall("Shard_UpdateWorldState", function(world_id, state)
    if TheWorld ~= nil then
        TheWorld:PushModEvent("shard_stateupdate", state)
    end
end)

-- Looks like this is pushed only on the Master shard
PEARL.AddGlobalFunctionPreCall("WorldRollbackFromSim", function(count)
    if TheWorld ~= nil then
        TheWorld:PushModEvent("world_rollback", count)
    end

    PEARL.ModShutdown()
end)

PEARL.AddGlobalFunctionPreCall("WorldResetFromSim", function()
    if TheWorld ~= nil then
        TheWorld:PushModEvent("world_reset")
    end

    PEARL.ModShutdown()
end)

PEARL.AddGlobalFunctionPreCall("Shutdown", function(...)
    if TheWorld ~= nil then
        TheWorld:PushModEvent("shard_shutdown")
    end

    PEARL.ModShutdown()
end)

-- We want to have full control over this function.
PEARL.OverrideVariable("ExecuteConsoleCommand", function(fnstr, guid, x, z)
    local saved_ThePlayer
    if guid ~= nil then
        saved_ThePlayer = ThePlayer
        ThePlayer = guid ~= nil and Ents[guid] or nil
    end
    TheInput.overridepos = (x ~= nil and z ~= nil and Vector3(x, 0, z)) or nil

    local success, response = pcall(loadstring(fnstr))
    if success then
        local doer = Ents[guid]
        if doer then
            doer:PushModEvent("ms_commandexecuted", fnstr)
        end
    else
        nolineprint(response)
    end

    if guid ~= nil then
        ThePlayer = saved_ThePlayer
    end
    TheInput.overridepos = nil
end)

----------------------------------
-- World Network Events
----------------------------------

PEARL.AddWorldPostInit(function(world)
    if not world then
        return
    end

    world:SafeListenForEvent("ms_clientauthenticationcomplete", function(self, data)
        if data.userid then
            client_cache[data.userid] = TheNet:GetClientTableForUser(data.userid)
        end

        PEARL.EventProcessor:HandleEvent("ms_clientauthenticationcomplete", data.userid)
    end)

    world:SafeListenForEvent("ms_clientdisconnected", function(self, data)
        PEARL.EventProcessor:HandleEvent("ms_clientdisconnected", data.userid, data.expected)
    end)

    world:SafeListenForEvent("invalidrpc", function(self, data)
        ServerNetwork:OnInvalidRPCFromClient(data.rpc_name, data.userid)
    end)

    -- Mod Events
    world:ListenForModEvent("clientconnectionclosed", function(self, data)
        PEARL.EventProcessor:HandleEvent("clientconnectionclosed", data.userid, data.reason)
    end)
end)

----------------------------------
-- Return
----------------------------------

return ServerNetwork
