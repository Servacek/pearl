--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- An layer of abstraction for all the user lists provided by Klei:
--- adminlist.txt, whitelist.txt, blacklist.txt and our custom allowlist.txt


local Library = PEARL.loadfile("models/library")

--------------------------------------
-- [[ Class Declaration ]]
--------------------------------------

--- @class ClusterUserList
local ClusterUserList = PEARL.Class(Library, function(self, path, ensure)
    assert(type(path) == "string", "Invalid filepath provided for ClusteridList!")

    --- @type table<string, boolean>
    self._path = path

    --- @type boolean
    --- Make these files ensured by default,
    --- so we do not need to remember their names and create them manually.
    self._ensure = ensure ~= false

    --- @type fun(self: ClusterUserList)?
    self._loadfn = nil

    --- @type fun(self: ClusterUserList)?
    self._savefn = nil

    --- @type fun(self: ClusterUserList, id: string, ...: any)?
    self._removefn = nil

    --- @type fun(self: ClusterUserList, id: string, ...: any)?
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

--- @param ids table<string, boolean>
function ClusterUserList:Set(ids)
    self._ids = ids
end

--- @param fn fun(self: ClusterUserList)? The custom load function for this list.
function ClusterUserList:SetLoadFn(fn)
    self._loadfn = fn
end

--- @param fn fun(self: ClusterUserList)? The custom save function for this list.
function ClusterUserList:SetSaveFn(fn)
    self._savefn = fn
end

--- @param fn fun(self: ClusterUserList, id: string, ...: any)? The add handler for this list.
function ClusterUserList:SetAddFn(fn)
    self._addfn = fn
end

--- @param fn fun(self: ClusterUserList, id: string, ...: any)? The add handler for this list.
function ClusterUserList:SetRemoveFn(fn)
    self._removefn = fn
end

--------------------------------------
-- [[ Getters ]]
--------------------------------------

--- @return table<string, boolean>
function ClusterUserList:Get()
    return self._ids
end

--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return boolean contains Whether the given identifier is on the list.
function ClusterUserList:Contains(id)
    return self._ids[id] == true
end

--------------------------------------
-- [[ Public Methods ]]
--------------------------------------

--- Adds the given ID to the local AND networked table.
--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return boolean result Whether the action was successfull or not.
function ClusterUserList:Add(id, ...)
    PEARL.debug("ClusterUserList:Add", id, self._path)

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
function ClusterUserList:AddLocal(id)
    if type(id) == "string" and self._ids[id] ~= true then
        self._ids[id] = true
        return true
    end

    return false
end

function ClusterUserList:AddGlobal(id, ...)
    PEARL.BroadcastRPCToConnectedShards(PEARL.RPC[self._RPC_NAME_ADD], id, ...)
end

--- Removes the given ID from the local AND networked table.
--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return boolean result Whether the action was successfull or not.
function ClusterUserList:Remove(id)
    PEARL.debug("ClusterUserList:Remove", id, self._path)

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
function ClusterUserList:RemoveLocal(id)
    if type(id) == "string" and self._ids[id] ~= nil then
        self._ids[id] = nil

        return true
    end

    return false
end

function ClusterUserList:RemoveGlobal(id, ...)
    PEARL.BroadcastRPCToConnectedShards(PEARL.RPC[self._RPC_NAME_REMOVE], id, ...)
end

--- https://forums.kleientertainment.com/klei-bug-tracker/dont-starve-together/thenetiswhitelist-does-not-properly-handle-files-that-use-crlf-line-break-r38498/
function ClusterUserList:Load()
    PEARL.debug("ClusterUserList:Load", self._path)

    if not PEARL.ClusterPersistence:FileExists(self._path) and self._ensure ~= true then
        return PEARL.info(self._path, "not found -> skipping this file...")
    end

    if type(self._loadfn) == "function" then
        return self._loadfn(self)
    end

    local lines = PEARL.ClusterPersistence:GetAllFileLines(self._path, self._ensure, true)
    for _, id in ipairs(lines) do
        self:AddLocal(id)
    end
end

function ClusterUserList:Save()
    PEARL.debug("ClusterUserList:Save", self._path)

    if type(self._savefn) == "function" then
        return self._savefn(self)
    end

    PEARL.ClusterPersistence:SetFileLines(self._path, table.keys(self._ids))
end

function ClusterUserList:Clear()
    for id, _ in pairs(self._ids) do
        self:RemoveLocal(id)
    end
end

function ClusterUserList:Reload()
    self:Clear()
    self:Load()
end

--------------------------------------
-- [[ Debugging ]]
--------------------------------------

function ClusterUserList:DisplayDebugInfo()
    table.dump(self._ids)
end

--------------------------------------
-- [[ Return ]]
--------------------------------------

return ClusterUserList
