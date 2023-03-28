--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--- @TODO: Think about a way to reduce duplication here...

local MARKDOWN = PEARL.loadfile("libraries/markdown")

local Webhook = PEARL.loadfile("libraries/discordapi/models/webhook")
local Message = PEARL.loadfile("libraries/discordapi/models/message")

-------------------------------------
-- [[ Constants ]]
-------------------------------------

local MAX_TRACEBACK_LENGHT = 1024
local MAX_REPORTED_CACHE = 5
local ERROR_ID_PATTERN = "^(.*)\n.*"

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

    --- @type table<string>
    self._reported = {}
end)

-------------------------------------
-- [[ Private Functions ]]
-------------------------------------

--- @param content string
--- @param force boolean?
function Reporter:_SendReportMessage(content, force)
    if type(content) ~= "string" then
        return PEARL.error("Attempted to send an invalid report message...")
    end

    PEARL.info("Sending error log to discord...")
    return self:SendRawReportMessage(Message(content), force)
end

function Reporter:_GetErrorID(traceback)
    return traceback and traceback:match(ERROR_ID_PATTERN)
end

function Reporter:_WasErrorReported(error_id)
    if not error_id then
        return false
    end

    for i = 1, #self._reported do
        if self._reported[i] == error_id then
            return true
        end
    end

    return false
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
--- @param force boolean?
function Reporter:SendRawReportMessage(message, force)
    local _, json_data = message:ToJson()

    return PEARL.DiscordRestAPI:ExecuteWebhook(
        self._webhook, json_data, force
    )
end

--- @param str string
--- @param force boolean?
function Reporter:SendRawReportString(str, force)
    return self:SendRawReportMessage(Message(str), force)
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

--- WARNING: Uses force sending to send the report. Use with caution!
--- The reporter will be disabled after calling this for safety reasons.
--- We expect that the server will shutdown after an uncatched error.
--- @param traceback string
function Reporter:ReportUncatchedLuaError(traceback, modname)
    if type(traceback) ~= "string" or self:IsDisabled() then
        return
    end

    -- Disable to prevent any looping since these reports are sent by force.
    self:SetIsDisabled(true)

    local mod_fancyname = modname and GetModFancyName(modname)
    local mod_id = modname and GetWorkshopIdNumber(modname)
    local mod_self = mod_id == PEARL.MODID

    local content
    traceback = MARKDOWN.codeblock(traceback:ltake(MAX_TRACEBACK_LENGHT, nil, "..."), "lua")
    if modname and not mod_self then
        content = STRINGS.PEARL.LOGS.EXC_MOD_SHARD:format(
            MARKDOWN.hlink(MARKDOWN.codeline(mod_fancyname), PEARL.CONSTS.STEAM_WORKSHOP:format(mod_id)),
            MARKDOWN.codeline(PEARL.GetShardFancyName()), traceback
        )
    else
        content = (STRINGS.PEARL.LOGS[mod_self and "EXC_SELF_SHARD" or "EXC_SHARD"]):format(
            MARKDOWN.codeline(PEARL.GetShardFancyName()), traceback
        )
    end

    return self:SendRawReportMessage(Message(MARKDOWN.bold(content))
        :AddFlag(Message.FLAGS.SUPPRESS_EMBEDS), true
    )

    -- if modname then
    --     return self:_SendReportMessage(MARKDOWN.bold(STRINGS.PEARL.LOGS.EXC_MOD_SERVER:format(
    --         MARKDOWN.hlink(MARKDOWN.codeline(mod_fancyname), PEARL.CONSTS.STEAM_WORKSHOP:format(mod_id)),
    --         traceback
    --     )), true) -- Force-send uncatched errors.
    -- end

    -- return self:_SendReportMessage(MARKDOWN.bold(STRINGS.PEARL.LOGS.EXC_SERVER:format(
    --     traceback
    -- )), true) -- Force-send uncatched errors.
end

--- @param traceback string
function Reporter:ReportCatchedLuaError(traceback)
    if type(traceback) ~= "string" or self:IsDisabled() then
        return
    end

    --- @TODO
    -- Some attempts to reduce duplication...
    -- local error_id = self:_GetErrorID(traceback)
    -- print("ERROR ID:", error_id)
    -- if self:_WasErrorReported(error_id) then
    --     return PEARL.debug("!!!!!!!!!!!!!!!!!!!! ALREADY REPORTED!!!!!")
    -- end
    -- self._reported[#self._reported+1] = error_id

    traceback = MARKDOWN.codeblock(traceback:ltake(MAX_TRACEBACK_LENGHT, nil, "..."), "lua")
    return self:_SendReportMessage(MARKDOWN.bold(STRINGS.PEARL.LOGS.EXC_CATCHED_SHARD:format(
        MARKDOWN.codeline(PEARL.GetShardFancyName()), traceback
    )))
end

--- @param userid string The identifier of the client where the error happened on.
--- @param data table The error data.
function Reporter:ReportClientLuaError(userid, data)
    if type(data) ~= "table" or self:IsDisabled() then
        return
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
            MARKDOWN.codeline(#data.enabled_mods), MARKDOWN.codeline(table.concat(data.enabled_mods, ", "))
        )

        if type(data.mod) == "table" and data.mod.disabled then
            content = content.."\n\n"..STRINGS.PEARL.LOGS.AFFLICTER_MOD_DISABLED
        end
    end

    return self:SendRawReportMessage(Message(MARKDOWN.bold(content))
        :AddFlag(Message.FLAGS.SUPPRESS_EMBEDS)
    )
end

-------------------------------------

return Reporter
