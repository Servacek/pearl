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

PEARL.OverrideVariable("c_fire", PEARL.ExtinguishFiresNearAll)
PEARL.OverrideVariable("c_fireall", PEARL.ExtinguishAllFires)
PEARL.OverrideVariable("c_repair", PEARL.RepairStructuresNearAll)
PEARL.OverrideVariable("c_unban", PEARL.UnbanUserByID)
PEARL.OverrideVariable("c_daysback", PEARL.RollbackByDays)
PEARL.OverrideVariable("c_hasreedtrap", PEARL.CheckForReedTrap)

PEARL.OverrideVariable("c_mods", function(userid)
    local mods = PEARL.PlayerDB:GetField(userid, "lastmods")
    if not mods then
        return PEARL.info("No mods found for player", userid)
    end

    PEARL.info("Sending player's mods report to discord...")
    PEARL.DiscordReporter:ReportMods(userid, mods)
end)

PEARL.OverrideVariable("c_inv", function(userid)
    PEARL.info("Sending player's inventory to discord...")
    PEARL.DiscordReporter:ReportInventory(userid)
end)

-- This is here mainly for debugging purposes, so we do not have to wait
-- for the Master shard to be restarted.
PEARL.OverrideVariable("c_resetshard", function()
    return StartNextInstance({
        reset_action = RESET_ACTION.LOAD_SLOT,
        save_slot = ShardGameIndex:GetSlot()
    })
end)
