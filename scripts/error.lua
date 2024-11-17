--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
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

--[[
    KNOWN ERRORS
    - DoLuaFile Error: #[string "scripts/json.lua"]:330: Failed to scan constant at starting position 19566 from string
       - Most likely one of the mods in the "mods" folder has some crap in it's modinfo.lua that our json is unable to parse.¨

    - [00:08:05]: [string "scripts/widgets/uiclock.lua"]:252: invalid number of time segs
      - Netvars desynchronized... again.
--]]


local PopupDialogScreen = require("screens/redux/popupdialog")

--------------------------------
-- [[ Constants ]]
--------------------------------

local MOD_AFFLICTER_PATTERN = "../mods/([^/]+)/.+" --"%#?%[string \"../mods/([^/]+)/.*\"%]%:"
local CLIENT_LOG_BACKUP_FILENAME_PATTERN = "client_log_%Y-%m-%d-%H-%M-%S.txt"
local CLIENT_LOG_BACKUP_PATH = "../../backup/client_log/%s"

local CLIENT_LOG_TIMESTAMP_TOLERANCE = 60 -- Seconds
local MAX_CLIENT_LOG_LENGTH = 10000
local GRACEFULL_SHUTDOWN_PT = "%[%d%d:%d%d:%d%d%]: Shutting down[\r\n]*$" -- This should be on the last line of the file.

--------------------------------
-- [[ Locals ]]
--------------------------------

local function TryGetAfflicterMod(traceback)
    return traceback:match(MOD_AFFLICTER_PATTERN)
end

local function OnClientError(traceback)
    --- First of all, ensure that only the afflicter mod will be disabled.
    --- We do not want all player mods to be disabled if the crash is our fault especially.
    local boot_modindex_filename = "boot_"..KnownModIndex:GetModIndexName()
    SavePersistentString(boot_modindex_filename, "done", false)

    PEARL.EventProcessor:HandleEvent("clienterror", traceback)

    local afflicter_modname = TryGetAfflicterMod(traceback)
    if (not KnownModIndex:IsModDisablingDisabled() or PEARL.CONFIG.DEBUG_MODE) then
        if KnownModIndex:IsModEnabledAny(afflicter_modname) then
            PEARL.info("Disabling mod", afflicter_modname, "because it crashed the game!")

            ModManager:RemoveBadMod(afflicter_modname, traceback)
        end
    end

    PEARL.SendErrorTracebackToServer(
        traceback, false, afflicter_modname
    )

    -- In case the error was caused by bad chat history data.
    if PEARL.CONFIG.DEBUG_MODE then
        ChatHistory:Clear()
    end

    -- No disconnecting in debug mode... We have our fancy "Realod Save" button!
    if PEARL.CONFIG.DEBUG_MODE then
        SetServerPaused(true) -- At least pause the game when viewing the error screen.
    -- elseif PEARL.ClientNetwork then
    --     PEARL.info("Disconnecting the user from the server...")
    --     PEARL.ClientNetwork:Disconnect("ID_DST_USER_CRASHED")
    -- else
    --     TheNet:Disconnect(false)
    end

    -- Do not force abort here in case we are displaying the error.
    if KnownModIndex:IsModKnownBad(afflicter_modname) then
        -- Make sure we call this only when all afflicter mods exist.
        -- Only the first error will be shown (so this one should be the first)
        ModManager:DisplayBadMods()
    end
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
-- Pre/Post Calls
----------------------------------

-- "DisplayError" is called from the engine (most of the time) for non-catched errors.
PEARL.AddGlobalFunctionPreCall("DisplayError", function(traceback)
    -- We do not want more errors
    local success, err = pcall(OnError, traceback)
    if not success then
        PEARL.error("Error while handling an error!\n", err)
    end
end)

-- "debug.traceback" is used for errors catched by the game.
PEARL.AddFunctionPostCall("traceback", function(data, thread, message)
    local traceback = type(data[1]) == "string" and data[1] or "No Traceback"
    if PEARL.DiscordReporter and PEARL.DiscordReporter:IsEnabled() then
        PEARL.DiscordReporter:ReportCatchedLuaError(traceback)
    elseif PEARL.ClientNetwork then
        PEARL.ClientNetwork:SendErrorTracebackToServer(traceback, true)
    end

    --TheSim:ResetError() -- The game is still frozen anyway.
end, debug, true)

----------------------------------
-- Event Listeners/Handlers
----------------------------------

