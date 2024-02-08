--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local CommandContext = PEARL.loadfile("models/commandcontext")

local Colour = PEARL.loadfile("libraries/datastructures/colour")

--- @static
--- @singleton
--- @class UserCommands
local UserCommands = require("usercommands")

-------------------------------------
-- Constants
-------------------------------------

local MENTION_DELIMETER = PEARL.CONSTS.DELIMS.PLAYER_NAME
local DEFAULT_COMMAND_PERMISSION = COMMAND_PERMISSION.ADMIN -- For safety

local REQUIRED_FIELDS = {
    options = {},
    params = {},
    permission = DEFAULT_COMMAND_PERMISSION
}

local COMMANDS_FILE_PATH = (PEARL.IS_WORKSHOP and PEARL.CONSTS.UGC_MODS_FOLDER or MODROOT)
    .."/scripts/extensions/commands.lua"

-------------------------------------
-- Locals
-------------------------------------

local custom_commands       = {}

--- @type table<string, fun(ctx: CommandContext, param: any, validate: boolean?): any, boolean?>
local standardized_params   = {}

local user_cooldowns        = PEARL.GameInstParams:GetModParam("user_cmd_cooldowns") or {}
PEARL.GameInstParams:SetModParam("user_cmd_cooldowns", user_cooldowns)

--------------------------------------
-- Local Functions
--------------------------------------

local function make_safe_cb(name, cb)
    if type(cb) ~= "function" then
        return
    end

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

UserCommands.OPTION_TYPE = {
    STRING      = "string",
    INTEGER     = "integer",
    BOOLEAN     = "boolean",
    NUMBER      = "number",
}

UserCommands.DEFAULT = {
    OPTION = {
        TYPE = UserCommands.OPTION_TYPE.STRING,
        OPTIONAL = false,
        VALIDATION = true,
    }
}

--- @TODO: Finish the commands API
UserCommands.STD_PARAMS = {
    PLAYER  = {name = "player", type = UserCommands.OPTION_TYPE.STRING},
    SHARD   = {name = "shard", type = UserCommands.OPTION_TYPE.STRING},
    PREFAB  = {name = "prefab", type = UserCommands.OPTION_TYPE.STRING},
    USER    = {name = "user", type = UserCommands.OPTION_TYPE.STRING},
    JSON    = {name = "json", type = UserCommands.OPTION_TYPE.STRING},
}

UserCommands.PERMISSION = COMMAND_PERMISSION

UserCommands.PATH = COMMANDS_FILE_PATH
UserCommands.VERSION = io.fmtime(COMMANDS_FILE_PATH) or "1.1"

local PARAMS = UserCommands.STD_PARAMS

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

function UserCommands.IsCommandRoutable(command)
    return command.routing ~= UserCommands.SHARD_ROUTING.NONE and PEARL.ServerNetwork:IsAnySecondaryShardConnected()
end

function UserCommands.IsCommandRegistered(name)
    return custom_commands[name] ~= nil
end

--- @return boolean, any
local function StandardizeParam(ctx, name, value, validate)
    --- @type any, boolean?
    local standardized, success = value, true
    local standardizer = standardized_params[name]
    if type(standardizer) == "function" then
        standardized, success = standardizer(ctx, value, validate)
    end

    return success == true, standardized
end

