--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--[[
    Stores logging handlers for event's pushed by TheWorld.
--]]


local TheShard, TheNet = TheShard, TheNet
local string, math = string, math

local MARKDOWN = PEARL.loadfile("libraries/markdown")
local EMBEDS = PEARL.loadfile("utils/embeds")

local UserCommands = require("usercommands")

-------------------------------
-- [[ World State Handlers ]]
-------------------------------

local last_cycle
local function OnCyclesChanged(world, cycle)
    if last_cycle == cycle then
        return
    end

    last_cycle = cycle

    PEARL.DiscordLogger:LogStringRaw(MARKDOWN.bold(MARKDOWN.codeline(
        STRINGS.PEARL.LOGS.DAY:format(
            ((cycle or 0) + 1),
            PEARL.GetSeasonFancyName(),
            math.floor((world.state.temperature or 0) / 2 + 0.5),

            --- @TEMPORARY until catcoon is finished.
            PEARL.ServerNetwork:GetConnectedClientsCount(),
            TheNet:GetDefaultMaxPlayers()
        ):center(20)
    )))
end

local function OnPhaseChanged(world, phase)
    if phase == "day" or not InGamePlay() then
        return
    end

    world.state._loaded = true

    local moonphase_icon
    if world.state.iswaxingmoon then
        moonphase_icon = PEARL.ICONS.MOONPHASES.WAXING[world.state.moonphase]
    else
        moonphase_icon = PEARL.ICONS.MOONPHASES.WANNING[world.state.moonphase]
    end

    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PHASE:format(
        STRINGS.PEARL.PHASES[string.upper(phase)]
    ), moonphase_icon)
end

-------------------------------
-- [[ Client State Handlers ]]
-------------------------------

local function OnClientAuthenticationComplete(world, data)
    -- TheNet:GetClientTableForUser crashes for nil values
    local client = data and data.userid and TheNet:GetClientTableForUser(data.userid)
    -- This is quite spammy without the joining check tbh.
    if not client or not PEARL.ServerNetwork:IsClientJoining(client.userid) then
        return
    end

    PEARL.DiscordLogger:LogStringRaw(MARKDOWN.escape_link_embeds(MARKDOWN.hlink(
        MARKDOWN.codeline(
            STRINGS.PEARL.LOGS.AUTH:format(
                client.name, client.userid
            )
        ), client.netid and PEARL.CONSTS.STEAM_ACCOUNT_URL:format(
            client.netid
        ) or nil
    )), PEARL.ICONS.PLAYER_STATE.AUTH)
end

local function OnClientConnectionClosed(userid, reason)
    if not userid then
        return
    end

    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.CONNECTION_CLOSE:format(
        userid, reason or "?"
    ), PEARL.ICONS.PLAYER_STATE.FORCE_DISCONNECTED)
end

local function OnClientDisconnected(userid, expected, reason)
    -- The userid here can sometimes be an empty string
    -- if we have failed to authenticate the client.
    -- Do not announce such cases.
    if type(userid) ~= "string" or #userid < 3 then
        return
    end

    local client = TheNet:GetClientTableForUser(userid)
    local name = client and client.name

    if type(name) ~= "string" or #name < 3 then
        return PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.DISCONNECT_GENERIC:format(
                userid, PEARL.GetShardFancyName()
        ))
    end

    if type(reason) == "string" and #reason > 1 then
        return PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.DISCONNECT_REASON:format(
                name, PEARL.GetShardFancyName(), userid, reason
        ))
    end

    if expected == false then
        return PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.DISCONNECT_UNEXPECTED:format(
                name, PEARL.GetShardFancyName(), userid
        ))
    end

    return PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.DISCONNECT:format(
            name, PEARL.GetShardFancyName(), userid
    ))
end

--- @TODO: v2.1
-- local function Logger.OnPlayerWarnedForGriefing(name)
--     if not name then return end

--     PEARL.Logger:LogString(
--         STRINGS.PEARL.LOGS.WARNED:format(name),
--         PEARL.ICONS.ANNOUNCEMENTS["default"]
--     )
-- end

