
local PEARL = PEARL
local TheShard = TheShard
local string = string

local MARKDOWN = require("libraries/markdown")
local TEMPLATES = require("widgets/redux/templates")
local Embed = require("libraries/discordapi/models/embed")

-------------------------------
-- [[ Server State Handlers ]]
-------------------------------

local function OnShutdown()
    PEARL.DiscordLogger:LogStringHighlighted(STRINGS.PEARL.LOGS.SHUTDOWN:format(
        MARKDOWN.codeline(PEARL.GetShardName())
    ), PEARL.ICONS.SERVER_STATE.STOP)
end

-- local function OnStart()
--     PEARL.Logger:LogStringHighlighted(STRINGS.PEARL.LOGS.START)
-- end

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
    if not (TheWorld and TheWorld.meta) then
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
    PEARL.DiscordLogger:LogStringHighlighted("Systém Inicializovaný. Načítavanie servera...", nil, true)
end

-- local function OnError(error_msg, silent)
--     PEARL.info("Sending error report...")

--     local message = PEARL.Rhook:SendLogLine(MARKDOWN.bold(STRINGS.PEARL.ERROR)
--         .."\n"..MARKDOWN.codeblock(tostring(error_msg)), nil, true
--     )
--     if message and not silent then
--         message:AllowMentionsForType(Message.MENTION_TYPES.USERS)
--     end
-- end

-------------------------------
-- [[ Listeners ]]
-------------------------------

PEARL.AddGamePostInit(function()
    if not (TheWorld and PEARL.CONFIG.DISCORD.ENABLED) then
        return
    end

    TheWorld:ListenForEvent("shard_shutdown", OnShutdown)

    if TheWorld.ismastershard then
        TheWorld:ListenForEvent("serverpauseddirty", OnPauseDirty)

        -- Shard Networking
        TheWorld:ListenForEvent("shard_stateupdate", OnShardStateUpdate)

        -- initial + current
        if TheSim:GetNumLaunches() == 2 then
            OnFirstLaunch()
        end
    end
end)

PEARL.AddModPostInit(function()
    if TheShard:IsMaster() and TheSim:GetNumLaunches() > 1 then
        OnModBackendPostInit()
    end
end)
