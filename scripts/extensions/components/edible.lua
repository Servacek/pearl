--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--- @class Edible
local Edible = require("components/edible")

--------------------------------
-- [[ Member Functions ]]
--------------------------------

function Edible:GetFoodValue()
    return (self:GetHunger() / 2) + self:GetHealth()
end

function Edible:FulfillsDiet(diet)
    for _, type in ipairs(diet.types) do
        if self.foodtype == type then
            return true
        end
    end

    return false
end
