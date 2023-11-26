--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local CommandContext = PEARL.loadfile("models/commandcontext")

--- @static
--- @singleton
--- @class UserCommands
local UserCommands = require("usercommands")

-------------------------------------
-- Constants
-------------------------------------

local MENTION_DELIMETER = PEARL.CONSTS.DELIMS.PLAYER_NAME

local REQUIRED_FIELDS = {
    params = {},
}

-------------------------------------
-- Locals
-------------------------------------

local custom_commands = {}

--------------------------------------
-- Local Functions
--------------------------------------

local function make_safe_cb(name, cb)
    return function(params, caller, ...)
        local result = {PEARL.SafeRun(cb, params, caller, ...)}
        if not result[1] then
            local traceback = result[2] or "No Traceback"
            PEARL.error("Failed to run command '/"..name.."'!\n", traceback)

            if PEARL.ServerNetwork and type(caller) == "table" and caller.userid then
                PEARL.ServerNetwork:SendCommandResponse(caller.userid,
                    STRINGS.PEARL.UI.CMD_ERRORS.EXECUTION
                )
            end

            -- Send the traceback to the server as well.
            if PEARL.ClientNetwork then
                PEARL.ClientNetwork:SendErrorTracebackToServer(traceback)
            end

            return
        end

        -- Skip the first element which is the status code.
        return unpack(result, 2)
    end
end

-------------------------------------
-- Static
-------------------------------------´

UserCommands.SHARD_ROUTING = {
    NONE    = 0, -- Command will be executed on the shard they are called on.
    ALL     = 1, -- Command will be executed on all shards.
    ACTIVE  = 2, -- Command will be executed on the shard the target player is playing on.
    AUTO    = 3, -- The routing will be determined according to the parameters passed.
}

-------------------------------------
-- Public Functions
-------------------------------------

--- @param name string
--- @param context CommandContext
--- @param shardid string|string?
--- @return boolean
function UserCommands.RouteHybridCommand(name, context, shardid)
    PEARL.debug("Routing command", name, "to shard", shardid)

    -- If we are routing this from a secondary shard.
    shardid = TheShard:IsMaster() and shardid or SHARDID.MASTER
    local data = ZipAndEncodeString(context:ToTable())
    if type(data) == "string" then
        PEARL.BroadcastRPCToShards(PEARL.RPC.RouteHybridCommand, shardid, name, data)

        return true
    end

    return false
end

--- @param command table<string, any>
--- @param context CommandContext
--- @param handler function?
--- @return boolean success
function UserCommands.RunHybridCommand(command, context, handler)
    if type(command) ~= "table" or type(command.fn) ~= "function" then
        context:Reply(STRINGS.PEARL.COMMAND_RESPONSES.INVALID)
        PEARL.error("Attempted to run an invalid hybrid command.")
        return false
    end

    -- Route commands from Master to secondary shards in case the player is not here.
    local target_userid = UserToClientID(context.params and context.params.player) or context.params.player
    local route = not handler and command.routing ~= UserCommands.SHARD_ROUTING.NONE and target_userid and
                    not PEARL.ServerNetwork:IsClientConnected(target_userid)

    local shardid = nil -- broadcast to all.
    if route and target_userid and command.routing == UserCommands.SHARD_ROUTING.ACTIVE then
        shardid = PEARL.DB:GetField(target_userid, "lastshardid") or nil
    end

    if route and shardid then
        if UserCommands.RouteHybridCommand(command.name, context, shardid) then
            return true
        end
    end

    handler = type(handler) == "function" and handler or command.fn
    handler(context)

    return true
end

--- @param name string The name of the command.
--- @param params table<string, any> Parameters provided to the command.
--- @param caller table<string, any> The authors data.
--- @param id string? The ID of the discord command that caused this function to be called.
--- @return string? errmsg
function UserCommands.RunDiscordCommand(name, params, caller, id)
    if not TheShard:IsMaster() then
        return PEARL.error("Attempted to run a discord command from a secondary shard.")
    end

    local command = UserCommands.GetCustomCommand(name)

    if type(command) ~= "table" or type(command.fn) ~= "function" then
        PEARL.error("Attempted to run an invalid hybrid command.")
        return STRINGS.PEARL.COMMAND_RESPONSES.INVALID
    end

    if caller.discordid then
        caller.userid = PEARL.DB:MapDiscordID(caller.discordid)
    end

    if caller.userid then
        caller.netid = PEARL.DB:MapUserIDToType(caller.userid, PEARL.DB.BINDING_TYPE.STEAM)
    end

    --- @type CommandContext
    local context = CommandContext(command, CommandContext.TYPE.DISCORD, params, caller)
    context:SetInteractionID(id)

    UserCommands.RunHybridCommand(command, context)
end

function UserCommands.GetCustomCommand(name)
    return custom_commands[name]
end

function UserCommands.GetCustomCommandsWithFlag(flagname)
    local flagged = {}
    for name, command in pairs(custom_commands) do
        if command[flagname] then
            flagged[name] = command
        end
    end

    return flagged
end

local function ParseParamsArray(command, params_array)
    local params = {}
    for i, paramname in ipairs(command.params) do
        if params_array and params_array[i] ~= nil then
            params[paramname] = params_array[i]
        else
            if command.paramsoptional ~= nil and command.paramsoptional[i] == true then
                break
            end

            PEARL.error("Didn't supply enough arguments to command!")
            return
        end
    end

    return params
