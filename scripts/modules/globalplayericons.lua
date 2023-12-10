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
    Makes player map icons globaly visible for all players or only
    the trusted ones, if configured so.
--]]

local PEARL = PEARL

--------------------------------
-- [[ Constants ]]
--------------------------------

local ONLY_FOR_TRUSTED = PEARL.CONFIG.PLAYER_MAP_ICONS.ONLY_FOR_TRUSTED == true

--------------------------------
-- [[ Implementation ]]
--------------------------------

PEARL.AddPlayerPostInit(function(inst)
    if not inst or not inst.components or not inst.components.maprevealable then
        return
    end

    -- Cleaning up is handled by the component itself
    inst.components.maprevealable:AddRevealSource(inst, "compatriot")

    if not ONLY_FOR_TRUSTED then
        inst:AddTag("compatriot")
    end
end)

if ONLY_FOR_TRUSTED then
    PEARL.AddGlobalFunctionPreCall("NotifyPlayerPresence", function(name, value, player)
        if name ~= "days" or not player or player:HasTag("compatriot") or not player.components.age then
            return
        end

        if player.components.age:IsTrustworthy() then
            player:AddTag("compatriot")
        end
    end)
end
