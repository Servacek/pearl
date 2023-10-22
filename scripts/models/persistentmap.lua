--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--- @class PersistentMap
local PersistentMap = Class(function(self, filepath)
    assert(type(filepath) == "string", "Invalid filepath provided for persistent map!")

    --- @type string
    self.filepath = filepath
    self.autocreate = false
    self.encode = false

    self.onloadfn = nil
    self.onsavefn = nil

    --- @type table
    self.map = {}
end)

-------------------------------------
-- [[ Getters ]]
-------------------------------------

function PersistentMap:GetData()
    return self.map
end

function PersistentMap:GetValue(name)
    return self.map[name]
end

-------------------------------------
-- [[ Setters ]]
-------------------------------------

function PersistentMap:SetEncode(encode)
    self.encode = encode
end

function PersistentMap:SetAutoCreate(autocreate)
    self.autocreate = autocreate
end

function PersistentMap:SetValue(key, value)
    self.map[key] = value
end

function PersistentMap:SetOnLoad(fn)
    self.onloadfn = fn
end

function PersistentMap:SetOnSave(fn)
    self.onsavefn = fn
end

-------------------------------------
-- [[ Public Methods ]]
-------------------------------------

-------------------------------------
-- [[ Save/Load ]]
-------------------------------------

function PersistentMap:Load()
    local loaded = PEARL.PlayerDB:LoadDatabaseFile(self.filepath, self.autocreate)
    if type(loaded) ~= "table" then
        PEARL.error("Failed to load persistent tables map file!")
        return
    end

    self.map = type(self.onloadfn) == "function" and self.onloadfn(loaded) or loaded
end

function PersistentMap:Save()
    local data = type(self.onloadfn) == "function" and self.onsavefn(self.map) or self.map
    local saved = PEARL.PlayerDB:SaveToDatabaseFile(self.filepath, data, self.autocreate, self.encode)
    if not saved then
        return PEARL.error("Failed to save persistant table map file!")
    end
end

-------------------------------------
-- [[ Return ]]
-------------------------------------

return PersistentMap
