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

--- @type table<string, Task>
local timeouts = {}

local join_filters = {}

local client_cache = {}

--- @class ServerNetwork
local ServerNetwork = {
    listing = TheNet:GetServerListing()
}

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

    -- Give a few ticks to the RPC queue to handle the Disconnect RPC first
    -- This makes sure that the connection is removed in case of errors.
    PEARL.WallScheduler:ExecuteInTime(1, function()
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
    return PEARL.SendRPCToClient(PEARL.RPCS.ConnectionAllowed, userid, ...)
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

function ServerNetwork:GetServerIP()
    return self.listing.ip
end

function ServerNetwork:GetHostTable()
    -- For dedicated servers the first index is reserved for the "host" machine.
    return TheNet:GetClientTable()[1]
end

function ServerNetwork:UserSessionExists(userid)
    return TheNet:GetUserSessionFile(TheNet:GetSessionIdentifier(), userid) ~= nil
end

function ServerNetwork:IsClientJoining(userid)
    local client = self:GetCachedClientTableFor(userid) or TheNet:GetClientTableForUser(userid)
    return client and (
        client.playerage == 0 and
        client.prefab == "" and
        client.lobbycharacter == ""
    ) or false
end

function ServerNetwork:IsAdmin(userid)
    local client = self:GetCachedClientTableFor(userid) or TheNet:GetClientTableForUser(userid)
    return client.admin == true
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

function ServerNetwork:StartTimeoutFor(userid)
    PEARL.debug("ServerNetwork:StartTimeoutFor", userid)

    if timeouts[userid] then
        return
    end

    timeouts[userid] = PEARL.WallScheduler:ExecuteInTime(
        PEARL.CONFIG.LOCALIZER.TIMEOUT, self.OnClientConnectionTimeout, nil, self, userid
    )
end

function ServerNetwork:CancelTimeoutFor(userid)
    PEARL.debug("ServerNetwork:CancelTimeoutFor", userid)

    if timeouts[userid] ~= nil then
        timeouts[userid]:cancel()
        timeouts[userid] = nil
    end
end

----------------------------------
-- Handlers
----------------------------------

function ServerNetwork:OnClientConnectionTimeout(userid)
    self:CancelTimeoutFor(userid)

    PEARL.warn("Client", userid, "didn't send connection data on time!")
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

function ServerNetwork:OnClientAuthenticationComplete(userid)
    -- Keep the newest data cached.
    local client = self:CacheClientTableFor(userid)

    if self:IsClientJoining(userid) and (not client.admin or PEARL.CONFIG.DEBUG_MODE) then
        -- Starting the timeout only makes sense if the client is joining the server.
        self:StartTimeoutFor(userid)
    end
end

function ServerNetwork:OnClientFilterDataReceived(userid, cfd)
    PEARL.debug("ServerNetwork:OnClientFilterDataReceived")
    PEARL.debug(DataDumper(cfd))

    self:CancelTimeoutFor(userid)

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
PEARL.AddGlobalFunctionPreCall("JoinServerFilter", function(userid, ...)
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
    return PEARL.IsAdminUserid(userid) or PEARL.IsCommandAllowed(cmd)
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

-- TheWorld is still nil when this is called.
PEARL.AddWorldPostInit(function(world)
    if not world then
        return
    end

    world:SafeListenForEvent("ms_playerjoined", function(self, player)
        if player and player.userid then
            ServerNetwork:CacheClientTableFor(player.userid)
        end
    end)

    world:SafeListenForEvent("ms_clientauthenticationcomplete", function(self, data)
        if data and data.userid then
            ServerNetwork:OnClientAuthenticationComplete(data.userid)
        end

        PEARL.EventProcessor:HandleEvent("ms_clientauthenticationcomplete", data.userid)
    end)

    world:SafeListenForEvent("ms_clientdisconnected", function(self, data)
        ServerNetwork:CancelTimeoutFor(data.userid)
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
-- Return
----------------------------------

return ServerNetwork
