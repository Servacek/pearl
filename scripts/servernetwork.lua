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
    Mod server-side network.

    This is like an higher level 'TheNet' for dedicated servers.
--]]

local ItemDepositor = PEARL.loadfile("libs/itemdepositor")
local ChatMessage = PEARL.loadfile("models/chatmessage")

----------------------------------
-- Constants
----------------------------------

local CLOSE_CONNECTION_FINALIZE_AFTER = 5

local ASYNC_FILTER_TIMEOUT = 2
local MIN_ASYNC_FILTER_TIMEOUT = 2

-- Give a few ticks to the RPC network for the reason to deliver.
local DISCONNECT_WITH_REASON_DELAY = 5

local DEFAULT_RPC_TIMEOUT = 5

----------------------------------
-- Netvars
----------------------------------

local _server_slots
PEARL.AddWorldNetworkPostInit(function(inst)
    if _server_slots == nil then
        _server_slots = net_byte(inst.GUID, "_server_slots")
        _server_slots:set(TheNet:GetDefaultMaxPlayers())
    end
end)

----------------------------------
-- Locals
----------------------------------

--- @type table<string, table>
local conn_filters = {}

--- @type table<string, table>
local async_conn_filters = {}

--- @type table<string, table>
local acknowledgment_data = {}

--- Let the cfd data be persistent.
--- @type table<string, table<any, any>>
local conn_data_cache = PEARL.GameInstParams:GetModParam("conn_data_cache") or {}
--- Prefer to use the database if possible cuz we do not know the limits of this.
if not PEARL.CONFIG.DATABASE.ENABLED then
    PEARL.GameInstParams:SetModParam("conn_data_cache", conn_data_cache)
end

--- @type table<string, function>
local join_filters = {}

--- @type table<string, table>
local client_cache = {}

--- @type table<string, boolean>
local joining_clients = {}

--- Clients can send RPCs to from this shard.
--- <AUTHENTICATION, DISCONNECT>
--- @type table<string, boolean>
local connected_clients = {}
--- @NOTE: Potential bug when restarting the server with players in caves.
--- @NOTE: "TheNet:GetClientTable()" can return nil when we are not connected!
for _, client in ipairs(GetPlayerClientTable() or {}) do
    connected_clients[client.userid] = true
end

local lua_command_id = 0

----------------------------------
-- Class Declaration
----------------------------------

--- @class ServerNetwork
local ServerNetwork = {
    FILTER_PRIORITY = {
        HIGH    = 10,
        MEDIUM  = 5,
        LOW     = 1,
    }
}

----------------------------------
-- Local Functions
----------------------------------

local function _OnConnectionFiltersFinished(userid, allowed, reason, title)
    PEARL.debug("Async filters finished with result", allowed, "reason", reason)

    if not ServerNetwork:IsClientConnectedAny(userid) then
        return PEARL.debug("Already disconnected... Deffering filter results...")
    end

    if allowed == false then
        return ServerNetwork:CloseConnectionFor(userid, reason, false, title)
    end

    -- If all the filters have successfully passed, then the connection should be allowed.
    PEARL.debug("Allowing connection for", userid)
    local data = {
        first_time_joined = PEARL.DB:IsEnabled() and PEARL.DB:FirstTimeJoined(userid) or false,
        new_session_file = not PEARL.ServerNetwork:UserSessionExists(userid),
        last_unexpected_disconnection = PEARL.DB:IsEnabled() and PEARL.DB:GetField(userid, "last_unexpected_disconnection"),
        last_joined_time = PEARL.DB:IsEnabled() and PEARL.DB:GetField(userid, "lastjoinedtime")
    }
    ServerNetwork:SendUserConnectionAllowedFor(userid, data)
end

local function filter_comp(a, b)
    return a.priority > b.priority
end

----------------------------------
-- Public Methods
----------------------------------

