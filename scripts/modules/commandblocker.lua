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

--------------------------------
-- [[ Handlers ]]
--------------------------------

-- PlayerPostInit on clients is like GamePostInit on servers
-- At this point everything should have already added it's commands.
PEARL.AddPlayerPostInit(function()
    for _, name in ipairs(UserCommands.GetCommandNames()) do
        local command = UserCommands.GetCommandFromName(name)
        if command then
            if PEARL.CONFIG.COMMAND_BLOCKLIST[name] == true then
                command.hasaccessfn = function() return false end
            end

            command.voteminstartage = PEARL.CONFIG.MIN_VOTE_AGE
        end
    end
end)