-- data.player, data.portalid, data.worldid
local function OnPlayerMigrating(self, data)
    if not (data and data.player) then
        return
    end

    local to_master = data.worldid == SHARDID.MASTER
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.MIGRATING:format(
        data.player:GetDisplayName(), PEARL.GetShardFancyNameByID(data.worldid)
    ), to_master and PEARL.ICONS.PLAYER_STATE.CAVE_LEAVE or PEARL.ICONS.PLAYER_STATE.CAVE_ENTER)
end

local function OnPlayerDespawnAndDelete(self, player)
    if not player then
        return
    end

    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PLAYER_DESPAWN:format(
        player:GetDisplayName(), STRINGS.CHARACTER_NAMES[player.prefab] or STRINGS.CHARACTER_NAMES.UNKNOWN
    ), PEARL.ICONS.PLAYER_PREFABS[player.prefab] or PEARL.ICONS.PLAYER_PREFABS.unknown)
end

local function OnPlayerSpawnedInCaves(self, player)
    if not player then
        return
    end

    -- Give a tick to the player's instance so it can load all the needed data.
    PEARL.WallScheduler:ExecuteInTime(0, function()
        local client = player.userid and TheNet:GetClientTableForUser(player.userid)
        if not client then
            return
        end

        PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.CONNECTED_TO_SHARD:format(
            client.name, PEARL.GetShardFancyName(), client.userid
        ))
    end)
end

-------------------------------
-- [[ Server State Handlers ]]
-------------------------------

-- Vote passed and vote failed is being announced by Networking.
-- So handle only the start and the cancelation of it.
local function OnStartVote(self, data)
    local doer = data and data.starteruserid and TheNet:GetClientTableForUser(data.starteruserid)
    local target = data and data.targetuserid and TheNet:GetClientTableForUser(data.targetuserid)
    if not (doer and target) then
        return
    end

    local command = UserCommands.GetCommandFromHash(data.commandhash)
    local votefmt = ResolveCommandStringProperty(command, "votenamefmt", STRINGS.UI.NOTIFICATION.DEFAULTVOTENAMEFMT)
    local votename = votefmt:format(target and target.name or "?")

    PEARL.DiscordLogger:LogString(
        (doer and doer.name) and STRINGS.PEARL.LOGS.START_VOTE:format(
            doer.name, votename
        ) or STRINGS.PEARL.LOGS.START_VOTE_ANONYMOUS:format(
            votename
        ), PEARL.ICONS.ANNOUNCEMENTS["vote"]
    )
end

local function OnStopVote(self)
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.STOP_VOTE,
        PEARL.ICONS.ANNOUNCEMENTS["vote"]
    )
end

