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
-- [[ Implementation ]]
--------------------------------

PEARL.AddPlayerPostInit(function(inst)
    if not inst or not inst.components or not inst.components.maprevealable then
        return
    end

    -- Cleaning up is handled by the component itself
    inst.components.maprevealable:AddRevealSource(inst, "compatriot")
end)

PEARL.AddGlobalFunctionPreCall("NotifyPlayerPresence", function(name, value, player)
    if name ~= "days" or not player or player:HasTag("compatriot") or not player.components.age then
        return
    end

    if player.components.age and player.components.age:IsTrustworthy() then
        player:AddTag("compatriot")
    end
end)
