--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



-- WARNING: This files is being loaded from modmain.lua using require so it doesn't have
--          access to the mod's environment. Use PEARL.ENV to access it.

--------------------------------
-- [[ Private Variables ]]
--------------------------------

local _cache = {}

--------------------------------
-- [[ Functions ]]
--------------------------------

--- Loads the mod file on the given path a returns the result.
--- Use this for loading all mod specific files to prevent any name conflicts.
--- @param rfp string Path to the target file starting from the mod's scripts dir (do not add '.lua' postfix)
--- @return any results Any results the target file returns after loading.
local function loadfile(rfp, env)
    local afp = PEARL.SRCDIR..tostring(rfp)..".lua"

    if type(_cache[afp]) == "table" then
        return unpack(_cache[afp])
    end

    -- fn is nil when the file was not found
    local fn = kleiloadlua(afp)
    if type(fn) ~= "function" then
        return error("Failed to load file "..afp.." - "..tostring(fn or "File not found!"))
    end

    -- The logging library doesn't have to be loaded yet.
    if PEARL.CONFIG and PEARL.CONFIG.DEBUG_MODE and PEARL.debug then
        PEARL.debug("Loading mod file ->", rfp)
    end

    -- This is here in case we declare there some global variables
    -- so they do not pollute the main global environment but they go to our mod
    -- environment instead.
    setfenv(fn, env or PEARL.ENV)
    _cache[afp] = {fn()}
    return unpack(_cache[afp])
end

--------------------------------
-- [[ Functions ]]
--------------------------------

return loadfile
