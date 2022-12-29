
local TheSim = TheSim
local toarrayornil, tostring  = toarrayornil, tostring
local string = string

---------------------------
-- [[ Constants ]]
---------------------------

local LOG_LEVELS = {
    ERROR   = "Error",
    WARN    = "Warn",
    INFO    = "Info",
    DEBUG   = "Debug",
}

local HEADER_NAME = "PEARL"
local SOURCE_PATTERN = "<%s>:%d"
local PATTERN = "["..HEADER_NAME.."] [%s] %s"
local PATTERN_DEBUG = "["..HEADER_NAME.."] [%s] %s -> %s"

---------------------------
-- [[ Local Functions ]]
---------------------------

local function get_file_name(filepath)
    return type(filepath) == "string" and filepath:match("([^/]*).lua")
    or nil
end

local function get_source()
    local info = debug.getinfo(4, "Sl")
    local source_filename = get_file_name(info.source)

    if not source_filename then
        return
    end

    return SOURCE_PATTERN:format(
        source_filename, info.currentline
    )
end

---------------------------
-- [[ Logging Utils ]]
---------------------------

function PEARL.log(lv, ...)
    -- Accept nil as an argument
    local args = toarrayornil(...)
    local src = PEARL.CONFIG.DEBUG_MODE and get_source() or nil

    lv = lv and tostring(lv) or LOG_LEVELS.INFO

    local content = ""
    if type(args) == "table" then
        for i = 1, #args do
            content = content..tostring(args[i]).." "
        end
    else
        content = tostring(args)
    end

    -- Using the lower level engine function for more control
    if PEARL.CONFIG.DEBUG_MODE and src then
        return TheSim:LuaPrint(PATTERN_DEBUG:format(
            lv, src, content
        ))
    else
        return TheSim:LuaPrint(PATTERN:format(
            lv, content
        ))
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
    return PEARL.log(LOG_LEVELS.ERROR, ...)
end
