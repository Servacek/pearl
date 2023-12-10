--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--[[
	Slightly modified Klei's version of PrintTranslatedStringTableV2.
	It's used for automatic updating strings from strings.lua for the currently
	used translation file.

	(Translations are kept, only new strings are added)

	ONLY USE WHEN YOU KNOW WHAT ARE YOU DOING!
--]]

local STRING_MATCH_CHAR = "%%s"

--- @param s string|stringlib
local function normalize(s)
	return (type(s) == "string" and s or ""):gsub("\n", "\\n")
			:gsub("\r", "\\r")
			:gsub("\t", "\\t")
			:gsub("\"", "\\\"")
end

local function write_text(file, path, msgid, msgstr)
	file:write("#. "..path)
	file:write("\n")
	file:write("msgctxt \""..path.."\"")
	file:write("\n")
	file:write("msgid \""..msgid.."\"")
	file:write("\n")
	file:write("msgstr \""..msgstr.."\"")
	file:write("\n\n")
end

local function getvbypath(t, path)
    --print(path)
    local value = t
    for key in path:gmatch("[^%.]+") do
        if type(value) ~= "table" then
            return nil -- If any intermediate value is not a table, return nil
        end

        value = value[key] or value[tonumber(key)]
        if value == nil then
            return nil -- If any key doesn't exist, return nil
        end
    end

    return value
end

local function WriteUntranslatedModStrings(base, original, translated, file)
    -- We are traversing the actual table from strings.lua
    -- These always start with STRINGS.PEARL
	for k, v in pairs(original) do
		local path = base and base.."."..tostring(k) or k

        -- Search for strings in our mod table that do not have translation
		if type(v) == "table" then
			WriteUntranslatedModStrings(path, v, translated, file)
		elseif translated[path] == nil then
			local msgid = getvbypath(original, path:sub(#base + 2)) or ""
			msgid = string.gsub(msgid, "\n", "\\n")
			msgid = string.gsub(msgid, "\r", "\\r")
			msgid = string.gsub(msgid, "\"", "\\\"")

			write_text(file, path, msgid, "")
		end
	end
end

local function WriteTranslatedStrings(base, original, translated, file)
    local unmatched = {}
    -- Here we traverse the translated strings.
    -- Some of these may not base in STRINGS.PEARL
	for path, msgstr in pairs(translated) do
        msgstr = normalize(msgstr)
        local msgid = normalize(getvbypath(original, path:sub(#base + 2)) or "")

        local tmatchers = #msgstr:findall(STRING_MATCH_CHAR)
        local omatchers = #msgid:findall(STRING_MATCH_CHAR)
        if tmatchers ~= omatchers then
            table.insert(unmatched, msgstr)
        end

        write_text(file, path, msgid, msgstr)
	end

    if #unmatched > 0 then
        PEARL.error("The following translation have unmatched magic characters:\n"..table.concat(unmatched, "\n"))
    end
end

return function(filename, original, translated)
	if not filename then
		return error("No filename provided!")
	end

	local file = io.open(filename, "w")
    if not file then
        return error("Failed to open the translation file!")
    end

	--Add file format info
    file:write("msgid \"\"\n")
    file:write("msgstr \"\"\n")
	file:write("\"Application: Don't Starve Together\\n\"")
	file:write("\n")
	file:write("\"POT Version: 2.0\\n\"")
	file:write("\n")
	file:write("\n")

	WriteTranslatedStrings("STRINGS", original, translated, file)
	WriteUntranslatedModStrings("STRINGS.PEARL", original.PEARL, shallowcopy(translated), file)

	file:close()
end