--- Returns an array of parameter values for the given context
--- Also modifies the given table so the changes apply accordingly.
--- or nil if there was an error.
--- @param ctx CommandContext
--- @return table? args, integer? count
local function ProccessParams(ctx, params)
    local optional      = ctx.command.paramsoptional
    local types         = ctx.command.paramtypes
    local novalidation  = ctx.command.paramsnovalidation
    local permission    = ctx.command.parampermissions

    local author_permission = UserCommands.GetPermissionLevel(
        ctx.author.permission or UserCommands.CalculatePermissionFor(ctx.author.userid)
    )

    local args, n = nil, 0
    for i, name in ipairs(ctx.command.params) do
        local value = params[name]
        if value ~= nil then
            local param_permission = permission and UserCommands.GetPermissionLevel(permission[name])
            if param_permission and param_permission > author_permission then
                ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.NO_PARAMETER_PERMISSIONS:format(name))
                return
            end
        end

        -- Parameters are optional by default
        if optional and optional[i] == false and value == nil then
            ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.MISSING_PARAMETER:format(name))
            return
        end

        -- Check if the value type is correct, if not try to convert it.
        local tp = types and types[name]
        if tp and value ~= nil and value ~= tp then
            value = PEARL.TryConvertToType(value, tp)
            if type(value) ~= tp then
                ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.INVALID_PARAM_VALUE:format(name))
                return
            end
        end

        local validate = not novalidation or novalidation[i] ~= true
        local success, standardized = StandardizeParam(ctx, name, value, validate)
        if success == false then
            if ctx:WasReplied() then
                return
            end

            return ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.STANDARDIZATION_FAILED:format(name))
        end

        n = n + 1
        args = args or {}
        args[n] = standardized
        params[name] = standardized
    end

    for paramname, _ in pairs(params) do
        if not table.contains(ctx.command.params, paramname) then
            ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.INVALID_PARAM:format(paramname))
            return
        end
    end

    return args, n
end

--- @param name string
--- @param fn fun(ctx: CommandContext, param: any, validate: boolean): any, boolean
function UserCommands.AddStandardizedParam(name, fn)
    standardized_params[name] = fn

    return fn -- So we allow chaining
end

function UserCommands.IsOnCooldownForCommand(userid, commandname)
    local cooldown_timeout = user_cooldowns[commandname] and user_cooldowns[commandname][userid]
    return cooldown_timeout and cooldown_timeout > os.time()
end

