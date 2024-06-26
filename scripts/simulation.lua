--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @backend


----------------------------------
-- Local Functions
----------------------------------

local function OnShardShutdown()
    PEARL.EventProcessor:HandleEvent("shard_shutdown", false)
    PEARL.ModShutdown()
end

----------------------------------
-- Function Pre-Calls
----------------------------------

-- Looks like this is pushed only on the Master shard
PEARL.AddGlobalFunctionPreCall("WorldRollbackFromSim", function(count)
    if TheWorld ~= nil then
        TheWorld:PushModEvent("world_rollback", count)
    end
end)

PEARL.AddGlobalFunctionPreCall("OnSimPaused", function()
    PEARL.EventProcessor:HandleEvent("simulation_paused")

    if TheWorld ~= nil then
        TheWorld:PushModEvent("ms_simpaused")
    end
end)

PEARL.AddGlobalFunctionPreCall("OnSimUnpaused", function()
    PEARL.EventProcessor:HandleEvent("simulation_unpaused")
end)

PEARL.AddUserDataFunctionPreCall("Reset", function()
    if TheWorld ~= nil then
        TheWorld:PushModEvent("world_restart")
    end

    PEARL.ModShutdown()
end, TheSim)

--- @TODO:
-- This is some additional server side check in case someone gets around our Agreement Screen.
-- PEARL.AddGlobalFunctionPreCall("VerifySpawnNewPlayerOnServerRequest", function(userid)
--     if PEARL.ServerNetwork:IsClientPriviliged(userid) or PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT == nil then
--         return
--     end

--     return type(PEARL.DB:GetField(userid, "agreement")) == "table"
-- end)

PEARL.AddUserDataFunctionPreCall("Quit", OnShardShutdown, TheSim)

-- Since these are very forcefull and destructive we have to delay their execution a bit.

-- This is not being called by the game itself, but we use this to force a reboot from inside.
local _Crash
_Crash  = PEARL.OverrideUserdataValue("Crash", function(self, silent, ...)
    if type(_Crash) == "function" then
        if not silent then
            -- Real crash
            return _Crash(self)
        end

        PEARL.WallScheduler:ExecuteInTime(1, _Crash, nil, self, silent, ...)
    end

    return OnShardShutdown()
end, TheSim)

PEARL.AddUserDataFunctionPreCall("BeginNewSession", OnShardShutdown, TheSim)

PEARL.AddGlobalFunctionPreCall("NotifyLoadingState", function(loading_state)
    if PEARL.LOADING_STATE ~= loading_state then
        PEARL.EventProcessor:HandleEvent("loading_state_changed", PEARL.LOADING_STATE, loading_state)

        PEARL.LOADING_STATE = loading_state
    end
end)
