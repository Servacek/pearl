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
    A very lightweight module for removing thermal stone durability.
--]]

PEARL.AddPrefabPostInit("heatrock", function(inst)
    if not (inst and inst.components and inst.components.fueled) then
        return
    end

    inst.components.fueled:SetDepletedFn(nil)
    inst.components.fueled:MakeEmpty()
end)
