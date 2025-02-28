--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @category Backend
--- @performance


--- @class UpdateLooper
local UpdateLooper = require("components/inventoryitem")


local function OnEntitySleep(inst)
    inst:StopUpdatingComponent(inst.components.updatelooper)
    inst:StopWallUpdatingComponent(inst.components.updatelooper)
end

local function OnEntityWake(inst)
    local self = inst.components.updatelooper
    if #self.onupdatefns > 0 then
        inst:StartUpdatingComponent(self)
    end

    if #self.onwallupdatefns > 0 then
        inst:StartWallUpdatingComponent(self)
    end
end

PEARL.AddComponentPostInit("updatelooper", function(self)
    self.inst:ListenForEvent("entitysleep", OnEntitySleep)
    self.inst:ListenForEvent("entitywake", OnEntityWake)
end)
