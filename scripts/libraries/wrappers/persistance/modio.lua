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
local Persistance = PEARL.loadlib("wrappers/persistance/persistance")

--------------------------------
-- [[ Constants ]]
--------------------------------

local DEFAULT_LOADING_ENV = {
    setmetatable = setmetatable,
}

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @class ModPersistance: Persistance
local ModPersistance = {}
setmetatable(ModPersistance, { __index = Persistance })

--------------------------------
-- [[ Getters ]]
--------------------------------

function ModPersistance:FileExists(fp)
    return io.exists(fp) == true
end

function ModPersistance:GetFileContent(fp, ensure)
    return self:ReadFromFile(fp, ensure)
end

function ModPersistance:GetRootDirectoryPath()
    return PEARL.CONFIG.DATA_ROOT_DIRECTORY
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

function ModPersistance:CreateFile(fp)
    return io.create(fp)
end

--- Creates the file with the given path if it doesn't exist.
--- @return boolean success True if file exists or was created otherwise false.
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

--- @return boolean, string?, string?
function ModPersistance:ReadFromFile(fp, ensure)
    if ensure == true and not io.ensure(fp) then
        return false, nil, "file could not be ensured"
    end

    local rf, open_error = io.open(fp, "r")
    if rf then
        local content, errmsg = rf:read("*a")
        rf:close()

        if type(content) == "string" then
            return true, content
        end

        return false, nil, errmsg or "file could not be read"
    end

    return false, nil, open_error or "file could not be opened"
end

--- @return boolean
function ModPersistance:SaveDataToFile(fp, data, ensure, encode)
    if ensure == true then
        io.ensure(fp)
    end

    local data_str
    if PEARL.CONFIG.DEBUG_MODE then
        -- In debug mode, we use datadumper with identation for better readability.
        -- The DataDumper seems to be pretty unreliable so this is recommended only for debugging.
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

--- @param fp filepath Starting from the <GAME INSTALL DIR>\data directory
--- @param ensure? boolean Whether to create the file that's being loaded if it doesn't exist.
--- @return table?
function ModPersistance:LoadDataFromFile(fp, ensure)
    local success, raw_str = self:ReadFromFile(fp, ensure)
    if not success or type(raw_str) ~= "string" then
        return
    end

    -- Try to JSON decode the raw string first.
    local success, data = pcall(json.decode, raw_str)
    if not success or type(data) ~= "table" then
        PEARL.debug("Failed to JSON decode the raw string, trying to unzip it first...")
        local decoded_str = TheSim:DecodeAndUnzipString(raw_str)
        success, data = pcall(json.decode, decoded_str)
    end

    -- If everything fails, last attempt is to interpret the raw_string as Lua.
    if not success or type(data) ~= "table" then
        PEARL.debug("Everything has failed so far! Trying to deseperately interpret it as Lua...")
        local fn, errmsg = loadstring(raw_str)
        if type(fn) == "function" then
            local ok, result = RunInEnvironmentSafe(fn, DEFAULT_LOADING_ENV)
            if ok == true and type(result) == "table" then
                return result
            end
        end

        PEARL.debug("Failed to load the provided file completely.", errmsg)
        return -- nil on total failure
    end

    return data
end

--------------------------------
-- [[ Return ]]
--------------------------------

return ModPersistance
