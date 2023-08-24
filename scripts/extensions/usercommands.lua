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


--- @param name string The name of the command.
--- @param params table<string, any> Parameters provided to the command.
--- @param callername string The display name of the caller.
--- @return (Message|Embed|string)?
function UserCommands.RunDiscordCommand(name, params, callername)
    local command = UserCommands.GetCommandFromName(name)
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
