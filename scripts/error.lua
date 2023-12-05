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


--[[
    Handles uncatched errors and reports them to discord.

    On clients, we should be able to send the traceback as soon as this file is loaded.
]]

--------------------------------
-- [[ Constants ]]
--------------------------------

local MOD_AFFLICTER_PATTERN = "%#?%[string \"../mods/([^/]+)/.*\"%]%:"

--------------------------------
-- [[ Locals ]]
--------------------------------

local function TryGetAfflicterMod(traceback)
    return traceback:match(MOD_AFFLICTER_PATTERN)
end

local function OnClientError(traceback)
    local afflicter_modname = TryGetAfflicterMod(traceback)
    if afflicter_modname ~= PEARL.MODNAME and (not KnownModIndex:IsModDisablingDisabled() or PEARL.CONFIG.DEBUG_MODE) and not KnownModIndex:IsModTempEnabled(afflicter_modname) then
        if KnownModIndex:IsModEnabledAny(afflicter_modname) then
            PEARL.info("Disabling mod", afflicter_modname, "because it crashed the game!")

            --- @TODO: Debug
            ModManager:RemoveBadMod(afflicter_modname, traceback)
            -- Make sure we call this only when all afflicter mods exist.
            ModManager:DisplayBadMods()
        end
    end

    PEARL.SendErrorTracebackToServer(
        traceback, false, afflicter_modname
    )

    -- In case the error was caused by bad chat history data.
    if PEARL.CONFIG.DEBUG_MODE then
        cleartable(ChatHistory.history)

        ChatHistory.request_history_start = 1
        ChatHistory.history_start = ChatHistory.MAX_CHAT_HISTORY
    end

    -- No disconnecting in debug mode... We have our fancy Realod Save button!
    if PEARL.ClientNetwork and not PEARL.CONFIG.DEBUG_MODE then
        PEARL.info("Disconnecting the user from the server...")
        PEARL.ClientNetwork:Disconnect("ID_DST_USER_CRASHED")
    end

    -- Do not force abort here in case we are displaying the error.
end

local function OnServerError(traceback)
    if PEARL.DiscordReporter and PEARL.DiscordReporter:IsEnabled() then
        PEARL.info("Sending error report to discord...")

        PEARL.DiscordReporter:ReportUncatchedLuaError(traceback, TryGetAfflicterMod(traceback))
    else
        PEARL.error("DiscordReporter disabled or not initialized yet!")
    end

    PEARL.EventProcessor:HandleEvent("shard_shutdown", true)

    PEARL.ServerNetwork:DisconnectAllClients("ID_DST_SERVER_CRASHED")

    PEARL.ModShutdown()
    -- We want to try save the game before shutting down here.
    if TheWorld then
        PEARL.WallScheduler:ExecuteInTime(0, SaveAndShutdown)
    else
        -- Silent crash in case of an error occuring at loading time.
        -- Do not load any further.
        -- We wait exactly one tick so that at least the crash can be reported gracefully.
        PEARL.WallScheduler:ExecuteInTime(0, TheSim.Crash, nil, TheSim)
    end
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

PEARL.AddRawServerRPCHandler("ClientError", function(userid, datastr)
    if not PEARL.DiscordReporter or PEARL.DiscordReporter:IsDisabled() then
        return PEARL.error("Client", userid, "crashed! Reports to discord are either disabled or not initialized!", datastr)
    end

    local data = checkstring(datastr) and DecodeAndUnzipString(datastr)
    if type(data) ~= "table" or
        (data.mod and type(data.mod) ~= "table") or
        (data.enabled_mods and type(data.enabled_mods) ~= "table") or
        not checkbool(data.catched) or
        not optstring(data.traceback)
    then
        return PEARL.ServerNetwork:OnInvalidRPCFromClient("ClientError", userid)
    end

    PEARL.DiscordReporter:ReportClientLuaError(userid, data)
end, true)

--- Defined here so we do not rely on ClientNetwork being loaded.
function PEARL.SendErrorTracebackToServer(traceback, catched, afflicter_modname)
    PEARL.info("Sending the error traceback to the server...")

    local mod
    -- In case our KnownModIndex extension is not loaded use default function.
    local enabled_mods = KnownModIndex.GetEnabledModFancyNames and KnownModIndex:GetEnabledModFancyNames() or ModManager:GetEnabledModNames()
    if type(afflicter_modname) == "string" then
        mod = {
            id          = GetWorkshopIdNumber(afflicter_modname),
            fancyname   = GetModFancyName(afflicter_modname),
            disabled    = KnownModIndex:IsModKnownBad(afflicter_modname),
        }
    end

    PEARL.SendRawRPCToServer(PEARL.RPC.ClientError, ZipAndEncodeString({
        traceback       = traceback,
        catched         = catched == true,
        enabled_mods    = enabled_mods,
        mod             = mod,
    }))
end

if TheNet:IsDedicated() then
    -- No widgets on a dedicated server.
    PEARL.OverrideValue(_G, "SetGlobalErrorWidget", function() end)
end
