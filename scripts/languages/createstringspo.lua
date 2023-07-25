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

local function PrintTranslatedStringTableV2(base, original, translated, file)
	local path

	for k, v in pairs(original) do
		path = base and base.."."..k or k

		if type(v) == "table" then
			PrintTranslatedStringTableV2(path, v, translated, file)
		else
			local msgstr = translated[path]
			if msgstr then
				msgstr = string.gsub(msgstr, "\n", "\\n")
				msgstr = string.gsub(msgstr, "\r", "\\r")
				msgstr = string.gsub(msgstr, "\"", "\\\"")
			else
				msgstr = ""
			end

			local msgid = v
			msgid = string.gsub(msgid, "\n", "\\n")
			msgid = string.gsub(msgid, "\r", "\\r")
			msgid = string.gsub(msgid, "\"", "\\\"")

			if msgid ~= "" then
				file:write("#. "..path)
				file:write("\n")
				file:write("msgctxt \""..path.."\"")
				file:write("\n")
				file:write("msgid \""..msgid.."\"")
				file:write("\n")
				file:write("msgstr \""..msgstr.."\"")
				file:write("\n\n")
			end
		end
	end
end

return function(filename, original, translated)
	if not filename then
		return error("No filename provided!")
	end

	--root = root or "STRINGS"

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

	PrintTranslatedStringTableV2("STRINGS.PEARL", original, translated, file)

	file:close()
end