function UserCommands.StartCommandCooldownFor(userid, command)
    if type(command.cooldown) ~= "number" then
        return PEARL.error("Attempted to start cooldown for an invalid command!")
    end

    if not user_cooldowns[command.name] then
        user_cooldowns[command.name] = {}
    end

    user_cooldowns[command.name][userid] = os.time() + command.cooldown
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

    if UserCommands.IsOnCooldownForCommand(ctx.author.userid, command.name) then
        ctx:Reply(STRINGS.UI.PLAYERSTATUSSCREEN.COMMANDCANNOTSTART.COOLDOWN)
        return false
    end

    local validated_args = ctx:GetValidatedArguments()
    local n = validated_args and table.size(validated_args) or 0
    if not validated_args then
        local count
        validated_args, count = ProccessParams(ctx, ctx.params)
        if not count then
            return false
        end

        ctx:SetValidatedArguments(validated_args)
        n = count
    end

    local player_param = ctx.params and (ctx.params[PARAMS.PLAYER] or ctx.params[PARAMS.USER])
    local target = type(player_param) == "table" and player_param or UserCommands.InputToClientTable(player_param)
    local target_userid = target and target.userid
    local target_permission = UserCommands.GetPermissionLevel(
        target_userid and UserCommands.CalculatePermissionFor(target_userid)
    )
    local author_permission = UserCommands.GetPermissionLevel(
        ctx.author.permission or UserCommands.CalculatePermissionFor(ctx.author.userid)
    )
    local command_permission = UserCommands.GetPermissionLevel(command.permission or DEFAULT_COMMAND_PERMISSION)
    if author_permission < command_permission then
        ctx:Reply(STRINGS.UI.USERCOMMANDS.NOTALLOWEDFMT:format(command.prettyname or command.name))
        return false
    end

    if (command.cantargetself == false and target_userid == ctx.author.userid and ctx.author.userid ~= nil) or
        (command.cantargetadmin == false and target_permission > author_permission)
    then
        ctx:Reply(STRINGS.UI.USERCOMMANDS.BADTARGETFMT:format(
            command.prettyname or command.name, target and target.name or "[UNKNOWN]"
        ))

        return false
    end

    -- local required_binding_type = command.requiredbindings[ctx.type]
    -- if required_binding_type ~= nil and not PEARL.AccountBindings:ExistsAny(ctx.author.userid, required_binding_type) then
    --     ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.MISSING_BINDING)
    --     return false
    -- end

    local route_shardid
    local routing_type      = norouting and UserCommands.SHARD_ROUTING.NONE or command.routing
    local is_routing        = norouting ~= true and UserCommands.IsCommandRoutable(command)

    if is_routing == true and routing_type == UserCommands.SHARD_ROUTING.AUTO then
        -- If a shardid is explicitly specified as a parameter, then prioritize it.
        -- "nil" is a valid parameter as well but it just means that we want the command on all shards.
        if ctx.params[PARAMS.SHARD] ~= nil and ctx.params[PARAMS.SHARD] ~= PEARL.SHARDID then
            route_shardid = ctx.params[PARAMS.SHARD]
        -- Route commands to the target player if the player is provided and connected to our server.
        elseif target_userid and PEARL.ServerNetwork:IsClientConnectedAny(target_userid) then
            is_routing = false

            -- Use the player's active shard ID as our routing target.
            local lastshardid = PEARL.DB:GetField(target_userid, "lastshardid")
            if lastshardid ~= nil and tostring(lastshardid) ~= tostring(TheShard:GetShardId()) then
                route_shardid = lastshardid
                is_routing = true
            end
        else -- Handle fallback
            if command.routingfallback ~= UserCommands.SHARD_ROUTINGFALLBACK.ALL then
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

    command.fn(ctx, PEARL.unpack(validated_args, 1, n))

    if not ctx:WasReplied() and command.async ~= true and ctx.type == CommandContext.TYPE.DISCORD then
        ctx:Reply(STRINGS.PEARL.UI.CMD_INFO.RECEIVED_FROM_THIRDPARTY, PEARL.ICONS.CHECK)
    end

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
    if type(command) ~= "table" or type(command.fn) ~= "function" or command.discord ~= true then
        PEARL.error("Attempted to run an invalid hybrid command.")
        return STRINGS.PEARL.COMMAND_RESPONSES.INVALID
    end

    if author.discordid then
        -- Just in case it stays as a number.
        author.userid = PEARL.AccountBindings:MapDiscordID(tostring(author.discordid))
    end

    if author.userid then
        author.netid = PEARL.AccountBindings:MapUserIDToType(author.userid, PEARL.AccountBindings.BINDING_TYPE.STEAM)
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
    return ((client and client.admin) or (PEARL.AdminList:Contains(userid))) and
        COMMAND_PERMISSION.ADMIN or COMMAND_PERMISSION.USER
end

function UserCommands.GetCustomCommand(name)
    return custom_commands[name]
end

--- Aliases are not included.
--- @param flagname string The name of the flag used to choose the commands.
--- @return table flagged The table of chosen commands.
function UserCommands.GetCustomCommandsWithFlag(flagname, value)
    if value == nil then
        value = true
    end

    local flagged = {}
    for name, command in pairs(custom_commands) do
        if command[flagname] == value then
            flagged[name] = command
        end
    end

    return flagged
end

local function ParseParamsArray(command, params_array)
    if params_array and #command.params < #params_array then
        PEARL.error("Too many arguments supplied!")
        return nil, false
    end

    local params = {}
    for i, paramname in ipairs(command.params) do
        if params_array and params_array[i] ~= nil then
            params[paramname] = params_array[i]
        else
            if command.paramsoptional == nil or command.paramsoptional[i] ~= true then
                PEARL.error("Didn't supply enough arguments to command!")
                return nil, false
            end
        end
    end

    return params, true
end

local function EnsureRequiredFields(command)
    for key, value in pairs(REQUIRED_FIELDS) do
        if command[key] == nil then
            command[key] = deepcopy(value)
        end
    end
end

