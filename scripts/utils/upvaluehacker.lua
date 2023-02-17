--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

---------------------------------
-- [[ Global Localization ]]
---------------------------------

local debug = debug

---------------------------------
-- [[ Class Declaration ]]
---------------------------------

local UpvalueHacker = {}

---------------------------------
-- [[ Static Methods ]]
---------------------------------

function UpvalueHacker.ListUpvalues(fn)
	local info = debug.getinfo(fn, "u")
	for i = 1, (info and info.nups or 0) do
		print(debug.getupvalue(fn, i))
	end
end

function UpvalueHacker.GetUpvalue(fn, name)
	local info = debug.getinfo(fn, "u")
	for i = 1, (info and info.nups or 0) do
		local n, v = debug.getupvalue(fn, i)
		if n == name then
			return v, i
		end
	end

	error("Upvalue '"..tostring(name).."' not found!")
end

function UpvalueHacker.SetUpvalue(start_fn, new_fn, ...)
	local fn, i = UpvalueHacker.GetUpvalue(start_fn, ...)
	debug.setupvalue(fn, i, new_fn)
end

---------------------------------
-- [[ Return ]]
---------------------------------

return UpvalueHacker
