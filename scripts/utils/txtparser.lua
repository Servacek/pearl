--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--------------------------------------
-- [[ Constants ]]
--------------------------------------

local PATH_TEMPLATE = PEARL.ROOTDIR..""..PEARL.DATA_DIR_NAME.."/%s"
local COMMENT_PREFIX = "//"
local ESCAPE_PREFIX = "/"
local TITLE_PREFIX = "#"
local VERSION_PREFIX = "@v"

--------------------------------------
-- [[ Locals ]]
--------------------------------------

--- @type table<string, string>?
local _open_section
local _version

local function RemoveLinePrefix(line, prefix)
    return line:rtake(#line - #prefix)
end

local function EnsureInputFile(fp)
    return io.create(fp)
end

local function AddSection(tbl, title, description)
    tbl[#tbl + 1] = {
        title = title,
        description = description,
    }

    _open_section = tbl[#tbl]
end

local function ParseLine(tbl, raw_line, subtitles)
    local line = raw_line:strip()

    if line:startswith(VERSION_PREFIX) and not _version then
        _version = line
    end

    -- Comments
    if line:startswith(COMMENT_PREFIX) then
        return
    end

    -- The title and subtitles
    if line:startswith(TITLE_PREFIX) and (subtitles or #tbl < 1) then
        local title = RemoveLinePrefix(line, TITLE_PREFIX):strip()
        return AddSection(tbl, title)
    end

    -- Escaped lines
    if line:startswith(ESCAPE_PREFIX) then
        line = RemoveLinePrefix(line, ESCAPE_PREFIX)
    end

    -- Descriptions
    if type(_open_section) == "table" then
        if type(_open_section.description) ~= "string" then
            _open_section.description = line
        else
            _open_section.description = _open_section.description.."\n"..line
        end
    end
end

return function(fp, create_if_needed, subtitles)
    local abs_path = PATH_TEMPLATE:format(fp)
    local rfile, errmsg = io.open(abs_path, "r")
    if not rfile then
        if create_if_needed == true then
            PEARL.info("Creating file", fp)

            EnsureInputFile(abs_path)
            return ""
        end

        return PEARL.error("File not found!", errmsg)
    end

    --- @type table<string, string>
    local result = {}

    -- strips new line characters
    for raw_line in rfile:lines() do
        ParseLine(result, raw_line, subtitles)
    end

    _open_section = nil

    result.version = _version

    return result
end
