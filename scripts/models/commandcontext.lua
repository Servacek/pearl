--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local Message = PEARL.loadfile("libraries/discordapi/models/message")

--------------------------------------
-- [[ Constants ]]
--------------------------------------

local RESPONSE_ICON_PATTERN = "%s %s"
local CONSOLE_RESPONSE_PREFIX = "Command Response:\n"

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

    --- @type table?
    self.validated_args = nil

    self.command = command or {}
    --- @type integer
    self.type = type

    --- @type boolean
    self.replied = false
end)

--------------------------------------
-- [[ Static ]]
--------------------------------------

CommandContext.TYPE = {
    SLASH   = 1,
    CONSOLE = 2,
    DISCORD = 3,
}

--- @type table<integer, fun(context: CommandContext, response: string)>
CommandContext.OHANDLER = {
    [CommandContext.TYPE.CONSOLE] = function(context, response)
        PEARL.info(CONSOLE_RESPONSE_PREFIX..response)
    end,
    [CommandContext.TYPE.SLASH]   = function(context, response)
        PEARL.ServerNetwork:SendCommandResponse(context.author.userid, response)
    end,
    [CommandContext.TYPE.DISCORD] = function(context, response)
        PEARL.DiscordProxy:SendCommandResponse(context.iid, Message(response))
    end,
}

--- @return CommandContext
function CommandContext.FromTable(tbl)
    local ctx = CommandContext(nil, tbl.type, tbl.params, tbl.author)
    ctx:SetInteractionID(tbl.iid)
    ctx:SetValidatedArguments(tbl.args)

    return ctx
end

--------------------------------------
-- [[ Getters ]]
--------------------------------------

function CommandContext:GetOutputHandler()
    return CommandContext.OHANDLER[self.type]
end

function CommandContext:WasReplied()
    return self.replied == true
end

function CommandContext:GetValidatedArguments()
    return self.validated_args
end

function CommandContext:ToTable()
    return {
        type   = self.type,
        params = self.params,
        args   = self.validated_args,
        author = self.author,
        iid    = self.iid,
    }
end

--------------------------------------
-- [[ Setters ]]
--------------------------------------

function CommandContext:SetInteractionID(id)
    self.iid = tostring(id)
end

function CommandContext:SetCommand(command)
    self.command = command
end

function CommandContext:SetValidatedArguments(args)
    self.validated_args = args
end

--------------------------------------
-- [[ Public Methods ]]
--------------------------------------

--- @param content string
--- @param icon string? Optional icon (emoji) to the content. Displayed only on discord.
function CommandContext:Reply(content, icon)
    local ohandler = self:GetOutputHandler()
    if type(ohandler) ~= "function" then
        return PEARL.error("No handler for command", self.command.name, self.type)
    end

    if type(icon) == "string" then
        local icon_type = PEARL.ICONS.GetType(icon)

        local icon_str = icon_type == PEARL.ICONS.TYPE.UNKNOWN and icon or nil
        if icon_type == PEARL.ICONS.TYPE.DISCORD then
            icon_str = self.type == CommandContext.TYPE.SLASH and PEARL.EMOTES.MAP_GAME[icon] or (
                self.type == CommandContext.TYPE.DISCORD and icon or nil
            )
        elseif icon_type == PEARL.ICONS.TYPE.INGAME then
            icon_str = self.type == CommandContext.TYPE.DISCORD and PEARL.EMOTES.MAP_DISCORD[icon] or (
                self.type == CommandContext.TYPE.SLASH and icon or nil
            )
        end

        -- Console doesnt support much icon types, so display only the unknown ones.
        if self.type == CommandContext.TYPE.CONSOLE and icon_type ~= PEARL.ICONS.TYPE.UNKNOWN then
            icon_str = nil
        end

        if icon_str then
            content = RESPONSE_ICON_PATTERN:format(icon_str, content)
        end
    end

    ohandler(self, content)

    self.replied = true
end

--- @param message Message
--- @return Request? request
function CommandContext:ReplyDiscordMessage(message)
    self.replied = true

    -- For non-discord commands calling this function
    if self.iid == nil then
        if self.command.permission == COMMAND_PERMISSION.USER then
            if PEARL.DiscordLogger:IsDisabled() and not self:WasReplied() then
                self:Reply(STRINGS.PEARL.UI.CMD_ERRORS.NO_LHOOK)
                return
            end

            return PEARL.DiscordLogger:LogMessage(message)
        else
            if PEARL.DiscordReporter:IsDisabled() and not self:WasReplied() then
                self:Reply(STRINGS.PEARL.UI.CMD_ERRORS.NO_RHOOK)
                return
            end

            return PEARL.DiscordReporter:SendRawReportMessage(message)
        end
    else
        PEARL.DiscordProxy:SendCommandResponse(self.iid, message)
    end
end

--- @param embed Embed
--- @return Request? request
function CommandContext:ReplyDiscordEmbed(embed)
    --- @type Message
    local message = Message()
    message:AddEmbed(embed)

    if not embed:IsValid() or not message:IsValid() then
        PEARL.error("CommandContext:ReplyDiscordEmbed Reply invalid!")
        return
    end

    return self:ReplyDiscordMessage(message)
end

--------------------------------------
-- [[ Return ]]
--------------------------------------

return CommandContext
