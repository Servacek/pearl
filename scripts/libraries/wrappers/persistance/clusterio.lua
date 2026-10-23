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

--------------------------------
-- [[ Localization ]]
--------------------------------

local TheSim = TheSim
local Persistance = PEARL.loadlib("wrappers/persistance/persistance")

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @class ClusterPersistance: Persistance
local ClusterPersistance = {}
setmetatable(ClusterPersistance, { __index = Persistance })

--------------------------------
-- [[ Getters ]]
--------------------------------

function ClusterPersistance:FileExists(fp)
    local file_exists = false
    TheSim:CheckPersistentStringExists(fp, function(exists)
        file_exists = exists
    end)

    return file_exists == true
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

function ClusterPersistance:GetRootDirectoryPath()
    return "." -- TODO? This is mainly for compatibility with ModPersistance
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

--------------------------------
-- [[ Return ]]
--------------------------------

return ClusterPersistance
