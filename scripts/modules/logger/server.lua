--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local TheShard = TheShard

local MARKDOWN = PEARL.loadfile("libraries/markdown")
local EMBEDS = PEARL.loadfile("utils/embeds")

local Message = PEARL.loadfile("libraries/discordapi/models/message")

-------------------------------
-- [[ Locals ]]
-------------------------------

local _is_shutting_down = false

-------------------------------
-- [[ Server State Handlers ]]
-------------------------------

local function OnShutdown(world, error)
    if _is_shutting_down then
        return
    end

    _is_shutting_down = true

    PEARL.DiscordLogger:LogStringHighlighted(
        STRINGS.PEARL.LOGS[error and "SHUTDOWN_ERROR" or "SHUTDOWN"]:format(
            MARKDOWN.codeline(PEARL.GetShardFancyName())
        ), PEARL.ICONS.SERVER_STATE.STOP, true
    )
end

local function OnShardStateUpdate(world, world_id, state)
    if not state then
        return
    end

    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.CAVES_STATE_UPDATE:format(
        state == REMOTESHARDSTATE.READY and STRINGS.PEARL.SHARD_STATE.CONNECTED or STRINGS.PEARL.SHARD_STATE.DISCONNECTED
    ))
end

--- Too spammy...
-- local function OnSimPaused()
--     PEARL.Logger:LogString(STRINGS.PEARL.LOGS.SIM_PAUSED, PEARL.ICONS.SIM_STATE.PAUSE)
-- end

-- local function OnSimUnpaused()
--     PEARL.Logger:LogString(STRINGS.PEARL.LOGS.SIM_UNPAUSED, PEARL.ICONS.SIM_STATE.RESUME)
-- end

local paused = false
local function OnPauseDirty(world, data)
    if not data then
        return
    end

    if not paused and data.pause then
        PEARL.DiscordLogger:LogString(
            data.source and STRINGS.PEARL.LOGS.SERVER_PAUSE_BY:format(data.source)
            or STRINGS.PEARL.SERVER_PAUSE, PEARL.ICONS.SERVER_STATE.PAUSE
        )
    elseif paused and not data.pause then
        PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.SERVER_UNPAUSE)
    end

    paused = data.pause
end

local function OnFirstLaunch()
    -- TheWorld should exist at this point
    if not (TheWorld and TheWorld.meta) or _is_shutting_down then
        return
    end

    PEARL.DiscordLogger:LogEmbed(EMBEDS.ServerBoot())
end

local function OnShardLoaded(master)
    local template = master and STRINGS.PEARL.LOGS.SHARD_LOADED_MASTER or STRINGS.PEARL.LOGS.SHARD_LOADED_SECONDARY
    PEARL.DiscordLogger:LogStringHighlighted(
        template:format(PEARL.GetShardFancyName(), STRINGS.PEARL.SHARDS.MASTER), PEARL.ICONS.CHECK
    )
end

local function OnModBackendPostInit()
    PEARL.DiscordLogger:LogStringHighlighted(
        STRINGS.PEARL.LOGS.SERVER_INITIALIZED, nil, true
    )
end

local function OnInvalidClientRPC(rpc_name, userid)
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.INVALIDRPC:format(
        (rpc_name or "???"), userid or "UNKNOWN"
    ), PEARL.ICONS.X)
end

-------------------------------
-- [[ Listeners ]]
-------------------------------

PEARL.AddSimPostInit(function()
    if not (TheWorld and PEARL.DiscordLogger and PEARL.DiscordLogger:IsEnabled()) then
        return
    end

    OnShardLoaded(TheWorld.ismastershard)

    TheWorld:ListenForModEvent("shard_shutdown", OnShutdown)

    if TheWorld.ismastershard then
        TheWorld:SafeListenForEvent("serverpauseddirty", OnPauseDirty)

        -- Shard Networking
        TheWorld:ListenForModEvent("shard_stateupdate", OnShardStateUpdate)

        -- initial + current
        if PEARL.IsFirstLaunch() then
            OnFirstLaunch()
        end
    end
end)

--- This is actually the point where most of the mod's stuff is loaded.
--- (translations, rpcs, ...)
PEARL.AddFrontEndPostInit(function(fe)
    if TheShard:IsMaster() and TheSim:GetNumLaunches() > 1 then
        OnModBackendPostInit()
    end
end)

PEARL.EventProcessor:AddSafeEventHandler("invalidrpc", OnInvalidClientRPC)
