--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


-- WARNING: This file is being loaded from modmain.lua using require so it doesn't have
--          access to the mod's environment. Use PEARL.ENV to access it.

--[[
    Set of some basic file loaders for the mod.

    Some naming conventions:
        FILE TYPES:
        - loadscript  - just loads the script file and returns it as a callable function.
        - runscript   - runs the file and returns the results.

        SCRIPT TYPES:
        - internscript - script file inside this mod's root folder (scripts folder specifically)
        - externscript - script file outside mod's root folder (probably another mod)
        - gamescript - script file inside the game's "scripts" folder
--]]

--------------------------------
-- [[ Constants ]]
--------------------------------

local SCRIPT_FILE_EXTENSION = ".lua"
local INTERNAL_SCRIPTS_DIR = PEARL.SRCDIR

--------------------------------
-- [[ Private Variables ]]
--------------------------------

-- Caches for storing results of Lua script file executions, since
-- the files rarely change during runtime.
-- Storing only run results since loading is quite fast.
-- local _run_cache = {}

--------------------------------
-- [[ Private ]]
--------------------------------

-- Add the extensions if not provided
local function _ensure_script_file_extension(path)
    if path:utf8sub(-SCRIPT_FILE_EXTENSION:len()) ~= SCRIPT_FILE_EXTENSION then
        path = path..SCRIPT_FILE_EXTENSION
    end

    return path
end

-- Make sure the path points to a file inside our internal file structure.
local function _internalize_script_path(path)
    -- Make sure the path is "absulute" for the game (starts from the "data" directory)
    if path:utf8sub(-INTERNAL_SCRIPTS_DIR:len()) ~= INTERNAL_SCRIPTS_DIR then
        path = INTERNAL_SCRIPTS_DIR..path
    end

    return path
end

--------------------------------
-- [[ Public ]]
--------------------------------

--- @param path string Path to the target file starting from the mod's scripts dir (do not add '.lua' postfix)
--- @param errcb function? The error handler this file.
--- @return function? fn The function of the file's global scope or nil if the file was not found.
local function loadscript(path, errcb)
    local path_with_extension = _ensure_script_file_extension(path)

    -- fn is nil when the file was not found
    local fn = kleiloadlua(path_with_extension)
    if type(fn) ~= "function" then
        local reason = tostring(fn or "File not found!")
        -- fn should be in this case the error message
        if type(errcb) == "function" then
            errcb(reason)
            return
        else
            return error("Failed to load file "..path_with_extension.." - "..reason)
        end
    end

    return fn
end

local function load_intern_script(path, errcb)
    return loadscript(_internalize_script_path(path), errcb)
end

-- local function runscriptfn(fn, env)
--     -- This is here in case we declare there some global variables
--     -- so they do not pollute the main global environment but they go to our mod
--     -- environment instead.
--     setfenv(fn, env or PEARL.ENV)
--     _run_cache[afp] = {fn()}

--     return unpack(_run_cache[afp])
-- end

--- Run the provided script file returning it's results.
--- @param path string Path to the target file starting from the mod's scripts directory.
--- @param env table? The environment the file should be loaded with. Be default the files are loaded with the mods env.
--- @param rerun boolean? Whether the file should be reloaded from disk and rerun.
--- @param errcb function? The error handler this file.
--- @return any results Any results the target file returns after loading.
local function runscript(path, env, rerun, errcb)
    if type(package.loaded[path]) == "table" and rerun ~= true then
        return unpack(package.loaded[path]) -- Used cached if possible
    end

    local fn = loadscript(path, errcb)
    if not fn then
        return
    end

    -- The logging library doesn't have to be loaded yet.
    if PEARL.CONFIG and PEARL.CONFIG.DEBUG_MODE then
        if PEARL.debug then
            PEARL.debug("Loading mod file ->", path)
        end

        if RequiredFilesForReload then
            -- Support for DoReload()
            local ft = TheSim:GetFileModificationTime(path)
            RequiredFilesForReload[path] = ft
        end
    end

    -- This is here in case we declare there some global variables
    -- so they do not pollute the main global environment but they go to our mod
    -- environment instead.
    setfenv(fn, env or PEARL.ENV)
    package.loaded[path] = {fn()}
    return unpack(package.loaded[path])
