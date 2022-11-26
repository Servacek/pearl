-- Note: This loads before modmain.lua

-- During world generation process TheNet and TheSim are nil.
-- Also worldgen_main.lua is loaded at that time so we are missing it's environment.
if GLOBAL.rawget(GLOBAL, "TheNet") or GLOBAL.rawget(GLOBAL, "TheSim") then
    return
end

-- local Layouts = require("map/layouts").Layouts
-- local StaticLayout = require("map/static_layout")

local wg_overrides
local gen_params = GLOBAL.json.decode(GLOBAL.GEN_PARAMETERS)
if gen_params then
    wg_overrides = gen_params.level_data and gen_params.level_data.overrides or nil
end


----------------------------------
-- Required Setpieces
----------------------------------

-- Layouts["tenticle_reeds"] = StaticLayout.Get("map/static_layouts/tenticle_reeds")

-- local reed_trap_tasks = {
--     "Squeltch",
--     "Lots-o-Spiders",
--     "Lots-o-Tentacles",
--     "Merms ahoy",
-- }

local function RequireTaskInTaskSet(taskset, task_name)
    if type(taskset) ~= "table" then
        taskset.tasks = {}
    elseif table.contains(taskset.tasks, task_name) then
        return
    end

    if not table.contains(taskset.optionaltasks, task_name) then
        return print("[PEARL] Warning:", task_name, " doesn't exist or is already required in takset", taskset.name)
    end

    print("[PEARL] Forcing task", task_name, "for taskset", taskset.name)
    table.insert(taskset.tasks, task_name)
end

-- local function ForceSetPiece(name, count, tasks)
-- 	AddLevelPreInitAny(function(level)
-- 		if level.location ~= GLOBAL.DEFAULT_LOCATION then return end

-- 		if not level.required_setpieces then
-- 			level.required_setpieces = {}
-- 		end

-- 		level.required_setpieces[name] = { count = count, tasks = tasks }
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

-- AddTaskSetPreInitAny(function(taskset)
-- print("[PEARL] Initialized task -> ", taskset.name)
-- end)

-- Most likely not needed since this can be configured in leveldataoverrides.lua
-- if GetModConfigData("FORCE_REEDTRAP") then
--     -- Force Reed Trap
--     ForceSetPiece("tenticle_reeds", 3, reed_trap_tasks)
-- end

----------------------------------
-- Seed
----------------------------------

print("[PEARL] Using configured world seed...")
GLOBAL.rawset(GLOBAL, "SEED", GetModConfigData("SEED") or GLOBAL.rawget(GLOBAL, "SEED"))
