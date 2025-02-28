--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @class Doer
local Doer = PEARL.Class(function(self, data)
    --- @type table?
    self._data = data
end)

--------------------------------
-- [[ Getters ]]
--------------------------------

function Doer:GetData()
    return self._data
end

function Doer:GetName()
    return self._data and self._data.name
end

function Doer:GetUserID()
    return self._data and self._data.userid
end

--------------------------------
-- [[ Setters ]]
--------------------------------

function Doer:SetData(data)
    self._data = data
end

function Doer:Set(userid, name)
    if type(self._data) ~= "table" then
        self._data = {}
    end

    self._data.userid = userid
    self._data.name   = name
end

--------------------------------
-- [[ Setters ]]
--------------------------------

return Doer
