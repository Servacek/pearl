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

--- @class PersistentUserIDList
local PersistentUserIDList = PEARL.Class(Library, function(self, path, ensure)
    assert(type(path) == "string", "Invalid filepath provided for ClusteridList!")

    --- @type table<string, boolean>
    self._path = path

    --- @type boolean
    --- Make these files ensured by default,
    --- so we do not need to remember their names and create them manually.
    self._ensure = ensure ~= false

    --- @type fun(self: PersistentUserIDList)?
    self._loadfn = nil

    --- @type fun(self: PersistentUserIDList)?
    self._savefn = nil

    --- @type fun(self: PersistentUserIDList, id: string, ...: any)?
    self._removefn = nil

    --- @type fun(self: PersistentUserIDList, id: string, ...: any)?
    self._addfn = nil

    --- @type table<string, boolean>
    self._ids  = {}

    -------------------

    self._RPC_NAME_ADD       = self._path.."_ADD"
    self._RPC_NAME_REMOVE    = self._path.."_REMOVE"

    PEARL.AddShardRPCHandler(self._RPC_NAME_ADD, function(shardid, id, ...)
        PEARL.debug("[RPC] Add", id)
        self:AddLocal(id)

        if type(self._addfn) == "function" and id then
            self._addfn(self, id, ...)
        end
    end)

    PEARL.AddShardRPCHandler(self._RPC_NAME_REMOVE, function(shardid, id, ...)
        PEARL.debug("[RPC] Remove", id)
        self:RemoveLocal(id)

        if type(self._removefn) == "function" and id then
            self._removefn(self, id, ...)
        end
    end)
end)

--------------------------------------
-- [[ Setters ]]
--------------------------------------

--- @param fn fun(self: PersistentUserIDList)? The custom load function for this list.
function PersistentUserIDList:SetLoadFn(fn)
    self._loadfn = fn
end

--- @param fn fun(self: PersistentUserIDList)? The custom save function for this list.
function PersistentUserIDList:SetSaveFn(fn)
    self._savefn = fn
end

--- @param fn fun(self: PersistentUserIDList, id: string, ...: any)? The add handler for this list.
function PersistentUserIDList:SetAddFn(fn)
    self._addfn = fn
end

--- @param fn fun(self: PersistentUserIDList, id: string, ...: any)? The add handler for this list.
function PersistentUserIDList:SetRemoveFn(fn)
    self._removefn = fn
end

--------------------------------------
-- [[ Getters ]]
--------------------------------------

--- @return table<string, boolean>
function PersistentUserIDList:Get()
    return self._ids
end

--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return boolean contains Whether the given identifier is on the list.
function PersistentUserIDList:Contains(id)
    return self._ids[id] == true
end

--------------------------------------
-- [[ Public Methods ]]
--------------------------------------

--- Adds the given ID to the local AND networked table.
--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return boolean result Whether the action was successfull or not.
function PersistentUserIDList:Add(id, ...)
    PEARL.debug("PersistentUserIDList:Add", id, self._path)

    if self:AddLocal(id) then
        if TheShard:IsMaster() then
            self:Save()
        end

        if type(self._addfn) == "function" and id then
            self._addfn(self, id, ...)
        end

        self:AddGlobal(id, ...)

        return true
    end

    return false
end

--- Adds the given ID only to the local table.
--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return boolean result Whether the action was successfull or not.
function PersistentUserIDList:AddLocal(id)
    if type(id) == "string" and self._ids[id] ~= true then
        self._ids[id] = true
        return true
    end

    return false
end

function PersistentUserIDList:AddGlobal(id, ...)
    PEARL.BroadcastRPCToConnectedShards(PEARL.RPC[self._RPC_NAME_ADD], id, ...)
end

--- Removes the given ID from the local AND networked table.
--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return boolean result Whether the action was successfull or not.
function PersistentUserIDList:Remove(id)
    PEARL.debug("PersistentUserIDList:Remove", id, self._path)

    if self:RemoveLocal(id) then
        if TheShard:IsMaster() then
            self:Save()
        end

        if type(self._removefn) == "function" and id then
            self._removefn(self, id)
        end

        self:RemoveGlobal(id)

        return true
    end

    return false
end


--- Removes the given ID only from the local table.
--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return boolean result Whether the action was successfull or not.
function PersistentUserIDList:RemoveLocal(id)
    if type(id) == "string" and self._ids[id] ~= nil then
        self._ids[id] = nil

        return true
    end

    return false
end

function PersistentUserIDList:RemoveGlobal(id, ...)
    PEARL.BroadcastRPCToConnectedShards(PEARL.RPC[self._RPC_NAME_REMOVE], id, ...)
end

function PersistentUserIDList:Load()
    PEARL.debug("PersistentUserIDList:Load", self._path)

    if not PEARL.ModPersistance:FileExists(self._path) and self._ensure ~= true then
        return PEARL.info(self._path, "not found -> skipping this file...")
    end

    if type(self._loadfn) == "function" then
        return self._loadfn(self)
    end

    local lines = PEARL.ModPersistance:GetAllFileLines(self._path, self._ensure, true)
    for _, id in ipairs(lines) do
        self:AddLocal(id)
    end
end

function PersistentUserIDList:Save()
    PEARL.debug("ModPersistance:Save", self._path)

    if type(self._savefn) == "function" then
        return self._savefn(self)
    end

    PEARL.ModPersistance:SetFileLines(self._path, table.keys(self._ids))
end

function PersistentUserIDList:Clear()
    for id, _ in pairs(self._ids) do
        self:RemoveLocal(id)
    end
end

function PersistentUserIDList:Reload()
    self:Clear()
    self:Load()
end

--------------------------------------
-- [[ Debugging ]]
--------------------------------------

function PersistentUserIDList:DisplayDebugInfo()
    table.dump(self._ids)
end

--------------------------------------
-- [[ Return ]]
--------------------------------------

return PersistentUserIDList
