--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local UpvalueHacker = PEARL.loadfile("utils/upvaluehacker")

--- @class Terrarium
local Terrarium = require("prefabs/terrarium")

--------------------------------
-- [[ Global Localization ]]
--------------------------------

local UPVALUES = UPVALUES
local _AllPlayers = PEARL.GetValue(_G, "AllPlayers")

--------------------------------
-- [[ Function Declarations ]]
--------------------------------

local OnSummonerDespawned

--------------------------------
-- [[ Private Functions ]]
--------------------------------

local function HasBossAnyTargets(inst)
    return inst.eyeofterror ~= nil and (
        inst.eyeofterror.components.grouptargeter and not IsTableEmpty(inst.eyeofterror.components.grouptargeter:GetTargets())
    )
end

local function GetSummoner(inst)
    return inst._summoner_userid and LookupPlayerInstByUserID(
        inst._summoner_userid
    )
end

local function SummonerExists(inst)
    return GetSummoner(inst) ~= nil
end

local function IsSummoner(inst, userid)
    return inst._summoner_userid == userid
end

local function SetSummoner(inst, summoner)
    PEARL.debug("SetSummoner", summoner)

    inst._summoner_userid = summoner.userid

    summoner:ListenForEvent("player_despawn", OnSummonerDespawned, inst)
end

local function ClearSummoner(inst, summoner)
    PEARL.debug("ClearSummoner", summoner)

    inst._summoner_userid = nil

    summoner = summoner or GetSummoner(inst)
    if summoner then
        summoner:RemoveEventCallback("player_despawn", OnSummonerDespawned, inst)
    end
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

local function CanBossSpawn(inst)
    return (
        not HasBossSpawned(inst) and
        type(_AllPlayers) == "table" and
        not IsTableEmpty(_AllPlayers) and
        SummonerExists(inst)
    )
end

local function PreSpawnEyeOfTerror(inst)
    if not CanBossSpawn(inst) then
        return false, CancelSummoning(inst)
    end

    PEARL.info("TARGETING THE SUMMONER!")
    -- Let's hope this is better than overriding the whole function just for one stupid line.
    PEARL.OverrideValue(_G, "AllPlayers", {GetSummoner(inst)}, true)
end

local function PostSpawnEyeOfTerror()
    print("PostSpawnEyeOfTerror")
    PEARL.OverrideValue(_G, "AllPlayers", _AllPlayers, true)
end

local function StartSummoning(inst, is_loading)
    print("START SUMMONING")
    -- Just to make sure
    if not is_loading and not SummonerExists(inst) then
        return UPVALUES.TurnOff(inst)
    end
end

local function TurnOff(inst)
    print("TURN OFF")
    if inst.components.timer:TimerExists("summon_delay") then
        inst.components.timer:StopTimer("summon_delay")
    end

    ClearSummoner(inst)
end

--------------------------------
-- [[ Event Handlers ]]
--------------------------------

OnSummonerDespawned = function(summoner, inst)
    if not (summoner and IsSummoner(inst, summoner.userid)) then
        return
    end

    if not HasBossSpawned(inst) and inst.is_on then
        return CancelSummoning(inst)
    end

    --- @TODO:
    -- Not sure if we want this since it could cause some side effects.
    -- If the boss has already been spawned, and has no other targets than
    -- if HasBossSpawned(inst) and not HasBossAnyTargets(inst) then
    --     SendBossAway(inst)
    -- end
end

local function OnLoadPostPass(inst, data)
    if data and data.is_on then
        inst._summoner_userid = data.summoner_userid
    end
end

local function OnSave(inst, data)
    data.summoner_userid = inst._summoner_userid
end

--------------------------------
-- [[ Setup ]]
--------------------------------

--- This is being called every time a new terrarium prefab is created.
--- Load here the dynamic extensions of the actual prefab's instance
PEARL.AddPrefabPostInit("terrarium", function(inst)
    -- Set it always since if we are turning off the summoner will be cleared anyway.
    PEARL.AddClassFunctionPreCall("OnActivate", SetSummoner, inst.components.activatable)
    PEARL.AddClassFunctionPreCall("OnSave", OnSave, inst)
    PEARL.AddClassFunctionPreCall("OnLoadPostPass", OnLoadPostPass, inst)
end)

--- This should be called just once when the prefab is actually loaded and registered.
--- Load here the static extensions for the prefab's class and it's environment.
PEARL.AddPrefabPostRegister("terrarium", function()
    PEARL.AddClassFunctionPreCall("TurnOff", TurnOff, UPVALUES)
    PEARL.AddClassFunctionPreCall("StartSummoning", StartSummoning, UPVALUES)

    PEARL.AddClassFunctionPostCall("SpawnEyeOfTerror", PostSpawnEyeOfTerror, UPVALUES)
    PEARL.AddClassFunctionPreCall("SpawnEyeOfTerror", PreSpawnEyeOfTerror, UPVALUES)
end)
