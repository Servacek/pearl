--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local Message = require("libraries/discordapi/models/message")

--------------------------------------
-- [[ Class Declaration ]]
--------------------------------------

--- @dataclass
--- @class CommandContext
local CommandContext = PEARL.Class(function(self, command, type, params, author)
    --- @type table
    self.author = author or {}
    --- @type table
    self.params = params or {}

    self.command = command or {}
    --- @type integer
    self.type = type

    --- @type boolean
    self.replied = false
end)

--------------------------------------
-- [[ Static Variables ]]
--------------------------------------

CommandContext.TYPE = {
    SLASH   = 1,
    CONSOLE = 2,
    DISCORD = 3,
}

--- @type table<integer, fun(context: CommandContext, response: string)>
CommandContext.OHANDLER = {
    [CommandContext.TYPE.CONSOLE] = function(context, response)
        PEARL.info(response)
    end,
    [CommandContext.TYPE.SLASH]   = function(context, response)
        PEARL.ServerNetwork:SendCommandResponse(context.author.userid, response)
    end,
    [CommandContext.TYPE.DISCORD] = function(context, response)
        PEARL.DiscordProxy:SendCommandResponse(context.command.id, Message(response))
    end,
}

--------------------------------------
-- [[ Getters ]]
--------------------------------------

function CommandContext:GetOutputHandler()
    return CommandContext.OHANDLER[self.type]
end

function CommandContext:WasReplied()
    return self.replied == true
end

--------------------------------------
-- [[ Public Methods ]]
--------------------------------------

--- @param content string
function CommandContext:Reply(content)
    local ohandler = self:GetOutputHandler()
    if type(ohandler) == "function" then
        ohandler(self, content)

        self.replied = true
    end
end

--- @param message Message
function CommandContext:ReplyDiscordMessage(message)
    -- For non-discord commands calling this function
    if self.command.id == nil then
        if self.command.permission == COMMAND_PERMISSION.USER then
            if PEARL.DiscordLogger:IsDisabled() and not self:WasReplied() then
                return self:Reply(STRINGS.PEARL.UI.CMD_ERRORS.NO_LHOOK)
            end

            PEARL.DiscordLogger:LogMessage(message)
        else
            if PEARL.DiscordReporter:IsDisabled() and not self:WasReplied() then
                return self:Reply(STRINGS.PEARL.UI.CMD_ERRORS.NO_RHOOK)
            end

            PEARL.DiscordReporter:SendRawReportMessage(message)
        end
    else
        PEARL.DiscordProxy:SendCommandResponse(self.command.id, message)
    end

    self.replied = true
end

--- @param embed Embed
function CommandContext:ReplyDiscordEmbed(embed)
    self:ReplyDiscordMessage(Message():AddEmbed(embed))
end

--------------------------------------
-- [[ Return ]]
--------------------------------------

return CommandContext
