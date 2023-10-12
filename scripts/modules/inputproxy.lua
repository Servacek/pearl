--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local UserCommands = require("usercommands")

local Message = PEARL.loadfile("libraries/discordapi/models/message")
local Embed = PEARL.loadfile("libraries/discordapi/models/embed")

local ChatMessage = PEARL.loadfile("models/chatmessage")

local Colour = PEARL.loadfile("libraries/colour")

----------------------------------
-- Constants
----------------------------------

local BASE_URL = PEARL.CONFIG.DISCORD.PROXY.URL
if type(BASE_URL) ~= "string" then
    return error("Discord proxy is enabled but invalid url was provided!")
end

local URLS = {
    INPUT = BASE_URL.."/input",
    OUTPUT = BASE_URL.."/output",
    SESSION = BASE_URL.."/session",
}

local FETCH_REQUEST_TIMEOUT = 5

local MAX_FAILED_ATTEMPTS = 5

local MESSAGE_NAME = "%s"
local MESSAGE_NAME_ADMIN = "[ADMIN] %s"

local PMESSAGE_COLOR = Colour.FromRGBA(173, 216, 230)

local START_SESSION_RETRIES = 3

----------------------------------
-- Local Variables
----------------------------------

local _failed_attempts = 0

--- @type Task?
local _fetching_task = nil

local _proxy_unreachable = false
local _running = false

local _response_cache = {}

local events = {
    player = nil,
    shard = nil,
}

----------------------------------
-- Declarations
----------------------------------

local RestartFetchingTask, SendCachedCommandResponses, AddCommandResponse

----------------------------------
-- Query Handlers
----------------------------------

local function HandleCommand(command)
    PEARL.info("Executing discord command", command.name.."...")

    local success, response = PEARL.SafeRun(
        UserCommands.RunDiscordCommand, command.name, command.params or {}, command.caller
    )

    local waiting_for_response = command.id ~= nil
    if success == false then
        PEARL.error("Command execution failed!")

        if waiting_for_response then
            return AddCommandResponse(command.id, Message(
                PEARL.ICONS.X.." "..STRINGS.PEARL.LOGS.PROXY_COMMAND_FAILED
            ):ToTable())
        end

        return PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_COMMAND_FAILED_N:format(command.name or "UNKNOWN"))
    end

    -- If command ID is provided, the command expects a response.
    if waiting_for_response then
        if type(response) == "string" then
            response = Message(response)
        end

        if type(response) ~= "table" then
            -- No response is fine, let the bot handle this case.
            return --PEARL.error("Invalid response provided for command that is waiting for it!")
        end

        if Embed.is_instance(response) then
            response = Message():AddEmbed(response)
        elseif Embed.is_instance(response[1]) then
            response = Message():AddEmbeds(response)
        end

        AddCommandResponse(
            command.id, Message.is_instance(response) and response:ToTable() or response
        )

    elseif type(response) == "string" then
        PEARL.DiscordLogger:LogString(response)
    end
end

local function HandleCommands(commands)
    for _, command in ipairs(commands) do
        table.dump(command)
        HandleCommand(command)
    end

    if not table.empty(_response_cache) then
        SendCachedCommandResponses()
    end
end

local function HandleChatMessages(messages)
    for _, data in ipairs(messages) do
        local a_colour
        local a_name = (data.admin == true and MESSAGE_NAME_ADMIN or MESSAGE_NAME):format(data.author)

        -- Make sure it's actually an decimal we have received and not something else...
        data.author_colour = tonumber(data.author_colour)
        if type(data.author_colour) == "number" then
            a_colour = Colour.FromDecimal(data.author_colour)
        end

        --- @type ChatMessage
        local message = ChatMessage(data.content)
        message:SetAuthor(a_name, a_colour)
        message:SetColour(PMESSAGE_COLOR)
        message:SetIcon(PEARL.CONSTS.PROFILE_FLAIRS.DISCORD)

        PEARL.ServerNetwork:DisplayChatMessage(message)
    end
end

local function HandleEvents(events)
    for _, event in ipairs(events) do
        PEARL.EventProcessor:HandleEvent("input_proxy_event", event)
    end
end

local function OnProxyUnreachable()
    _running = false

    if not _proxy_unreachable then
        _proxy_unreachable = true

        PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_UNREACH)
        PEARL.DiscordReporter:SendRawReportString(STRINGS.PEARL.LOGS.PROXY_SERVER_UNREACH)
    end
end

local function OnInputFetchingDone(data)
    if type(data) ~= "table" then
        return
    end

    if PEARL.CONFIG.DISCORD.PROXY.CHAT_ENABLED and type(data.messages) == "table" then
        if PEARL.SafeRun(HandleChatMessages, data.messages) == false then
            PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_MESSAGE_FAILED)
        end
    end

    if PEARL.CONFIG.DISCORD.PROXY.COMMANDS_ENABLED and type(data.commands) == "table" then
        -- Commands are actually waiting for our response.
        HandleCommands(data.commands)
    end

    if type(data.events) == "table" then
        HandleEvents(data.events)
    end
end

local function OnFetchingFailed()
    if _failed_attempts >= MAX_FAILED_ATTEMPTS and _fetching_task then
        PEARL.info("Stopping the fetching task...")
        _fetching_task:stop()

        OnProxyUnreachable()
    end

    _failed_attempts = _failed_attempts + 1
end

local function OnProxyInternalError()
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_ERROR)
    OnFetchingFailed()
end

local function OnSessionStarted()
    _running = true
    _proxy_unreachable = false

    PEARL.info("The input proxy session has successfully started!")
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_STARTED)

    RestartFetchingTask()
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

----------------------------------
-- Local Functions
----------------------------------

