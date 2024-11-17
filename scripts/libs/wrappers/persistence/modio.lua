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
    Class for managing global save files in the "data" folder of the game.
    Similiar to ClusterPersistence but these files are per machine rather than per server.

    Also since these can use the builtin Lua IO library, it allows for more flexibility.
--]]

local Persistence = PEARL.loadfile("libs/wrappers/persistence/persistence")

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @singleton
--- @class ModPersistence: Persistence
local ModPersistence = deepcopy(Persistence)

--------------------------------
-- [[ Getters ]]
--------------------------------

--- @param path string
--- @return boolean
function ModPersistence:FileExists(path)
    return io.exists(path)
end

--- @return boolean
function ModPersistence:GetRootDirectoryPath()
    return PEARL.CONFIG.DATA_ROOT_DIRECTORY
end

--- @param path string
--- @param ensure boolean Whether to make sure the file exists or not.
--- @return table<string> lines
function ModPersistence:GetAllFileLines(path, ensure, strip)
    local lines = {}
    self:ForEachLineIn(path, function(line)
        if strip == true then
            local stripped = line:strip()
            if not line:empty() then
                lines[#lines + 1] = stripped
            end
        else
            lines[#lines + 1] = line
        end
    end, ensure)

    return lines
end

--------------------------------
-- [[ Setters ]]
--------------------------------

--- @param path string Path to the file for writing.
--- @param content string The actual content to be set.
--- @param encode boolean? Whether to encode the content before saving or not.
--- @return boolean success, string? errmsg
function ModPersistence:SetFileContent(path, content, encode)
    PEARL.debug("ModPersistence:SetFileContent", path, encode)
    -- Klei has some weird checks here when opening files with special characters in path.
    -- This throws an error when the path cotains a ':' for example (this makes sense actually).
    local _, wf, errmsg, success
    wf, errmsg = io.open(path, "w")
    if not wf then
        PEARL.debug("Failed to open file in write mode!", errmsg)
        return false, errmsg
    end

    if encode == true then
        content = TheSim:ZipAndEncodeString(content)
    end

    success, errmsg = wf:write(content)
    wf:close()

    return success and errmsg == nil or false, errmsg
end

--- @param path string Path to the file for writing.
--- @param lines table<string>
function ModPersistence:SetFileLines(path, lines)
    return self:SetFileContent(path, table.concat(lines, "\n"))
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------


function ModPersistence:ForEachLineIn(path, fn, ensure)
    if ensure == true then
        self:EnsureFile(path)
    end

    for line in io.lines(path) do
        fn(line)
    end
end

function ModPersistence:CreateFile(path)
    return io.create(path)
end

function ModPersistence:EnsureFile(path)
    return io.ensure(path)
end

--- @param path string Path to the file for reading.
--- @param ensure boolean? Whether to make sure the file exists or not.
--- @return string? result
function ModPersistence:GetFileContent(path, ensure)
    PEARL.debug("ModPersistence:GetFileContent", path, ensure)
    if ensure == true and io.ensure(path) then
        return
    end

    local rf = io.open(path, "r")
    if rf then
        local content = rf:read("*a")
        rf:close()

        return content
    end
end

--------------------------------
-- [[ Return ]]
--------------------------------

return ModPersistence
