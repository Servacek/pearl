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

-- Fix for items with durability which wont disapeare after reaching 0%.

local postinits = TARGET_MOD and TARGET_MOD.postinitfns
local targetpostinits = postinits and postinits.PrefabPostInit and postinits.PrefabPostInit[TARGET_PREFAB]
if targetpostinits then
    for i = 1, #targetpostinits do

        local _PrefabPostInit
        local PrefabPrePostInit = function(item)
            local inst = item.entity and item.entity:GetParent()
            if not inst:HasTag("show_broken_ui") then
                _PrefabPostInit(item)
            end
        end

        _PrefabPostInit = PEARL.OverrideValue(targetpostinits, i, function(inst)
            -- Wait a tick for the prefab to fully load.
            inst:DoStaticTaskInTime(0, PrefabPrePostInit)
        end)
    end
end
