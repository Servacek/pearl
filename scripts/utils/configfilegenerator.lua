--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

local FILE_PATH = PEARL.ROOTDIR..PEARL.DATA_DIR_NAME.."/modoverrides.lua"

local function options_string(options)
    return options and table.concat(options, ", ") or ""
end

return function()
    local f, err = io.open(FILE_PATH, "w")
    if not f then
        return PEARL.error("Failed to open the result file!", err)
    end

    f:write("return {")
    for _, option in ipairs(PEARL.MOD_INFO.configuration_options) do
        local comment = option.type and option.options and "\t-- "..tostring(option.type)..": " or ""

        for i = 1, option.options and #option.options or 0 do
            option.options[i] = tostring(option.options[i])
        end

        if type(option.default) == "string" then
            -- Keep quotes
            option.default = string.raw(tostring(option.default))
        end

        local expression = tostring(option.name).." = "..tostring(option.default)
        if type(option.default) == "table" then
            expression = DataDumper(option.default, option.name, false, 4)
            comment = ""
        end

        if comment and comment ~= "" then
            comment = comment..options_string(option.options)
        end

        f:write("\n    "..expression..","..comment)
    end
    f:write("\n}")
    f:close()

    PEARL.info("Success! Config file saved at", FILE_PATH)
end
