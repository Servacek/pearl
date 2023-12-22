--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--- @TODO: There is a bug where sometimes items in a table gets printed two times.


local PEARL = PEARL

local O_FILE_PATH = PEARL.ROOTDIR..PEARL.DATA_DIR_NAME.."/translation.po"

local function raw(str)
    return string.format("%q", str:gsub("\n", "\\n"))
end


-- Path must be an array.
local function IndexFromTotalPath(tbl, path)
    if type(tbl) ~= "table" then
        return print("[Error] IndexFromTotalPath: Table is nil!")
    end

    if type(path) == "string" then
        path = string.split(path, ".")
    end

    local value = tbl
    for i = 1, #path do
        if not value then
            break
        end

        value = rawget(value, path[i])
    end

    return value
end

local wfile
local function TranslationTableToFile(src, dist, path)
    if type(src) == "string" then
        path = src
        src = IndexFromTotalPath(_G, path)
    end

    if not wfile then
        wfile = io.open(O_FILE_PATH, "w")
        if not wfile then
            return print("[Error] Couldn't load the translation output file!")
        end

        wfile:write([[
"Language: sk\n"
"Content-Type: text/plain; charset=utf-8\n"
"Content-Transfer-Encoding: 8bit\n"
"POT Version: 2.0"
        ]], "\n")
    end

    --local found = false
    for k, v in pairs(src) do
        local path = path.."."..k

        if type(v) == "table" then
            TranslationTableToFile(v, dist, path)

        elseif not tonumber(k) then
            local translation = IndexFromTotalPath(dist, path)
            if type(translation) == "string" then
                local msgid = raw(v)
                local msgstr = raw(translation)

                wfile:write("\n",
                    "msgctxt ", raw(path), "\n",
                    "msgid ", msgid, "\n",
                    "msgstr ", msgstr, "\n"
                )
            end
        end
    end

    if not path and wfile then
        wfile:close()
        wfile = nil
    end
end

return TranslationTableToFile
