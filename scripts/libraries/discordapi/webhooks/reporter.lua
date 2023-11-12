--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local MARKDOWN = PEARL.loadfile("libraries/markdown")
local MESSAGES = PEARL.loadfile("utils/messages")

local Webhook = PEARL.loadfile("libraries/discordapi/models/webhook")
local Message = PEARL.loadfile("libraries/discordapi/models/message")

-------------------------------------
-- [[ Constants ]]
-------------------------------------

local MAX_TRACEBACK_LENGHT = 1024
local ERROR_ID_PATTERN = "([^\n\r]*)"

-------------------------------------
-- [[ Class Declarations ]]
-------------------------------------

--- @class Reporter
local Reporter = Class(function(self)
    self._disabled = not PEARL.CONFIG.DISCORD.RHOOK.ENABLED
    if self._disabled then
        return
    end

    self._webhook = Webhook(PEARL.CONFIG.DISCORD.RHOOK.ID, PEARL.CONFIG.DISCORD.RHOOK.TOKEN)
    if not self._webhook:IsValid() then
        self:SetIsDisabled(true)
        return PEARL.error("Token and/or ID is not configured for the reporter webhook correctly!")
    end

    self._reported = {}
    self._last_reports = 0
    self._last_report_time = 0

    -- Config
    self._cooldown_time = PEARL.CONFIG.DISCORD.RHOOK.COOLDOWN
    self._max_reports   = PEARL.CONFIG.DISCORD.RHOOK.MAX_REPORTS
end)

-------------------------------------
-- [[ Private Functions ]]
-------------------------------------

--- @param content string
function Reporter:_SendReportMessage(content)
    if type(content) ~= "string" then
        return PEARL.error("Attempted to send an invalid report message...")
    end

    PEARL.info("Sending error log to discord...")
    return self:SendRawReportMessage(Message(content))
end

function Reporter:_GetErrorID(traceback)
    return type(traceback) == "string" and traceback:match(ERROR_ID_PATTERN)
end

function Reporter:_WasErrorReported(error_id)
    if not error_id then
        return false
    end

    return self._reported[error_id] or nil
end

--- @return boolean success
function Reporter:HandleError(traceback)
    if self:IsDisabled() then
        return false
    end

    local error_id = self:_GetErrorID(traceback)
    if not error_id then
        return false
    end

    if self:_WasErrorReported(error_id) then
        return false -- Error with this ID already reported.
    end

    if (os.time() - self._last_report_time) < self._cooldown_time then
        return false -- We are on cooldown, so ignore this error
    end

    self._reported[error_id] = true
    self._last_reports = self._last_reports + 1
    if self._last_reports >= self._max_reports then
        self._last_report_time = os.time()
        self._last_reports = 0
    end

    return true
end

-------------------------------------
-- [[ Public Functions ]]
-------------------------------------

function Reporter:IsDisabled()
    return self._disabled
end

function Reporter:IsEnabled()
    return not self._disabled
end

function Reporter:SetIsDisabled(disabled)
    self._disabled = disabled
end

--- @param message Message
--- @return Request?
function Reporter:SendRawReportMessage(message)
    if self:IsEnabled() then
        return self._webhook:PostMessage(message)
    end
end

--- @param str string
function Reporter:SendRawReportString(str)
    if type(str) ~= "string" then
        return PEARL.error("Invalid report string provided!")
    end

    return self:SendRawReportMessage(Message(str))
end

--- @param reason string A short description of the issue that has occured.
function Reporter:ReportFailedHTTPRequest(reason)
    if type(reason) ~= "string" or self:IsDisabled() then
        return
    end

    reason = MARKDOWN.codeblock(reason:ltake(MAX_TRACEBACK_LENGHT, nil, "..."))
    return self:_SendReportMessage(MARKDOWN.bold(STRINGS.PEARL.LOGS.HTTP_ERROR:format(
        MARKDOWN.codeline(PEARL.GetShardFancyName()), reason
    )))
end

function Reporter:ReportInvalidClientRPC(userid, reason)
    userid = userid or STRINGS.PEARL.REPORTS.USERID_UNKNOWN
    reason = reason or STRINGS.PEARL.REPORTS.NO_STACKTRACE

    self:_SendReportMessage(MARKDOWN.bold(STRINGS.PEARL.REPORTS.INVALID_RPC:format(
        MARKDOWN.codeline(PEARL.GetShardFancyName()), userid, reason:ltake(MAX_TRACEBACK_LENGHT, nil, "...")
    )))
end

