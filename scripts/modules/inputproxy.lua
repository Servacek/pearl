--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--- @TODO: Send empty response if no data to save some bytes.

----------------------------------
-- Constants
----------------------------------

local URL = PEARL.CONFIG.DISCORD.PROXY.URL
local FETCH_REQUEST_TIMEOUT = 10

local PROXY_MESSAGE_PATTERN = "[DISCORD] %s: %s"
local PROXY_MESSAGE_PATTERN_ADMIN = "[ADMIN] [DISCORD] %s: %s"

----------------------------------
-- Local Variables
----------------------------------

--- @type Task?
local _fetching_task = nil

----------------------------------
-- Query Handlers
----------------------------------

local function HandleCommands(commands)

end

local function HandleChatMessages(messages)
    if IsTableEmpty(messages) then
        return
    end

    for _, message in ipairs(messages) do
        local pattern = message.admin and PROXY_MESSAGE_PATTERN_ADMIN or PROXY_MESSAGE_PATTERN

        TheNet:SystemMessage(pattern:format(message.author, message.content))
    end
end

local function OnInputFetchingDone(data)
    if not data then
        return
    end

    if PEARL.CONFIG.DISCORD.PROXY.CHAT_ENABLED and data.messages then
        HandleChatMessages(data.messages)
    end

    if PEARL.CONFIG.DISCORD.PROXY.COMMANDS_ENABLED and data.commands then
        HandleCommands(data.commands)
    end
end

----------------------------------
-- Local Functions
----------------------------------

local function StartSession()
    PEARL.HTTPClient:POST(URL, nil, {
        messages = PEARL.CONFIG.DISCORD.PROXY.CHAT_ENABLED,
        commands = PEARL.CONFIG.DISCORD.PROXY.COMMANDS_ENABLED,
        running = true
    })
    :SetMaxRetries(0)
    :Send()
end

local function PauseSession()
    --- @TODO
end

local function StopSession()
    PEARL.HTTPClient:POST(URL, nil, {
        running = false
    })
    :SetMaxRetries(0)
    :Send(true)
end

local function FetchInput()
    PEARL.HTTPClient:GET(URL, OnInputFetchingDone, FETCH_REQUEST_TIMEOUT)
        :SetMaxRetries(0)
        :Send()
end

local function StartFetchingTask()
    if not _fetching_task then
        _fetching_task = PEARL.WallScheduler:ExecutePeriodic(
            PEARL.CONFIG.DISCORD.PROXY.SYNC_INTERVAL, FetchInput
        )
    end
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

----------------------------------
-- Setup
----------------------------------

PEARL.AddSimPostInit(function()
    StartSession()

    StartFetchingTask()
end)

----------------------------------
-- Event Listeners
----------------------------------

PEARL.EventProcessor:AddSafeEventHandler("quit", OnQuit)
