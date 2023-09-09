--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local function OnEntitySleep(inst)
    local self = inst.components.timer
    for name, _ in pairs(self.timers) do
        self:PauseTimer(name)
    end
end

local function OnEntityWake(inst)
    local self = inst.components.timer
    for name, _ in pairs(self.timers) do
        self:ResumeTimer(name)
    end
end

PEARL.AddComponentPostInit("timer", function(self)
    self.inst:ListenForEvent("entitysleep", OnEntitySleep)
    self.inst:ListenForEvent("entitywake", OnEntityWake)
end)
