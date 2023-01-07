--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--local PEARL = PEARL
local TheShard = TheShard

local TEMPLATES = require("widgets/redux/templates")

local MARKDOWN = PEARL.loadfile("libraries/markdown")
local Embed = PEARL.loadfile("libraries/discordapi/models/embed")

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
            MARKDOWN.codeline(PEARL.GetShardName())
        ), PEARL.ICONS.SERVER_STATE.STOP, true
    )
end

local function OnShardStateUpdate(world, state)
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

-- This is being called only for Master shard
-- function Logger.OnGamePostInit()
--     SUB.Lhook:SendNotifyImportant(SUB.STRINGS.GAME_LOADED:format(
--         MARKDOWN.codeline(SUB.GetShardName())
--     ))
-- end

local function OnFirstLaunch()
    -- TheWorld should exist at this point
    if not (TheWorld and TheWorld.meta) or _is_shutting_down then
        return
    end

    PEARL.DiscordLogger:LogEmbed(Embed()
        :SetTitle(STRINGS.PEARL.LOGS.STARTUP_EMBED_TITLE)
        :SetColor(Embed.COLORS.GREEN)
        :SetThumbnail(STRINGS.PEARL.LOGS.STARTUP_EMBED_THUMBNAIL_URL)

        :AddField(STRINGS.PEARL.LOGS.STARTUP_EMBED_FIELD_NAMES.PLATFORM, MARKDOWN.codeline(PLATFORM), true)
        :AddField(STRINGS.PEARL.LOGS.STARTUP_EMBED_FIELD_NAMES.MOD_V, MARKDOWN.codeline(PEARL.MOD_INFO.version), true)
        :AddField(STRINGS.PEARL.LOGS.STARTUP_EMBED_FIELD_NAMES.GAME_V, MARKDOWN.codeline(TEMPLATES.GetBuildString()), true)
        :AddField(STRINGS.PEARL.LOGS.STARTUP_EMBED_FIELD_NAMES.SEED, MARKDOWN.codeline(TheWorld.meta.seed), true)
        :AddField(STRINGS.PEARL.LOGS.STARTUP_EMBED_FIELD_NAMES.PLAYSTYLE, MARKDOWN.codeline(TheNet:GetServerGameMode()), true)
    )
end

local function OnModBackendPostInit()
    -- This is being sent before FrontEnd so the translations are not applied.
    PEARL.DiscordLogger:LogStringHighlighted(
        STRINGS.PEARL.LOGS.SERVER_INITIALIZED, nil, true
    )
end

-------------------------------
-- [[ Listeners ]]
-------------------------------

PEARL.AddGamePostInit(function()
    if not (TheWorld and PEARL.CONFIG.DISCORD.LHOOK.ENABLED) then
        return
    end

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

-- PEARL.AddModPostInit(function()
--     if TheShard:IsMaster() and TheSim:GetNumLaunches() > 1 then
--         OnModBackendPostInit()
--     end
-- end)

--- This is actually the point where most of the mod's stuff is loaded.
--- (translations, rpcs, ...)
PEARL.AddFrontEndPostInit(function(fe)
    if TheShard:IsMaster() and TheSim:GetNumLaunches() > 1 then
        OnModBackendPostInit()
    end
end)

-- This is being called on regens and resets as well
-- PEARL.EventProcessor:AddEventHandler("quit", OnShutdown)
