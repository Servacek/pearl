--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--- Only for singleton classes.


-------------------------------------
-- [[ Class Declaration ]]
-------------------------------------

--- @class Library
local Library

--- @param self Library
--- @param data table<string, any>?
--- @param enabled boolean?
Library = PEARL.Class(function(self, data, enabled)
    if type(data) == "table" then
        --- Inherit fields from the data table
        for k, v in pairs(data) do
            self[k] = v
        end
    end

    --- @type boolean
    self.enabled = type(enabled) == "boolean" and enabled or false
end)

-------------------------------------
-- [[ Getters ]]
-------------------------------------

--- @return boolean
function Library:IsEnabled()
    return self.enabled == true
end

--- @return boolean
function Library:IsDisabled()
    return not self:IsEnabled()
end
-------------------------------------
-- [[ Setters ]]
-------------------------------------

--- @param enabled boolean
function Library:SetIsEnabled(enabled)
    self.enabled = enabled
end

--- @param disabled boolean
function Library:SetIsDisabled(disabled)
    self.enabled = not disabled
end

function Library:ToggleEnabled()
    self.enabled = not self.enabled
end

-------------------------------------
-- [[ Return ]]
-------------------------------------

return Library
