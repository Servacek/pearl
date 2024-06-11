--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local TheShard = TheShard

local MARKDOWN = PEARL.loadfile("libraries/markdown")
local EMBEDS = PEARL.loadfile("utils/embeds")

local LogLine = PEARL.loadfile("libraries/discordapi/models/logline")

-------------------------------
-- [[ Locals ]]
-------------------------------

local _is_shutting_down = false

-------------------------------
-- [[ Server State Handlers ]]
-------------------------------

local function OnShutdown(error)
    PEARL.debug("OnShutdown")

    if _is_shutting_down then
        return PEARL.debug("Already announced shutdown!")
    end

    _is_shutting_down = true

    PEARL.DiscordLogger:LogStringHighlighted(
        STRINGS.PEARL.LOGS[error and "SHUTDOWN_ERROR" or "SHUTDOWN"]:format(
            MARKDOWN.codeline(PEARL.GetShardFancyName())
        ), PEARL.ICONS.SERVER_STATE[error and "CRASH" or "STOP"], true
    )
end

--- @TODO: Log temporary bans
local function OnClientBanned(userid)
    -- Log only offline players being banned, since they are announced by the game itself otherwise.
    if userid and not PEARL.ServerNetwork:IsClientConnectedAny(userid) then
        PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.OFFLINE_CLIENT_BANNED:format(
            userid
        ), PEARL.ICONS.ANNOUNCEMENTS["banned_from_game"])
    end
end

local function OnClientUnbanned(userid)
    if userid then
        PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.CLIENT_UNBANNED:format(
            userid
        ), PEARL.ICONS.PLAYER_STATE.UNBAN)
    end
end

local function OnShardStateUpdate(world_id, state, ...)
    if not (state and TheWorld) then
        return
    end

    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.CAVES_STATE_UPDATE:format(
        state == REMOTESHARDSTATE.READY and STRINGS.PEARL.SHARD_STATE.CONNECTED or STRINGS.PEARL.SHARD_STATE.DISCONNECTED
    ))
end

--- Too spammy...
--- 18.02.2023: Or maybe not?
local function OnSimPaused()
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.SIM_PAUSED)
end

local function OnSimUnpaused()
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.SIM_UNPAUSED)
end

local function OnServerPaused(doer)
    PEARL.DiscordLogger:LogString(
        doer and STRINGS.PEARL.LOGS.SERVER_PAUSE_BY:format(doer)
        or STRINGS.PEARL.LOGS.SERVER_PAUSE, PEARL.ICONS.SERVER_STATE.PAUSE
    )
end

local function OnServerUnpaused(doer)
    PEARL.DiscordLogger:LogString(
        doer and STRINGS.PEARL.LOGS.SERVER_UNPAUSE_BY:format(doer)
        or STRINGS.PEARL.LOGS.SERVER_UNPAUSE
    )
end

local function OnInitialFullLaunch()
    -- TheWorld should exist at this point
    if _is_shutting_down then
        return
    end

    PEARL.DiscordLogger:LogEmbed(EMBEDS.ServerInfo(true))
end

local function OnShardLoaded(master)
    if POPULATING or PEARL.IsShuttingDown() then
        return
    end

    local template = master and STRINGS.PEARL.LOGS.SHARD_LOADED_MASTER or STRINGS.PEARL.LOGS.SHARD_LOADED_SECONDARY
    PEARL.DiscordLogger:LogStringHighlighted(
        template:format(PEARL.GetShardFancyName(), STRINGS.PEARL.SHARDS.MASTER), PEARL.ICONS.CHECK, true
    )
end

local function OnModBackendPostInit()
    if PEARL.IsShuttingDown() then
        return
    end

    local str = PEARL.IS_BACKUP and STRINGS.PEARL.LOGS.MOD_BACKUP_INIT or
        STRINGS.PEARL.LOGS.MOD_INIT

    --- @type LogLine
    local logline = LogLine(MARKDOWN.bold(str))
    logline:SetSize(LogLine.SIZES.SMALL)
    PEARL.DiscordLogger:LogLine(logline, true)
end

local function OnInvalidClientRPC(rpc_name, userid)
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.INVALIDRPC:format(
        (rpc_name or "???"), userid or "UNKNOWN"
    ), PEARL.ICONS.X)
end

local function OnErrorCatched(traceback)

end

local function OnDatabaseFieldChanged(userid, field, new_value, old_value)
    if field == "username" then
        PEARL.DiscordLogger:LogStringHighlighted(STRINGS.PEARL.LOGS.PLAYER_RENAMED:format(
            MARKDOWN.codeline(userid), MARKDOWN.codeline(old_value), MARKDOWN.codeline(new_value)
        ), PEARL.ICONS.TAG)
    end
end

-------------------------------
-- [[ Listeners ]]
-------------------------------

PEARL.AddSimPostInit(function()
    if not (TheWorld and PEARL.DiscordLogger and PEARL.DiscordLogger:IsEnabled()) then
        return
    end

    if PEARL.IsShuttingDown() then
        return
    end

    OnShardLoaded(TheWorld.ismastershard)

    if TheWorld.ismastershard then
        --- Use the world event since it called later so ActionLog has time to send it's logs.
        TheWorld:ListenForModEvent("ms_simpaused", OnSimPaused)

        PEARL.EventProcessor:AddSafeEventHandler("shard_stateupdate", OnShardStateUpdate)

        -- initial + current
        if PEARL.INITIAL_FULL_LAUNCH then
            OnInitialFullLaunch()
        end
    end
end)

--- This is actually the point where most of the mod's stuff is loaded.
--- (translations, rpcs, ...)
PEARL.AddFrontEndPostInit(function(fe)
    if TheShard:IsMaster() and not PEARL.INIT then
        OnModBackendPostInit()
    end
end)

PEARL.EventProcessor:AddSafeEventHandler("invalidrpc", OnInvalidClientRPC)
PEARL.EventProcessor:AddSafeEventHandler("shard_shutdown", OnShutdown)

if TheShard:IsMaster() then
    PEARL.EventProcessor:AddSafeEventHandler("clientbanned", OnClientBanned)
    PEARL.EventProcessor:AddSafeEventHandler("clientunbanned", OnClientUnbanned)

    PEARL.EventProcessor:AddSafeEventHandler("simulation_unpaused", OnSimUnpaused)

    PEARL.EventProcessor:AddSafeEventHandler("server_paused", OnServerPaused)
    PEARL.EventProcessor:AddSafeEventHandler("server_unpaused", OnServerUnpaused)
end

PEARL.EventProcessor:AddSafeEventHandler("errorcatched", OnErrorCatched)

PEARL.EventProcessor:AddSafeEventHandler("db_fieldchanged", OnDatabaseFieldChanged)
