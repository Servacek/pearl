--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--- Locates a specific structure built in a base and spawns a newly connected
--- player (relative to the current world) at it's position.

local function IsStructureAtBase(inst)
    if not inst.Transform then
        return false
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, PEARL.CONFIG.BASE_SPAWNER.BASE_RADIUS)

    local base_structure_count = 0
    local base_structure_prefabs = {}
    for i, v in ipairs(ents) do
        -- First entity is the target structure
        -- Find and count all unique base structures around our target entity.
        if i ~= 1 and v.prefab ~= nil and base_structure_prefabs[v.prefab] == nil and v:IsBaseStructure() then
            base_structure_count = base_structure_count + 1
            base_structure_prefabs[v.prefab] = true
        end
    end

    return base_structure_count >= PEARL.CONFIG.BASE_SPAWNER.UNIQUE_BASE_STRUCTURE_THRESHOLD
end


local function FindStructureAtBase(prefabs)
    for _, prefab in ipairs(prefabs) do
        for _, ent in pairs(Ents) do
            if ent.prefab == prefab and ent:GetCurrentPlatform() == nil and ent:IsOnPassablePoint(false, true) and IsStructureAtBase(ent) then
                return ent
            end
        end
    end
end


PEARL.AddWorldPostInit(function(world)
    if not world.components.playerspawner then
        return
    end

    local _SpawnAtLocation = world.components.playerspawner.SpawnAtLocation
    function world.components.playerspawner:SpawnAtLocation(world, player, x, y, z, isloading, ...)
        local spawned_at_base = false
        --- Do only override on first join (in this session).
        if not isloading and not PEARL.ServerNetwork:UserSessionExists(player.userid) then
            local structure_at_base = FindStructureAtBase(PEARL.CONFIG.BASE_SPAWNER.SPAWN_STRUCTURE_PREFABS)
            if structure_at_base ~= nil and structure_at_base.Transform then
                -- No need for the preparations since there will be spawned a temporary life zone.
                -- Prepare the spawnpoint for the new player.
                -- if structure_at_base
                --     and structure_at_base.prefab == PEARL.DEFAULT_CONFIG.BASE_SPAWNER.SPAWN_STRUCTURE_PREFABS
                --     and structure_at_base.components.fueled ~= nil
                --     and structure_at_base.components.fueled.currentfuel < TUNING.FIREPIT_FUEL_START
                -- then
                --     -- Fuel the firepit a bit before spawning the player.
                --     structure_at_base.components.fueled:InitializeFuelLevel(TUNING.FIREPIT_FUEL_START)
                -- end

                -- Ensure spawn protection is applied.
                player:AddDebuff("spawnprotectionbuff", "spawnprotectionbuff")

                local _x, _y, _z = structure_at_base.Transform:GetWorldPosition()
                if _x and _y and _z and (math.abs(x - _x) > 50 or math.abs(z - _z) > 50) then
                    repeat
                        x = _x + math.random(-5, 5)
                        z = _z + math.random(-5, 5)
                        y = _y
                    until TheWorld.Map:IsPassableAtPoint(x, 0, z)
                    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.SPAWN_AT_BASE_NEAR:format(
                        player:GetDisplayName(), structure_at_base:GetStandardizedName()
                    ), PEARL.EMOJIS.GAME_TO_DISCORD.FIREPIT)
                end
            end
        end

        -- We will lie here a bit, because intially there is no spawn FX being played,
        -- since that's usually handled by the portal. Here we do not have a portal.
        return _SpawnAtLocation(self, world, player, x, y, z, (spawned_at_base and true) or isloading, ...)
    end
end)
