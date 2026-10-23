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
    Base class for persistence wrappers.
    Contains the methods shared by ClusterPersistance and ModPersistance.
--]]

--------------------------------
-- [[ Localization ]]
--------------------------------

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

--- @class Persistance
local Persistance = {}

--------------------------------
-- [[ Getters ]]
--------------------------------

function Persistance:GetAllFileLines(fp, ensure, strip)
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

--- @return boolean, string?
function Persistance:ReadFromFile(fp, ensure)
    return self:GetFileContent(fp, ensure)
end

--------------------------------
-- [[ Setters ]]
--------------------------------

--- Always does implicit ensuring of the file similiar to the "w" read mode in "io".
function Persistance:SetFileContent(fp, str, encode)
    if encode == true then
        str = TheSim:ZipAndEncodeString(str)
    end

    return self:WriteToFile(fp, str)
end

--- Always does implicit ensuring of the file similiar to the "w" read mode in "io".
function Persistance:SetFileLines(fp, lines, encode)
    -- Start we a new line to make the file a bit more readable because of the prefix.
    return self:SetFileContent(fp, "\n"..table.concat(lines, "\n"), encode)
end

--- Always does implicit ensuring of the file.
--- @param fp string Path to the file for writing.
--- @param ... any
--- @return boolean, string?
function Persistance:WriteToFile(fp, ...)
    local parts = {}
    for index, value in ipairs({...}) do
        parts[index] = tostring(value)
    end

    return self:SetFileContent(fp, table.concat(parts))
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

function Persistance:ForEachLineIn(fp, fn, ensure)
    local success, content = self:GetFileContent(fp, ensure)
    if not success or type(content) ~= "string" then
        return PEARL.error("Failed to load the file!", fp)
    end

    local prefix = string.strip(PEARL.CONSTS.KLEI_DATA_PREFIX)
    for _, line in ipairs(content:split("\n")) do
        if string.strip(line) ~= prefix then
            fn(line)
        end
    end

    return true
end

--- @param userid string
--- @param sessionid string? The ID of the target session or the newest one if not provided.
--- @return boolean exists
function Persistance:UserSessionExists()
    return false
end

function Persistance:CreateFile(fp)
    return self:SetFileContent(fp, "")
end

-- Ensures the file with the provided path exists.
function Persistance:EnsureFile(fp)
    if not self:FileExists(fp) then
        if not self:CreateFile(fp) then
            PEARL.error("Failed to create file", fp)
            return false
        end
    end

    return true
end

function Persistance:LoadLuaFile(fp, ensure, env)
    if ensure and not self:EnsureFile(fp) then
        return false, PEARL.error("Failed to create the file!")
    end

    local success, lua_str = self:GetFileContent(fp, ensure)
    if not success or type(lua_str) ~= "string" then
        return false, PEARL.error("Failed to load the given lua file!")
    end

    if type(env) == "table" then
        return RunInEnvironmentSafe(function()
            return loadstring(lua_str)()
        end, env)
    end

    return RunInSandboxSafe(lua_str)
end

--- @return boolean
function Persistance:SaveDataToFile(fp, data, ensure, encode)
    if ensure == true then
        self:EnsureFile(fp)
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

    if type(data_str) ~= "string" then
        return false
    end

    return self:SetFileContent(fp, data_str, encode)
end

--- @param fp filepath Starting from the <GAME INSTALL DIR>\data directory
--- @param ensure? boolean Whether to create the file that's being loaded if it doesn't exist.
--- @return table?
function Persistance:LoadDataFromFile(fp, ensure)
    local success, raw_str = self:GetFileContent(fp, ensure)
    if not success or type(raw_str) ~= "string" then
        return
    end

    -- Try to JSON decode the raw string first.
    local decoded_success, data = pcall(json.decode, raw_str)
    if not decoded_success or type(data) ~= "table" then
        PEARL.debug("Failed to JSON decode the raw string, trying to unzip it first...")
        local decoded_str = TheSim:DecodeAndUnzipString(raw_str)
        decoded_success, data = pcall(json.decode, decoded_str)
    end

    if not decoded_success or type(data) ~= "table" then
        -- If everything fails, last attempt is to interpret the raw_string as Lua.
        PEARL.debug("Everything has failed so far! Trying to desperately interpret it as Lua...")
        local fn, errmsg = loadstring(raw_str)
        if type(fn) == "function" then
            local ok, result = RunInEnvironmentSafe(fn, DEFAULT_LOADING_ENV)
            if ok == true and type(result) == "table" then
                PEARL.debug("YEAH that worked! NVM")
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

return Persistance
