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

local URL = PEARL.CONFIG.DISCORD.PROXY.URL
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

----------------------------------
-- Declarations
----------------------------------

local RestartFetchingTask, SendCommandResponse

----------------------------------
-- Query Handlers
----------------------------------

local function HandleCommands(commands)
    for _, command in ipairs(commands) do
        PEARL.debug("Executing command", command.name)
        tdump(command)
        local message = UserCommands.RunDiscordCommand(command.name, command.params or {}, command.caller)

        -- If command ID is provided, the command expects a response.
        if command.id then
            if type(message) == "string" then
                message = Message(message)
            end

            if type(message) ~= "table" then
                return PEARL.error("Invalid response provided for command that is waiting for it!")
            end

            if Message.is_instance(message) then
                message = message:ToTable()
            end

            if Embed.is_instance(message) then
                message = Message():AddEmbed(message)
            end

            SendCommandResponse(command.id, message)
        end
    end
end

local function HandleChatMessages(messages)
    for _, message in ipairs(messages) do
        local name = (message.admin == true and MESSAGE_NAME_ADMIN or MESSAGE_NAME):format(message.author)
        local name_color = PEARL.GetColorFromDecimal(message.author_colour, WHITE)

        PEARL.ServerNetwork:DisplayChatMessage(name, message.content, name_color, PMESSAGE_COLOR, "dft_discord")
    end
end

local function OnProxyUnreachable()
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
            PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_COMMAND_FAILED)
        end
    end

    if PEARL.CONFIG.DISCORD.PROXY.COMMANDS_ENABLED and not table.empty(data.commands) then
        --HandleCommands(data.commands)
        if PEARL.SafeRun(HandleCommands, data.commands) == false then
            PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_MESSAGE_FAILED)
        end
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
    _proxy_unreachable = false

    PEARL.info("The input proxy session has successfully started!")
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_STARTED)

    RestartFetchingTask()
end

local function OnSessionStartFailed(response, status, request)
    print("OnSessionStartFailed", response, status, request.retries)
    if request:IsRetryable() then
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

SendCommandResponse = function(command_id, message)
    local response = {
        response = message,
        id = command_id,
    }

    PEARL.info("Sending command response to server.")
    PEARL.HTTPClient:POST(URL, OnProxyReceviedResponse, response)
        :SetIsRaw(true)
        :SetErrorHandler(OnSessionStartFailed)
        :Send()
end

local function StartSession()
    PEARL.info("Sending start session request to input proxy server...")

    PEARL.HTTPClient:POST(URL, OnSessionStarted, {
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
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_RESTARTED)
    StartSession()
end

local function PauseSession()
    --- @TODO
end

local function StopSession()
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_STOPPED)
    PEARL.info("Sending stop session request to input proxy server...")

    -- We do not care about the response at this point
    PEARL.HTTPClient:POST(URL, nil, {
        running = false
    })
    :SetIsRaw(true)
    :SetMaxRetries(0)
    :Send(true)
end

local function FetchInput()
    PEARL.HTTPClient:GET(URL, OnInputFetchingDone, FETCH_REQUEST_TIMEOUT)
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
    if _fetching_task then
        PEARL.info("Restarting the fetching task...")
        _fetching_task:restart()
        return
    end

    PEARL.info("Starting the fetching task...")
    _fetching_task = PEARL.WallScheduler:ExecutePeriodic(
        PEARL.CONFIG.DISCORD.PROXY.SYNC_INTERVAL, FetchInput, nil, nil, PEARL.CONSTS.TASK_ID.INPUTPROXY_FETCH
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
