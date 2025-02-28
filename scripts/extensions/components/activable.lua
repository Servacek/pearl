--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--- @class Activatable
local Activatable = require("components/activatable")

--------------------------------
-- [[ Getters ]]
--------------------------------

function Activatable:IsLastPlayerActivator(player)
    return self._last_player_ac == player
end

--------------------------------
-- [[ Setters ]]
--------------------------------

function Activatable:SetLastPlayerActivator(activator)
    self._last_player_ac = activator
end


PEARL.AddComponentPostInit("activatable", function(self)
    PEARL.AddClassAttrPostSet("inactive", function(t, inactive, old)
        if inactive == old or not self._last_player_ac then
            return
        end

        if inactive == true then
            self._last_player_ac = nil
            return
        end
    end, self)
end)