end

local function EnsureRequiredFields(command)
    for key, value in pairs(REQUIRED_FIELDS) do
        if command[key] == nil then
            command[key] = value
        end
    end
end

function UserCommands.RegisterCustomCommand(name, command)
    if custom_commands[name] ~= nil then
        PEARL.error("Custom command", name, "already registered!")
        return
    end

    custom_commands[name] = command
end

--- @param name string
--- @param fn fun(command: table): any
function UserCommands.CustomizeCommand(name, fn)
    PEARL.AddUserCommandPreInit(name, function(command)
        fn(command)

        UserCommands.AddCustomCommand(name, command)
    end)
end

function UserCommands.AddConsoleCommand(name, command)
    -- When executed from STDIN, these are always in a protected call so no need for make_safe_cb.
    PEARL.OverrideValue(_G, "c_"..name:gsub("-", "_"), function(...)
        local caller = ThePlayer
        local params = ParseParamsArray(command, toarrayornil(...))

        print(DataDumper(params))
        UserCommands.RunHybridCommand(
            command, CommandContext(command, CommandContext.TYPE.CONSOLE, params, caller)
        )
    end)
end

function UserCommands.AddSlashCommand(name, command)
    command.serverfn = make_safe_cb(name, function(params, caller)
        UserCommands.RunHybridCommand(
            command, CommandContext(command, CommandContext.TYPE.SLASH, params, caller)
        )
    end)

    AddUserCommand(name, command)
end

function UserCommands.AddCustomCommand(name, command)
    if command.slash ~= true and not TheNet:GetIsServer() then
        return -- Ignore backend-only commands
    end

    local origin = UserCommands.GetCommandFromName(name)
    if origin ~= nil then
        PEARL.warn("Overriding command", name)
    end

    EnsureRequiredFields(command)

    PEARL.info("Registering command", name)
    command.name = name

    command.remote = type(command.fn) == "function"

    command.slash = command.slash ~= false and PEARL.CONFIG.SLASH_COMMANDS
    command.console = command.console ~= false and PEARL.CONFIG.CONSOLE_COMMANDS
    command.discord = command.discord ~= false and PEARL.CONFIG.DISCORD_COMMANDS

    -- Make all the functions safe
    if command.localfn then
        command.localfn = make_safe_cb(name, command.localfn)
    end

    if command.canstartfn then
        command.canstartfn = make_safe_cb(name, command.canstartfn)
    end

    -- Console commands are server-only.
    if not TheNet:GetIsServer() then
        command.console = false
    end

    UserCommands.RegisterCustomCommand(name, command)
    if command.aliases then
        for _, alias in ipairs(command.aliases) do
            UserCommands.RegisterCustomCommand(alias, command)
        end
    end

    if not command.remote and TheNet:GetIsServer() then
        return -- Ignore local only commands on the server.
    end

    if command.console ~= false then
        UserCommands.AddConsoleCommand(command.consolename or name, command)

        if command.consolename and command.consolename ~= name then
            if not command.aliases then
                command.aliases = {}
            end

            -- Register the console name as an alias for better consistency.
            if not table.contains(command.aliases, command.consolename) then
                command.aliases[#command.aliases+1] = command.consolename
            end
        end
    end

    if command.slash == true or command.usermenu or command.servermenu then
        UserCommands.AddSlashCommand(name, command)
    end
end

--- @return string userid The client's Klei ID or nil on failure.
function UserCommands.InputToUserID(input)
    return UserToClientID(input) or PEARL.DB:MapSteamID(input) or
        PEARL.DB:MapDiscordID(input) or input
end

--- @return table? client The client's table or nil on failure.
function UserCommands.InputToClientTable(input)
    local userid = UserCommands.InputToUserID(input)
    return userid and TheNet:GetClientTableForUser(userid)
end

-------------------------------------
-- Overrides
-------------------------------------

-- Support for mentions.
--- @param client table?
--- @param input string?
PEARL.OverrideReturnValue(_G, "UserToClient", function(client, input)
    -- If the original function was not able to find any match.
    -- Make sure the input is valid and that it starts with the delimeter.
    if client == nil and type(input) == "string" and input:startswith(MENTION_DELIMETER) then
        -- Remove the delimeter and try again.
        local nodelim = input:sub(#MENTION_DELIMETER + 1)
        for _, c in ipairs(GetPlayerClientTable()) do
            if c.name == nodelim then
                return c
            end
        end
    end

    return client
end)

-------------------------------------
-- RPCs
-------------------------------------

PEARL.AddShardRPCHandler("RouteHybridCommand", function(shardid, name, datastr)
    PEARL.debug("[RPC] RouteHybridCommand", shardid, name)

    if tostring(shardid) ~= SHARDID.MASTER then
        return PEARL.error("Got hybrid command routing from a secondary shard!")
    end

    local data = DecodeAndUnzipString(datastr)
    if type(data) ~= "table" then
        return PEARL.error("Received invalid command routing data from Master!")
    end

    local command = UserCommands.GetCustomCommand(name)
    if type(command) ~= "table" then
        return PEARL.error("Attempted to route an invalid command", name)
    end

    local context = CommandContext.FromTable(data)
    context:SetCommand(command)

    UserCommands.RunHybridCommand(command, context)
end)
