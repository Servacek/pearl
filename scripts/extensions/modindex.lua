--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--- @class KnownModIndex
local KnownModIndex = KnownModIndex



function KnownModIndex:Block(modname)
    self:Disable(modname)

    if not self.savedata.known_mods[modname] then
        self.savedata.known_mods[modname] = {}
    end

    -- This is just a temporary flag that will be removed after the game restarts
    -- The thing that will stay is the disabled flag.
    self.savedata.known_mods[modname].blocked = true
    self._mods_blocked = true
end

function KnownModIndex:IsModBlocked(modname)
	local known_mod = self.savedata.known_mods[modname]
	return known_mod and known_mod.blocked == true
end

function KnownModIndex:AreAnyModsBlocked()
    return self._mods_blocked == true
end

function KnownModIndex:GetAllEnabledModsCount()
    local count = 0
    for modname, _ in pairs(KnownModIndex.savedata.known_mods) do
        if KnownModIndex:IsModEnabledAny(modname) then
            count = count + 1
        end
    end

    return count
end
