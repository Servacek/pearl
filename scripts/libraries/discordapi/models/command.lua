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
    Class representing a discord application command.
--]]


local Option = PEARL.loadfile("libraries/discordapi/models/option")
local Permission = PEARL.loadfile("libraries/discordapi/models/permission")

------------------------------------------
-- [[ Constants ]]
------------------------------------------

local DEFAULT_OPTION_TYPE = "string"
local ADMIN_COMMAND_DEFAULT_PERMISSIONS = Permission.PRIORITY_SPEAKER

------------------------------------------
-- [[ Class Declaration ]]
------------------------------------------

--- @dataclass
--- @class Command
--- @field type CommandType
--- @field guild_id integer
--- @field name string
--- @field name_localizations table?
--- @field description string?
--- @field options table?
--- @field description_localizations table?
--- @field default_member_permissions Permission?
--- @field nsfw boolean?
--- Custom:
--- @field wait boolean? Whether we should wait for the response or not. Defaults to True.
--- @field private boolean? Whether the response should be ephemeral or not.
--- @field notify boolean? Whether it should notify the user that the command was fetched or not.
local Command

Command = PEARL.Class(function(self, name, description)
    assert(name, "Name parameter is required!")
    assert(not description or string.utf8len(description) <= Command.MAX_DESCRIPTION_LENGTH, "Description too long for command "..name)

    --- Official Discord API fields
    self.type = Command.TYPE.CHAT_INPUT
    self.guild_id = nil
    self.name = name
    self.name_localizations = nil
    self.description = description
    self.description_localizations = nil
    self.default_member_permissions = nil
    self.options = nil
    self.dm_permission = nil
    self.nsfw = nil

    --- Custom Discord API wrapper fields
    self.private = nil
end)

------------------------------------------
-- [[ Static ]]
------------------------------------------

--- @enum CommandType
Command.TYPE = {
    CHAT_INPUT = 1,  -- Slash commands; a text-based command that shows up when a user types /
    USER       = 2,  -- A UI-based command that shows up when you right click or tap on a user
    MESSAGE    = 3,  -- A UI-based command that shows up when you right click or tap on a message
}

Command.MAX_DESCRIPTION_LENGTH = 100

--- @return Command
function Command.FromTable(t)
    --- @type Command
    local command = Command(t.name, t.description)
    for k, v in pairs(t) do
        if k == "options" and table.empty(v) == false then
            command.options = {}
            for _, option_data in pairs(v) do
                command.options[#command.options+1] = Option.FromTable(option_data)
            end
        else
            if type(v) == "table" then
                command[k] = deepcopy(v)
            end

            command[k] = v
        end
    end

    return command
end

function Command.FromGameAPICommand(cmd)
    --- @type Command
    local command = Command(cmd.name, cmd.desc)
    command.dm_permission = false
    command.private = cmd.privateresponse
    command.permission = cmd.permission

    if cmd.permission ~= COMMAND_PERMISSION.USER then
        command.default_member_permissions = ADMIN_COMMAND_DEFAULT_PERMISSIONS
    end

    if table.empty(cmd.params) == false then
        command.options = {}
        for i, paramname in ipairs(cmd.params) do
            local type = Option.TypeFromGeneric(cmd.paramtypes and cmd.paramtypes[paramname] or DEFAULT_OPTION_TYPE)
            --- @type Option
            local option = Option(type, paramname)
            option.required = not cmd.paramsoptional or cmd.paramsoptional[i] ~= true

            local cmd_option = cmd.options and cmd.options[i]
            option.description = (cmd_option and cmd_option.description) or STRINGS.PEARL.UI.PARAM_DESCRIPTIONS[paramname]
            option.autocomplete = cmd_option and cmd_option.autocomplete
            option.choices = cmd_option and cmd_option.choices -- Its already a list of Choice objects.
            option.min_value = cmd_option.minvalue
            option.max_value = cmd_option.maxvalue
            option.max_length = cmd_option.maxlength
            option.min_length = cmd_option.minlength

            command.options[i] = option
        end
    end

    return command
end

------------------------------------------
-- [[ Public Functions ]]
------------------------------------------

function Command:ToTable()
    local t = {}
    for k, v in pairs(self) do
        if k == "options" and table.empty(v) == false then
            t.options = {}
            for _, option in pairs(v) do
                t.options[#t.options+1] = option:ToTable()
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

return Command
