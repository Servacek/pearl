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

if TheNet:GetIsServerAdmin() or not PEARL.CONFIG.CONSOLE_DISABLED then
	return
end

PEARL.OverrideVariable("CONSOLE_ENABLED", false, _G)
PEARL.OverrideVariable("ExecuteConsoleCommand", function() end, _G)

--- @class ConsoleScreen
local ConsoleScreen = require("screens/consolescreen")

-----------------------------------------

-- ConsoleScreen.DoInit = function() end
-- ConsoleScreen.Run = function() end

-- -- Just in case this is called from some other place
-- ConsoleScreen.Run = function(self)
--     self:Close()
-- end

ConsoleScreen.OnBecomeActive = function(self)
    return self:Close()
    -- if TheFrontEnd ~= nil then
    --     TheFrontEnd:ShowConsoleLog()
    -- end

    -- if self.console_edit ~= nil then
    --     self.console_edit:SetString(STRINGS.PEARL.UI.CONSOLE_DISABLED)
    -- end
end
