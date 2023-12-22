--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local Library = PEARL.loadfile("models/library")

--------------------------------------
-- [[ Class Declaration ]]
--------------------------------------

--- @class ClusterUserList
local ClusterUserList = PEARL.Class(Library, function(self, path, ensure)
    assert(type(path) == "string", "Invalid filepath provided for ClusterUseridList!")

    --- @type table<string, boolean>
    self._path = path

    --- @type boolean
    --- Make these files ensured by default,
    --- so we do not need to remember their names and create them manually.
    self._ensure = ensure ~= false

    --- @type fun(self: ClusterUserList)?
    self._savefn = nil

    --- @type table<string, boolean>
    self._ids  = {}
end)

--------------------------------------
-- [[ Setters ]]
--------------------------------------

--- @param fn fun(self: ClusterUserList)? The custom save function for this list.
function ClusterUserList:SetSaveFn(fn)
    self._savefn = fn
end

--------------------------------------
-- [[ Getters ]]
--------------------------------------

--- @return table<string, boolean>
function ClusterUserList:Get()
    return self._ids
end

--- @param userid string? Klei User Identifier - KU_ID
--- @return boolean contains Whether the given identifier is on the list.
function ClusterUserList:Contains(userid)
    return self._ids[userid] == true
end

--------------------------------------
-- [[ Public Methods ]]
--------------------------------------

--- @param userid string? Klei User Identifier - KU_ID
--- @return boolean result Whether the action was successfull or not.
function ClusterUserList:Add(userid)
    if type(userid) == "string" and not self._ids[userid] then
        self._ids[userid] = true
        return true
    end

    return false
end

--- @param userid string? Klei User Identifier - KU_ID
--- @return boolean result Whether the action was successfull or not.
function ClusterUserList:Remove(userid)
    if type(userid) == "string" and self._ids[userid] ~= nil then
        self._ids[userid] = nil
        return true
    end

    return false
end

function ClusterUserList:Load()
    if not PEARL.ClusterPersistance:FileExists(self._path) then
        return PEARL.info(self._path, "not found -> skipping this file...")
    end

    local lines = PEARL.ClusterPersistance:GetAllFileLines(self._path, self._ensure, true)
    for _, userid in ipairs(lines) do
        self._ids[userid] = true
    end
end

function ClusterUserList:Save()
    if type(self._savefn) == "function" then
        return self._savefn(self)
    end

    PEARL.ClusterPersistance:SetFileLines(self._path, table.values(self._ids))
end

function ClusterUserList:Clear()
    for userid, _ in pairs(self._ids) do
        self:Remove(userid)
    end
end

function ClusterUserList:Reload()
    self:Clear()
    self:Load()
end

--------------------------------------
-- [[ Return ]]
--------------------------------------

return ClusterUserList
