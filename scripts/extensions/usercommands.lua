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

local Colour = PEARL.loadfile("libraries/colour")

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

-- Shard routing policy types
UserCommands.SHARD_ROUTING = {
    NONE    = 0, -- Command will be executed on the shard they are called on.
    ALL     = 1, -- Command will be executed on all shards.
    AUTO    = 3, -- Command will be executed on the shard the target player is playing on.
}

-- Fallbacks for the ACTIVE and AUTO routing policies when the player is not on the server at all.
UserCommands.SHARD_ROUTINGFALLBACK = {
    CURRENT = 0, -- Fallback to the current shard (no routing).
    ALL     = 1, -- Fallback by broadcasting the command to all shards (complete routing).
}

-- Why it could not be an integer from the beginning Klei?
-- Why such unnecessary complexity?
UserCommands.PERMISSION_LEVEL = {
    [COMMAND_PERMISSION.USER] = 0,
    [COMMAND_PERMISSION.MODERATOR] = 1,
    [COMMAND_PERMISSION.ADMIN] = 2,
}

-------------------------------------
-- Public Functions
-------------------------------------

--- @param name string
--- @param context CommandContext
--- @param shardid string|string?
--- @return boolean
function UserCommands.RouteHybridCommand(name, context, shardid)
    PEARL.debug("Routing command", name, "to shard", tostring(shardid))

    -- If we are routing this from a secondary shard.
    local data = DataDumper(context:ToTable(), nil, true)
    if type(data) == "string" then
        PEARL.BroadcastRPCToShardsGlobal(PEARL.RPC.RouteHybridCommand, shardid, name, data)

        return true
    end

    return false
end

--- @param command table<string, any>
--- @param ctx CommandContext
--- @param norouting boolean?
--- @return boolean success
function UserCommands.RunHybridCommand(command, ctx, norouting)
    PEARL.debug("UserCommands.RunHybridCommand")

    if not TheNet:GetIsServer() then
        PEARL.debug("Ignoring client side call of a command.")
        return false
    end

    if type(command) ~= "table" or type(command.fn) ~= "function" then
        ctx:Reply(STRINGS.PEARL.COMMAND_RESPONSES.INVALID)
        PEARL.error("Attempted to run an invalid hybrid command.")
        return false
    end

    local target = UserCommands.InputToClientTable(ctx.params and ctx.params.player or ctx.params.user)
    local target_userid = target and target.userid
    local target_permission = UserCommands.GetPermissionLevel(
        target_userid and UserCommands.CalculatePermissionFor(target_userid)
    )
    if (command.cantargetself == false and target_userid == ctx.author.userid) or
        (command.cantargetadmin == false and target_permission == COMMAND_PERMISSION.ADMIN)
    then
        ctx:Reply(STRINGS.UI.USERCOMMANDS.BADTARGETFMT:format(
            command.prettyname or command.name, target and target.name or "[UNKNOWN]"
        ))
    end

    local route_shardid
    local routing_type      = norouting and UserCommands.SHARD_ROUTING.NONE or command.routing
    local routing_fallback  = command.routingfallback
    local is_routing        = routing_type ~= UserCommands.SHARD_ROUTING.NONE and PEARL.ServerNetwork:IsAnySecondaryShardConnected()

    if routing_type == UserCommands.SHARD_ROUTING.AUTO then
        -- Route commands to the target player if the player is provided and connected to our server.
        if target_userid and PEARL.ServerNetwork:IsClientConnectedAny(target_userid) then
            is_routing = false

            -- Use the player's active shard ID as our routing target.
            local lastshardid = PEARL.DB:GetField(target_userid, "lastshardid")
            if lastshardid ~= nil and tostring(lastshardid) ~= tostring(TheShard:GetShardId()) then
                route_shardid = lastshardid
                is_routing = true
            end
        else -- Handle fallback
            if routing_fallback == UserCommands.SHARD_ROUTINGFALLBACK.CURRENT then
                is_routing = false -- Looks like no routing this time :,(
            end
        end
    end

    if is_routing == true then
        if UserCommands.RouteHybridCommand(command.name, ctx, route_shardid) then
            return true
        end

        -- Command failed to route for some reason, so continue execution on the current shard.
        PEARL.error("Routing command", command.name, "failed! Continuing execution on the current shard!")
        -- Maybe do not execute at all?
    end

    print("RUNNING THE COMMAND!")
    command.fn(ctx)

    return true
end

--- @param name string The name of the command.
--- @param params table<string, any> Parameters provided to the command.
--- @param author table<string, any> The authors data.
--- @param id string? The ID of the discord command that caused this function to be called.
--- @return string? errmsg
function UserCommands.RunDiscordCommand(name, params, author, id)
    if not TheShard:IsMaster() then
        return PEARL.error("Attempted to run a discord command from a secondary shard.")
    end

    local command = UserCommands.GetCustomCommand(name)

    if type(command) ~= "table" or type(command.fn) ~= "function" then
        PEARL.error("Attempted to run an invalid hybrid command.")
        return STRINGS.PEARL.COMMAND_RESPONSES.INVALID
    end

    if author.discordid then
        -- Just in case it stays as a number.
        author.userid = PEARL.DB:MapDiscordID(tostring(author.discordid))
    end

    if author.userid then
        author.netid = PEARL.DB:MapUserIDToType(author.userid, PEARL.DB.BINDING_TYPE.STEAM)
    end

    -- Colour has to be a table
    author.colour = tonumber(author.colour)
    if author.colour then
        author.colour = {Colour.DecimalToPercent(author.colour)}
    else
        author.colour = WHITE
    end

    --- @type CommandContext
    local context = CommandContext(command, CommandContext.TYPE.DISCORD, params, author)
    context:SetInteractionID(id)

    UserCommands.RunHybridCommand(command, context)
end

function UserCommands.GetPermissionLevel(permission)
    return UserCommands.PERMISSION_LEVEL[permission] or 0
end

function UserCommands.CalculatePermissionFor(userid)
    local client = userid and TheNet:GetClientTableForUser(userid)
    return (client and client.admin) or (PEARL.AdminList:Contains(userid)) and
        COMMAND_PERMISSION.ADMIN or COMMAND_PERMISSION.USER
end

function UserCommands.GetCustomCommand(name)
    return custom_commands[name]
end

--- @param flagname string The name of the flag used to choose the commands.
--- @return table flagged The table of chosen commands.
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
        local params = ParseParamsArray(command, toarrayornil(...))

        UserCommands.RunHybridCommand(
            command, CommandContext(command, CommandContext.TYPE.CONSOLE, params, {
                name = "[Host]",
                permission = COMMAND_PERMISSION.ADMIN,
            })
        )
    end)
