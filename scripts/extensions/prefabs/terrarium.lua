--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--- @class Terrarium
local Terrarium = require("prefabs/terrarium")

--------------------------------
-- [[ Global Localization ]]
--------------------------------

--- @type table<string, any>
local UPVALUES = UPVALUES
--- @type table This should always be a table.
local _AllPlayers = PEARL.GetValue(_G, "AllPlayers")

--------------------------------
-- [[ Private Functions ]]
--------------------------------

local function GetSummoner(inst)
    return inst._summoner_userid and LookupPlayerInstByUserID(
        inst._summoner_userid
    )
end

local function SummonerExists(inst)
    local summoner = GetSummoner(inst)
    return summoner and summoner:IsValid()
end

local function IsSummoner(inst, userid)
    return inst._summoner_userid == userid
end

local function IsSummonerConnected(inst)
    return inst._summoner_userid and TheNet:GetClientTableForUser(inst._summoner_userid) ~= nil
end

local function IsSummoning(inst)
    return inst.components.timer and inst.components.timer:TimerExists("warning")
end

local function SetSummoner(inst, summoner)
    inst._summoner_userid = type(summoner) == "table" and summoner.userid or summoner
end

local function ClearSummoner(inst, summoner)
    inst._summoner_userid = nil
end

-- Use this only if the boss was not already spawned.
local function CancelSummoning(inst)
    TheNet:Announce(STRINGS.EYEOFTERROR_CANCEL)

    -- Stops the warning timer as well.
    UPVALUES.TurnOff(inst)
end

local function HasBossSpawned(inst)
    return inst.eyeofterror ~= nil
end

local function IsBossActive(inst)
    -- When the boss leaves it enters the LIMBO state instead of being completely removed.
    return HasBossSpawned(inst) and not inst.eyeofterror:IsInLimbo()
end

local function CanSummonBoss(inst)
    return not IsBossActive(inst) and SummonerExists(inst)
end

local function SetPossibleTargets(targets)
    return PEARL.OverrideValue(_G, "AllPlayers", targets, true)
end

local function ClearPossibleTargets()
    return PEARL.OverrideValue(_G, "AllPlayers", _AllPlayers, true)
end

local function PreSpawnEyeOfTerror(inst)
    if not CanSummonBoss(inst) then
        return false, CancelSummoning(inst)
    end

    -- Let's hope this is better than overriding the whole function just for one stupid line.
    SetPossibleTargets({GetSummoner(inst)})
end

local function PostSpawnEyeOfTerror()
    ClearPossibleTargets()
end

-- When loading, this is being called from OnLoadPostPass,
-- so the summoner should be already loaded at this point.
local function StartSummoning(inst, is_loading)
    if not SummonerExists(inst) then
        return false, UPVALUES.TurnOff(inst)
    end
end

local function TurnOff(inst)
    if inst.components.timer:TimerExists("summon_delay") then
        inst.components.timer:StopTimer("summon_delay")
    end

    ClearSummoner(inst)
end

--------------------------------
-- [[ Event Handlers ]]
--------------------------------

local function OnActivate(inst, doer)
    if not inst.is_on and doer then
        SetSummoner(inst, doer)
    end
end

-- Called after everything loads up
local function OnLoadPostPass(inst, newents, data)
    if inst.is_on then
        SetSummoner(inst, data.summoner_userid)

        if not IsSummonerConnected(inst) then
            return UPVALUES.TurnOff(inst)
        end
    end
end

local function OnSave(inst, data)
    data.summoner_userid = inst._summoner_userid
end

--------------------------------
-- [[ Class Pre-Initializator ]]
--------------------------------

--- This is being called every time a new terrarium prefab is created.
--- Load here the dynamic extensions of the actual prefab's instance
PEARL.AddPrefabPostInit("terrarium", function(inst)
    inst.OnSummonerDespawned = function(world, player)
        if IsBossActive(inst) or not IsSummoner(inst, (player and player.userid)) then
            -- If the boss is already active just leave it as is,
            -- so we do not interupt any existing fights.
            return
        end

        if IsSummoning(inst) then
            return CancelSummoning(inst)
        end

        return UPVALUES.TurnOff(inst)
    end

    -- Set it always since if we are turning off the summoner will be cleared anyway.
    PEARL.AddClassFunctionPreCall("OnActivate", OnActivate, inst.components.activatable)
    PEARL.AddClassFunctionPreCall("OnSave", OnSave, inst)
    PEARL.AddClassFunctionPostCall("OnLoadPostPass", OnLoadPostPass, inst)

    inst:ListenForEvent("ms_playerdespawn", inst.OnSummonerDespawned, TheWorld)
    inst:ListenForEvent("ms_playerdespawnanddelete", inst.OnSummonerDespawned, TheWorld)
    inst:ListenForEvent("ms_playerdespawnandmigrate", function(world, data)
        if data and data.player then
            inst.OnSummonerDespawned(world, data.player)
        end
    end, TheWorld)
end)

--- This should be called just once when the prefab is actually loaded and registered.
--- Load here the static extensions for the prefab's class and it's environment.
PEARL.AddPrefabPostRegister("terrarium", function()
    PEARL.AddClassFunctionPreCall("TurnOff", TurnOff, UPVALUES)
    PEARL.AddClassFunctionPreCall("StartSummoning", StartSummoning, UPVALUES)

    PEARL.AddClassFunctionPostCall("SpawnEyeOfTerror", PostSpawnEyeOfTerror, UPVALUES)
    PEARL.AddClassFunctionPreCall("SpawnEyeOfTerror", PreSpawnEyeOfTerror, UPVALUES)
end)
