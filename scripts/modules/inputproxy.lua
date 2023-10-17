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

local MESSAGE_NAME = "%s"
local MESSAGE_NAME_ADMIN = "[ADMIN] %s"

local PMESSAGE_COLOR = Colour.FromRGBA(173, 216, 230)

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
            return PEARL.DiscordProxy:AddCommandResponse(command.id, Message(
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

        PEARL.DiscordProxy:AddCommandResponse(
            command.id, Message.is_instance(response) and response:ToTable() or response
        )

    elseif type(response) == "string" then
        PEARL.DiscordLogger:LogString(response)
    end
end

local function HandleCommands(commands)
    for _, command in ipairs(commands) do
        if PEARL.CONFIG.DEBUG_MODE then
            table.dump(command)
        end

        HandleCommand(command)
    end

    if PEARL.DiscordProxy:HasAnyCommandResponses() then
        PEARL.DiscordProxy:SendCachedCommandResponses()
    end
end

local function HandleChatMessage(data)
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

local function HandleChatMessages(messages)
    for _, data in ipairs(messages) do
        if PEARL.SafeRun(HandleChatMessage, data) == false then
            PEARL.EventProcessor:HandleEvent("proxy_message_failed", data)
        end
    end
end

local function HandleEvents(events)
    for _, event in ipairs(events) do
        PEARL.EventProcessor:HandleEvent("input_proxy_event", event)
    end
end

----------------------------------
-- Event Handlers
----------------------------------

local function OnProxyFetchingDone(data)
    if type(data) ~= "table" then
        return
    end

    if PEARL.CONFIG.DISCORD.PROXY.CHAT_ENABLED and type(data.messages) == "table" then
        HandleChatMessages(data.messages)
    end

    if PEARL.CONFIG.DISCORD.PROXY.COMMANDS_ENABLED and type(data.commands) == "table" then
        -- Commands are actually waiting for our response.
        HandleCommands(data.commands)
    end

    -- These are always enabled if commands are enabled as well.
    -- We use them for better autocompletion.
    if PEARL.CONFIG.DISCORD.PROXY.COMMANDS_ENABLED and type(data.events) == "table" then
        HandleEvents(data.events)
    end
end

local function OnQuit()
    PEARL.DiscordProxy:StopSession()
    PEARL.DiscordProxy:StopFetchTask()
end

local function OnSave()
    if PEARL.DiscordProxy:IsRunning() then
        -- Attempt to silently restart the session if not started yet.
        -- Do not retry here, just a one-shot to not flood the logs.
        PEARL.DiscordProxy:RestartSession(0)

    -- Making sure to handle rare case where the session is running but the fetch task doesn't.
    -- Normally they should ALWAYS run symultaneously.
    elseif not PEARL.DiscordProxy:IsFetching() then
        PEARL.DiscordProxy:RestartFetchTask()
    end
end

local function OnShardConnected(shardid)
    PEARL.DiscordProxy:AddShardEvent("shard_connected", shardid, PEARL.GetShardFancyNameByID(shardid))
end

local function OnShardDisconnected(shardid)
    PEARL.DiscordProxy:AddShardEvent("shard_disconnected", shardid)
end

local function OnClientConnected(userid)
    local client = TheNet:GetClientTableForUser(userid)
    PEARL.DiscordProxy:AddPlayerEvent("player_connected", userid, client and client.name or userid)
end

local function OnClientDisconnected(userid)
    PEARL.DiscordProxy:AddPlayerEvent("player_disconnected", userid)
end

----------------------------------
-- Setup
----------------------------------

PEARL.AddSimPostInit(function()
    PEARL.DiscordProxy:StartSession()
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

PEARL.EventProcessor:AddSafeEventHandler("proxy_fetching_done", OnProxyFetchingDone)
