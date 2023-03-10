--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
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

local function MakeLazyLoader(prefab)
    print("MakeLazyLoader", prefab)
    if type(prefab.fn) ~= "function" then
		--Prefab's without a .fn get loaded immediatly, since its just assets for Skins
        TheSim:UnloadPrefabs({prefab.name})
		TheSim:LoadPrefabs({prefab.name})
    end

    local fn = prefab.fn
    local current_fn

    local function new_fn(...)
        print("LAZY LOADING PREFAB", prefab.name)
        TheSim:UnloadPrefabs({prefab.name})
        TheSim:LoadPrefabs({prefab.name})

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
        current_fn(...)
    end
end

------------------------------------------------------------------------

-- PEARL.AddUserDataFunctionPreCall("RegisterPrefabs", function(prefab)
--     for _, dep in ipairs(prefab.deps) do
--         print("LAZY LOAD")
--         MakeLazyLoader(Prefabs[dep])
--     end

--     return false
-- end, TheSim)

-- local _LoadPrefabs
-- _LoadPrefabs = PEARL.AddUserDataFunctionPreCall("LoadPrefabs", function(self, prefabs)
--     print("TheSim:LoadPrefabs")
--     for _, prefab in ipairs(prefabs) do
--         if not Prefabs[prefab] then
--             _LoadPrefabs(TheSim, {prefab})
--         else
--             MakeLazyLoader(Prefabs[prefab])
--         end
--     end

--     return false
-- end, TheSim)

--- @TODO: Looks like this doesn't work anymore.
local ModMananger_RegisterPrefabs = ModManager.RegisterPrefabs
function ModManager.RegisterPrefabs(self, ...)
    local mod_prefabnames = {}

    local _RegisterPrefabs = PEARL.AddGlobalFunctionPreCall("RegisterPrefabs", function(...)
        error("RegisterPrefabs")
        for _, prefab in ipairs({...}) do
            for _, name in ipairs(prefab.deps) do
                table.insert(mod_prefabnames, name)
            end

            prefab.deps = {}
        end
    end)

    ModMananger_RegisterPrefabs(self, ...)

    PEARL.SetValue(_G, "RegisterPrefabs", _RegisterPrefabs)

    -- First, do a pass over recipes to extend dependencies if need be.
    for k, v in pairs(AllRecipes) do
        table.removearrayvalue(mod_prefabnames, v.name)
        if v.placer then
            table.removearrayvalue(mod_prefabnames, v.placer)
        end
    end

    for _, prefabname in ipairs(mod_prefabnames) do
        print("Registering "..prefabname)

        local prefab = Prefabs[prefabname]

        _RegisterPrefabs(prefab)

        MakeLazyLoader(prefab)

        -- This also takes care of the unloading, so there's no need to patch ModWrangler:UnloadPrefabs.
        table.insert(self.loadedprefabs, prefabname)
    end

    -- --re-reset this with modded recipes.
    RECIPE_PREFABS = {}
    for k,v in pairs(AllRecipes) do
        table.insert(RECIPE_PREFABS, v.name)
        if v.placer then
            table.insert(RECIPE_PREFABS, v.placer)
        end
    end
end
