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
    PEARL.debug("Persistence:SaveDataToFile", path)
    local data_str, success = nil, true
    if PEARL.CONFIG.DEBUG_MODE then
        -- In debug mode, we use datadumper with identation for better readability.
        data_str = CustomDataDumper(data, nil, false, 2, true)
    else
        success, data_str = pcall(json.encode, data)
    end

    if not success or type(data_str) ~= "string" then
        return false
    end

    return self:SetFileContent(path, data_str, encode)
end

--- @return table?
function Persistence:LoadDataFromFile(path, ensure)
    PEARL.debug("Persistence:LoadDataFromFile", path, ensure)
    local str = self:GetFileContent(path, ensure)
    if type(str) ~= "string" then
        return
    end

    -- trying undecoded
    local success, data = pcall(json.decode, str)
    if success and type(data) == "table" then
        return data
    end

    -- trying decoded
    local decoded_str = TheSim:DecodeAndUnzipString(str)
    success, data = pcall(json.decode, decoded_str)
    if success and type(data) == "table" then
        return data
    end

    local _, result
    --- There seems to be some bug in the DataDumper that causes a redundant coma in an empty array.
    str = str:gsub("{[\n%s]*,[\n%s]*}", "{}")
    decoded_str = decoded_str:gsub("{[\n%s]*,[\n%s]*}", "{}")
    local fn = loadstring(str) or loadstring(decoded_str)
    if type(fn) == "function" then
        _, result = RunInEnvironmentSafe(fn, DEFAULT_LOADING_ENV)
    end

    if type(result) ~= "table" then
        return
    end

    return result
end

--------------------------------
-- [[ Return ]]
--------------------------------

return Persistence