local function ValidateFields(command)
    local optional_reached = false
    for i, paramname in ipairs(command.params) do
        if command.paramsoptional then
            if command.paramsoptional and command.paramsoptional[i] == true then
                optional_reached = true
            elseif optional_reached then
                return error(("Required options must be placed before non-required options (param %s command %s)"):format(
                    paramname, command.name
                ))
            end
        end

        if command.options[i] == nil then
            command.options[i] = {
                name = paramname,
                optional = command.paramsoptional and command.paramsoptional[i] == true or false,
                type = UserCommands.OPTION_TYPE.STRING,
            }
        end
    end

    local params = command.params
    local paramsoptional = command.paramsoptional or {}
    for i, option in ipairs(command.options) do
        params[i] = option.name
        paramsoptional[i] = option.optional == true

        for name, default in pairs(UserCommands.DEFAULT.OPTION) do
            local field = name:lower()
            if option[field] == nil then
                option[field] = default
            end
        end
    end

    command.params = params
    command.paramsoptional = paramsoptional
end

--- @param name string
local function NormalizeCommandName(name)
    return name:gsub("-", "_")
end

function UserCommands.RegisterCustomCommand(name, command)
    --PEARL.debug("UserCommands.RegisterCustomCommand", name)

    if UserCommands.IsCommandRegistered(name) then
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

function UserCommands.AddConsoleCommand(normalized_name, command)
    -- When executed from STDIN, these are always in a protected call so no need for make_safe_cb.
    PEARL.OverrideGlobalVariable("c_"..normalized_name, function(...)
        local params, success = ParseParamsArray(command, toarrayornil(...))
        if success == false then
            return PEARL.error("Executing console command failed!")
        end

        UserCommands.RunHybridCommand(
            command, CommandContext(command, CommandContext.TYPE.CONSOLE, params, {
                name = "[Host]",
                permission = COMMAND_PERMISSION.ADMIN,
                userid = TheNet:GetUserID(),
            })
        )
    end)

    if command.consolename and command.consolename ~= normalized_name then
        -- Register the console name as an alias for better consistency.
        -- For now, aliases are only for slash commands to not flood the command list.
        command.aliases = command.aliases or {}
        if not table.contains(command.aliases, command.consolename) then
            command.aliases[#command.aliases+1] = command.consolename
        end
    end
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
            author.discordid = PEARL.AccountBindings:MapUserIDToType(caller.userid, PEARL.AccountBindings.BINDING_TYPE.DISCORD)
            author.colour = client.colour or WHITE
            author.netid = (client and client.netid) or (
                PEARL.AccountBindings:MapUserIDToType(caller.userid, PEARL.AccountBindings.BINDING_TYPE.STEAM)
            )
            author.permission = UserCommands.CalculatePermissionFor(userid)
        end

        UserCommands.RunHybridCommand(
            command, CommandContext(command, CommandContext.TYPE.SLASH, params, author)
        )
    end)

    AddUserCommand(name, command)
end

