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

if not (TheNet and TheInput and not TheNet:GetIsServerAdmin()) then
	return
end

local ConsoleScreen = require("screens/consolescreen")

-----------------------------------------

-- Just in case this is called from some other place
ConsoleScreen.Run = function(self)
    self:Close()
end

ConsoleScreen.OnBecomeActive = function(self)
    if TheFrontEnd ~= nil then
        TheFrontEnd:ShowConsoleLog()
    end

    if self.console_edit ~= nil then
        self.console_edit:SetString("Disabled :)")
    end
end

-----------------------------------------

return ConsoleScreen
