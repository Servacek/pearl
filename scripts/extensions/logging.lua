--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

-- Do not use "return PEARL.log(...)" because that counts as a tail call and doesn't provide the source info.

local TheSim = TheSim
local toarrayornil, tostring  = toarrayornil, tostring

---------------------------
-- [[ Constants ]]
---------------------------

local LOG_LEVELS = {
    ERROR   = "Error",
    WARN    = "Warn]",
    INFO    = "Info]",
    DEBUG   = "Debug",
}

local HEADER_NAME = "PEARL"
local PATTERN = "["..HEADER_NAME.."] [%s] %s"
local PATTERN_DEBUG = "["..HEADER_NAME.."] [%s] %s -> %s"

-- Keep it enabled by default if we fail to retrive the data.
local ENABLED = PEARL.CONFIG.LOGGING and PEARL.CONFIG.LOGGING.ENABLED or true

local DEBUG_FILE_PATH = PEARL.MODROOT.."logs/debug_log.txt"
local MAX_DEBUG_FILE_LEN = 10000

---------------------------
-- [[ Locals]]
---------------------------

--- @type file*?
local _debug_file
--- @type string
local _debug_file_content = ""

---------------------------
-- [[ Logging Utils ]]
---------------------------

--- @param lv string? The log level of this message.
--- @param ... any Anything you want to print out. (uses tostring)
function PEARL.log(lv, ...)
    if not ENABLED then
        return
    end

    lv = lv and tostring(lv) or LOG_LEVELS.INFO

    -- Accept nil as an argument
    local args = toarrayornil(...)
    local src = (PEARL.CONFIG.DEBUG_MODE or lv == LOG_LEVELS.ERROR) and (debug.PEARL.getsrc(5) or debug.PEARL.getsrc(4))

    local content = ""
    if type(args) == "table" then
        for i = 1, #args do
            content = content..tostring(args[i]).." "
        end
    else
        content = tostring(args)
    end

    local log = (PEARL.CONFIG.DEBUG_MODE and src) and
        PATTERN_DEBUG:format(lv, src, content) or PATTERN:format(lv, content)

    -- Using the lower level engine function for more control
    TheSim:LuaPrint(log)
    if _debug_file and (lv == LOG_LEVELS.ERROR or lv == LOG_LEVELS.WARN) then

        _debug_file:write(log.."\n")
        _debug_file:write("") -- This will flush the line.
    end
end

---------------------------
-- Wrappers for PEARL.log function

--- Does only actually log the parameters provided if the debug mode is enabled.
--- @param ... any Anything you want to log in the DEBUG level.
function PEARL.debug(...)
    if not PEARL.CONFIG.DEBUG_MODE then
        return
    end

    return PEARL.log(LOG_LEVELS.DEBUG, ...)
end

--- @param ... any Anything you want to log in the INFO level.
function PEARL.info(...)
    return PEARL.log(LOG_LEVELS.INFO, ...)
end

--- @param ... any Anything you want to log in the WARN level.
function PEARL.warn(...)
    return PEARL.log(LOG_LEVELS.WARN, ...)
end

--- @param ... any Anything you want to log on the ERROR level.
function PEARL.error(...)
    -- if PEARL.CONFIG.DEBUG_MODE then
    --     return error(msg)
    -- end

    return PEARL.log(LOG_LEVELS.ERROR, ...)
end

---------------------------
-- [[ Debug File Setup ]]
---------------------------

-- We should keep this file open until the program ends.
if PEARL.CONFIG.LOGGING.DEBUG_FILE and ENABLED and TheNet:IsDedicated() then
    local rfile = io.open(DEBUG_FILE_PATH, "r")
    if rfile then
        _debug_file_content = (rfile and rfile:read("*a") or _debug_file_content):rtake(MAX_DEBUG_FILE_LEN)
        rfile:close()
    end

    local errmsg
    _debug_file, errmsg = io.open(DEBUG_FILE_PATH, "w")

    if not _debug_file then
        PEARL.error("Failed to load the debug file!", errmsg)
        return
    end

    _debug_file:write(_debug_file_content)
end
