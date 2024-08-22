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
    Put functions these two storage methods have in common here.
    Also try to define the functions with the same parameters.
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

--- @class Persistence
local Persistence = {}

--------------------------------
-- [[ Getters ]]
--------------------------------

--- @param path string Path to the file for reading.
--- @param ensure boolean? Whether to make sure the file exists or not.
--- @return string? result
function Persistence:GetFileContent(path, ensure)
    error("Not implemented!")
end

--------------------------------
-- [[ Setters ]]
--------------------------------

--- Always does implicit ensuring of the file.
--- @param path string Path to the file for writing.
--- @param content string The actual content to be set.
--- @param encode boolean? Whether to encode the content before saving or not.
--- @return boolean success, string? errmsg
function Persistence:SetFileContent(path, content, encode)
    error("Not implemented!")
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

--- @return boolean
function Persistence:SaveDataToFile(path, data, encode)
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

    return self:SetFileContent(path, data_str)
end

--- @return table?
function Persistence:LoadDataFromFile(path, ensure)
    local str = self:GetFileContent(path, ensure)
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

return Persistence
