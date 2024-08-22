--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--[[
    Class representing a discord application command option choice.
--]]

------------------------------------------
-- [[ Class Declaration ]]
------------------------------------------

--- @dataclass
--- @class Choice
--- @field name string 1-100 character choice name
--- @field name_localizations table? Localization dictionary for the name field. Values follow the same restrictions as name
--- @field value string|number Value for the choice, up to 100 characters if string (depends on the option type)
local Choice

Choice = PEARL.Class(function(self, name, value)
    assert(name, "Name parameter is required!")

    self.name = name
    self.name_localizations = nil
    self.value = value
    if self.value == nil then
        self.value = name
    end
end)

------------------------------------------
-- [[ Static ]]
------------------------------------------

function Choice.FromTable(t)
    --- @type Choice
    local choice = Choice(t.name, t.value)
    choice.name_localizations = t.name_localizations

    return choice
end

------------------------------------------
-- [[ Public Functions ]]
------------------------------------------

function Choice:ToTable()
    return deepcopy(self)
end

------------------------------------------
-- [[ Return ]]
------------------------------------------

return Choice
