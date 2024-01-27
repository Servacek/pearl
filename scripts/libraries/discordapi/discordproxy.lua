--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--- @type UserCommands
local UserCommands = require("usercommands")

local Command = PEARL.loadfile("libraries/discordapi/models/command")
local Option  = PEARL.loadfile("libraries/discordapi/models/option")
local Choice  = PEARL.loadfile("libraries/discordapi/models/choice")
local Library = PEARL.loadfile("models/library")

--------------------------------
-- [[ Constants ]]
--------------------------------

local BASE_URL = PEARL.CONFIG.DISCORD.PROXY.URL or ""

local MAX_RETRIES = 3

local STATE = {
    FAILED      = 0,
    STOPPED     = 1,
    RUNNING     = 2,
    CONNECTING  = 3,
}

local URL = {
    INPUT       = BASE_URL.."/input",
    OUTPUT      = BASE_URL.."/output",
    SESSION     = BASE_URL.."/session",
    MESSAGE     = BASE_URL.."/message",
    COMMANDS    = BASE_URL.."/commands",
}

local FETCH_REQUEST_TIMEOUT = 5
local RETRY_TIMEOUT         = 10

local START_SESSION_RETRIES = 3

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @singleton
--- @class DiscordProxy: Library
local DiscordProxy = {
    --- @type integer
    state = STATE.STOPPED,

    --- @type Task?
    fetch_task = nil,

    --- @type table<string, table<string, any>?>
    events = {
        player = nil,
        shard = nil,
    },
    --- @type table
    response_cache = {},

    processingtype = nil,
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

DiscordProxy.PROCESSING_TYPE = {
    MESSAGES = 1,
    COMMANDS = 2,
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

function DiscordProxy:IsProcessing(type)
    return self.processingtype == type
end

--------------------------------
-- [[ Setters ]]
--------------------------------

function DiscordProxy:SetState(state)
    if not table.contains(DiscordProxy.STATE, state) then
        return PEARL.error("Attempted to set an invalid state for discord proxy.")
    end

    if self.state ~= state then
        self.state = state

        PEARL.EventProcessor:HandleEvent("proxy_state_changed", state)
    end

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
    if not DiscordProxy:IsRunning() then
        DiscordProxy:SetState(DiscordProxy.STATE.RUNNING)
    end

    if type(data) ~= "table" then
        return
    end

    PEARL.EventProcessor:HandleEvent("proxy_fetching_done", data)
end

local function OnFetchingFailed(response, code, request)
    if DiscordProxy:IsFetching() then
        PEARL.info("Fetching failed! Stopping the fetching task...")
        DiscordProxy.fetch_task:stop()
    end

    if not request:IsRetryable() then
        return OnProxyUnreachable()
    end

    DiscordProxy:SetState(DiscordProxy.STATE.CONNECTING)
end

local function OnProxyInternalError()
    PEARL.EventProcessor:HandleEvent("proxy_server_error")

    OnFetchingFailed()
end

local function OnSessionStarted(data)
    DiscordProxy:SetState(DiscordProxy.STATE.RUNNING)

    PEARL.info("The input proxy session has successfully started!")
    PEARL.EventProcessor:HandleEvent("proxy_server_start")

    DiscordProxy:RestartFetchTask()

    if data.command_version ~= PEARL.MOD_INFO.version or PEARL.CONFIG.DEBUG_MODE then
        DiscordProxy:SyncCommands()
    end
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
        request = PEARL.HTTPClient:GET(DiscordProxy.URL.INPUT, OnInputFetchingDone, FETCH_REQUEST_TIMEOUT)
    else
        request = PEARL.HTTPClient:POST(DiscordProxy.URL.INPUT, OnInputFetchingDone, DiscordProxy.events, FETCH_REQUEST_TIMEOUT)
    end

    request
        -- We will retry again implicitly on the next cycle.
        :SetMaxRetries(MAX_RETRIES)
        :SetTimeBetweenRetries(RETRY_TIMEOUT)
        :SetOnError(OnFetchingFailed)
        :AddStatusCodeHandle(500, OnProxyInternalError)
        :AddStatusCodeHandle(204, function() end) -- Ignore empty responses
        :AddStatusCodeHandle(202, function()
            PEARL.info("Received request to restart the session from proxy server.")
            DiscordProxy:RestartSession()
        end)
        :Send()

    DiscordProxy:CleanupEvents()
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

--- @param message Message
function DiscordProxy:PostMessage(message, channelid)
    return PEARL.HTTPClient:POST(URL.MESSAGE, nil, {
        message = message:ToTable(),
        channel = channelid,
    }):SetDecodeResponse(false):Send()
end

function DiscordProxy:StartProcessingData(type)
    PEARL.debug("DiscordProxy:StartProcessingData", type)

    self.processingtype = type
end

function DiscordProxy:StopProcessing()
    PEARL.debug("DiscordProxy:StopProcessing", self.processingtype)

    self.processingtype = nil
end

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

function DiscordProxy:AddCommandResponse(commandid, message_table)
    if type(commandid) ~= "string" then
        return PEARL.error("Invalid command id provided!")
    end

    self.response_cache[commandid] = message_table
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

    PEARL.HTTPClient:POST(DiscordProxy.URL.SESSION, nil, {
        running = true,

        messages = PEARL.CONFIG.DISCORD.PROXY.CHAT_ENABLED,
        commands = PEARL.CONFIG.DISCORD.PROXY.COMMANDS_ENABLED,
        -- Keep our data in sync from the start.
        players = DiscordProxy:GetPlayerAutocompleteData(),
        shards  = DiscordProxy:GetShardAutocompleteData(),
    })
    :SetOnSuccess(OnSessionStarted)
    :SetDecodeResponse(false)
    :SetOnError(retries ~= 0 and OnSessionStartFailed or nil)
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
    :SetDecodeResponse(false)
    :SetMaxRetries(0)
    :Send()
end

function DiscordProxy:RestartSession(retries)
    if self:IsRunning() then
        PEARL.EventProcessor:HandleEvent("proxy_server_restart")
    end

    self:SetState(DiscordProxy.STATE.STOPPED)
    self:StartSession(retries)
end

function DiscordProxy:SendCachedCommandResponses()
    PEARL.info("Sending command response to server.")
    PEARL.HTTPClient:POST(DiscordProxy.URL.OUTPUT, OnProxyReceviedResponse, self.response_cache)
        :SetDecodeResponse(false)
        :SetOnError(OnProxyResponseFailed)
        :Send()

    self:CleanupResponseCache()
end

--- @param commandid string
--- @param message Message|table
function DiscordProxy:SendCommandResponse(commandid, message)
    if type(message) ~= "table" then
        return PEARL.error("Attempted to respond with an invalid message!", message)
    end

    -- if TheShard:IsSecondary() then
    --     local success, jsondata = message:ToJson()
    --     if success then
    --         -- Send the message to Master because only the Master can communicate with the server.
    --         return PEARL.SendRPCToMaster(PEARL.RPC.SendDiscordCommandResponse, jsondata)
    --     end

    --     return PEARL.error("Failed to encode the message for RPC!")
    -- end

    local message_table = message
    if message.ToTable then
        message_table = message:ToTable()
    end

    self:AddCommandResponse(commandid, message_table)

    -- If we are not processing any commands and there are some responses send them immediately.
    if not self:IsProcessing(self.PROCESSING_TYPE.COMMANDS) and self:HasAnyCommandResponses() then
        self:SendCachedCommandResponses()
    end
end

function DiscordProxy:SyncCommands()
    local sync_data = {
        commands = {},
        version  = PEARL.MOD_INFO.version,
    }
    local discord_commands = UserCommands.GetCustomCommandsWithFlag("discord", true)
    for _, command_data in pairs(discord_commands) do
        sync_data.commands[#sync_data.commands+1] = Command.FromGameAPICommand(command_data):ToTable()
    end

    table.dump(sync_data)
    -- We do not care about the response at this point
    PEARL.HTTPClient:POST(DiscordProxy.URL.COMMANDS, function()
        PEARL.info("Commands successfully synchronized!")
    end, sync_data)
        :SetDecodeResponse(false)
        :SetMaxRetries(0)
        :Send()
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
-- [[ RPCs ]]
--------------------------------

PEARL.AddShardRPCHandler("SendDiscordCommandResponse", function(shardid, commandid, msgstr)
    if shardid == SHARDID.MASTER then
        return PEARL.error("SendDiscordCommandResponse: Received from Master!")
    end

    local success, message_table = pcall(json.decode, msgstr)
    if success == true and type(message_table) == "table" then
        return DiscordProxy:SendCommandResponse(commandid, message_table)
    end

    PEARL.error("Failed to decode received JSON data!")
end)

--------------------------------
-- [[ Return ]]
--------------------------------

return DiscordProxy