--- Sends the given lua string to the specified shard, if connected.
--- If a callback is provided, it will wait for the response of the command
--- and call the callback function when the response is received or it timeouts.
--- @param shardid string
--- @param lua_str string
--- @param cb fun(success: boolean, ...: any)
--- @param timeout integer The time to wait for the response until timeout.
function ServerNetwork:SendLuaToShard(shardid, lua_str, cb, timeout)
    -- if not ServerNetwork:IsShardConnected(shardid) then
    --     return PEARL.error("Shard", shardid, "is not connected!")
    -- end

    local id
    if type(cb) == "function" then
        -- Make sure we always receive some response.
        local timeout_task
        local respond = false
        timeout = timeout or DEFAULT_RPC_TIMEOUT
        timeout_task = PEARL.WallScheduler:ExecuteInTime(timeout, function()
            if respond == false then
                cb(false)
            end

            if timeout_task ~= nil then
                timeout_task:cancel()
                timeout_task = nil
            end
        end)

        lua_command_id = lua_command_id + 1
        id = lua_command_id

        local eventname = "shardresponse_"..tostring(id)
        PEARL.EventProcessor:AddSafeOneTimeHandler(eventname, function(success, response)
            cb(success, PEARL.unpack(response))
        end)
    end

    PEARL.SendRPCToShard(PEARL.RPC.BroadcastLua, shardid, lua_str, id)
end

-- Called from server-side user command handlers.
-- Sends a RPC to the client with the given userid.
-- Note: This works only if the player is connected to the local shard.
function ServerNetwork:SendCommandResponse(userid, response, colour)
    local message = ChatMessage(response)
    message:SetType(ChatTypes.CommandResponse)
    message:SetIsLocalOnly(true)
    message:SetColour(colour)

    self:DisplayChatMessageFor(userid, message)
end

-- Display to chosen client(s) or all if "userids" is nil.
--- @param userids table|string? The optional list of userids or userid of the receiver(s)
--- @param message ChatMessage The message to be displayed.
function ServerNetwork:DisplayChatMessageFor(userids, message)
    local jsonstr, data = message:ToJson()
    if type(jsonstr) ~= "string" then
        return PEARL.error("Failed to encode message data to JSON format!")
    end

    if PEARL.IsRPCSenderListValid(userids) then
        PEARL.BroadcastRPCToClientsGlobal(
            PEARL.RPC.DisplayChatMessage, userids, jsonstr
        )
    end

    -- Make sure the message is archived on the server as well.
    -- Direct messages are not being archived on the server just locally by the client.
    ChatHistory:AddChatMessage(data)
end

--- Display a message to all connected clients.
--- @param message ChatMessage The message to be displayed
function ServerNetwork:DisplayChatMessage(message)
    return self:DisplayChatMessageFor(nil, message)
end

function ServerNetwork:DisplayPopupFor(userids, title, message)
    return PEARL.SendRPCToClientGlobal(PEARL.RPC.DisplayPopupMessage, userids, title, message)
end

--- @param userids table|string? The optional list of userids or userid of the receiver(s)
--- @param content string
--- @param announce_type string?
--- @param colour table<int, int, int, int>?
function ServerNetwork:AnnounceFor(userids, content, announce_type, colour)
    local message = ChatMessage(content)
    message:SetType(ChatTypes.Announcement)
    message:SetIcon(announce_type)
    message:SetColour(colour)

    return self:DisplayChatMessageFor(userids, message)
end

function ServerNetwork:SendUserDisconnectFor(userid, reason, immediately, reason_title)
    PEARL.info("ServerNetwork:SendUserDisconnectFor", userid, reason)

    if not self:IsClientConnectedAny(userid) then
        return PEARL.error("Attempted to disconnect a not connected client!")
    end

    PEARL.SendRPCToClientGlobal(PEARL.RPC.Disconnect, userid, reason, immediately, reason_title)

    -- Since we are shutting down, the disconnect event
    -- wont be pushed anymore so do it now.
    if PEARL.IsShuttingDown() then
        PEARL.EventProcessor:HandleEvent("ms_clientdisconnected", userid, true, reason, reason_title)
    end
end

