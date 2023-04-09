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

    This is like an higher level 'TheNet' for dedicated servers.
--]]

local Ents = Ents
local TheNet, TheInput = TheNet, TheInput

----------------------------------
-- Constants
----------------------------------

local TIME_UNTIL_KICK = 10

----------------------------------
-- Declaration
----------------------------------

local conn_filters = {}
local conn_data_cache = {}

local join_filters = {}

local client_cache = {}

local joining_clients = {}

--- @class ServerNetwork
local ServerNetwork = {}

----------------------------------
-- Public Functions
----------------------------------

--- Sends the given lua string to all connected shards (except the sender).
function ServerNetwork:BroadcastLuaToShards(lua_str)
    if not TheShard:IsMaster() then
        return PEARL.error("Attempted to send arbitrary lua from a secondary shard!")
    end

    if not self:IsAnySecondaryShardConnected() then
        return PEARL.error("No shards connected!")
    end

    return PEARL.SendRPCToShard(PEARL.RPC.BroadcastLua, self:GetConnectedShardIDs(), lua_str)
end

-- Called from server-side user command handlers.
-- Sends a RPC to the client with the given userid.
-- Note: This works only if the player is connected to the local shard.
function ServerNetwork:SendCommandResponse(userid, message, ...)
    if not (message and userid) then
        return
    end

    PEARL.info("ServerNetwork:SendCommandResponse<"..userid..">", message)
    return PEARL.SendRPCToClient(PEARL.RPC.CommandResponse, userid, message)
end

function ServerNetwork:SendUserDisconnectFor(userid, reason, ...)
    PEARL.info("ServerNetwork:SendUserDisconnectFor", userid, reason)

    PEARL.SendRPCToClient(PEARL.RPC.Disconnect, userid, reason, ...)
    if TheWorld ~= nil then
        TheWorld:PushModEvent("clientconnectionclosed", {
            userid = userid, reason = reason
        })
    end

    -- Give a few seconds to the client so he can peacefully disconnect.
    PEARL.WallScheduler:ExecuteInTime(TIME_UNTIL_KICK, function()
        if not self:IsUserConnected(userid) then
            return PEARL.debug("Already disconnected...")
        end

        -- Kick out the connection from this user,
        -- so it doesn't block other incoming connections.
        --
        -- Note: This doesn't work for admins.
        PEARL.debug("Kicking player from the server...")
        TheNet:Kick(userid, PEARL.CONSTS.DISCONNECT_KICK_TIME)
    end)
end

function ServerNetwork:SendUserConnectionAllowedFor(userid, ...)
    PEARL.debug("ServerNetwork:SendUserConnectionAllowedFor", userid, ...)
    return PEARL.SendRPCToClient(PEARL.RPC.ConnectionAllowed, userid, ...)
end

-- Returns a boolean representing whether the client is allowed
-- to join according the filters or not.
function ServerNetwork:RunClientConnectionFiltersFor(userid, cfd)
    cfd = cfd or self:GetCachedCFDFor(userid)

    for _, filter in ipairs(conn_filters) do
        local success, allowed, reason = PEARL.SafeRun(filter, userid, cfd)
        if success == false then
            -- Allowed should be the error message in this case.
            PEARL.error("Failed to execute a connection data filter!", allowed)
        elseif allowed == false then -- Check for explicit false
            return allowed, reason
        end
    end

    return true
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

function ServerNetwork:IsAnySecondaryShardConnected()
    return not IsTableEmpty(ShardList)
end

