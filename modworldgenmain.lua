--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


-- Note: This loads before modmain.lua

-- During world generation process TheNet and TheSim are nil.
-- Also worldgen_main.lua is loaded at that time so we are missing it's environment.
if GLOBAL.rawget(GLOBAL, "TheNet") or GLOBAL.rawget(GLOBAL, "TheSim") then
    return
end

----------------------------------
-- Constants
----------------------------------

local SEED_PATH = MODROOT.."data/seed.txt"

local wg_overrides
local _, gen_params = GLOBAL.pcall(GLOBAL.json.decode, GLOBAL.GEN_PARAMETERS)
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

----------------------------------
-- Seed
----------------------------------

local io = GLOBAL.io
local tonumber = GLOBAL.tonumber

local SEED = tonumber(GetModConfigData("SEED") or nil)
local rf = io.open(SEED_PATH, "r")
if rf then
    local content = rf:read()
    rf:close()

    SEED = tonumber(content) or SEED

    -- Clear the file, this is just an single-use seed.
    local wf = io.open(SEED_PATH, "w")
    if wf then
        wf:close()
    end
end

if SEED ~= nil then
    print("[PEARL] Using configured world seed ", SEED)
    GLOBAL.rawset(GLOBAL, "SEED", SEED)
end

------------------------------

if wg_overrides then do
    local taskset_name = (wg_overrides and wg_overrides.task_set) or "default"
    --- @type table?
    local required_tasks = GetModConfigData("REQUIRED_WORLDGEN_TASKS")
    if type(required_tasks) ~= "table" or GLOBAL.next(required_tasks) == nil then
        return
    end

    print("[PEARL] Applying required tasks for", taskset_name)
    AddTaskSetPreInit(taskset_name, function(taskset)
        for _, task_name in ipairs(required_tasks) do
            RequireTaskInTaskSet(taskset, task_name)
        end
    end)
end end