-- This is a more forcefull version of SendUserDisconnectFor
function ServerNetwork:CloseConnectionFor(userid, reason, immediately, reason_title, finalizerfn)
    self:SendUserDisconnectFor(userid, reason, immediately, reason_title)

    -- If no reason is specified and it's immediate disconnect, keep it silent.
    -- Because we can use the disconnection internally (e. g. server updates)
    PEARL.EventProcessor:HandleEvent("clientconnectionclosed", userid, reason)

    -- Give a few seconds to the client so he can peacefully disconnect.
    PEARL.WallScheduler:ExecuteInTime(CLOSE_CONNECTION_FINALIZE_AFTER, function()
        if type(finalizerfn) == "function" then
            finalizerfn(userid, reason, immediately, reason_title)
        elseif self:IsClientConnectedAny(userid) then
            -- Cleanup the connection in case it still hangs out here (doesn't work for admins).
            PEARL.debug("Cleaning up the connection...")
            TheNet:Kick(userid, PEARL.CONSTS.DISCONNECT_KICK_TIME)
        end
    end)
end

--- @param userid string
--- @param data table? Whether this is the first connection according to the DB.
function ServerNetwork:SendUserConnectionAllowedFor(userid, data)
    PEARL.debug("ServerNetwork:SendUserConnectionAllowedFor", userid)

    acknowledgment_data[userid] = data
    PEARL.EventProcessor:HandleEvent("clientconnectionallowed", userid, data)
    PEARL.SendRPCToClient(PEARL.RPC.ConnectionAllowed, userid, json.encode(data))
end

function ServerNetwork:IsClientFirstTimeOnServer(userid)
    return acknowledgment_data[userid] and acknowledgment_data[userid].first_time_joined == true
end

function ServerNetwork:DisconnectAllClients(reason, immediately)
    for _, client in pairs(self:GetConnectedClients()) do
        if client.userid then
            self:SendUserDisconnectFor(client.userid, reason, immediately)
        end
    end
end

--- @param userid string The Klei ID of the user you want to run filters for.
--- @param filters table The filters to execute for the given user.
--- @param cfd table The data proccessed by the filters.
--- @return boolean allowed Representing whether the client is allowed to join.
--- @return string? reason The code of the reason why the access was prohibited.
--- @return string? title The code of the title why the access was prohibited.
function ServerNetwork:RunConnectionFiltersFor(userid, filters, cfd)
    for i = 1, #filters do
        local success, allowed, reason, title = PEARL.SafeRun(conn_filters[i].fn, userid, cfd)
        if success == false then
            -- Allowed should be the error message in this case.
            PEARL.error("Failed to execute a connection data filter!", allowed)
        elseif allowed == false then -- Check for explicit false
            return allowed == true, reason, title
        end
    end

    return true
end

--- Using the paralel aproach for efficiency, since we are storing most of the filter data anyway.
--- @param userid string The Klei ID of the user you want to run filters for.
--- @param filters table The async filters to execute for the given user.
--- @param finishcb fun(userid: string, allowed: boolean?, reason: string?)
function ServerNetwork:RunAsyncConnectionFilters(userid, filters, finishcb)
    local finished, canceled          = false, false
    local count_finished, count_total = 0, #filters

    local function handle_filter(allowed, reason)
        if finished then
            return -- Ignore responses after we are done with the filters.
        end

        count_finished = count_finished + 1
        if count_finished >= count_total or canceled or allowed == false then
            PEARL.debug("Asynchrounous connection filters finished!", reason)
            finished = true

            return finishcb(userid, allowed == true, reason)
        end
    end

    for _, filter in ipairs(filters) do
        if PEARL.SafeRun(filter.fn, userid, handle_filter) == false then
            PEARL.error("Failed to execute an async connection data filter!")
            handle_filter(true)
        end
    end

    -- Give each filter some time to execute
    local timeout = math.max(ASYNC_FILTER_TIMEOUT * count_total, MIN_ASYNC_FILTER_TIMEOUT)
    PEARL.WallScheduler:ExecuteInTime(timeout, function()
        if finished then
            return
        end

        canceled = true
        PEARL.error("Async filters timed out! Did you forgot to call 'oncomplete'?")
        handle_filter(true)
    end)
end

--- @param userid string
--- @return boolean passed
function ServerNetwork:RunJoinServerFiltersFor(userid)
    for _, filter in ipairs(join_filters) do
        local success, allowed, reason = PEARL.SafeRun(filter, userid)
        if success == false then
            -- Allowed should be the error message in this case.
            PEARL.error("Failed to execute a join server filter!", allowed)
        end

        if allowed == false then -- Check for explicit false
            PEARL.EventProcessor:HandleEvent("clientconnectionclosed", userid, reason)

            return false
        end
    end

    return true
end

----------------------------------
-- Getters
----------------------------------

--- @return table<string, table<any, any>>
function ServerNetwork:GetCFDCache()
    return conn_data_cache
end

function ServerNetwork:GetCachedCFDFor(userid)
    return conn_data_cache[userid]
end

function ServerNetwork:GetCachedClientTableFor(userid)
    return client_cache[userid]
end

-- All clients connected from each shard!
--- @return table<integer, table> player_array
function ServerNetwork:GetConnectedClients()
    return GetPlayerClientTable()
end

function ServerNetwork:IsClientBanned(userid)
    return PEARL.BlackList:Contains(userid)
end

function ServerNetwork:IsAnySecondaryShardConnected()
    return table.empty(ShardList) == false
end

--- @return table<integer, string>
function ServerNetwork:GetConnectedShardIDs()
    return table.keys(ShardList)
end

--- @return table<integer, table>
function ServerNetwork:GetConnectedClientIDs()
    local ids = {}
    for _, client in pairs(self:GetConnectedClients()) do
        ids[#ids+1] = client.userid
    end

    return ids
end

--- @return table<string, boolean>
function ServerNetwork:GetLocalClientIDs()
    return connected_clients
end

--- So far, this is the most reliable approach to get ALL connected clients on the server.
--- This should output the same number on each connected shard.
function ServerNetwork:GetConnectedClientsCount()
    -- Looks like TheNet:GetPlayerCount() counts only the local shard players.
    -- We decrement this by one because of the host client for dedicated servers.
    return #(TheNet:GetClientTable() or {}) - (TheNet:IsDedicated() and 1 or 0)
end

function ServerNetwork:GetConnectingClientIDs()
    return joining_clients
end

function ServerNetwork:GetHostTable()
    -- For dedicated servers the first index is reserved for the "host" machine.
    return (TheNet:GetClientTable() or {})[1]
end

function ServerNetwork:GetUserFlags(userid)
    local client = userid and TheNet:GetClientTableForUser(userid)
    return client and client.userflags or 0
end

function ServerNetwork:HasUserAnyFlags(userid)
    return self:GetUserFlags(userid) ~= 0
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
--- @return boolean connected Whether the client is connected to any of the server's shards.
function ServerNetwork:IsClientConnectedAny(userid)
    return userid and TheNet:GetClientTableForUser(userid) ~= nil
end

--- @param id string Klei ID of the account.
--- @return boolean known Whether the Klei ID was seen on the server before.
--- We are using all the available information for determining that. For greater precision
--- of this function turn on the DB!
function ServerNetwork:IsKleiIDKnown(id)
    return self:IsClientConnectedAny(id) or
        self:UserSessionExists(id) or
        PEARL.DB:HasRecordFile(id)
end

--- Whether the client is connected to the current shard.
function ServerNetwork:IsClientConnected(userid)
    return connected_clients[userid] == true
end

function ServerNetwork:IsShardConnected(shardid)
    for id, _ in pairs(ShardList) do
        if id == shardid then
            return true
        end
    end

    return false
end

function ServerNetwork:IsShardEmpty()
    -- Just to be extra safe.
    return type(AllPlayers) ~= "table" or table.empty(AllPlayers) == true
end

function ServerNetwork:IsClientInactive(userid)
    return userid and self:HasUserFlag(userid, USERFLAGS.IS_AFK)
end

function ServerNetwork:IsClientGhost(userid)
    return userid and self:HasUserFlag(userid, USERFLAGS.IS_GHOST)
end

function ServerNetwork:IsClientLoading(userid)
    return userid and self:HasUserFlag(userid, USERFLAGS.IS_LOADING)
end

function ServerNetwork:IsClientInLobby(userid)
    local client = userid and TheNet:GetClientTableForUser(userid)
    return client and self:IsClientLoading(userid) == false and
        client.prefab == "" and not self:HasClientActiveInstance(userid)
end

-- Migration doesn't count here.
-- True only from the JoinServerFilter/clientauthenticationcomplete -> ms_playerjoined
function ServerNetwork:IsClientJoining(userid)
    local client = userid and TheNet:GetClientTableForUser(userid)
    return joining_clients[userid] == true and self:IsClientLoading(userid) and
        -- Ensures this is true only on initial join.
        client and client.prefab == "" and client.lobbycharacter == ""
end

function ServerNetwork:IsAdmin(userid)
    local client = userid and TheNet:GetClientTableForUser(userid)
    return client and client.admin == true or PEARL.AdminList:Contains(userid) or TheNet:GetUserID() == userid
end

function ServerNetwork:IsClientPriviliged(userid)
    return self:IsAdmin(userid) or PEARL.AllowList:Contains(userid) or TheNet:GetUserID() == userid
end

function ServerNetwork:HasClientActiveInstance(userid)
    return LookupPlayerInstByUserID(userid) ~= nil
end

function ServerNetwork:GetClientInstance(userid, active_only)
    local inst = LookupPlayerInstByUserID(userid)
    if active_only == true or inst ~= nil then
        return inst
    end

    local meta = PEARL.GetPlayerMetadataFor(userid, true)
    return meta and meta:GetInstance() or nil
end

--- Debugging puposes.

function ServerNetwork:GetFilterByName(name, async)
    local t = async == true and async_conn_filters or conn_filters

    for _, filter in ipairs(t) do
        if filter.name and filter.name == name then
            return filter
        end
    end
end

----------------------------------
-- Setters
----------------------------------

local function AddFilter(tbl, filter, priority, timeout, name)
    if type(filter) ~= "function" then
        error("Invalid filter function")
    end

    -- Keep the filters sorted. (filters with higher priority will be higher)
    table.insort(tbl, {
        fn = filter,
        priority = type(priority) == "number" and priority or 0,
        timeout = type(timeout) == "number" and timeout or ASYNC_FILTER_TIMEOUT,
        name = type(name) == "string" and name or nil,
    }, filter_comp)
end

--- @param filter function<userid, data>
--- @param priority number? Whether this filter should be called sooner or later.
--- @param name string? Whether this filter should be called sooner or later.
function ServerNetwork:AddConnectionFilter(filter, priority, name)
    PEARL.debug("ServerNetwork:AddConnectionFilter", filter, priority)

    -- Sync filters do not have timeouts
    AddFilter(conn_filters, filter, priority, nil, name)
end

--- NOTE: Async filters ALWAYS require a response by calling the filter function!
--- @param filter function<userid, fun(allowed: boolean?, reason: string?)>
--- @param priority number? Whether this filter should be called sooner or later.
--- @param timeout integer? Whether this filter should be called sooner or later.
--- @param name string? Whether this filter should be called sooner or later.
function ServerNetwork:AddAsyncConnectionFilter(filter, priority, timeout, name)
    PEARL.debug("ServerNetwork:AddAsyncConnectionFilter", filter, priority)

    AddFilter(async_conn_filters, filter, priority, timeout, name)
end

function ServerNetwork:AddJoinServerFilter(filter)
    if TheShard:IsSecondary() then
        return -- JoinServerFilter is not being called on secondary shards.
    end

    PEARL.debug("ServerNetwork:AddJoinServerFilter", filter)

    return table.insert(join_filters, filter)
end

--- @param slots integer
function ServerNetwork:SetClientSlots(slots)
    if _server_slots then
        _server_slots:set(slots)
    end
end

function ServerNetwork:CacheClientTableFor(userid)
    if type(userid) == "string" then
        client_cache[userid] = TheNet:GetClientTableForUser(userid)
    end

    return client_cache[userid]
end

function ServerNetwork:CacheClientCFDFor(userid, cfd)
    PEARL.debug("ServerNetwork:CacheClientCFDFor", userid)
    conn_data_cache[userid] = cfd
end

----------------------------------
-- Handlers
----------------------------------

function ServerNetwork:OnQuit()
    -- Disconnect clients that have not yet sent their filter data.
    for userid, joining in pairs(self:GetConnectingClientIDs()) do
        if joining and not self:IsClientPriviliged(userid) then
            self:CloseConnectionFor(userid, "ID_DST_GAME_SESSION_AUTH_FAILED")
        end
    end
end

function ServerNetwork:OnClientFilterDataTimedout(userid)
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

function ServerNetwork:OnClientDisconnectedLocally(userid)
    PEARL.debug("OnClientDisconnectedLocally")

    joining_clients[userid] = nil
    connected_clients[userid] = nil
end

function ServerNetwork:OnClientJoined(userid)
    PEARL.debug("OnClientJoined")
    self:CacheClientTableFor(userid)

    if self:IsClientJoining(userid) and self:GetCachedCFDFor(userid) == nil then
        self:OnClientFilterDataTimedout(userid)
    end

    joining_clients[userid] = nil

    PEARL.EventProcessor:HandleEvent("playerjoinedgame", userid)
end

function ServerNetwork:OnClientJoining(userid)
    joining_clients[userid] = true
end

function ServerNetwork:OnClientAuthenticationComplete(userid)
    -- Keep the newest data cached.
    self:CacheClientTableFor(userid)

    -- From this point we can send RPCs to the client until the disconnect event.
    connected_clients[userid] = true

    -- This event occurrs also only when joining the shard.
    -- Ensure this is true in case it isn't
    if joining_clients[userid] ~= true then
        self:OnClientJoining(userid)
    end
end

function ServerNetwork:OnClientFilterDataReceived(userid, cfd)
    PEARL.debug("ServerNetwork:OnClientFilterDataReceived")
    --PEARL.debug(DataDumper(cfd))

    -- Always keep just the newest record
    -- This is here just to make sure the data are being cached in case the RCP fails.
    self:CacheClientCFDFor(userid, cfd)

    -- This is being called just for some logging and stuff, to actually
    -- control the connection use the connection filters.
    PEARL.EventProcessor:HandleEvent("clientdatareceived", userid, cfd)

    -- Make sure the client is still connected at this point
    -- because those filter checks can be quite expensive.
    if not self:IsClientConnectedAny(userid) then
        return PEARL.debug("Already disconnected... Deffering filter execution...")
    end

    if not self:IsClientJoining(userid) then
        return PEARL.debug("Not joining..")
    end

    -- Skip already trusted clients
    local allowed, reason, title = true, nil, nil
    local run_filters = not self:IsClientPriviliged(userid) or PEARL.CONFIG.DEBUG_MODE
    if run_filters and allowed ~= false and table.empty(conn_filters) == false then
        allowed, reason, title = self:RunConnectionFiltersFor(userid, conn_filters, cfd)
    end

    -- Privilidged clients ignore filters that means they have passed them automatically.
    PEARL.EventProcessor:HandleEvent("synchronousfiltersdone", userid, allowed, cfd)

    if run_filters and allowed ~= false and table.empty(async_conn_filters) == false then
        return self:RunAsyncConnectionFilters(
            userid, async_conn_filters, _OnConnectionFiltersFinished
        )
    end

    _OnConnectionFiltersFinished(userid, allowed, reason, title)
end

function ServerNetwork:OnRawConnectionData(userid, data)
    -- All the data is untrusted in this case.
    local data_tbl = DecodeAndUnzipString(data)
    if type(data_tbl) ~= "table" or IsTableEmpty(data_tbl) then
        return self:OnInvalidRPCFromClient("ConnectionFilterData", userid)
    end

    self:OnClientFilterDataReceived(userid, data_tbl)
end

----------------------------------
-- Debug
----------------------------------

function ServerNetwork:PrintDebugInfo()
    table.dump(connected_clients)
    table.dump(joining_clients)
end

----------------------------------
-- Return
----------------------------------

return ServerNetwork
