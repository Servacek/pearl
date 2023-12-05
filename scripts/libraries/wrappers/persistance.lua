--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
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

--------------------------------
-- [[ Localization ]]
--------------------------------

local TheSim = TheSim

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @class ClusterPersistance
local ClusterPersistance = {}

--------------------------------
-- [[ Getters ]]
--------------------------------

function ClusterPersistance:FileExists(fp)
    local file_exists = false
    TheSim:CheckPersistentStringExists(fp, function(exists)
        file_exists = exists
    end)

    return file_exists
end

function ClusterPersistance:GetFileContent(fp, ensure)
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

function ClusterPersistance:GetAllFileLines(fp, ensure, strip)
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

--- @param userid string
--- @param sessionid string? The ID of the target session or the newest one if not provided.
--- @return boolean exists
function ClusterPersistance:UserSessionExists(userid, sessionid)
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

--- Always does implicit ensuring of the file similiar to the "w" read mode in "io".
function ClusterPersistance:SetFileContent(fp, str, encode)
    encode = encode or false

    local s = false
    TheSim:SetPersistentString(fp, str, encode, function(success)
        s = success
    end)

    return s
end

--- Always does implicit ensuring of the file similiar to the "w" read mode in "io".
function ClusterPersistance:SetFileLines(fp, lines, encode)
    -- Start we a new line to make the file a bit more readable because of the prefix.
    return self:SetFileContent(fp, "\n"..table.concat(lines, "\n"), encode)
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

function ClusterPersistance:ForEachLineIn(fp, fn, ensure)
    if self:FileExists(fp) ~= true then
        if ensure == true then
            PEARL.info("Creating file", fp)

            return self:CreateFile(fp)
        end

        return PEARL.error("File not found!")
    end

    return TheSim:GetPersistentString(fp, function(success, str)
        if not success or type(str) ~= "string" then
            return PEARL.error("Failed to load the file!", fp)
        end

        local prefix = string.strip(PEARL.CONSTS.KLEI_DATA_PREFIX)
        for _, line in ipairs(str:split("\n")) do
            if string.strip(line) ~= prefix then
                fn(line)
            end
        end
    end)
end

function ClusterPersistance:CreateFile(fp)
    return self:SetFileContent(fp, "")
end

-- Ensures the file with the provided path exists.
function ClusterPersistance:EnsureFile(fp)
    if not self:FileExists(fp) then
        if not self:CreateFile(fp) then
            PEARL.error("Failed to create file", fp)
            return false
        end
    end

    return true
end

function ClusterPersistance:LoadLuaFile(fp, ensure, env)
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

--------------------------------
-- [[ Return ]]
--------------------------------

return ClusterPersistance
