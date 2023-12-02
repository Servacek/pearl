--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--- @class Input
local Input = require("input")

-- Fixes the some weird issue with Right ALT key being interpreted as CTRL
-- when used in combination with "V" key in order to write the "@" symbol.
PEARL.AddClassFunctionPreCall("IsPasteKey", function(self, key)
    if self:IsKeyDown(KEY_RALT) then
        return false
    end
end, Input)
