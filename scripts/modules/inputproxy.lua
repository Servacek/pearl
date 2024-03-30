--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local UserCommands = require("usercommands")

local Message = PEARL.loadfile("libraries/discordapi/models/message")
local Embed = PEARL.loadfile("libraries/discordapi/models/embed")

local ChatMessage = PEARL.loadfile("models/chatmessage")

local Colour = PEARL.loadfile("libraries/datastructures/colour")

----------------------------------
-- Constants
----------------------------------

local MESSAGE_NAME = "%s"
local MESSAGE_NAME_ADMIN = "[ADMIN] %s"

local PMESSAGE_COLOR = Colour.FromRGBA(173, 216, 230)

----------------------------------
-- Locals
----------------------------------

local proxy_state_client, proxy_state_shard

----------------------------------
-- Query Handlers
----------------------------------

local function HandleCommand(command)
    PEARL.info("Executing discord command", command.name.."...")

    command.id = tostring(command.id)

    local success, response = PEARL.SafeRun(
        UserCommands.RunDiscordCommand, command.name, command.params or {}, command.caller, command.id
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

local function HandleChatMessage(data)
    local a_colour
    local a_name = (data.admin == true and MESSAGE_NAME_ADMIN or MESSAGE_NAME):format(data.author)

    -- Make sure it's actually an decimal we have received and not something else...
    -- This can also be nil.
    data.author_colour = tonumber(data.author_colour)
    if type(data.author_colour) == "number" then
        a_colour = Colour.FromDecimal(data.author_colour)
    end

    --- @type ChatMessage
    local message = ChatMessage(PEARL.EMOJIS.EmojifyForGame(data.content))
    message:SetAuthor(a_name, a_colour)
    message:SetColour(PMESSAGE_COLOR)
    message:SetIcon(PEARL.CONSTS.PROFILE_FLAIRS.DISCORD)

    PEARL.ServerNetwork:DisplayChatMessage(message)
end

local function HandleCommands(commands)
    PEARL.DiscordProxy:CleanupResponseCache()
    PEARL.DiscordProxy:StartProcessingData(PEARL.DiscordProxy.PROCESSING_TYPE.COMMANDS)

    for _, command in ipairs(commands) do
        if PEARL.CONFIG.DEBUG_MODE then
            table.dump(command)
        end

        HandleCommand(command)
    end

    if PEARL.DiscordProxy:HasAnyCommandResponses() then
        PEARL.DiscordProxy:SendCachedCommandResponses()
    end

    PEARL.DiscordProxy:StopProcessing()
end

local function HandleChatMessages(messages)
    PEARL.DiscordProxy:StartProcessingData(PEARL.DiscordProxy.PROCESSING_TYPE.MESSAGES)

    for _, data in ipairs(messages) do
        if PEARL.SafeRun(HandleChatMessage, data) == false then
            PEARL.EventProcessor:HandleEvent("proxy_message_failed", data)
        end
    end

    PEARL.DiscordProxy:StopProcessing()
end

local function HandleEvents(events)
    for _, event in ipairs(events) do
        PEARL.EventProcessor:HandleEvent("input_proxy_event", event)
    end
end

----------------------------------
-- Event Handlers
----------------------------------

local function OnProxyStateChanged(state)
    if proxy_state_client then
        proxy_state_client:set(state)
    end

    if proxy_state_shard and TheShard:IsMaster() then
        proxy_state_shard:set(state)
    end
end

local function OnProxyFetchingDone(data)
    if type(data) ~= "table" then
        return
    end

    if PEARL.CONFIG.DISCORD.PROXY.CHAT_ENABLED and type(data.messages) == "table" and not table.empty(data.messages) then
        HandleChatMessages(data.messages)
    end

    if PEARL.CONFIG.DISCORD.PROXY.COMMANDS_ENABLED and type(data.commands) == "table" and not table.empty(data.commands) then
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
    if PEARL.DiscordProxy:IsRunning() then
        PEARL.DiscordProxy:StopSession()
    end

    if PEARL.DiscordProxy:IsFetching() then
        PEARL.DiscordProxy:StopFetchTask()
    end
end

local function OnSave()
    if not PEARL.DiscordProxy:IsRunning() then
        -- Attempt to silently restart the session if not started yet.
        -- Do not retry here, just a one-shot to not flood the logs.
        PEARL.DiscordProxy:RestartSession(0)

    -- Making sure to handle rare case where the session is running but the fetch task doesn't.
    -- Normally they should ALWAYS run symultaneously.
    elseif not PEARL.DiscordProxy:IsFetching() then
        PEARL.DiscordProxy:RestartFetchTask()
    end
end

--- @TODO: Handle those events on all active shards. (prob. RPCs)

local function OnShardConnected(shardid)
    PEARL.DiscordProxy:AddShardEvent("shard_connected", shardid, PEARL.GetShardFancyNameByID(shardid))
end

local function OnShardDisconnected(shardid)
    PEARL.DiscordProxy:AddShardEvent("shard_disconnected", shardid)
end

local function OnClientConnected(userid) -- Replace with "filtersdone"
    PEARL.DiscordProxy:AddPlayerEvent("player_connected", userid, PEARL.GetUserName(userid))
end

local function OnClientDisconnected(userid)
    if not PEARL.ServerNetwork:IsClientConnectedAny(userid) then
        PEARL.DiscordProxy:AddPlayerEvent("player_disconnected", userid)
    end
end

----------------------------------
-- Setup
----------------------------------

PEARL.AddGamePostInit(function()
    if TheShard:IsMaster() then
        PEARL.DiscordProxy:StartSession()
    end
end)

PEARL.AddWorldNetworkPostInit(function(inst)
    if proxy_state_client == nil then
        proxy_state_client = net_tinybyte(inst.GUID, "proxy_state_client")
        proxy_state_client:set(PEARL.DiscordProxy:GetState())
    end
end)

--- Communication between shards.
PEARL.AddShardNetworkPostInit(function(inst)
    if proxy_state_shard == nil then
        proxy_state_shard = net_tinybyte(inst.GUID, "proxy_state_shard", "proxy_state_shard_changed")
        proxy_state_shard:set(PEARL.DiscordProxy:GetState())
        proxy_state_shard:set_local(PEARL.DiscordProxy:GetState())

        if TheShard:IsSecondary() then
            inst:ListenForEvent("proxy_state_shard_changed", function()
                PEARL.DiscordProxy:SetState(proxy_state_shard:value())
            end)
        end
    end
end)

----------------------------------
-- Event Listeners
----------------------------------

if TheShard:IsMaster() then
    PEARL.EventProcessor:AddSafeEventHandler("quit", OnQuit)
    PEARL.EventProcessor:AddSafeEventHandler("save", OnSave)

    PEARL.EventProcessor:AddSafeEventHandler("shard_connected", OnShardConnected)
    PEARL.EventProcessor:AddSafeEventHandler("shard_disconnected", OnShardDisconnected)
    PEARL.EventProcessor:AddSafeEventHandler("ms_clientauthenticationcomplete", OnClientConnected)
    PEARL.EventProcessor:AddSafeEventHandler("ms_clientdisconnected", OnClientDisconnected)

    PEARL.EventProcessor:AddSafeEventHandler("proxy_fetching_done", OnProxyFetchingDone)
end

PEARL.EventProcessor:AddSafeEventHandler("proxy_state_changed", OnProxyStateChanged)
