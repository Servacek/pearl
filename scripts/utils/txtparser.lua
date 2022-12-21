
--------------------------------------
-- [[ Constants ]]
--------------------------------------

local PATH_TEMPLATE = PEARL.MODROOT..""..PEARL.DATA_DIR_NAME.."/%s"
local COMMENT_PREFIX = "//"
local ESCAPE_PREFIX = "/"
local TITLE_PREFIX = "#"

--------------------------------------
-- [[ Locals ]]
--------------------------------------

--- @type table<string, string>?
local _open_section

local function RemoveLinePrefix(line, prefix)
    return line:rtake(#line - #prefix)
end

local function EnsureInputFile(filename)
    local wfile = io.open(PATH_TEMPLATE:format(filename), "w")
    return wfile and wfile:close()
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

    -- Comments
    if line:startswith(COMMENT_PREFIX) then
        return
    end

    -- The title and subtitles
    if line:startswith(TITLE_PREFIX) and (subtitles or #tbl < 1) then
        local title = RemoveLinePrefix(line, TITLE_PREFIX)
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

return function(filename, create_if_needed, subtitles)
    local rfile = io.open(PATH_TEMPLATE:format(filename), "r")
    if not rfile then
        if create_if_needed then
            EnsureInputFile()
            return ""
        end

        return PEARL.error("File not found!")
    end

    --- @type table<string, string>
    local result = {}

    -- strips new line characters
    for raw_line in rfile:lines() do
        ParseLine(result, raw_line, subtitles)
    end

    _open_section = nil

    return result
end
