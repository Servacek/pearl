--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- Note: Errors before gamelogic won't be loaded.
--- @TODO: In case of mod errors get the afflicter mod.


--[[
    Handles uncatched errors and reports them to discord.

    On clients, we should be able to send the traceback as soon as this file is loaded.
]]

--------------------------------
-- [[ Constants ]]
--------------------------------

local MOD_AFFLICTER_PATTERN = "%#?%[string \"../mods/(.*)/.*\"%]%:"

--------------------------------
-- [[ Locals ]]
--------------------------------

local function TryGetAfflicterMod(traceback)
    return traceback:match(MOD_AFFLICTER_PATTERN)
end

local function OnClientError(traceback)
    local afflicter_modname = TryGetAfflicterMod(traceback)
    if afflicter_modname ~= PEARL.MODNAME and not KnownModIndex:IsModDisablingDisabled() and not KnownModIndex:IsModTempEnabled(afflicter_modname) then
        PEARL.info("Disabling mod", afflicter_modname, "because it crashed the game!")

        KnownModIndex:DisableBecauseBad(afflicter_modname)
    end

    PEARL.SendErrorTracebackToServer(
        traceback, false, afflicter_modname
    )

    if PEARL.ClientNetwork then
        PEARL.info("Disconnecting the user from the server...")
        PEARL.ClientNetwork:Disconnect("ID_DST_USER_CRASHED")
    end

    -- Do not force abort here in case we are displaying the error.
end

local function OnServerError(traceback)
    if PEARL.DiscordReporter and PEARL.DiscordReporter:IsEnabled() then
        PEARL.DiscordReporter:ReportUncatchedLuaError(traceback, TryGetAfflicterMod(traceback))
    else
        PEARL.error("DiscordReporter disabled or not initialized yet!")
    end

    PEARL.EventProcessor:HandleEvent("shard_shutdown", true)

    PEARL.ModShutdown()
    -- We want to try save the game before shutting down here.
    SaveAndShutdown()
end

local function OnError(traceback)
    traceback = traceback or "No Traceback"
    if not TheNet:GetIsClient() then
        return OnServerError(traceback)
    end

    OnClientError(traceback)
end

----------------------------------
-- Post Constuctor
----------------------------------

PEARL.AddGlobalFunctionPreCall("DisplayError", function(traceback)
    -- We do not want more errors
    local success, err = pcall(OnError, traceback)
    if not success then
        PEARL.error("Error while handling an error!\n", err)
    end
end)

----------------------------------
-- RPC
----------------------------------

PEARL.AddRawServerRPC("ClientError", function(userid, data)
    if not checkstring(data) then
        return PEARL.ServerNetwork:OnInvalidRPCFromClient("ClientError", userid)
    end

    if not PEARL.DiscordReporter or PEARL.DiscordReporter:IsDisabled() then
        return
    end

    local error_data = DecodeAndUnzipString(data)
    if type(error_data) ~= "table" then
        return PEARL.error("Failed to decode error data!")
    end

    PEARL.DiscordReporter:ReportClientLuaError(
        userid, error_data
    )
end, true)

function PEARL.SendErrorTracebackToServer(traceback, catched, afflicter_modname, ...)
    PEARL.info("Sending the error traceback to the server...")

    local enabled_mods = ModManager:GetEnabledModNames()
    PEARL.SendRawRPCToServer(PEARL.RPC.ClientError, ZipAndEncodeString({
        traceback = traceback,
        catched = catched,
        enabled_mods = enabled_mods,
        mod = {
            id = GetWorkshopIdNumber(afflicter_modname),
            fancyname = GetModFancyName(afflicter_modname),
            disabled = not table.contains(enabled_mods, afflicter_modname)
        },
    }), ...)
end
