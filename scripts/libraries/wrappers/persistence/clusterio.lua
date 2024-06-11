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
    Class for managing save files inside a server's cluster and it's shard folders.
    It can be also used for modifying files inside the client's cluster probably.

    Acts as a wrapper for the default async-like TheSim file handlers
    making them synchronous.
--]]

local Persistence = PEARL.loadfile("libraries/wrappers/persistence/persistence")

--------------------------------
-- [[ Localization ]]
--------------------------------

local TheSim = TheSim

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @class ClusterPersistence: Persistence
local ClusterPersistence = deepcopy(Persistence)

--------------------------------
-- [[ Getters ]]
--------------------------------

function ClusterPersistence:FileExists(path)
    local file_exists = false
    TheSim:CheckPersistentStringExists(path, function(exists)
        file_exists = exists
    end)

    return file_exists == true
end

--- https://forums.kleientertainment.com/klei-bug-tracker/dont-starve-together/thesimgetpersistentstring-cannot-handle-large-file-r38509/
--- @param path string Path to the file for reading.
--- @param ensure boolean? Whether to make sure the file exists or not.
--- @return string? result
function ClusterPersistence:GetFileContent(path, ensure)
    local result
    if ensure then
        self:EnsureFile(path)
    end

    TheSim:GetPersistentString(path, function(successfull, str)
        result = str
    end)

    return result
end

function ClusterPersistence:GetAllFileLines(path, ensure, strip)
    local lines = {}
    self:ForEachLineIn(path, function(line)
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

--- @param userid string
--- @param sessionid string? The ID of the target session or the newest one if not provided.
--- @return boolean exists
function ClusterPersistence:UserSessionExists(userid, sessionid)
    sessionid = sessionid or TheNet:GetSessionIdentifier()
    if type(sessionid) == "string" then
        local filepath = TheNet:GetUserSessionFile(sessionid, userid)
        return type(filepath) == "string" and self:FileExists(filepath)
    end

    return false
end

--------------------------------
-- [[ Setters ]]
--------------------------------

--- Always does implicit ensuring of the file.
--- @param path string Path to the file for writing.
--- @param content string The actual content to be set.
--- @param encode boolean? Whether to encode the content before saving or not.
--- @return boolean success, string? errmsg
function ClusterPersistence:SetFileContent(path, content, encode)
    local s = false
    TheSim:SetPersistentString(path, content, encode or false, function(success)
        s = success -- This doesn't provide any errmsgs, it prints them directly in the console if any.
    end)

    return s
end


function ClusterPersistence:SetFileLines(path, lines, encode)
    -- Start we a new line to make the file a bit more readable because of the prefix.
    return self:SetFileContent(path, "\n"..table.concat(lines, "\n"), encode)
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

function ClusterPersistence:ForEachLineIn(path, fn, ensure)
    if self:FileExists(path) ~= true then
        if ensure == true then
            PEARL.info("Creating file", path)

            return self:CreateFile(path)
        end

        return PEARL.error("File not found!")
    end

    return TheSim:GetPersistentString(path, function(success, str)
        if not success or type(str) ~= "string" then
            return PEARL.error("Failed to load the file!", path)
        end

        local prefix = string.strip(PEARL.CONSTS.KLEI_DATA_PREFIX)
        for _, line in ipairs(str:split("\n")) do
            if string.strip(line) ~= prefix then
                fn(line)
            end
        end
    end)
end

function ClusterPersistence:CreateFile(path)
    return self:SetFileContent(path, "")
end

-- Ensures the file with the provided path exists.
--- @return boolean exists, boolean created
function ClusterPersistence:EnsureFile(path)
    if not self:FileExists(path) then
        if not self:CreateFile(path) then
            PEARL.error("Failed to create file", path)
            return false, true
        end
        return true, true
    end
    return true, false
end

function ClusterPersistence:LoadLuaFile(path, ensure, env)
    if ensure and not self:EnsureFile(path) then
        return false, PEARL.error("Failed to create the file!")
    end

    local lua_str = self:GetFileContent(path, ensure)
    if type(lua_str) ~= "string" then
        return false, PEARL.error("Failed to load the given lua file!")
    end

    if type(env) == "table" then
        return RunInEnvironmentSafe(function()
            return loadstring(lua_str)()
        end, env)
    end

    return RunInSandboxSafe(lua_str)
end

--------------------------------
-- [[ Return ]]
--------------------------------

return ClusterPersistence
