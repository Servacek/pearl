--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--[[
    Class representing a discord application command option.
--]]

------------------------------------------
-- [[ Class Declaration ]]
------------------------------------------

--- @dataclass
--- @class Option
--- @field type OptionType Type of option
--- @field name string 1-32 character name
--- @field name_localizations table? Localization dictionary for the name field. Values follow the same restrictions as name
--- @field description string? 1-100 character description
--- @field description_localizations table? Localization dictionary for the description field. Values follow the same restrictions as description
--- @field required boolean If the parameter is required or optional--default false
--- @field choices table<integer, Choice>? Choices for STRING, INTEGER, and NUMBER types for the user to pick from, max 25
--- @field options table<integer, Option>? If the option is a subcommand or subcommand group type, these nested options will be the parameters
--- @field min_value integer? If the option is an INTEGER or NUMBER type, the minimum value permitted
--- @field max_value integer? If the option is an INTEGER or NUMBER type, the maximum value permitted
--- @field min_length integer? For option type STRING, the minimum allowed length (minimum of 0, maximum of 6000)
--- @field max_length integer? For option type STRING, the maximum allowed length (minimum of 1, maximum of 6000)
--- @field autocomplete boolean? If autocomplete interactions are enabled for this STRING, INTEGER, or NUMBER type option
local Option

Option = PEARL.Class(function(self, type, name, description)
    assert(type, "Type parameter is required!")
    assert(name, "Name parameter is required!")

    self.type = type
    self.name = name

    self.name_localizations = nil
    self.description = description
    self.description_localizations = nil
    self.required = nil
    self.choices = nil
    self.options = nil
    self.channel_types = nil
    self.min_value = nil
    self.max_value = nil
    self.min_length = nil
    self.max_length = nil
    self.autocomplete = nil
end)

------------------------------------------
-- [[ Static ]]
------------------------------------------

--- @enum OptionType
Option.TYPE = {
    SUB_COMMAND         = 1,
    SUB_COMMAND_GROUP   = 2,
    STRING              = 3,
    INTEGER             = 4,    -- Any integer between -2^53 and 2^53
    BOOLEAN             = 5,
    USER                = 6,
    CHANNEL             = 7,    -- Includes all channel types + categories
    ROLE                = 8,
    MENTIONABLE         = 9,    -- Includes users and roles
    NUMBER              = 10,   -- Any double between -2^53 and 2^53
    ATTACHMENT          = 11,   -- attachment object
}

--- @param generic string
function Option.TypeFromGeneric(generic)
    return Option.TYPE[tostring(generic):upper()]
end

--- @param tp OptionType
function Option.GenericFromType(tp)
    return tostring(table.getkey(tp)):lower()
end

function Option.FromTable(t)
    --- @type Option
    local option = Option(t.type, t.name, t.description)
    for k, v in pairs(t) do
        if type(v) == "table" then
            option[k] = deepcopy(v)
        end

        option[k] = v
    end

    return option
end

------------------------------------------
-- [[ Public Functions ]]
------------------------------------------

function Option:ToTable()
    local t = {}
    for k, v in pairs(self) do
        if k == "choices" and table.empty(v) == false then
            t.choices = {}
            print("CHOICE!!!")
            for i, choice in ipairs(v) do
                t.choices[i] = choice:ToTable()
            end
        else
            if type(v) == "table" then
                t[k] = deepcopy(v)
            end

            t[k] = v
        end
    end

    return t
end

------------------------------------------
-- [[ Return ]]
------------------------------------------

return Option