end

function UserCommands.AddSlashCommand(name, command)
    PEARL.debug("UserCommands.AddSlashCommand", name)

    command.serverfn = make_safe_cb(name, function(params, caller)
        local author = {}
        if type(caller) == "table" and type(caller.userid) == "string" then
            local userid = caller.userid
            local client = TheNet:GetClientTableForUser(userid)

            author.name = caller.name
            author.userid = userid
            author.discordid = PEARL.DB:MapUserIDToType(caller.userid, PEARL.DB.BINDING_TYPE.DISCORD)
            author.colour = client.colour or WHITE
            author.netid = (client and client.netid) or (
                PEARL.DB:MapUserIDToType(caller.userid, PEARL.DB.BINDING_TYPE.STEAM)
            )
            author.permission = UserCommands.CalculatePermissionFor(userid)
        end

        UserCommands.RunHybridCommand(
            command, CommandContext(command, CommandContext.TYPE.SLASH, params, author)
        )
    end)

    AddUserCommand(name, command)
end

function UserCommands.AddCustomCommand(name, command)
    if (command.slash ~= true and command.console ~= true) and not TheNet:GetIsServer() then
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

    command.routing = command.routing or UserCommands.SHARD_ROUTING.AUTO
    command.routingfallback = command.routingfallback or UserCommands.SHARD_ROUTINGFALLBACK.CURRENT

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
    return input and (UserToClientID(input) or PEARL.DB:MapToKleiID(input)) or input
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

    local success, data = RunInSandbox(datastr)
    if not success or type(data) ~= "table" then
        return PEARL.error("Received invalid command routing data from Master!")
    end

    local command = UserCommands.GetCustomCommand(name)
    if type(command) ~= "table" then
        return PEARL.error("Attempted to route an invalid command", name)
    end

    local context = CommandContext.FromTable(data)
    context:SetCommand(command)

    PEARL.WallScheduler:ExecuteInTime(0, function()
        UserCommands.RunHybridCommand(command, context, true)
    end)
end)
