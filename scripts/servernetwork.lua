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

--- @TODO: There is some weird error when a player connecting during a restart
--- passes through this checks without the need to provide filter data.

local Ents = Ents
local TheNet, TheInput = TheNet, TheInput

----------------------------------
-- Constants
----------------------------------

local TIME_UNTIL_KICK = 10

----------------------------------
-- Declaration
----------------------------------

--- @type table<number, function>
local conn_filters = {}

--- @type table<number, function>
local async_conn_filters = {}

--- Let the cfd data be persistent.
--- @type table<string, table<any, any>>
local conn_data_cache = PEARL.GameInstParams:GetModParam("conn_data_cache") or PEARL.GameInstParams:SetModParam("conn_data_cache", {})

--- @type table<number, function>
local join_filters = {}

--- @type table<string, table>
local client_cache = {}

--- @type table<string, boolean>
local joining_clients = {}

--- @class ServerNetwork
local ServerNetwork = {}

----------------------------------
-- Local Functions
----------------------------------

local function _OnConnectionFiltersFinished(userid, allowed, reason)
    if not ServerNetwork:IsUserConnected(userid) then
        return PEARL.debug("Already disconnected... Deffering filter results...")
    end

    if allowed == false then
        return ServerNetwork:CloseConnectionFor(userid, reason)
    end

    if TheWorld then
        TheWorld:PushModEvent("ms_clientconnected", {userid = userid})
    end

    -- If all the filters have successfully passed, then the connection should be allowed.
    PEARL.debug("Allowing connection for", userid)
    return ServerNetwork:SendUserConnectionAllowedFor(userid)
end

----------------------------------
-- Public Methods
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

    PEARL.debug("ServerNetwork:SendCommandResponse<"..userid..">", message)
    if self:IsPlayerOnThisShard(userid) then
        return PEARL.SendRPCToClient(PEARL.RPC.AddToChatHistory, userid, nil, ChatTypes.CommandResponse, nil, nil, nil, message)
    end

    return PEARL.BroadcastRPCToAllShards(PEARL.RPC.AddToChatHistory, userid, nil, ChatTypes.CommandResponse, nil, nil, nil, message, ...)
end

-- Display to chosen clients or all if "userids" is nil.
function ServerNetwork:DisplayChatMessageFor(userids, name, message, name_colour, message_colour, flair, ...)
    local m_colour_dec = tonumber(message_colour)
    if type(m_colour_dec) ~= "number" then
        m_colour_dec = PEARL.PercentToDecimal(message_colour or WHITE)
    end

    local n_colour_dec = tonumber(name_colour)
    if type(n_colour_dec) ~= "number" then
        n_colour_dec = PEARL.PercentToDecimal(name_colour or WHITE)
    end

    PEARL.BroadcastRPCToAllShards(PEARL.RPC.BroadcastClientRPC, PEARL.RPC.AddToChatHistory, userids,
        m_colour_dec, 1, nil, nil, name, message, n_colour_dec, flair, ...
    )

    local vanity = { [2] = flair }
    local colour = ChatHistory:GetColourForMessage(name_colour, message_colour)
    Networking_Say(nil, "", name, nil, message, colour, false, false, vanity)
end

-- Display to all connected clients
function ServerNetwork:DisplayChatMessage(name, message, name_colour, message_colour, flair, ...)
    return self:DisplayChatMessageFor(nil, name, message, name_colour, message_colour, flair, ...)
end

function ServerNetwork:SendUserDisconnectFor(userid, reason, immediately, reason_title)
    PEARL.info("ServerNetwork:SendUserDisconnectFor", userid, reason)

    PEARL.SendRPCToClient(PEARL.RPC.Disconnect, userid, reason, immediately, reason_title)

    -- Since we are shutting down, the disconnect event
    -- wont be pushed anymore so do it now.
    if PEARL.IsShuttingDown() then
        PEARL.EventProcessor:HandleEvent("ms_clientdisconnected", userid, reason)
    end
end

-- This is a more forcefull version of SendUserDisconnectFor
function ServerNetwork:CloseConnectionFor(userid, reason, immediately, reason_title)
    self:SendUserDisconnectFor(userid, reason, immediately, reason_title)

    -- If not reason is specified and it's immediate disconnect, keep it silent.
    -- Because we can use the disconnection internally (e. g. server updates)
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

function ServerNetwork:DisconnectAllClients(reason, immediately)
    for _, client in ipairs(TheNet:GetClientTable()) do--pairs(self:GetConnectedClients()) do
        if client.userid then
            self:SendUserDisconnectFor(client.userid, reason, immediately)
        end
    end