end

--- Run the provided mod script file returning it's results.
--- Use this for loading all mod specific files to prevent any name conflicts.
--- @param path string Path to the target file starting from the mod's scripts directory.
--- @param env table? The environment the file should be loaded with. Be default the files are loaded with the mods env.
--- @param rerun boolean? Whether the file should be reloaded from disk and rerun.
--- @param errcb function? The error handler this file.
--- @return any results Any results the target file returns after loading.
local function run_intern_script(path, env, rerun, errcb)
    return runscript(_internalize_script_path(path), env, rerun, errcb)
end

-- --- @param path string Path to the target file starting from the mod's scripts dir (do not add '.lua' postfix)
-- --- @param errcb function? The error handler this file.
-- --- @param normalized boolean? Whether the path provided was normalized or not (defaults to false).
-- --- @return function? Function The function of the files global scope.
-- local function loadfilefn(path, errcb, normalized)
--     local afp = normalized and path or _internalize_script_path(path)

--     -- fn is nil when the file was not found
--     local fn = kleiloadlua(afp)
--     if type(fn) ~= "function" then
--         local reason = tostring(fn or "File not found!")
--         -- fn should be in this case the error message
--         if type(errcb) == "function" then
--             errcb(reason)
--             return
--         else
--             return error("Failed to load file "..afp.." - "..reason)
--         end
--     end

--     return fn
-- end

-- --- Loads the mod file on the given path a returns the result.
-- --- Use this for loading all mod specific files to prevent any name conflicts.
-- --- @param rfp string Path to the target file starting from the mod's scripts dir (do not add '.lua' postfix)
-- --- @param env table? The environment the file should be loaded with. Be default the files are loaded with the mods env.
-- --- @param reload boolean? Whether the file should be loaded from disk or from the cache.
-- --- @param errcb function? The error handler this file.
-- --- @return any results Any results the target file returns after loading.
-- local function loadfile(rfp, env, reload, errcb)
--     local afp = _internalize_script_path(rfp)

--     if type(_run_cache[afp]) == "table" and not reload then
--         return unpack(_run_cache[afp])
--     end

--     -- fn is nil when the file was not found
--     local fn = loadfilefn(afp, errcb, true)
--     if not fn then
--         return
--     end

--     -- The logging library doesn't have to be loaded yet.
--     if PEARL.CONFIG and PEARL.CONFIG.DEBUG_MODE then
--         if PEARL.debug then
--             PEARL.debug("Loading mod file ->", rfp)
--         end

--         -- Support for DoReload()
--         local ft = TheSim:GetFileModificationTime(afp)
--         RequiredFilesForReload[afp] = ft
--     end

--     -- This is here in case we declare there some global variables
--     -- so they do not pollute the main global environment but they go to our mod
--     -- environment instead.
--     setfenv(fn, env or PEARL.ENV)
--     _run_cache[afp] = {fn()}

--     return unpack(_run_cache[afp])
-- end

--- Loads the mods libary from the libs folder throwing an error if the returned
--- type is invalid or none.
--- @param name string Name of the library (file name).
--- @param ... any Additional paramaters to "loadfile" function.
--- @return table library The library table returned by the provided file.
local function loadlib(name, ...)
    name = tostring(name)

    local lib = loadfile(PEARL.LIBRARY_DIR_NAME.."/"..name, ...)
    if type(lib) ~= "table" then
        error("Invalid library return type!".." Library: "..name.." Type: "..type(lib))
    end

    return lib
end

--------------------------------
-- [[ Return ]]
--------------------------------

return {
    loadfilefn = loadfilefn,
    loadfile   = loadfile,
    loadlib    = loadlib,
}
