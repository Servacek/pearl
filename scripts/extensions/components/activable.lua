--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--- @TODO: Activator should be cleared after the object is deactivated by something else.

--- @class Activatable
local Activatable = require("components/activatable")

--------------------------------
-- [[ Getters ]]
--------------------------------

function Activatable:IsLastPlayerActivator()
    return self._last_player_ac
end

--------------------------------
-- [[ Setters ]]
--------------------------------

function Activatable:SetLastPlayerActivator(activator)
    self._last_player_ac = activator
end
