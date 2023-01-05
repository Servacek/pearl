--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @category BackEnd


--[[
    Makes player icons globaly visible for all players.
--]]

local PEARL = PEARL

--------------------------------
-- [[ Constants ]]
--------------------------------

local REQUIRED_AGE = 20
local REQUIRED_AGE_PERCENT = 0.3

--------------------------------
-- [[ Implementation ]]
--------------------------------

PEARL.AddPlayerPostInit(function(inst)
    if not inst or not inst.components or not inst.components.maprevealable then
        return
    end

    -- Cleaning up is handled by the component itself
    inst.components.maprevealable:AddRevealSource(inst, "compatriot")
end)

PEARL.AddGlobalFunctionPreCall("NotifyPlayerProgress", function(name, value, player)
    if name ~= "days" or not player or player:HasTag("compatriot") or not player.components.age then
        return
    end

    local age_percent = player.components.age:GetPercent()
    if value >= REQUIRED_AGE or age_percent >= REQUIRED_AGE_PERCENT then
        player:AddTag("compatriot")
    end
end)
