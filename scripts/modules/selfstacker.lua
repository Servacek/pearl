--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @category Backend

--[[
    A small little module for assigning the selfstacker component to configured prefabs.
--]]

--------------------------------------
-- [[ Constants ]]
--------------------------------------

local CONFIG = PEARL.CONFIG.SELF_STACKER

--------------------------------------
-- [[ Setup ]]
--------------------------------------

for _, prefab in ipairs(CONFIG.PREFABS) do
    PEARL.AddPrefabPostInit(prefab, function(self)
        if not self or not self:IsValid() or not self.components then
            return
        end

        if not self.components.selfstacker then
            self:AddComponent("selfstacker")
        end

        self.components.selfstacker.stackradius = CONFIG.RADIUS
    end)
end
