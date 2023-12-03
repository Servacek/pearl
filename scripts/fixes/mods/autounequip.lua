--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--- @type string
local TARGET_MOD = CUSTOM_ENV.TARGET_MOD
local TARGET_PREFAB  = "inventoryitem_classified"

--- @TODO: Crashing mods are not being disabled!
print("TARGET", TARGET_MOD)
-- Fix for items with durability which wont disapeare after reaching 0%.

local modpostinitfns = TARGET_MOD and TARGET_MOD.postinitfns and TARGET_MOD.postinitfns[TARGET_PREFAB]
if modpostinitfns then
    for i = 1, #modpostinitfns do
        print("OVERRIDING POST INITS")
        PEARL.AddFunctionPreCall(i, function(inst)
            print("POST INIT", inst)
            if inst:HasTag("show_broken_ui") then
                return false
            end
        end)
    end
end
