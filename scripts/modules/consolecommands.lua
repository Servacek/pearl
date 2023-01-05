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
    This module adds a bunch of console commands (prefixed with c_) to the global environment.
]]

PEARL.OverrideGlobal("c_inv", PEARL.LogInventoryFor)
PEARL.OverrideGlobal("c_fire", PEARL.ExtinguishFiresNearAll)
PEARL.OverrideGlobal("c_repair", PEARL.RepairStructuresNearAll)
PEARL.OverrideGlobal("c_unban", PEARL.UnbanUserByID)
PEARL.OverrideGlobal("c_daysback", PEARL.RollbackByDays)
PEARL.OverrideGlobal("c_hasreedtrap", PEARL.CheckForReedTrap)
