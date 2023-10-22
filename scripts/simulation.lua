--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @backend


----------------------------------
-- Local Functions
----------------------------------

local function OnShardCrashed()
    PEARL.EventProcessor:HandleEvent("shard_shutdown", true)
    PEARL.ModShutdown()
end

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
    if TheWorld ~= nil then
        TheWorld:PushModEvent("simpaused")
    end
end)

PEARL.AddUserDataFunctionPreCall("Reset", function()
    if TheWorld ~= nil then
        TheWorld:PushModEvent("world_restart")
    end

    PEARL.ModShutdown()
end, TheSim)

PEARL.AddGlobalFunctionPreCall("WorldResetFromSim", function()
    if TheWorld ~= nil then
        TheWorld:PushModEvent("world_reset")
    end

    PEARL.GameInstParams:SetModParam("regenerated", true)
    PEARL.ModShutdown()
end)

-- This is some additional server side check in case someone gets around our Agreement Screen.
PEARL.AddGlobalFunctionPreCall("VerifySpawnNewPlayerOnServerRequest", function(userid)
    if PEARL.ServerNetwork:IsClientPriviliged(userid) or not PEARL.ServerNetwork:IsAgreementEnabled() then
        return
    end

    return type(PEARL.PlayerDB:GetField(userid, "agreement")) == "table"
end)

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

----------------------------------
-- Simulation Post Init
----------------------------------

-- Looks like GamePostInit isn't called when regenerating the world.
PEARL.AddSimPostInit(function()
    if not TheWorld then
        return
    end

    -- Push this here since this is the place where all the meta data are loaded as well.
    if PEARL.GameInstParams:GetModParam("regenerated") == true then
        TheWorld:PushModEvent("worldgencomplete")
    end
end)
