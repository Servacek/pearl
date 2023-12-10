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
    Overrides the default console screen widget callbacks
    for non-admins.
--]]

--- @type UserCommands
local UserCommands = require("usercommands")

-------------------------------
-- [[ Constants ]]
-------------------------------

local DISABLE_CONSOLE = not TheNet:GetIsServerAdmin() and not PEARL.CONFIG.CLIENT_CONSOLE_ENABLED

-------------------------------
-- [[ Class Declaration ]]
-------------------------------

--- @class ConsoleScreen
local ConsoleScreen = require("screens/consolescreen")

-------------------------------
-- [[ Local Functions ]]
-------------------------------

local function ExpandWordPredictorWithCustomCommands(predictor, commands)
    local permission = UserCommands.GetPermissionLevel(
        TheNet:GetIsServerAdmin() and COMMAND_PERMISSION.ADMIN or COMMAND_PERMISSION.USER
    )

    for _, v in pairs(predictor.dictionaries) do
        if v.delim == PEARL.CONSTS.DELIMS.CONSOLE_COMMAND then
            for name, command in pairs(commands) do
                local commandpermission = UserCommands.GetPermissionLevel(command.permission)

                -- Only autocomplete the commands we have permission to.
                if permission >= commandpermission and not table.contains(v.words, name) then
                    table.insert(v.words, name)
                end
            end

            break -- Extend only once
        end
    end
end

local function DisableConsole()
    PEARL.OverrideVariable("OnBecomeActive", function(self)
        self:Close()
    end, ConsoleScreen)

    PEARL.OverrideVariable("CONSOLE_ENABLED", false, _G)

    -- Disable this function so even input from stdout won't be executed.
    PEARL.OverrideVariable("ExecuteConsoleCommand", function() end, _G)
end

local function DisableRemoteCommandSending()
    PEARL.OverrideUserdataValue("SendRemoteExecute", function() end, TheNet)
end

-------------------------------
-- [[ Post Construct ]]
-------------------------------

AddClassPostConstruct("screens/consolescreen", function(self)
    local prediction_widget = self and self.console_edit and self.console_edit.prediction_widget
    local predictor = prediction_widget and prediction_widget.word_predictor
    if predictor then
        local commands = UserCommands.GetCustomCommandsWithFlag("console")
        ExpandWordPredictorWithCustomCommands(predictor, commands)
    end

    -- Just to be safe.
    if DISABLE_CONSOLE then
        DisableConsole()
        DisableRemoteCommandSending()
    end
end)

if DISABLE_CONSOLE then
    PEARL.debug("Disabling the console and remote command sending...")

    DisableConsole()
    DisableRemoteCommandSending()
end
