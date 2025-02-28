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
local Colour = PEARL.loadfile("libraries/datastructures/colour")

--------------------------------------
-- [[ Constants ]]
--------------------------------------

local RESPONSE_ICON_PATTERN = "%s %s"
local CONSOLE_RESPONSE_PREFIX = "Command Response:\n"

local ERROR_TEXT_COLOUR = Colour.FromRGBA(237, 67, 55)

--------------------------------------
-- [[ Class Declaration ]]
--------------------------------------

--- @dataclass
--- @class CommandContext
local CommandContext
CommandContext = PEARL.Class(function(self, command, type, params, author)
    assert(table.getkey(CommandContext.TYPE, type) ~= nil, "Invalid type provided!")

    --- @type table
    self.author = author or {}
    --- @type table
    self.params = params or {}

    --- @type table?
    self.validated_args = nil

    self.command = command or {}
    --- @type CommandContextType
    self.type = type

    --- @type boolean
    self.replied = false
end)

--------------------------------------
-- [[ Static ]]
--------------------------------------

--- @enum CommandContextType
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
-- [[ Private Functions ]]
--------------------------------------

local function _ConvertIconToType(icon, target_type)
    local icon_type = PEARL.ICONS.GetType(icon)

    local icon_str = icon_type == PEARL.ICONS.TYPE.UNKNOWN and icon or nil
    if icon_type == PEARL.ICONS.TYPE.DISCORD then
        icon_str = target_type == CommandContext.TYPE.SLASH and PEARL.EMOJIS.DISCORD_TO_UTF[icon] or (
            target_type == CommandContext.TYPE.DISCORD and icon or nil
        )
    elseif icon_type == PEARL.ICONS.TYPE.INGAME then
        icon_str = target_type == CommandContext.TYPE.DISCORD and PEARL.EMOJIS.UTF_TO_DISCORD[icon] or (
            target_type == CommandContext.TYPE.SLASH and icon or nil
        )
    end

    -- Console doesnt support much icon types, so display only the unknown ones.
    if target_type == CommandContext.TYPE.CONSOLE and icon_type ~= PEARL.ICONS.TYPE.UNKNOWN then
        icon_str = nil
    end

    return icon_str
end

--------------------------------------
-- [[ Getters ]]
--------------------------------------

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

function CommandContext:ExecuteAfter(time, fn, ...)
    local task = PEARL.WallScheduler:ExecuteInTime(time, fn, nil, ...)
    if task then
        task:seterrfn(function()
            self:ReplyError(STRINGS.PEARL.UI.CMD_ERRORS.EXECUTION)
        end)
    end
end

--- @param content string
--- @param icon string? Optional icon (emoji) to the content. Displayed only on discord.
function CommandContext:Reply(content, icon)
    local ohandler = CommandContext.OHANDLER[self.type]
    if type(ohandler) ~= "function" then
        return error("No handler for command "..self.command.name.." with type "..tostring(self.type))
    end

    if type(icon) == "string" then
        local icon_str = _ConvertIconToType(icon, self.type)
        if icon_str then
            content = RESPONSE_ICON_PATTERN:format(icon_str, content)
        end
    end

    ohandler(self, content)

    self.replied = true
end

function CommandContext:ReplyError(content)
    self.replied = true

    if self.type == CommandContext.TYPE.SLASH then
        PEARL.ServerNetwork:SendCommandResponse(self.author.userid, content, ERROR_TEXT_COLOUR)
    else
        self:Reply(content, PEARL.ICONS.X)
    end
end

--- @param message Message
--- @return Request? request
function CommandContext:ReplyDiscordMessage(message)
    self.replied = true

    -- For non-discord commands calling this function
    if self.iid == nil then
        local request
        if self.author.discordid and PEARL.DiscordProxy:IsRunning() then
            request = PEARL.DiscordProxy:PostMessage(message, self.author.discordid)
        elseif self.command.privateresponse == false then
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

            request = PEARL.DiscordReporter:SendRawReportMessage(message)
        end

        if request then
            request:AddOnComplete(function()
                if request.ok then
                    return self:Reply(STRINGS.PEARL.UI.CMD_INFO.SENT_TO_THIRDPARTY)
                end

                self:Reply(STRINGS.PEARL.UI.CMD_ERRORS.SENT_TO_THIRDPARTY_FAILED)
            end)
        end
    else
        PEARL.DiscordProxy:SendCommandResponse(self.iid, message)
    end
end

--- @param data table
--- @return Request? request
function CommandContext:ReplyDiscordData(data)
    self.replied = true

    PEARL.DiscordProxy:SendCommandResponse(self.iid, data)
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
