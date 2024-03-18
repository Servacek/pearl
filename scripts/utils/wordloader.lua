--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--[[
    A small helper tool for the profanity filter. Returns a function
    with two parameters (input file and output file) capable of creating
    a valid dictionary of filtered words for the built in profanity filter.

    NOTE:
        - The input file needs to contain the words
          separated with a new line character.
        - The output file should a be a lua file
          since the output string itself is in lua.
--]]

local io = io
local PEARL = PEARL

return function(ifile, ofile)
    -- Search for the file in the local data directory
    local rfile = io.open(MODROOT..""..PEARL.DATA_DIR_NAME.."/"..ifile, "r")
    if not rfile then
        return PEARL.error("File not found!")
    end

    local wfile = io.open(PEARL.SRCDIR.."languages/filters/"..ofile, "w")
    if wfile == nil then
        return PEARL.error("File not found!")
    end

    wfile:write("return {\n    loose_match = {\n")
    for word in rfile:lines() do
        word = word:gsub("%s", "")

        local _, errmsg = wfile:write(
            "        \""..PEARL.EncodeKleiData(word), "\",\n"
        )

        if errmsg ~= nil then
            return PEARL.error("Error", "Couldn't write to the word file:\n", errmsg)
        end
    end
    wfile:write("    }\n}")

    wfile:close()
    rfile:close()

    PEARL.info("Success!")
end
