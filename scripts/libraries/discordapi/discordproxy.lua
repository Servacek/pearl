--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local Library = PEARL.loadfile("models/library.lua")

--------------------------------
-- [[ Constants ]]
--------------------------------

local BASE_URL = PEARL.CONFIG.DISCORD.PROXY.URL
if type(BASE_URL) ~= "string" then
    return error("Discord proxy is enabled but invalid url was provided!")
end

local MAX_RETRIES = 3

local STATE = {
    FAILED      = -1,
    STOPPED     = 0,
    RUNNING     = 1,
}

local URL = {
    INPUT = BASE_URL.."/input",
    OUTPUT = BASE_URL.."/output",
    SESSION = BASE_URL.."/session",
}

local FETCH_REQUEST_TIMEOUT = 5

local START_SESSION_RETRIES = 3

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @singleton
--- @class DiscordProxy
local DiscordProxy = {
    --- @type number
    state = STATE.STOPPED,
    --- @type number
    retries = 0,

    --- @type Task?
    fetch_task = nil,

    --- @type table<string, table<string, any>?>
    events = {
        player = nil,
        shard = nil,
    },
    --- @type table
    response_cache = {},
}

--- @type DiscordProxy
DiscordProxy = Library(DiscordProxy)

--------------------------------
-- [[ Static ]]
--------------------------------

DiscordProxy.STATE = STATE
DiscordProxy.URL   = URL

DiscordProxy.EVENT_CATEGORY = {
    SHARD   = "shard",
    PLAYER  = "player",
}

--------------------------------
-- [[ Getters ]]
--------------------------------

function DiscordProxy:IsFailed()
    return self.state == DiscordProxy.STATE.FAILED
end

function DiscordProxy:IsStopped()
    return self.state == DiscordProxy.STATE.STOPPED
end

function DiscordProxy:IsRunning()
    return self.state == DiscordProxy.STATE.RUNNING
end

function DiscordProxy:IsFetching()
    return self.fetch_task and self.fetch_task.running == true
end

function DiscordProxy:HasAnyCommandResponses()
    return not table.empty(self.response_cache)
end

function DiscordProxy:GetState()
    return self.state
end

function DiscordProxy:GetPlayerAutocompleteData()
    local players
    for _, client in pairs(PEARL.ServerNetwork:GetConnectedClients()) do
        if not players then
            players = {}
        end

        players[client.userid] = client.name
    end

    return players
end

function DiscordProxy:GetShardAutocompleteData()
    local shards
    for _, shardid in pairs(PEARL.ServerNetwork:GetConnectedShardIDs()) do
        if not shards then
            shards = {}
        end

        shards[shardid] = PEARL.GetShardFancyNameByID(shardid)
    end

    return shards
end

function DiscordProxy:GetAllAutocompleteData()

end

--------------------------------
-- [[ Setters ]]
--------------------------------

function DiscordProxy:SetState(state)
    if not table.contains(DiscordProxy.STATE, state) then
        return PEARL.error("Attempted to set an invalid state for discord proxy.")
    end

    self.state = state

    return self
end

--------------------------------
-- [[ Event Handlers  ]]
--------------------------------

local function OnProxyUnreachable()
    if DiscordProxy:GetState() == DiscordProxy.STATE.FAILED then
        return
    end

    DiscordProxy:SetState(DiscordProxy.STATE.FAILED)

    PEARL.EventProcessor:HandleEvent("proxy_server_unreachable")
end

local function OnInputFetchingDone(data)
    if type(data) ~= "table" then
        return
    end

    PEARL.EventProcessor:HandleEvent("proxy_fetching_done", data)
end

local function OnRetry()
    DiscordProxy.retries = DiscordProxy.retries + 1
end

--- @TODO
local function OnFetchingFailed()
    if DiscordProxy.retries >= MAX_RETRIES and DiscordProxy.fetch_task then
        PEARL.info("Stopping the fetching task...")
        DiscordProxy.fetch_task:stop()

        return OnProxyUnreachable()
    end

    OnRetry()
end

local function OnProxyInternalError()
    PEARL.EventProcessor:HandleEvent("proxy_server_error")

    OnFetchingFailed()
end

local function OnSessionStarted()
    DiscordProxy:SetState(DiscordProxy.STATE.RUNNING)

    PEARL.info("The input proxy session has successfully started!")
    PEARL.EventProcessor:HandleEvent("proxy_server_start")

    DiscordProxy:RestartFetchTask()
end

local function OnSessionStartFailed(response, status, request)
    if not request:IsRetryable() then
        PEARL.info("Failed to start the input proxy session!")
        OnProxyUnreachable()
    end
end

local function OnProxyReceviedResponse()
    PEARL.info("Proxy server has successfully received our command response.")
end

local function OnProxyResponseFailed()
    PEARL.info("Failed to send the response to the proxy server.")
