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

local ChatMessage = PEARL.loadfile("models/chatmessage")

----------------------------------
-- Constants
----------------------------------

local TIME_UNTIL_KICK = 10

local ASYNC_FILTER_TIMEOUT = 5
local MIN_ASYNC_FILTER_TIMEOUT = 2

-- Give a few ticks to the RPC network for the reason to deliver.
local DISCONNECT_WITH_REASON_DELAY = 5

----------------------------------
-- Netvars
----------------------------------

local _server_slots
PEARL.AddPlayerPostInit(function(inst)
    _server_slots = net_byte(inst.GUID, "_server_slots")
    _server_slots:set(TheNet:GetDefaultMaxPlayers())
end)

----------------------------------
-- Locals
----------------------------------

--- @type table<string, table>
local conn_filters = {}

--- @type table<string, table>
local async_conn_filters = {}

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
for _, client in ipairs(TheNet:GetClientTable()) do
    connected_clients[client.userid] = true
end

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

local _Kick, _Ban, _BanForTime

local function _DoBan(userid, seconds)
    seconds = tonumber(seconds)
    if seconds then
        return _BanForTime(TheNet, userid, seconds)
    end

    return _Ban(TheNet, userid)
end

local function _OnConnectionFiltersFinished(userid, allowed, reason, title)
    if not ServerNetwork:IsClientConnectedAny(userid) then
        return PEARL.debug("Already disconnected... Deffering filter results...")
    end

    if allowed == false then
        return ServerNetwork:CloseConnectionFor(userid, reason, false, title)
    end

    if TheWorld then
        TheWorld:PushModEvent("ms_clientconnected", {userid = userid})
    end

    local hasrecord
    if PEARL.DB:IsEnabled() then
        hasrecord = PEARL.DB:FirstTimeJoined(userid)
    end

    -- If all the filters have successfully passed, then the connection should be allowed.
    PEARL.debug("Allowing connection for", userid, hasrecord)
    return ServerNetwork:SendUserConnectionAllowedFor(userid, hasrecord)
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
function ServerNetwork:SendCommandResponse(userid, response)
    local message = ChatMessage(response)
    message:SetType(ChatTypes.CommandResponse)
    message:SetIsLocalOnly(true)

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

    PEARL.BroadcastRPCToClients(PEARL.RPC.DisplayChatMessage, userids, jsonstr)

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
    return PEARL.SendRPCToClient(PEARL.RPC.DisplayPopupMessage, userids, title, message)
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

    PEARL.SendRPCToClient(PEARL.RPC.Disconnect, userid, reason, immediately, reason_title)

    -- Since we are shutting down, the disconnect event
    -- wont be pushed anymore so do it now.
    if PEARL.IsShuttingDown() then
        PEARL.EventProcessor:HandleEvent("ms_clientdisconnected", userid, reason, reason_title)
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
        if not self:IsClientConnectedAny(userid) then
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

function ServerNetwork:KickUser(userid, seconds, reason, author)
    PEARL.debug("User", userid, "was kicked by", author or "[HOST]")
    PEARL.EventProcessor:HandleEvent("clientkicked", userid, reason, author, seconds)

    if type(reason) == "string" then
        -- Display the reason if any.
        self:CloseConnectionFor(
            userid, reason, false, STRINGS.UI.NETWORKDISCONNECT.TITLE["ID_DST_USER_KICKED"]
        )

        PEARL.WallScheduler:ExecuteInTime(DISCONNECT_WITH_REASON_DELAY, _Kick, nil, TheNet, userid, seconds)
        return
    end

    return _Kick(TheNet, userid, seconds)
end

function ServerNetwork:BanUser(userid, seconds, reason, author)
    if not self:IsClientBanned(userid) then
        PEARL.debug("User", userid, "was banned by", author or "[HOST]")

        PEARL.EventProcessor:HandleEvent("clientbanned", userid, reason, author, seconds)
    end

    if type(reason) == "string" then
        -- Display the reason if any.
        self:CloseConnectionFor(
            userid, reason, false, STRINGS.UI.NETWORKDISCONNECT.TITLE["ID_DST_USER_BANNED"]
        )

        PEARL.WallScheduler:ExecuteInTime(DISCONNECT_WITH_REASON_DELAY, _DoBan, nil, userid, seconds)
        return
    end

    return _DoBan(userid, seconds)
end

function ServerNetwork:SendUserConnectionAllowedFor(userid, initial)
    PEARL.debug("ServerNetwork:SendUserConnectionAllowedFor", userid, initial)
    return PEARL.SendRPCToClient(PEARL.RPC.ConnectionAllowed, userid, initial)