function ServerNetwork:GetConnectedShardIDs()
    local ids = {}
    for id, _ in pairs(ShardList) do
        ids[#ids+1] = id
    end

    return ids
end

--- @TODO: Think of a better alternative.
--- So far, this is the most reliable approach.
function ServerNetwork:GetConnectedClientsCount()
    -- Looks like TheNet:GetPlayerCount() counts only the local shard players.
    return #TheNet:GetClientTable() - 1
end

-- Sadly, this doesn't work...
-- So currently the only way I can think of is to fetch the server lisiting
-- from the lobby servers.
-- function ServerNetwork:GetServerIP()
--     return self.listing.ip
-- end

function ServerNetwork:GetHostTable()
    -- For dedicated servers the first index is reserved for the "host" machine.
    return TheNet:GetClientTable()[1]
end

function ServerNetwork:GetUserFlags(userid)
    local client = userid and TheNet:GetClientTableForUser(userid)
    return client and client.userflags
end

function ServerNetwork:HasUserAnyFlags(userid)
    return self:GetUserFlags(userid) == 0
end

function ServerNetwork:HasUserFlag(userid, flag)
    return checkbit(self:GetUserFlags(userid), flag)
end

function ServerNetwork:UserSessionExists(userid)
    return TheNet:GetUserSessionFile(TheNet:GetSessionIdentifier(), userid) ~= nil
end

--- Client tables are the same between shards!
function ServerNetwork:IsUserConnected(userid)
    return userid and TheNet:GetClientTableForUser(userid) ~= nil
end

function ServerNetwork:IsClientInactive(userid)
    return self:HasUserFlag(userid, USERFLAGS.IS_AFK)
end

function ServerNetwork:IsClientGhost(userid)
    return self:HasUserFlag(userid, USERFLAGS.IS_GHOST)
end

function ServerNetwork:IsClientLoading(userid)
    return self:HasUserFlag(userid, USERFLAGS.IS_LOADING)
end

function ServerNetwork:IsClientJoining(userid)
    return joining_clients[userid] == true
end

function ServerNetwork:IsAdmin(userid)
    local client = TheNet:GetClientTableForUser(userid)
    return client and client.admin == true or PEARL.AdminList:Contains(userid)
end

function ServerNetwork:IsClientTrusted(userid)
    return self:IsAdmin(userid) or PEARL.AllowList:Contains(userid)
end

----------------------------------
-- Setters
----------------------------------

--- @param filter function<userid, data>
function ServerNetwork:AddClientConnectionFilter(filter)
    PEARL.debug("ServerNetwork:AddClientConnectionFilter", filter)

    self:SetServerRequiresCFD(true)

    return table.insert(conn_filters, filter)
end

function ServerNetwork:AddJoinServerFilter(filter)
    PEARL.debug("ServerNetwork:AddJoinServerFilter", filter)

    return table.insert(join_filters, filter)
end

function ServerNetwork:SetServerRequiresCFD(requires)
    PEARL.CONFIG.SERVER_REQUIRE_CFD = requires
end

function ServerNetwork:CacheClientTableFor(userid)
    if type(userid) == "string" then
        client_cache[userid] = TheNet:GetClientTableForUser(userid)
    end

    return client_cache[userid]
end

function ServerNetwork:CacheClientCFDFor(userid, cfd)
    conn_data_cache[userid] = cfd
end

-- function ServerNetwork:StartTimeoutFor(userid)
--     PEARL.debug("ServerNetwork:StartTimeoutFor", userid)

--     if timeouts[userid] then
--         return
--     end

--     timeouts[userid] = PEARL.WallScheduler:ExecuteInTime(
--         PEARL.CONFIG.AUTH_TIMEOUT, self.OnClientConnectionTimeout, nil, self, userid
--     )
-- end

-- function ServerNetwork:CancelTimeoutFor(userid)
--     PEARL.debug("ServerNetwork:CancelTimeoutFor", userid)

--     if timeouts[userid] ~= nil then
--         timeouts[userid]:cancel()
--         timeouts[userid] = nil
--     end
-- end

----------------------------------
-- Handlers
----------------------------------

function ServerNetwork:OnClientFilterDataFailed(userid)
    PEARL.warn("Client", userid, "didn't send connection filter data to the server!")
    if PEARL.DiscordReporter then
        PEARL.DiscordReporter:SendRawReportString(STRINGS.PEARL.LOGS.LOCALIZATION_TIMEOUT:format(
            userid
        ))
    end

    if not PEARL.CONFIG.FAIL_SAFE_NETWORK then
        -- Show the authentication failed popup and disconnect the client.
        self:SendUserDisconnectFor(userid, "ID_DST_GAME_SESSION_AUTH_FAILED")
    end
end

function ServerNetwork:OnInvalidRPCFromClient(rpc_name, userid)
    PEARL.warn("Invalid Mod RPC", rpc_name, "from client", userid)

    PEARL.EventProcessor:HandleEvent("invalidrpc", rpc_name, userid)
end

function ServerNetwork:OnClientDisconnected(userid)
    joining_clients[userid] = nil
end

function ServerNetwork:OnClientJoined(userid)
    self:CacheClientTableFor(userid)

    if self:IsClientJoining(userid) and self:GetCachedCFDFor(userid) == nil then
        self:OnClientFilterDataFailed(userid)
    end

    joining_clients[userid] = nil
end

function ServerNetwork:OnClientJoining(userid)
    if (PEARL.AdminList:Contains(userid) and not PEARL.CONFIG.DEBUG_MODE) then
        return
    end

    joining_clients[userid] = true
end

function ServerNetwork:OnClientAuthenticationComplete(userid)
    -- Keep the newest data cached.
    self:CacheClientTableFor(userid)
end

function ServerNetwork:OnClientFilterDataReceived(userid, cfd)
    PEARL.debug("ServerNetwork:OnClientFilterDataReceived")
    PEARL.debug(DataDumper(cfd))

    -- Always keep just the newest record
    -- This is here just to make sure the data are being cached in case the RCP fails.
    self:CacheClientCFDFor(userid, cfd)

    -- This is being called just for some logging and stuff, to actually
    -- control the connection use the connection filters.
    PEARL.EventProcessor:HandleEvent("clientdatareceived", userid, cfd)

    -- Skip already trusted clients
    if not self:IsClientTrusted(userid) or PEARL.CONFIG.DEBUG_MODE then
        local allowed, reason = self:RunClientConnectionFiltersFor(userid)
        if allowed == false then
            return self:SendUserDisconnectFor(userid, reason)
        end
    end

    -- If all the filters have successfully passed, then the connection should be allowed.
    PEARL.debug("Allowing connection...")
    self:SendUserConnectionAllowedFor(userid)
end

----------------------------------
-- Network Callbacks
----------------------------------
--- @TODO: I guess this should be moved somewhere else.

local function OnShardCrashed()
    PEARL.EventProcessor:HandleEvent("shard_shutdown", true)
    PEARL.ModShutdown()
end

local function OnShardShutdown()
    PEARL.EventProcessor:HandleEvent("shard_shutdown")
    PEARL.ModShutdown()
end

-- Returning false here will cause the client to be disconnected immediately.
-- The "Slots Reserved" popup will be displayed.
-- Start the timeout here since we are sure that this is being only called when joining.
PEARL.AddGlobalFunctionPreCall("JoinServerFilter", function(userid, ...)
    if PEARL.ServerNetwork:IsUserConnected(userid) then
        return -- If the user is already connected then ignore this call.
    end

    for _, filter in ipairs(join_filters) do
        local success, allowed, reason = PEARL.SafeRun(filter, userid, ...)
        if success == false then
            -- Allowed should be the error message in this case.
            PEARL.error("Failed to execute a join server filter!", allowed)
        end

        if allowed == false then -- Check for explicit false
            if TheWorld then
                TheWorld:PushModEvent("clientconnectionclosed", {
                    userid = userid, reason = reason
                })
            end

            return false
        end
    end

    PEARL.ServerNetwork:OnClientJoining(userid)

    -- Let the default callback to handle this case.
end)

-- Used by the engine to notify lua on the master shard
-- that a secondary shard has changed it's state. This also notifies the shard itself.
PEARL.AddGlobalFunctionPreCall("Shard_UpdateWorldState", function(...)
    PEARL.EventProcessor:HandleEvent("shard_stateupdate", ...)
end)

-- Looks like this is pushed only on the Master shard
PEARL.AddGlobalFunctionPreCall("WorldRollbackFromSim", function(count)
    if TheWorld ~= nil then
        TheWorld:PushModEvent("world_rollback", count)
    end
end)

PEARL.AddGlobalFunctionPreCall("OnSimPaused", function()
    if TheWorld ~= nil then
        TheWorld:PushModEvent("simpaused")
    end
end)

PEARL.AddUserDataFunctionPreCall("Reset", function()
    if TheWorld ~= nil then
        TheWorld:PushModEvent("world_restart")
    end

    PEARL.ModShutdown()
end, TheSim)

PEARL.AddGlobalFunctionPreCall("WorldResetFromSim", function()
    if TheWorld ~= nil then
        TheWorld:PushModEvent("world_reset")
    end

    PEARL.GameInstParams:SetModParam("regenerated", true)
    PEARL.ModShutdown()
end)

PEARL.AddUserDataFunctionPreCall("Quit", OnShardShutdown, TheSim)
PEARL.AddUserDataFunctionPreCall("Crash", OnShardCrashed, TheSim)
PEARL.AddUserDataFunctionPreCall("ForceAbort", OnShardCrashed, TheSim)

-- Filter out prohibited commands recevied by the server.
PEARL.AddGlobalFunctionPreCall("Networking_SlashCmd", function(guid, userid, cmd)
    return ServerNetwork:IsAdmin(userid) or PEARL.CONFIG.COMMAND_BLOCKLIST[cmd] ~= true
end)

-- We want to have full control over this function on servers.
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

-- TheWorld is still nil when this is called.
PEARL.AddWorldPostInit(function(world)
    if not world then
        return
    end

    world:SafeListenForEvent("ms_playerjoined", function(self, player)
        if player and player.userid then
            ServerNetwork:OnClientJoined(player.userid)
        end
    end)

    world:SafeListenForEvent("ms_clientauthenticationcomplete", function(self, data)
        if data and data.userid then
            ServerNetwork:OnClientAuthenticationComplete(data.userid)
        end

        PEARL.EventProcessor:HandleEvent("ms_clientauthenticationcomplete", data.userid)
    end)

    world:SafeListenForEvent("ms_clientdisconnected", function(self, data)
        if not data or not data.userid then
            return
        end

        ServerNetwork:OnClientDisconnected(data.userid)
        PEARL.EventProcessor:HandleEvent("ms_clientdisconnected", data.userid, data.expected)
    end)

    world:SafeListenForEvent("invalidrpc", function(self, data)
        ServerNetwork:OnInvalidRPCFromClient(data.rpc_name, data.userid)
    end)

    -- Mod Events
    world:ListenForModEvent("clientconnectionclosed", function(self, data)
        if not data and not data.userid then
            return
        end

        ServerNetwork:OnClientDisconnected(data.userid)
        PEARL.EventProcessor:HandleEvent("clientconnectionclosed", data.userid, data.reason)
    end)
end)

-- Looks like GamePostInit isn't called when regenerating the world.
PEARL.AddSimPostInit(function()
    if not TheWorld then
        return
    end

    -- Push this here since this is the place where all the meta data are loaded as well.
    if PEARL.GameInstParams:GetModParam("regenerated") == true then
        TheWorld:PushModEvent("worldgencomplete")
    end
end)

----------------------------------
-- RPC Handlers
----------------------------------

PEARL.AddRawServerUseridRPCHandler("ClientDisconnected", function(userid, reason, force)
    if not (optstring(reason) and optbool(force)) then
        return PEARL.ServerNetwork:OnInvalidRPCFromClient("ClientDisconnected", userid)
    end

    PEARL.debug("RPC: ClientDisconnected", reason, force)
    PEARL.EventProcessor:HandleEvent("clientconnectionclosed", userid, reason)
end)

--- @TODO: Handle secondary shards receiving this data. Redirect them to Master?
--- We need this data on the Master shard as well...
---
--- We will probably save the data from this to the DB.
PEARL.AddRawServerUseridRPCHandler("ConnectionFilterData", function(userid, data)
    if not checkstring(data) then
        return PEARL.ServerNetwork:OnInvalidRPCFromClient("ConnectionFilterData", userid)
    end

    -- All the data is untrusted in this case.
    local data_tbl = DecodeAndUnzipString(data)
    if not data_tbl or IsTableEmpty(data_tbl) then
        return PEARL.ServerNetwork:OnInvalidRPCFromClient("ConnectionFilterData", userid)
    end

    --PEARL.debug("Received CFD from client:", DataDumper(data_tbl))

    PEARL.ServerNetwork:OnClientFilterDataReceived(userid, data_tbl)

    -- Broadcast the CFD to all connected shards so they have the fresh info as well.
    PEARL.SendRPCToShard(
        PEARL.RPC.ClientCFDRecevied, nil, userid, data
    )
end)

----------------------------------
-- Return
----------------------------------

return ServerNetwork
