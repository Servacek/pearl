
local function CheckForTripleMacTusk(taskset)
	-- check if caves, if so then exit
	if not GetModConfigData("FORCE_MACTUSK") or taskset.location ~= "forest" then
		return
	end

    if not table.contains(taskset.tasks, "The hunters") then
		SUB.info("WorldGen", "Forcing triple mactusk to be generated on the new world!")
        table.insert(taskset.tasks, "The hunters")
    end
end

------------------------------

AddTaskSetPreInitAny(CheckForTripleMacTusk)
