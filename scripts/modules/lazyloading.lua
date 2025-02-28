--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--Thanks NSimplex!

--[[
-- Receives a Prefab object, and tweaks its entity constructor ("fn") to
-- make the prefab be loaded before it is spawned.
--]]

local Prefabs = _G.Prefabs

local _LoadPrefabs

local function MakeLazyLoader(prefab)
    -- Whether the prefab is already being lazy loaded.
    if prefab._lazy then
        return
    end

    local fn = prefab.fn
    if type(fn) ~= "function" then
		-- Prefab's without a .fn get loaded immediatly, since its just assets for Skins
		return _LoadPrefabs(TheSim, {prefab.name})
    end

    local current_fn

    local function new_fn(...)
        PEARL.debug("LAZY LOADING PREFAB", prefab.name)

        _LoadPrefabs(TheSim, {prefab.name})

        -- Ensures this only runs once, for efficiency.
        current_fn = fn

        return fn(...)
    end

    current_fn = new_fn

    --[[
    -- This extra layer of indirection ensures greater mod friendliness.
    --
    -- If we just set prefab.fn to new_fn, and later back to fn, we could
    -- end up overriding an fn patch done by another mod. By switching between
    -- the two internally, via the current_fn upvalue, we preserve any such
    -- patching.
    --]]
    prefab.fn = function(...)
        -- This is being modified from inside.
        return current_fn(...)
    end

    prefab._lazy = true
end

------------------------------------------------------------------------

-- Mod prefabs are being loaded first.
-- All these prefabs are being loaded only on the first launch.
_LoadPrefabs = PEARL.AddUserDataFunctionPreCall("LoadPrefabs", function(self, prefabs)
    for _, prefab in ipairs(prefabs) do
        local p = Prefabs[prefab]
        if not p then
            _LoadPrefabs(self, {prefab})
        else
            MakeLazyLoader(p)
        end
    end

    return false -- Override
end, TheSim)