--- e. g. client_log_2024-05-17-09-07-15
local function GetClientLogFileNameForTime(timestamp)
    return os.date(CLIENT_LOG_BACKUP_FILENAME_PATTERN, timestamp)
end

local function GetClientLogForTime(timestamp)
    --- @Note: Currently this method won't work because the backup folder has
    ---        logs containing their backup time instead of their last modification time.
    timestamp = PEARL.BOOT_TIME

    for offset = 0, CLIENT_LOG_TIMESTAMP_TOLERANCE * 2 do -- Center around the timestamp
        local modifier = offset % 2 == 0 and -(offset * .5) or (offset + 1) * .5
        local logfilename = GetClientLogFileNameForTime(timestamp + modifier)
        local logfilepath = CLIENT_LOG_BACKUP_PATH:format(logfilename)
        local log = PEARL.ClusterPersistence:GetFileContent(logfilepath)
        if log and not log:blank() then
            return log, logfilename
        end
    end
end

local show_last_crash_popup, logs_sent = false, false
PEARL.EventProcessor:AddSafeEventHandler("connection_allowed", function(data)
    if (tonumber(data.last_joined_time) or 0) < (tonumber(data.last_unexpected_disconnection) or 0) then
        PEARL.info("Looks like last time we didn't disconnect gracefully, let's see what was the problem...")
        show_last_crash_popup = true

        local log, logfilename = GetClientLogForTime(data.last_unexpected_disconnection)
        if not log then
            return PEARL.info("Couldn't fetch any reasonable log for this, so nevermind I guess.")
        end

        if log:find(GRACEFULL_SHUTDOWN_PT) ~= nil then
            return PEARL.info("No error detected, ignoring...")
        end

        -- Since the error is usually at the bottom, we can throw the lslice right away.
        local _, rslice = log:slice(MAX_CLIENT_LOG_LENGTH, "\n")
        PEARL.SendClientLogToThirdParty(rslice, logfilename, STRINGS.PEARL.LOGS.LAST_CRASH_LOG_FETCHED:format(
            TheNet:GetUserID(), TheNet:GetLocalUserName()
        ))
    end
end)

local function OnPlayerActivated()
    if show_last_crash_popup then
        show_last_crash_popup = false

        local popup
        local body = logs_sent and STRINGS.PEARL.UI.LAST_CRASH_POPUP.BODY_CATCHED or STRINGS.PEARL.UI.LAST_CRASH_POPUP.BODY_UNCATCHED
        popup = TheFrontEnd:PushScreen(PopupDialogScreen(
            STRINGS.PEARL.UI.LAST_CRASH_POPUP.TITLE, body, {
                {
                    text = STRINGS.PEARL.UI.LAST_CRASH_POPUP.CONTINUE,
                    cb = function() TheFrontEnd:PopScreen(popup) end
                }
            }, nil, nil, "dark"
        ))
    end
end

PEARL.AddWorldPostInit(function(world)
    world:ListenForEvent("playeractivated", OnPlayerActivated)
    -- Show the popup in lobby as well.
    world:ListenForEvent("entercharacterselect", OnPlayerActivated)
end)

----------------------------------
-- RPC
----------------------------------

PEARL.AddRawServerRPCHandler("ClientError", function(userid, datastr)
    PEARL.debug("ClientError", userid)

    if not PEARL.DiscordReporter or PEARL.DiscordReporter:IsDisabled() then
        return PEARL.error("Client", userid, "crashed! Reports to discord are either disabled or not initialized!", datastr)
    end

    -- datastr here should be always zipped.
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
            disabled    = KnownModIndex:IsModKnownBad(afflicter_modname) and not KnownModIndex:IsModTempEnabled(afflicter_modname),
        }
    end

    PEARL.SendRawRPCToServer(PEARL.RPC.ClientError, ZipAndEncodeString({
        traceback       = traceback,
        catched         = catched == true,
        enabled_mods    = enabled_mods,
        mod             = mod,
    }))
end

function PEARL.SendClientLogToThirdParty(log, filename, title)
    PEARL.info("Sending our client logs to a third party service for error identification...")

    PEARL.HTTPClient:POST(PEARL.CONFIG.DISCORD.PROXY.URL.."/client_log_report", function()
        logs_sent = true
    end, {
        content = title,
        log = log,
        filename = filename,
    }):Send()
end

if TheNet:IsDedicated() then
    -- No widgets on a dedicated server.
    PEARL.OverrideValue(_G, "SetGlobalErrorWidget", function() end)
end