end

--- @param userid string The Klei ID of the user you want to run filters for.
--- @param cfd table? The data proccessed by the filters.
--- @return boolean? allowed Representing whether the client is allowed
--- to join according the filters or not.
--- @return string? reason The code of the reason why the access was prohibited.
function ServerNetwork:RunConnectionFiltersFor(userid, cfd)
    cfd = cfd or self:GetCachedCFDFor(userid)

    for i = 1, #conn_filters do
        local success, allowed, reason = PEARL.SafeRun(conn_filters[i], userid, cfd)
        if success == false then
            -- Allowed should be the error message in this case.
            PEARL.error("Failed to execute a connection data filter!", allowed)
        elseif allowed == false then -- Check for explicit false
            return allowed, reason
        end
    end

    return true
end

-- Returns always nil, this one requires a finishcb function
-- where the first 2 parameters will be the allowed flag and reason string.
--- @param userid string The Klei ID of the user you want to run filters for.
--- @param cfd table? The data proccessed by the filters.
--- @param finishcb fun(userid: string, allowed: boolean?, reason: string?)
function ServerNetwork:RunAsyncConnectionFilters(userid, cfd, finishcb)
    cfd = cfd or self:GetCachedCFDFor(userid)

    local i = 0
    local handle_async_filter
    local function run_async_filter()
        i = i + 1

        PEARL.debug("Running asynchrounous connection filter at index", i)
        if PEARL.SafeRun(
            async_conn_filters[i], userid, cfd, handle_async_filter
        ) == false then
            handle_async_filter()

            -- Allowed should be the error message in this case.
            PEARL.error("Failed to execute an async connection data filter!")
        end
    end

    handle_async_filter = function(allowed, reason)
        -- If this was the last filter or the filter failed.
        if i >= #async_conn_filters or allowed == false then
            PEARL.debug("Asynchrounous connection filters finished!")

            return finishcb(userid, allowed, reason)
        end

        -- Else run the next filter.
        run_async_filter()
    end

    run_async_filter()
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

function ServerNetwork:GetConnectedClients()
    return GetPlayerClientTable()
end

function ServerNetwork:IsPlayerOnThisShard(userid)
    return LookupPlayerInstByUserID(userid) ~= nil
end

function ServerNetwork:IsClientBanned(userid)
    return PEARL.BlackList:Contains(userid)
end

function ServerNetwork:IsAgreementEnabled()
    return PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT ~= nil
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
    -- We decrement this by one because of the host client for dedicated servers.
    return #TheNet:GetClientTable() - (TheNet:IsDedicated() and 1 or 0)
end

-- Sadly, this doesn't work...
-- So currently the only way I can think of is to fetch the server lisiting
-- from the lobby servers.
-- function ServerNetwork:GetServerIP()
--     return self.listing.ip
-- end

function ServerNetwork:GetCFDCache()
    return conn_data_cache
end

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

function ServerNetwork:IsLocaleAllowed(localecode)
    return localecode and (PEARL.CONFIG.LOCALIZER.ALLOWED_LOCALES[localecode] == true or
    table.contains(PEARL.CONFIG.LOCALIZER.ALLOWED_LOCALES, localecode))
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

function ServerNetwork:IsClientPriviliged(userid)
    return self:IsAdmin(userid) or PEARL.AllowList:Contains(userid) or TheNet:GetUserID() == userid
end

----------------------------------
-- Setters
----------------------------------

--- @param filter function<userid, data>
function ServerNetwork:AddConnectionFilter(filter)
    PEARL.debug("ServerNetwork:AddConnectionFilter", filter)

    self:SetServerRequiresCFD(true)

    return table.insert(conn_filters, filter)
end

--- NOTE: Async filters ALWAYS require a response by calling the filter function!
--- @param filter function<userid, data, fun(allowed: boolean?, reason: string?)>
function ServerNetwork:AddAsyncConnectionFilter(filter)
    PEARL.debug("ServerNetwork:AddAsyncConnectionFilter", filter)

    self:SetServerRequiresCFD(true)

    return table.insert(async_conn_filters, filter)
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
        self:CloseConnectionFor(userid, "ID_DST_GAME_SESSION_AUTH_FAILED")
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
    PEARL.debug("OnClientJoined")
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

    -- Make sure the client is still connected at this point
    -- because those filter checks can be quite expensive.
    if not ServerNetwork:IsUserConnected(userid) then
        return PEARL.debug("Already disconnected... Deffering filter execution...")
    end

    -- Skip already trusted clients
    local allowed, reason
    if not self:IsClientPriviliged(userid) or PEARL.CONFIG.DEBUG_MODE then
        if allowed ~= false and conn_filters and #conn_filters > 0 then
            allowed, reason = self:RunConnectionFiltersFor(userid)
        end

        if allowed ~= false and async_conn_filters and #async_conn_filters > 0 then
            return self:RunAsyncConnectionFilters(
                userid, cfd, _OnConnectionFiltersFinished
            )
        end
    end

    _OnConnectionFiltersFinished(userid, allowed, reason)
