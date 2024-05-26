--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--------------------------------------
-- [[ Constants ]]
--------------------------------------

local PATH_TEMPLATE = "../../%s"
local COMMENT_PREFIX = "//"
local ESCAPE_PREFIX = "\\"
local TITLE_PREFIX = "#"
local VERSION_PREFIX = "@v"
local LMT_PREFIX = "@>"

local COMMENT_SUBITLES = [[
// This is a file used for storing content for UI screens.
// You can specify the version of this file by typing @v{YOUR_VERSION}.

// Lines starting with "//" will be automatically ignored when parsing this file (so this text will be ignored as well).

// The "KLEI     1" text in the first line is just a way Klei marks their files. This will be
// ignored and can be removed if needed.

// The first line starting with a '#' will be the initial title of the screen.
// The following lines starting with a '#' will be displayed as subtitles.

// You can also specify the last update time of the file.
]]

local COMMENT = [[
// This is a file used for storing content for UI screens.

// Lines starting with "//" will be automatically ignored when parsing this file (so this text will be ignored as well).

// The "KLEI     1" text in the first line is just a way Klei marks their files. This will be
// ignored and can be removed if needed.

// The first line starting with a '#' will be the initial title of the screen.
// Following lines will be the body text.
]]

--------------------------------------
-- [[ Locals ]]
--------------------------------------

return function(fname, create_if_needed, subtitles)
    local file_exists
    local abs_path = PATH_TEMPLATE:format(fname)
    TheSim:CheckPersistentStringExists(abs_path, function(exists)
        file_exists = exists

        if exists == true then
            return
        end

        if create_if_needed == true then
            PEARL.info("Creating file", fname)

            return TheSim:SetPersistentString(abs_path, "\n"..(
                subtitles and COMMENT_SUBITLES or COMMENT
            ))
        end

        return PEARL.error("File not found!")
    end)

    if not file_exists then
        return
    end

    --- @type table<string, string>?
    local open_section
    local version
    local lmt

    --- @type table<string, string>
    local result = {}

    local function RemoveLinePrefix(line, prefix)
        return line:rtake(#line - #prefix)
    end

    local function AddSection(tbl, title, description)
        tbl[#tbl + 1] = {
            title = title,
            description = description,
        }

        open_section = tbl[#tbl]
    end

    local function ParseLine(tbl, raw_line)
        local line = raw_line:strip()

        if line == "" and not open_section then
            return -- Ignore leading new lines and spaces
        end

        -- Comments
        if line:startswith(COMMENT_PREFIX) then
            return
        end

        if line:startswith(VERSION_PREFIX) and not version then
            version = RemoveLinePrefix(line, VERSION_PREFIX)
        end

        if line:startswith(LMT_PREFIX) and not lmt then
            lmt = RemoveLinePrefix(line, LMT_PREFIX)
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
        if type(open_section) == "table" then
            if type(open_section.description) ~= "string" then
                open_section.description = line
            else
                open_section.description = open_section.description.."\n"..line
            end
        end
    end

    PEARL.ClusterPersistence:ForEachLineIn(abs_path, function(line)
        ParseLine(result, line)
    end)

    if IsTableEmpty(result) then
        return
    end

    result.version = version
    result.lmt = lmt -- Since the file is in the cluster folder, we cannot use "io.fmtime" :/

    return result
end
