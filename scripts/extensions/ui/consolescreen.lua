--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--[[
    Overrides the default console screen widget callbacks
    for non-admins.
--]]

if TheNet:GetIsServerAdmin() or PEARL.CONFIG.CLIENT_CONSOLE_ENABLED then
    return -- Do not disable it
end

PEARL.debug("Disabling the console and remote command sending...")

-------------------------------
-- [[ Class Declaration ]]
-------------------------------

--- @class ConsoleScreen
local ConsoleScreen = require("screens/consolescreen")

-------------------------------
-- [[ Function Overrides ]]
-------------------------------

PEARL.OverrideVariable("OnBecomeActive", function(self)
    self:Close()
end, ConsoleScreen)

PEARL.OverrideVariable("CONSOLE_ENABLED", false, _G)
-- Disable this function so even input from stdout won't be executed.
PEARL.OverrideVariable("ExecuteConsoleCommand", function() end, _G)

PEARL.OverrideUserdataValue("SendRemoteExecute", function() end, TheNet)