end

local function OnFetchInput()
    -- Do it explicitly. Since implicit method changes are prohibited.
    local request
    if type(DiscordProxy.events) == "table" and table.empty(DiscordProxy.events) then
        request = PEARL.HTTPClient:GET(DiscordProxy.URL.INPUT, OnInputFetchingDone, nil, FETCH_REQUEST_TIMEOUT)
    else
        request = PEARL.HTTPClient:POST(DiscordProxy.URL.INPUT, OnInputFetchingDone, DiscordProxy.events, FETCH_REQUEST_TIMEOUT)
    end

    request
        :SetMaxRetries(0)
        :SetStatusCodeHandle(0, OnFetchingFailed)
        :SetStatusCodeHandle(500, OnProxyInternalError)
        :SetStatusCodeHandle(204, function() end) -- Ignore empty responses
        :SetStatusCodeHandle(202, function()
            PEARL.info("Received request to restart the session from proxy server.")
            DiscordProxy:RestartSession()
        end)
        :Send()

    DiscordProxy:CleanupEvents()
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

function DiscordProxy:CreateEvent(name, ...)
    return {
        name = name,
        args = toarrayornil(...),
    }
end

function DiscordProxy:SetEventData(category, data)
    self.events[category] = data
end

function DiscordProxy:AddPlayerEvent(name, ...)
    self:SetEventData(self.EVENT_CATEGORY.PLAYER, self:CreateEvent(name, ...))
end

function DiscordProxy:AddShardEvent(name, ...)
    self:SetEventData(self.EVENT_CATEGORY.SHARD, self:CreateEvent(name, ...))
end

function DiscordProxy:AddCommandResponse(command_id, message_table)
    self.response_cache[command_id] = message_table
end

function DiscordProxy:CleanupEvents()
    cleartable(self.events)
end

function DiscordProxy:CleanupResponseCache()
    cleartable(self.response_cache)
end

function DiscordProxy:StartSession(retries)
    if self:IsRunning() then
        PEARL.error("Discord proxy session already running!")
        return
    end

    PEARL.info("Sending start session request to input proxy server...")

    PEARL.HTTPClient:POST(DiscordProxy.URL.SESSION, OnSessionStarted, {
        running = true,

        messages = PEARL.CONFIG.DISCORD.PROXY.CHAT_ENABLED,
        commands = PEARL.CONFIG.DISCORD.PROXY.COMMANDS_ENABLED,
        -- Keep our data in sync from the start.
        players = DiscordProxy:GetPlayerAutocompleteData(),
        shards  = DiscordProxy:GetShardAutocompleteData(),
    })
    :SetIsRaw(true)
    :SetOnError(OnSessionStartFailed)
    :SetMaxRetries(retries or START_SESSION_RETRIES)
    :Send()
end

function DiscordProxy:StopSession()
    if not self:IsRunning() then
        PEARL.error("Attempted to stop a non-running discord proxy session!")
        return
    end

    PEARL.info("Sending stop session request to input proxy server...")
    PEARL.EventProcessor:HandleEvent("proxy_server_stop")

    -- We do not care about the response at this point
    PEARL.HTTPClient:POST(DiscordProxy.URL.SESSION, nil, {
        running = false
    })
    :SetIsRaw(true)
    :SetMaxRetries(0)
    :Send()
end

function DiscordProxy:RestartSession(retries)
    if self:IsRunning() then
        PEARL.EventProcessor:HandleEvent("proxy_server_restart")
    end

    self:StartSession(retries)
end

function DiscordProxy:SendCachedCommandResponses()
    PEARL.info("Sending command response to server.")
    PEARL.HTTPClient:POST(DiscordProxy.URL.OUTPUT, OnProxyReceviedResponse, self.response_cache)
        :SetIsRaw(true)
        :SetOnError(OnProxyResponseFailed)
        :Send()

    self:CleanupResponseCache()
end

function DiscordProxy:StopFetchTask()
    if self.fetch_task then
        self.fetch_task:cancel()
        self.fetch_task = nil
    end
end

function DiscordProxy:RestartFetchTask()
    local period = PEARL.CONFIG.DISCORD.PROXY.SYNC_INTERVAL

    if self.fetch_task then
        PEARL.info("Restarting the fetching task...")

        -- Ensure we use the default interval in case it was changed before by some commands.
        self.fetch_task:settime(period)
        self.fetch_task:restart()
        return
    end

    PEARL.info("Starting the fetching task...")
    self.fetch_task = PEARL.WallScheduler:ExecutePeriodic(
        period, OnFetchInput, nil, nil, PEARL.CONSTS.TASK_ID.INPUTPROXY_FETCH, self
    )
end

--------------------------------
-- [[ Return ]]
--------------------------------

return DiscordProxy