local function CreateFetchEvent(name, ...)
    return {
        name = name,
        args = toarrayornil(...),
    }
end

local function GetPlayerAutocompleteData()
    local players
    for _, client in pairs(PEARL.ServerNetwork:GetConnectedClients()) do
        if not players then
            players = {}
        end

        players[client.userid] = client.name
    end

    return players
end

local function GetShardAutocompleteData()
    local shards
    for _, shardid in pairs(PEARL.ServerNetwork:GetConnectedShardIDs()) do
        if not shards then
            shards = {}
        end

        shards[shardid] = PEARL.GetShardFancyNameByID(shardid)
    end

    return shards
end

AddCommandResponse = function(command_id, message_table)
    if _response_cache[command_id] ~= nil then
        PEARL.error("Response already exists for this command!")
        return
    end

    _response_cache[command_id] = message_table
end

SendCachedCommandResponses = function()
    PEARL.info("Sending command response to server.")
    PEARL.HTTPClient:POST(URLS.OUTPUT, OnProxyReceviedResponse, _response_cache)
        :SetIsRaw(true)
        :SetOnError(OnProxyResponseFailed)
        :Send()

    cleartable(_response_cache)
end

local function StartSession(retries)
    PEARL.info("Sending start session request to input proxy server...")

    PEARL.HTTPClient:POST(URLS.SESSION, OnSessionStarted, {
        messages = PEARL.CONFIG.DISCORD.PROXY.CHAT_ENABLED,
        commands = PEARL.CONFIG.DISCORD.PROXY.COMMANDS_ENABLED,
        players = GetPlayerAutocompleteData(),
        shards  = GetShardAutocompleteData(),
        running = true,
    })
    :SetIsRaw(true)
    :SetOnError(OnSessionStartFailed)
    :SetMaxRetries(retries or START_SESSION_RETRIES)
    :Send()
end

local function RestartSession(retries)
    if _running and not _proxy_unreachable then
        PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_RESTARTED)
    end

    StartSession(retries)
end

local function StopSession()
    if not _running or _proxy_unreachable then
        return
    end

    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_STOPPED)
    PEARL.info("Sending stop session request to input proxy server...")

    -- We do not care about the response at this point
    PEARL.HTTPClient:POST(URLS.SESSION, nil, {
        running = false
    })
    :SetIsRaw(true)
    :SetMaxRetries(0)
    :Send()
end

local function FetchInput()
    -- Do it explicitly. Since implicit method changes are prohibited.
    local request
    if table.empty(events) then
        request = PEARL.HTTPClient:GET(URLS.INPUT, OnInputFetchingDone, nil, FETCH_REQUEST_TIMEOUT)
    else
        request = PEARL.HTTPClient:POST(URLS.INPUT, OnInputFetchingDone, events, FETCH_REQUEST_TIMEOUT)
    end

    request
        :SetMaxRetries(0)
        :SetStatusCodeHandle(0, OnFetchingFailed)
        :SetStatusCodeHandle(500, OnProxyInternalError)
        :SetStatusCodeHandle(204, function() end) -- Ignore empty responses
        :SetStatusCodeHandle(202, function()
            PEARL.info("Received request to restart the session from proxy server.")
            RestartSession()
        end)
        :Send()

    cleartable(events)
end

RestartFetchingTask = function()
    local period = PEARL.CONFIG.DISCORD.PROXY.SYNC_INTERVAL

    if _fetching_task then
        PEARL.info("Restarting the fetching task...")

        -- Ensure we use the default interval in case it was changed before by some commands.
        _fetching_task:settime(period)
        _fetching_task:restart()
        return
    end

    PEARL.info("Starting the fetching task...")
    _fetching_task = PEARL.WallScheduler:ExecutePeriodic(
        period, FetchInput, nil, nil, PEARL.CONSTS.TASK_ID.INPUTPROXY_FETCH
    )
end

local function StopFetchingTask()
    if _fetching_task then
        _fetching_task:cancel()
        _fetching_task = nil
    end
end

----------------------------------
-- Event Handlers
----------------------------------

local function OnQuit()
    StopSession()

    StopFetchingTask()
end

local function OnSave()
    if not _fetching_task or _fetching_task.running == false then
        -- Attempt to silently restart the session if not started yet.
        -- Do not retry here, just a one-shot to not flood the logs.
        RestartSession(0)
    end
end

local function OnShardConnected(shardid)
    events.shard = CreateFetchEvent("shard_connected", shardid, PEARL.GetShardFancyNameByID(shardid))
end

local function OnShardDisconnected(shardid)
    events.shard = CreateFetchEvent("shard_disconnected", shardid)
end

local function OnClientConnected(userid)
    local client = TheNet:GetClientTableForUser(userid)
    events.player = CreateFetchEvent("player_connected", userid, client and client.name or userid)
end

local function OnClientDisconnected(userid)
    events.player = CreateFetchEvent("player_disconnected", userid)
end

----------------------------------
-- Setup
----------------------------------

PEARL.AddSimPostInit(function()
    StartSession()
end)

----------------------------------
-- Event Listeners
----------------------------------

PEARL.EventProcessor:AddSafeEventHandler("quit", OnQuit)
PEARL.EventProcessor:AddSafeEventHandler("save", OnSave)

PEARL.EventProcessor:AddSafeEventHandler("shard_connected", OnShardConnected)
PEARL.EventProcessor:AddSafeEventHandler("shard_disconnected", OnShardDisconnected)
PEARL.EventProcessor:AddSafeEventHandler("ms_clientauthenticationcomplete", OnClientConnected)
PEARL.EventProcessor:AddSafeEventHandler("ms_clientdisconnected", OnClientDisconnected)