local function OnNewPlayerSpawn(self, player)
    if not player then
        return
    end

    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.NEW_PLAYER_SPAWN:format(
        player:GetDisplayName(), STRINGS.CHARACTER_NAMES[player.prefab] or STRINGS.CHARACTER_NAMES.UNKNOWN
    ), PEARL.ICONS.PLAYER_PREFABS[player.prefab])

    local cfd = PEARL.ServerNetwork:GetCachedCFDFor(player.userid)
    if not cfd or not cfd.novice == true then
        return
    end

    -- Send a nice welcome message for novices.
    local welcome_msg_template = STRINGS.PEARL.NOVICE_ANNOUNCEMENTS[math.random(1, #STRINGS.PEARL.NOVICE_ANNOUNCEMENTS)]
    local welcome_msg = welcome_msg_template:format(player:GetDisplayName())
    if #AllPlayers > 1 then
        return PEARL.AnnounceWithType(welcome_msg, PEARL.CONSTS.ANNOUNCEMENT_TYPES.WELCOME)
    end

    if PEARL.DiscordLogger and PEARL.DiscordLogger:IsEnabled() then
        return PEARL.DiscordLogger:LogString(
            welcome_msg, PEARL.ICONS.ANNOUNCEMENTS[PEARL.CONSTS.ANNOUNCEMENT_TYPES.WELCOME]
        )
    end
end

--- Note: This seems to be a bit spammy.
local _countdown_started = false
local function OnResetCountDownStart(self)
    if not InGamePlay() or _countdown_started then
        return
    end

    local resettime = GetResetTime() or {time = 120}
    -- This should never really happen
    if not resettime then
        return PEARL.error("OnResetCountDownStart was called even though resettime is nil!")
    end

    -- There is no point in the announcement here.
    if resettime.instant then
        return
    end

    _countdown_started = true

    PEARL.DiscordLogger:LogStringHighlighted(STRINGS.PEARL.LOGS.RESET_COUNTDOWN_START:format(
        MARKDOWN.codeline(tostring(resettime.time or 0))
    ), PEARL.ICONS.ANNOUNCEMENTS["default"])
end

--- Note: Sometimes this is being called even when the countdown hasn't started yet.
local function OnResetCountDownStop(self)
    if _countdown_started and InGamePlay() then
        PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.RESET_COUNTDOWN_STOP)
    end
end

local function OnReset(self)
    PEARL.DiscordLogger:LogStringHighlighted(STRINGS.PEARL.LOGS.RESET:format(
        MARKDOWN.codeline(PEARL.GetShardFancyName())
    ), PEARL.ICONS.SIM_STATE.REGENERATE)
end

local function OnRollback(self, count)
    if not count or count <= 0 then
        return
    end

    PEARL.DiscordLogger:LogStringHighlighted(STRINGS.PEARL.LOGS.ROLLBACK:format(
        MARKDOWN.codeline(tostring(count))
    ), PEARL.ICONS.SERVER_STATE.ROLLBACK)
end

local function OnRestart()
    PEARL.DiscordLogger:LogStringHighlighted(STRINGS.PEARL.LOGS.RESTART:format(
        MARKDOWN.codeline(PEARL.GetShardFancyName())
    ), PEARL.ICONS.SERVER_STATE.RESTART)
end

local function OnWorldGenComplete(world)
    if not world then
        return
    end

    PEARL.DiscordLogger:LogEmbed(EMBEDS.WorldRegen(world))
end

local function OnSaved(world)
    return PEARL.DiscordLogger:LogStringHighlighted(STRINGS.PEARL.LOGS.SAVE:format(
        MARKDOWN.codeline(PEARL.GetShardFancyName())
    ), PEARL.ICONS.SERVER_STATE.SAVE)
end

-------------------------------
-- [[ Listeners ]]
-------------------------------

-- TheWorld is not provided here.
PEARL.AddWorldPostInit(function(world)
    if not world then
        return
    end

    if PEARL.DiscordLogger and PEARL.DiscordLogger:IsEnabled() then
        if world.ismastershard then

            -- We care about these event's only on the master shard
            world:SafeListenForEvent("cycleschanged", OnCyclesChanged)
            world:SafeListenForEvent("phasechanged", OnPhaseChanged)

            world:SafeListenForEvent("showworldreset", OnResetCountDownStart)
            world:SafeListenForEvent("hideworldreset", OnResetCountDownStop)

            world:SafeListenForEvent("ms_startvote", OnStartVote)
            world:SafeListenForEvent("ms_stopvote", OnStopVote)
        else
            world:SafeListenForEvent("ms_playerspawn", OnPlayerSpawnedInCaves)
        end

        world:SafeListenForEvent("ms_clientauthenticationcomplete", OnClientAuthenticationComplete)
        world:SafeListenForEvent("ms_playerdespawnandmigrate", OnPlayerMigrating)
        world:SafeListenForEvent("ms_newplayerspawned", OnNewPlayerSpawn)
        world:SafeListenForEvent("ms_save", OnSaved)

        --> Mod Events
        world:ListenForModEvent("world_rollback", OnRollback)
        world:ListenForModEvent("world_restart", OnRestart)
        world:ListenForModEvent("world_reset", OnReset)
        world:ListenForModEvent("worldgencomplete", OnWorldGenComplete)
    end
end)

--> Mod Internal Events
PEARL.EventProcessor:AddSafeEventHandler("clientconnectionclosed", OnClientConnectionClosed)
PEARL.EventProcessor:AddSafeEventHandler("ms_clientdisconnected", OnClientDisconnected)
