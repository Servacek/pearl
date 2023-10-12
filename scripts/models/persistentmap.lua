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
    self.filepath = filepath
    self.autocreate = false
    self.encode = false

    self.map = {}
end)

function PersistentMap:SetEncode(encode)
    self.encode = encode
end

function PersistentMap:SetAutoCreate(autocreate)
    self.autocreate = autocreate
end

function PersistentMap:Load()
    local loaded = PEARL.PlayerDB:LoadDatabaseFile(self.filepath, self.autocreate)
    if not loaded then
        return PEARL.error("Failed to load persistent tables map file!")
    end

    self.map = loaded
end

function PersistentMap:Save()
    local saved = PEARL.PlayerDB:SaveToDatabaseFile(self.filepath, self.autocreate, self.encode)
    if not saved then
        return PEARL.error("Failed to save persistant table map file!")
    end
end

-------------------------------------
-- [[ Return ]]
-------------------------------------

return PersistentMap