--- @param name string
--- @param command table
function UserCommands.AddCustomCommand(name, command)
    assert(type(name) == "string", "Missing or invalid command name!")

    if (command.slash == false and command.console == false) and not TheNet:GetIsServer() then
        return -- Ignore backend-only commands
    end

    local origin = UserCommands.GetCommandFromName(name)
    if origin ~= nil then
        PEARL.warn("Overriding command", name)
    end

    command.name = name

    EnsureRequiredFields(command)
    ValidateFields(command)

    PEARL.info("Registering command", name)

    local normalized_name = NormalizeCommandName(name)
    command.consolename = normalized_name

    local strings = STRINGS.PEARL.UI.BUILTINCOMMANDS[normalized_name:upper()]
    command.prettyname = command.prettyname or (strings and strings.PRETTYNAME)
    command.desc = command.desc or (strings and strings.DESC)

    command.remote = type(command.fn) == "function" -- Whether we should send the response to the server.
    command.routing = command.routing or UserCommands.SHARD_ROUTING.AUTO
    command.routingfallback = command.routingfallback or UserCommands.SHARD_ROUTINGFALLBACK.CURRENT

    -- Everything is enabled by default
    command.slash = command.slash ~= false and PEARL.CONFIG.SLASH_COMMANDS
    command.console = command.console ~= false and PEARL.CONFIG.CONSOLE_COMMANDS
    command.discord = command.discord ~= false and PEARL.CONFIG.DISCORD_COMMANDS

    -- Disabled by default
    command.usermenu = command.usermenu or false
    command.servermenu = command.servermenu or false

    -- Cooldown
    if type(command.cooldown) == "number" then
        if command.canstartfn then
            PEARL.warn("Command has already implemented canstartfn.")
        end
    end

    -- Make all the functions safe
    command.localfn = make_safe_cb(name, command.localfn)
    command.canstartfn = make_safe_cb(name, command.canstartfn)

    UserCommands.RegisterCustomCommand(name, command)
    if not command.remote and TheNet:GetIsServer() then
        return -- Ignore local only commands on the server.
    end

    if command.console == true then
        UserCommands.AddConsoleCommand(command.consolename or name, command)
    end

    if command.slash == true or command.usermenu or command.servermenu then
        UserCommands.AddSlashCommand(name, command)
    end
end

function UserCommands.AddCustomAsyncCommand(name, command)
    command.async = true
    UserCommands.AddCustomCommand(name, command)
end

--- @return string userid The client's Klei ID or nil on failure.
function UserCommands.InputToUserID(input)
    return input and (UserToClientID(input) or PEARL.AccountBindings:MapToKleiID(input)) or input
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

-------------------------------------
-- Param Standardizers
-------------------------------------

UserCommands.AddStandardizedParam(PARAMS.USER,
UserCommands.AddStandardizedParam(PARAMS.PLAYER, function(ctx, param, validate)
    if param == nil then
        if ctx.command and ctx.command.targetselfbydefault == true then
            return ThePlayer and ThePlayer.userid or ctx.author.userid, true
        end

        return nil, true
    end

    local userid = UserCommands.InputToUserID(tostring(param))
    if validate and (not userid or not PEARL.ServerNetwork:IsKleiIDKnown(userid)) then
        -- Player is unknown to the server as a whole.
        ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.UNKNOWN_PLAYER)
        return nil, false
    end

    if ctx.command.instrequired == true or ctx.command.activeinstrequired == true then
        local player_inst = PEARL.ServerNetwork:GetClientInstance(userid, ctx.command.activeinstrequired)
        if player_inst ~= nil then
            return player_inst, true
        end

        if validate then
            -- Player has no active instance.
            ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PLAYER_NOT_FOUND)
            return nil, false
        end
    end

    return userid, true
end))

UserCommands.AddStandardizedParam(PARAMS.SHARD, function(ctx, param, validate)
    if param == nil then
        return nil, true
    end

    local shardid = tostring(param)
    if validate and shardid ~= SHARDID.MASTER and not PEARL.ServerNetwork:IsShardConnected(shardid) then
        ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.SHARD_NOT_FOUND)
        return nil, false
    end

    return shardid, true
end)

UserCommands.AddStandardizedParam(PARAMS.PREFAB, function(ctx, param, validate)
    if param == nil then
        return nil, true
    end

    local prefab = tostring(param):lower():gsub("-", "_")
    if validate and not PEARL.PrefabExists(param) then
        ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.PREFAB_INVALID)
        return nil, false
    end

    return prefab, true
end)

UserCommands.AddStandardizedParam(PARAMS.JSON, function(ctx, param, validate)
    if param == nil then
        return nil, true
    end

    local success, data = pcall(json.encode, param)
    if validate and (success ~= true or type(data) ~= "table" or table.empty(data)) then
        ctx:Reply(STRINGS.PEARL.UI.CMD_ERRORS.INVALID_JSON)
        return nil, false
    end

    return data, true
end)
