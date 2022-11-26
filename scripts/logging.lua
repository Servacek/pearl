
local TheSim = TheSim
local PEARL = PEARL
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
local SOURCE_PATTERN = "[%s]:%d ->"
local PATTERN = "["..HEADER_NAME.."] [%s] %s%s"

---------------------------
-- [[ Local Functions ]]
---------------------------

local function get_file_name(filepath)
    return type(filepath) == "string" and filepath:match("[^/]*.lua$")
    or "unknown"
end

local function get_debug_header()
    local info = debug.getinfo(3, "Sl")
    local source_filename = get_file_name(info.source)

    return string.format(
        SOURCE_PATTERN, source_filename, info.currentline
    )
end

---------------------------
-- [[ Logging Utils ]]
---------------------------

function PEARL.log(level, class, ...)
    local args = toarrayornil(...)
    if not args and class then
        args = class
        class = nil
    end

    level = level and tostring(level) or LOG_LEVELS.INFO
    class = class and tostring(class).." " or ""

    local content = ""
    if type(args) == "table" then
        for i = 1, #args do
            content = content..tostring(args[i]).." "
        end
    else
        content = tostring(args)
    end

    -- Using the lower level engine function for more control
    TheSim:LuaPrint(PATTERN:format(
        level, class, content
    ))
end

---------------------------
-- Wrappers for SUB.log
-- 'debug' and 'error' levels do not support custom class.

function PEARL.debug(...)
    if not PEARL.CONFIG.DEBUG_MODE then
        return
    end

    return PEARL.log(LOG_LEVELS.DEBUG, get_debug_header(), ...)
end

function PEARL.info(class, ...)
    return PEARL.log(LOG_LEVELS.INFO, class, ...)
end

function PEARL.warn(class, ...)
    return PEARL.log(LOG_LEVELS.WARN, class, ...)
end

function PEARL.error(...)
    return PEARL.log(LOG_LEVELS.ERROR, get_debug_header(), ...)
end
