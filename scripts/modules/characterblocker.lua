--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local CLIENT_SIDE = TheNet:GetIsClient()

if CLIENT_SIDE and TheNet:GetIsServerAdmin() then
    return -- No character disabling for admins
end

local function OnBlockedCharacterSpawned(inst)
    if inst and TheWorld and TheWorld.ismastersim and not (inst.userid and PEARL.ServerNetwork:IsClientPriviliged(inst.userid)) then
        TheWorld:DoTaskInTime(0, function()
            TheWorld:PushEvent("ms_playerdespawnanddelete", inst)
        end)
    end
end

for prefab, blocked in pairs(PEARL.CONFIG.CHARACTER_BLOCKLIST) do
    if blocked then
        if CLIENT_SIDE then
            PEARL.RemoveDefaultCharacter(prefab)
        else
            PEARL.AddPrefabPostInit(prefab, OnBlockedCharacterSpawned)
        end
    end
end
