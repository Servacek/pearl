--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


-- This is a static singleton "class" (no self).
local UserCommands = require("usercommands")


local MENTION_DELIMETER = PEARL.CONSTS.DELIMS.PLAYER_NAME


local discord_commands = {}


--- @param name string The name of the command.
--- @param params table<string, any> Parameters provided to the command.
--- @param callername string The display name of the caller.
--- @return (Message|Embed|string)?
function UserCommands.RunDiscordCommand(name, params, callername)
    local command = UserCommands.GetCommandFromName(name) or UserCommands.GetDiscordCommand(name)
    if not command or command.discord == false then
        PEARL.error("Attempted to run an invalid discord command!")
        return STRINGS.PEARL.COMMAND_RESPONSES.INVALID
    end

    local caller = {
        name = callername,
        GetDisplayName = function() return callername end
    }

    -- Even the main function is optional for discord only commands.
    local mainfn = command and command.mainfn
    local response = mainfn and {mainfn(params, caller)}

    if type(command.discordfn) == "function" then
        return command.discordfn(params, caller, PEARL.unpack(response))
    end

    return PEARL.unpack(response)
end

function UserCommands.GetDiscordCommand(name)
    return discord_commands[name]
end

function UserCommands.AddDiscordCommand(name, command)
    discord_commands[name] = command
end

----------------------

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
