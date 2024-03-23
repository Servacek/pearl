--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--- @category Backend/Frontend

--[[
    Class for managing global save files in the "data" folder of the game.
    Similiar to ClusterPersistance but these files are per machine rather than per server.

    Also since these can use the builtin Lua IO library, it allows for more flexibility.
--]]

local CustomDataDumper = PEARL.loadfile("utils/datadumper")

--------------------------------
-- [[ Constants ]]
--------------------------------

local DEFAULT_LOADING_ENV = {
    setmetatable = setmetatable,
}

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @class ModPersistance
local ModPersistance = {}

--------------------------------
-- [[ Getters ]]
--------------------------------

function ModPersistance:FileExists(fp)
    return io.exists(fp)
end

function ModPersistance:GetFileContent(fp, ensure)
    if ensure and not self:EnsureFile(fp) then
        return false
    end

    local result, success
    TheSim:GetPersistentString(fp, function(successfull, str)
        success = successfull
        result = str
    end)

    return success, result
end

function ModPersistance:GetRootDirectoryPath()
    return PEARL.CONFIG.DATA_ROOT_DIRECTORY
end

function ModPersistance:GetAllFileLines(fp, ensure, strip)
    local lines = {}
    self:ForEachLineIn(fp, function(line)
        if strip == true then
            local stripped = string.strip(line)
            if #stripped > 0 then
                lines[#lines + 1] = stripped
            end
        else
            lines[#lines + 1] = line
        end
    end, ensure)

    return lines
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

function ModPersistance:CreateFile(fp)
    return io.create(fp)
end

function ModPersistance:EnsureFile(fp)
    return io.ensure(fp)
end

--- Always does implicit ensuring of the file.
--- @param fp string Path to the file for writing.
--- @param ... any
--- @return boolean, string?
function ModPersistance:WriteToFile(fp, ...)
    -- Klei has some weird checks here when opening files with special characters in path.
    -- This throws an error when the path cotains a ':' for example.
    local _, wf, errmsg
    wf, errmsg = io.open(fp, "w")
    if wf then
        _, errmsg = wf:write(...)
        wf:close()

        return errmsg == nil, errmsg
    end

    return false, errmsg
end

--- @return string?
function ModPersistance:ReadFromFile(fp, ensure)
    if ensure == true and io.ensure(fp) then
        return
    end

    local rf = io.open(fp, "r")
    if rf then
        local content = rf:read("*a")
        rf:close()

        return content
    end
end

--- @return boolean
function ModPersistance:SaveDataToFile(fp, data, ensure, encode)
    if ensure == true then
        io.ensure(fp)
    end

    local data_str
    if PEARL.CONFIG.DEBUG_MODE then
        -- In debug mode, we use datadumper with identation for better readability.
        data_str = CustomDataDumper(data, nil, false, 2, true)
    else
        local success, str = pcall(json.encode, data)
        if not success or type(str) ~= "string" then
            return false
        end

        data_str = str
    end

    if encode == true and data_str then
        data_str = TheSim:ZipAndEncodeString(data_str)
    end

    if type(data_str) ~= "string" then
        return false
    end

    return self:WriteToFile(fp, data_str)
end

--- @return table?
function ModPersistance:LoadDataFromFile(fp, ensure)
    local str = self:ReadFromFile(fp, ensure)
    if type(str) ~= "string" then
        return
    end

    -- Decoding and un-encoded string should return nil
    local decoded = TheSim:DecodeAndUnzipString(str)
    str = decoded and #decoded > 0 and decoded or str

    local success, data = pcall(json.decode, str)
    if not success or type(data) ~= "table" then
        local _, result
        local fn = loadstring(str)
        if type(fn) == "function" then
            _, result = RunInEnvironmentSafe(fn, DEFAULT_LOADING_ENV)
        end

        if type(result) ~= "table" then
            return
        end

        data = result
    end

    return data
end

--------------------------------
-- [[ Return ]]
--------------------------------

return ModPersistance
