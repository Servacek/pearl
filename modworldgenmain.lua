-- Note: this file is loaded before modmain.lua so SUB is not declared here yet

local function CheckForTripleMacTusk(taskset)
    if not GetModConfigData("FORCE_MACTUSK") or taskset.location ~= GLOBAL.DEFAULT_LOCATION then
        return
    end

    if not table.contains(taskset.tasks, "The hunters") then
        print("[WorldGen] Forcing triple mactusk to be generated on the new world!")
        table.insert(taskset.tasks, "The hunters")
    end
end

------------------------------

AddTaskSetPreInitAny(CheckForTripleMacTusk)