--- WARNING: Uses force sending to send the report. Use with caution!
--- The reporter will be disabled after calling this for safety reasons.
--- We expect that the server will shutdown after an uncatched error.
--- @param traceback string
function Reporter:ReportUncatchedLuaError(traceback, modname)
    if type(traceback) ~= "string" or self:IsDisabled() then
        return PEARL.error("Invalid error data or the webhook is disabled!")
    end

    local mod_fancyname = modname and GetModFancyName(modname)
    local mod_id = modname and GetWorkshopIdNumber(modname)
    local mod_self = mod_id == PEARL.MODID

    local content
    traceback = MARKDOWN.codeblock(traceback:ltake(MAX_TRACEBACK_LENGHT, nil, "..."), "lua")
    if mod_fancyname and not mod_self then
        content = STRINGS.PEARL.LOGS.EXC_MOD_SHARD:format(
            MARKDOWN.hlink(MARKDOWN.codeline(mod_fancyname), PEARL.CONSTS.STEAM_WORKSHOP:format(mod_id)),
            MARKDOWN.codeline(PEARL.GetShardFancyName()), traceback
        )
    else
        content = (STRINGS.PEARL.LOGS[mod_self and "EXC_SELF_SHARD" or "EXC_SHARD"]):format(
            MARKDOWN.codeline(PEARL.GetShardFancyName()), traceback
        )
    end

    self:SendRawReportMessage(Message(MARKDOWN.bold(content))
        :AddFlag(Message.FLAGS.SUPPRESS_EMBEDS)
    )

    -- Disable to prevent any looping.
    self:SetIsDisabled(true)
end

--- @param traceback string
function Reporter:ReportCatchedLuaError(traceback)
    if not self:HandleError(traceback) then
        return -- Error was already handled
    end

    traceback = MARKDOWN.codeblock(traceback:ltake(MAX_TRACEBACK_LENGHT, nil, "..."), "lua")
    return self:_SendReportMessage(MARKDOWN.bold(STRINGS.PEARL.LOGS.EXC_CATCHED_SHARD:format(
        MARKDOWN.codeline(PEARL.GetShardFancyName()), traceback
    )))
end

--- @param userid string The identifier of the client where the error happened on.
--- @param data table The error data.
function Reporter:ReportClientLuaError(userid, data)
    if type(data) ~= "table" or not self:HandleError(data.traceback) then
        return -- Error was already handled
    end

    local client = TheNet:GetClientTableForUser(userid) or PEARL.ServerNetwork:GetCachedClientTableFor(userid)
    local client_name = client.name or "UNKNOWN"

    local self_afflicter = type(data.mod) == "table" and data.mod.id == PEARL.MODID
    local pattern = (
        (self_afflicter and STRINGS.PEARL.LOGS.EXC_SELF_CLIENT) or
        (data.catched and STRINGS.PEARL.LOGS.EXC_CATCHED_CLIENT) or
        STRINGS.PEARL.LOGS.EXC_CLIENT
    )

    local content
    local traceback = MARKDOWN.codeblock(type(data.traceback) == "string" and
        data.traceback:ltake(MAX_TRACEBACK_LENGHT, nil, "...") or "NO TRACEBACK",
    "lua")

    if type(data.mod) == "table" and not self_afflicter then
        content = STRINGS.PEARL.LOGS.EXC_MOD_CLIENT:format(
            MARKDOWN.hlink(
                MARKDOWN.codeline(data.mod.fancyname), PEARL.CONSTS.STEAM_WORKSHOP:format(data.mod.id)
            ), MARKDOWN.codeline(userid), MARKDOWN.codeline(client_name), traceback
        )
    else
        content = pattern:format(MARKDOWN.codeline(userid), MARKDOWN.codeline(client_name), traceback)
    end

    if type(data.enabled_mods) == "table" and #data.enabled_mods > 0 then
        content = content..STRINGS.PEARL.LOGS.EXC_ENABLED_MODS:format(
            MARKDOWN.codeline(#data.enabled_mods), MARKDOWN.codeline("\""..table.concat(
                data.enabled_mods, "\" "
            ).."\"")
        )

        if type(data.mod) == "table" and data.mod.disabled then
            content = content.."\n\n"..STRINGS.PEARL.LOGS.AFFLICTER_MOD_DISABLED
        end
    end

    return self:SendRawReportMessage(Message(MARKDOWN.bold(content))
        :AddFlag(Message.FLAGS.SUPPRESS_EMBEDS)
    )
end

function Reporter:ReportInventory(userid, player_reference)
    if type(userid) ~= "string" then
        PEARL.error("Invalid userid parameter")

        return false
    end

    self:SendRawReportMessage(MESSAGES.InvReport(userid, player_reference))

    return true
end

function Reporter:ReportMods(userid, mods)
    self:SendRawReportMessage(MESSAGES.ModsReport(userid, mods))
end

function Reporter:SendPlayerReportMessage(userid, message)
    local client = userid and TheNet:GetClientTableForUser(userid)
    local username = client and client.name or "UNKNOWN"

    --- @TODO: Maybe use an embed instead.
    self:SendRawReportMessage(Message(STRINGS.PEARL.LOGS.PLAYER_REPORT:format(
        PEARL.ICONS.ANNOUNCEMENTS["default"], userid, MARKDOWN.escape(username), MARKDOWN.escape(message or "")
    )):SetAllowedMentionTypes({
        Message.MENTION_TYPES.EVERYONE
    }))
end

-------------------------------------

return Reporter
