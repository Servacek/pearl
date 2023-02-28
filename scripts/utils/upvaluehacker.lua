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

--- @class UpvalueHacker
local UpvalueHacker = {}

---------------------------------
-- [[ Static Methods ]]
---------------------------------

function UpvalueHacker:PrintUpvalues(fn)
	local upvalues = self:GetUpvalues(fn)
	for name, value in pairs(upvalues) do
		print(name, value)
	end
end

function UpvalueHacker:GetUpvalues(fn)
	local upvalues = {}
	local info = debug.getinfo(fn, "u")
	for i = 1, (info and info.nups or 0) do
		local name, value = debug.getupvalue(fn, i)
		upvalues[name] = value
	end

	return upvalues
end

-- Returns all upvalues that are used by other functions in the source file.
--- @param fn function Some arbitrary accessible function located in the source file.
--- @return table<string, any> upvalues Upvalues of the source file.
function UpvalueHacker:GetSourceFileUpvalues(fn)
	local upvalues = {}

	-- Direct upvalues of the function
	local dups = self:GetUpvalues(fn)
	for n, v in pairs(dups) do
		upvalues[n] = v
		if type(v) == "function" then
			for name, upvalue in pairs(self:GetUpvalues(v)) do
				upvalues[name] = upvalue
			end
		end
	end

	return upvalues
end

function UpvalueHacker:GetUpvalueRecursively(fn, name, _visited)
	_visited = _visited or {fn = true}

	local info = debug.getinfo(fn, "u")
	-- Iterate over every upvalue of the given function
	for i = 1, (info and info.nups or 0) do
		local n, v = debug.getupvalue(fn, i) -- Get the upvalues name and value.
		if n == name then -- Is it the one we are looking for?
			return v, i
		end

		if not _visited[v] then -- Is this a new value we have never seen before?
			_visited[v] = true

			-- Is this upvalue a function containing other upvalues?
			if type(v) == "function" then
				-- Do the same for it as well
				local upv = self:GetUpvalueRecursively(v, name, _visited)
				if upv then
					return upv
				end
			end
		end
	end
end

function UpvalueHacker:GetUpsRecursively(fn, name, _visited, _ups)
	_visited = _visited or {fn = true}
	_ups = _ups or {}

	local info = debug.getinfo(fn, "u")
	-- Iterate over every upvalue of the given function
	for i = 1, (info and info.nups or 0) do
		local n, v = debug.getupvalue(fn, i) -- Get the upvalues name and value.
		if n == name then -- Is it the one we are looking for?
			_ups[fn] = i
		end

		if v and not _visited[v] then -- Is this a new value we have never seen before?
			_visited[v] = true

			-- Is this upvalue a function containing other upvalues?
			if type(v) == "function" then
				-- Do the same for it as well
				self:GetUpsRecursively(v, name, _visited, _ups)
			end
		end
	end

	return _ups
end

function UpvalueHacker:GetUpvalue(fn, name)
	local info = debug.getinfo(fn, "u")
	for i = 1, (info and info.nups or 0) do
		local n, v = debug.getupvalue(fn, i)
		if n == name then
			return v, i
		end
	end

	error("Upvalue '"..tostring(name).."' not found!")
end

function UpvalueHacker:SetUpvalue(start_fn, new_fn, name)
	local fups = self:GetUpsRecursively(start_fn, name)
	if IsTableEmpty(fups) then
		return error("No upvalues found with name", name)
	end

	for fn, i in pairs(fups) do
		debug.setupvalue(fn, i, new_fn)
	end
end

---------------------------------
-- [[ Return ]]
---------------------------------

return UpvalueHacker