end

function ServerNetwork:DisconnectAllClients(reason, immediately)
    for _, client in pairs(self:GetConnectedClients()) do
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
--- @return string? title The code of the title why the access was prohibited.
function ServerNetwork:RunConnectionFiltersFor(userid, cfd)
    cfd = cfd or self:GetCachedCFDFor(userid)

    for i = 1, #conn_filters do
        local success, allowed, reason, title = PEARL.SafeRun(conn_filters[i].fn, userid, cfd)
        if success == false then
            -- Allowed should be the error message in this case.
            PEARL.error("Failed to execute a connection data filter!", allowed)
        elseif allowed == false then -- Check for explicit false
            return allowed, reason, title
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
    if not (async_conn_filters and #async_conn_filters > 0) then
        return
    end

    cfd = cfd or self:GetCachedCFDFor(userid)

    -- Starting with the first filter in the set.
    local i = 1

    local default_timeout = math.max(ASYNC_FILTER_TIMEOUT / #async_conn_filters)

    --- @type Task?
    local timeout_task
    local handle_async_filter
    local function run_async_filter(index)
        local filter = async_conn_filters[index]
        local timeout = filter.timeout or default_timeout

        if timeout_task then
            timeout_task:settime(timeout)
            timeout_task:restart()
        else -- In case the timeout task was disabled by the previous filter or something.
            timeout_task  = PEARL.WallScheduler:ExecuteInTime(timeout, function()
                if PEARL.CONFIG.DEBUG_MODE then
                    return error("Async filter timed out!")
                end

                PEARL.error("Async filter timed out! Did you forgot to call 'oncomplete'?")
                handle_async_filter(true)
            end)
        end

        PEARL.debug("Running asynchrounous connection filter at index", i)
        if PEARL.SafeRun(
            filter.fn, userid, cfd, handle_async_filter
        ) == false then
            -- If the filter throws an error, ignore it and mark it as allowing the connection.
            handle_async_filter(true)

            -- Allowed should be the error message in this case.
            PEARL.error("Failed to execute an async connection data filter!")
        end
    end

    handle_async_filter = function(allowed, reason)
        -- If this was the last filter or the filter failed.
        if i >= #async_conn_filters or allowed == false then
            PEARL.debug("Asynchrounous connection filters finished!")

            if timeout_task then
                timeout_task:cancel()
            end

            return finishcb(userid, allowed, reason)
        end

        -- Move to the next filter
        i = i + 1
        run_async_filter(i)
    end

    run_async_filter(i)
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

-- All clients connected from each shard!
function ServerNetwork:GetConnectedClients()
    return GetPlayerClientTable()
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
    return table.keys(ShardList)
end

function ServerNetwork:GetConnectedClientIDs()
    local ids = {}
    for _, client in pairs(self:GetConnectedClients()) do
        ids[#ids+1] = client.userid
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
--- @return boolean connected Whether the client is connected to any of the server's shards.
function ServerNetwork:IsClientConnectedAny(userid)
    return userid and TheNet:GetClientTableForUser(userid) ~= nil
end

--- Whether the client is connected to the current shard.
function ServerNetwork:IsClientConnected(userid)
    return userid and connected_clients[userid] == true
end

function ServerNetwork:IsShardConnected(shardid)
    for id, _ in pairs(ShardList) do
        if id == shardid then
            return true
        end
    end

    return false
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

--- True when in the lobby!
--- @Note: If better precision is required in the future, use RPCs and the enteredlobby event!
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

    ServerNetwork:SetServerRequiresCFD(true)

    table.insert(tbl, {
        fn = filter,
        priority = type(priority) == "number" and priority or math.huge,
        timeout = type(timeout) == "number" and timeout or ASYNC_FILTER_TIMEOUT,
        name = type(name) == "string" and name or nil,
    })

    -- Keep the filters sorted.
    table.sort(tbl, function(f1, f2)
        return f1.priority < f2.priority
    end)
end

--- @param filter function<userid, data>
--- @param priority string? Whether this filter should be called sooner or later.
--- @param name string? Whether this filter should be called sooner or later.
function ServerNetwork:AddConnectionFilter(filter, priority, name)
    PEARL.debug("ServerNetwork:AddConnectionFilter", filter, priority)

    -- Sync filters do not have timeouts
    AddFilter(conn_filters, filter, priority, nil, name)
end

--- NOTE: Async filters ALWAYS require a response by calling the filter function!
--- @param filter function<userid, data, fun(allowed: boolean?, reason: string?)>
--- @param priority string? Whether this filter should be called sooner or later.
--- @param timeout integer? Whether this filter should be called sooner or later.
--- @param name string? Whether this filter should be called sooner or later.
function ServerNetwork:AddAsyncConnectionFilter(filter, priority, timeout, name)
    PEARL.debug("ServerNetwork:AddAsyncConnectionFilter", filter, priority)

    AddFilter(async_conn_filters, filter, priority, timeout, name)
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
    PEARL.debug("ServerNetwork:CacheClientCFDFor", userid)
    conn_data_cache[userid] = cfd
end

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
    connected_clients[userid] = nil
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

    -- From this point we can send RPCs to the client until the disconnect event.
    connected_clients[userid] = true
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
    if not ServerNetwork:IsClientConnectedAny(userid) then
        return PEARL.debug("Already disconnected... Deffering filter execution...")
    end

    -- Skip already trusted clients
    local allowed, reason, title
    if not self:IsClientPriviliged(userid) or PEARL.CONFIG.DEBUG_MODE then
        if allowed ~= false and conn_filters and #conn_filters > 0 then
            allowed, reason, title = self:RunConnectionFiltersFor(userid)
        end

        if allowed ~= false and async_conn_filters and #async_conn_filters > 0 then
            return self:RunAsyncConnectionFilters(
                userid, cfd, _OnConnectionFiltersFinished
            )
        end
    end

    _OnConnectionFiltersFinished(userid, allowed, reason, title)
end

function ServerNetwork:HandleRawConnectionData(userid, data)
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
    table.dump(conn_data_cache)
end

----------------------------------
-- Network Callbacks
----------------------------------
-- Returning false here will cause the client to be disconnected immediately.
-- The "Slots Reserved" popup will be displayed.
-- Start the timeout here since we are sure that this is being only called when joining.
-- After this is called, the OnClientDisconnected event will ALWAYS follow.
PEARL.AddGlobalFunctionPreCall("JoinServerFilter", function(userid, ...)
    PEARL.debug("JoinServerFilter", userid, ...)

    if ServerNetwork:IsClientConnectedAny(userid) then
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

    ServerNetwork:OnClientJoining(userid)

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
    -- Returning false means the command will be skipped.
    return ServerNetwork:IsAdmin(userid) or PEARL.CONFIG.COMMAND_BLOCKLIST[cmd] ~= true
end)

_Kick = PEARL.OverrideUserdataValue("Kick", function(self, userid, seconds, reason, author)
    return ServerNetwork:KickUser(userid, seconds, reason, author)
end, TheNet)

_Ban = PEARL.OverrideUserdataValue("Ban", function(self, userid, reason, author)
    return ServerNetwork:BanUser(userid, nil, reason, author)
end, TheNet)

_BanForTime = PEARL.OverrideUserdataValue("BanForTime", function(self, userid, seconds, reason, author)
    return ServerNetwork:BanUser(userid, seconds, reason, author)
end, TheNet)

PEARL.AddUserDataFunctionPostCall("SetDefaultMaxPlayers", function(self, value)
    local slots = tonumber(TheNet:GetDefaultMaxPlayers())
    if _server_slots and slots then
        _server_slots:set(slots)
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

    local success = false
    local fn, response = loadstring(fnstr)
    if fn then
        success, response = pcall(fn)
    end

    if success == true then
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

    -- This actually runs after we enter the game world, not lobby.
    world:SafeListenForEvent("ms_playerjoined", function(self, player)
        if player and player.userid then
            ServerNetwork:OnClientJoined(player.userid)
        end
    end)

    world:SafeListenForEvent("ms_clientauthenticationcomplete", function(self, data)
        if data and data.userid then
            PEARL.debug("OnClientAuthenticationComplete", data.userid)

            ServerNetwork:OnClientAuthenticationComplete(data.userid)
        end

        PEARL.EventProcessor:HandleEvent("ms_clientauthenticationcomplete", data.userid)
    end)

    -- Called everytime even when banned but with no info.
    world:SafeListenForEvent("ms_clientdisconnected", function(self, data)
        PEARL.debug("ClientOnDisconnects", data.userid, data.expected)

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
    if not ServerNetwork:IsClientConnectedAny(userid) then
        return PEARL.debug("Already disconnected...")
    end

    PEARL.EventProcessor:HandleEvent("clientconnectionclosed", userid, reason)
end)

--- Since the players are always only on one shard,
--- we load the db record only on the active shard and unload it everywhere else.
--- This way there are no conflicts and the DB is accessible from any shard.
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
