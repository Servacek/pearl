--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- This file's task is to centralize netvars.
--- Why do we do this?
--- - netvar desynchronization sucks
--- - reduce duplication


--- @TODO: Create some AddNetvar and a Netvars table
--- This file should be loaded unconditionally on all instances (client and server).

-- PEARL.AddClassPostConstruct("components/health_replica", function(self, inst)
--     self._max = net_uint(inst.GUID, PEARL.MODNAME.."_health._max", PEARL.MODNAME.."healthmaxdirty")
--     self._max:set(100)

--     self._percent = net_float(inst.GUID, PEARL.MODNAME.."_health._percent", PEARL.MODNAME.."healthpercentdirty")
--     self._percent:set(1)
-- end)
