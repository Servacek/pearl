--[[
Copyright (c) 2023 Fi7iP
The Czechoslovakian Don't Starve Together Game Comunity
<https://discord.gg/RHzJxut>

This file is part of the 'Pearl'.

The source code of this program and all its parts are shared under
the RECEX SHARED SOURCE LICENSE (version 1.0).
This is NOT Free and Open Source software, and the code is
NOT redistributable without permission of the author(s).
The source code licensed under this license is shared "as is" and does
not come with any warranty including the implied warranty of merchandise.
Read the RECEX SHARED SOURCE LICENSE for details.

You should have received a copy of the RECEX SHARED SOURCE LICENSE
in the form of a LICENSE file in the root of the source directory.
If not, please refer to
<https://raw.githubusercontent.com/Recex/Licenses/master/SharedSourceLicense/LICENSE.txt>

You can contact the author(s) at
<https://steamcommunity.com/profiles/76561198339302667/>
--]]



-- Note: This loads before modmain.lua

-- During world generation process TheNet and TheSim are nil.
-- Also worldgen_main.lua is loaded at that time so we are missing it's environment.
if GLOBAL.rawget(GLOBAL, "TheNet") or GLOBAL.rawget(GLOBAL, "TheSim") then
    return
end

----------------------------------
-- Contants
----------------------------------

-- local LOCATION_TYPE = {
--     FOREST = "forest",
--     CAVES  = "cave",
-- }

local wg_overrides
local gen_params = GLOBAL.json.decode(GLOBAL.GEN_PARAMETERS)
if gen_params then
    wg_overrides = gen_params.level_data and gen_params.level_data.overrides or nil
end

----------------------------------
-- Required Setpieces
----------------------------------

local function RequireTaskInTaskSet(taskset, task_name)
    if type(taskset) ~= "table" then
        taskset.tasks = {}
    elseif table.contains(taskset.tasks, task_name) then
        return
    end

    if not table.contains(taskset.optionaltasks, task_name) then
        return print("[PEARL] [WorldGen] Warning:", task_name, " doesn't exist or is already required in takset", taskset.name)
    end

    print("[PEARL] [WorldGen] Forcing task", task_name, "for taskset", taskset.name)
    table.insert(taskset.tasks, task_name)
end

--- @deprecated This can be set directly via leveldataoverrides.lua
-- local function AddRequiredSetpiece(name)
-- 	AddLevelPreInitAny(function(level)
--         if not level.required_setpieces or table.contains(level.required_setpieces, name) then
--             return
--         end

--         print("[PEARL] [WorldGen] Setting setpiece", name, "as required!")
--         table.insert(level.required_setpieces, name)
-- 	end)
-- end

------------------------------

if wg_overrides then
    local taskset_name = (wg_overrides and wg_overrides.task_set) or "default"
    local required_tasks = GetModConfigData("REQUIRED_WORLDGEN_TASKS")

    print("[PEARL] Applying required tasks for", taskset_name)
    AddTaskSetPreInit(taskset_name, function(taskset)

        for _, task_name in ipairs(required_tasks) do
            RequireTaskInTaskSet(taskset, task_name)
        end
    end)
end

----------------------------------
-- Seed
----------------------------------

print("[PEARL] Using configured world seed...")
GLOBAL.rawset(GLOBAL, "SEED", GetModConfigData("SEED") or GLOBAL.rawget(GLOBAL, "SEED"))