end

function ServerNetwork:HandleRawConnectionData(userid, data, shardid)
    -- All the data is untrusted in this case.
    local data_tbl = DecodeAndUnzipString(data)
    if type(data_tbl) ~= "table" or IsTableEmpty(data_tbl) then
        return PEARL.ServerNetwork:OnInvalidRPCFromClient("ConnectionFilterData", userid)
    end

    --PEARL.debug("Received CFD from client:", DataDumper(data_tbl))

    PEARL.ServerNetwork:OnClientFilterDataReceived(userid, data_tbl)

    -- This won't be needed in the future because we will save all
    -- the important stuff in the DB.
    -- if TheShard:IsMaster() then
    --     -- Broadcast the CFD to all connected shards so they have the fresh info as well.
    --     PEARL.BroadcastRPCToShardsExcept(
    --         PEARL.RPC.ClientCFDRecevied, shardid, userid, data
    --     )
    -- elseif tostring(shardid) ~= tostring(SHARDID.MASTER) then
    --     PEARL.SendRPCToMaster(PEARL.RPC.ClientCFDRecevied, userid, data)
    -- end
end

----------------------------------
-- Debug
----------------------------------

function ServerNetwork:PrintDebugInfo()
    table.dump(conn_data_cache)
end

----------------------------------
-- Network Callbacks
----------------------------------
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
                    userid = userid, reason = reason or "ID_DST_SLOT_RESERVATION"
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
PEARL.AddGlobalFunctionPreCall("Shard_UpdateWorldState", function(world_id, state, ...)
    PEARL.EventProcessor:HandleEvent(
        state == REMOTESHARDSTATE.READY and "shard_connected" or "shard_disconnected", world_id, ...
    )

    PEARL.EventProcessor:HandleEvent("shard_stateupdate", world_id, state, ...)
end)

PEARL.EventProcessor:AddEventHandler("quit", function()
    for userid, joining in pairs(joining_clients) do
        if joining and not ServerNetwork:IsClientPriviliged(userid) then
            ServerNetwork:CloseConnectionFor(userid, "ID_DST_GAME_SESSION_AUTH_FAILED")
        end
    end
end)

-- Filter out prohibited commands recevied by the server.
PEARL.AddGlobalFunctionPreCall("Networking_SlashCmd", function(guid, userid, cmd)
    return ServerNetwork:IsAdmin(userid) or PEARL.CONFIG.COMMAND_BLOCKLIST[cmd] ~= true
end)

PEARL.AddUserDataFunctionPreCall("Ban", function(self, userid)
    if not ServerNetwork:IsClientBanned(userid) then
        PEARL.debug("User banned", userid)

        PEARL.EventProcessor:HandleEvent("clientbanned", userid)
    end
end, TheNet)

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

    world:SafeListenForEvent("ms_save", function(...)
        PEARL.EventProcessor:HandleEvent("save", ...)
    end)

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

----------------------------------
-- RPC Handlers
----------------------------------

PEARL.AddRawServerUseridRPCHandler("ClientDisconnected", function(userid, reason, force)
    if not (optstring(reason) and optbool(force)) then
        return ServerNetwork:OnInvalidRPCFromClient("ClientDisconnected", userid)
    end

    PEARL.debug("RPC: ClientDisconnected", reason, force)
    if not ServerNetwork:IsUserConnected(userid) then
        return PEARL.debug("Already disconnected...")
    end

    PEARL.EventProcessor:HandleEvent("clientconnectionclosed", userid, reason)
end)

--- @TODO: Handle secondary shards receiving this data. Redirect them to Master?
--- We need this data on the Master shard as well...
---
--- We will probably save the data from this to the DB.
PEARL.AddRawServerUseridRPCHandler("ConnectionFilterData", function(userid, data)
    if not checkstring(data) then
        return ServerNetwork:OnInvalidRPCFromClient("ConnectionFilterData", userid)
    end

    return ServerNetwork:HandleRawConnectionData(userid, data)
end)

----------------------------------
-- Return
----------------------------------

return ServerNetwork
