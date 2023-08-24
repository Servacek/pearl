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

----------------------------------
-- Constants
----------------------------------

local URLS = {
    INPUT = PEARL.CONFIG.DISCORD.PROXY.INPUT_URL,
    OUTPUT = PEARL.CONFIG.DISCORD.PROXY.OUTPUT_URL,
}

local FETCH_REQUEST_TIMEOUT = 5

local MAX_FAILED_ATTEMPTS = 5

local MESSAGE_NAME = "%s"
local MESSAGE_NAME_ADMIN = "[ADMIN] %s"

local PMESSAGE_COLOR = RGB(173, 216, 230)

----------------------------------
-- Local Variables
----------------------------------

local _failed_attempts = 0

--- @type Task?
local _fetching_task = nil

local _proxy_unreachable = false
local _running = false

local _response_cache = {}

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
        HandleCommand(command)
    end

    if not table.empty(_response_cache) then
        SendCachedCommandResponses()
    end
end

local function HandleChatMessages(messages)
    for _, message in ipairs(messages) do
        local name = (message.admin == true and MESSAGE_NAME_ADMIN or MESSAGE_NAME):format(message.author)

        PEARL.ServerNetwork:DisplayChatMessage(
            name, message.content, message.author_colour, PMESSAGE_COLOR, "dft_discord"
        )
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

    if PEARL.CONFIG.DISCORD.PROXY.CHAT_ENABLED and not table.empty(data.messages) then
        if PEARL.SafeRun(HandleChatMessages, data.messages) == false then
            PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_MESSAGE_FAILED)
        end
    end

    if PEARL.CONFIG.DISCORD.PROXY.COMMANDS_ENABLED and not table.empty(data.commands) then
        -- Commands are actually waiting for our response.
        HandleCommands(data.commands)
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
        :SetErrorHandler(OnProxyResponseFailed)
        :Send()

    cleartable(_response_cache)
end

local function StartSession()
    PEARL.info("Sending start session request to input proxy server...")

    PEARL.HTTPClient:POST(URLS.INPUT, OnSessionStarted, {
        messages = PEARL.CONFIG.DISCORD.PROXY.CHAT_ENABLED,
        commands = PEARL.CONFIG.DISCORD.PROXY.COMMANDS_ENABLED,
        running = true
    })
    :SetIsRaw(true)
    :SetErrorHandler(OnSessionStartFailed)
    :SetMaxRetries(3)
    :Send()
end

local function RestartSession()
    if _running and not _proxy_unreachable then
        PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_RESTARTED)
    end

    StartSession()
end

local function StopSession()
    if not _running or _proxy_unreachable then
        return
    end

    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_STOPPED)
    PEARL.info("Sending stop session request to input proxy server...")

    -- We do not care about the response at this point
    PEARL.HTTPClient:POST(URLS.INPUT, nil, {
        running = false
    })
    :SetIsRaw(true)
    :SetMaxRetries(0)
    :Send(true)
end

local function FetchInput()
    PEARL.HTTPClient:GET(URLS.INPUT, OnInputFetchingDone, FETCH_REQUEST_TIMEOUT)
        :SetMaxRetries(0)
        :SetStatusCodeHandle(0, OnFetchingFailed)
        :SetStatusCodeHandle(500, OnProxyInternalError)
        :SetStatusCodeHandle(204, function() end) -- Ignore empty responses
        :SetStatusCodeHandle(202, function()
            PEARL.info("Received request to restart the session from proxy server.")
            RestartSession()
        end)
        :Send()
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
        RestartSession()
    end
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
