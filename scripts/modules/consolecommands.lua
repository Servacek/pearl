--[[
    This module adds a bunch of console commands (prefixed with c_) to the global environment.
]]

PEARL.OverrideGlobal("c_inv", PEARL.LogInventoryFor)

PEARL.OverrideGlobal("c_fire", PEARL.ExtinguishFiresNearAll)

PEARL.OverrideGlobal("c_repair", PEARL.RepairStructuresNearAll)

PEARL.OverrideGlobal("c_unban", PEARL.UnbanUserByID)
