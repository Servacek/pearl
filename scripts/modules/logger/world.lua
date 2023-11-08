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


local TheNet = TheNet
local string, math = string, math

local MARKDOWN = PEARL.loadfile("libraries/markdown")
local EMBEDS = PEARL.loadfile("utils/embeds")
local LogLine = PEARL.loadfile("libraries/discordapi/models/logline")

local UserCommands = require("usercommands")

-------------------------------
-- [[ World State Handlers ]]
-------------------------------

local last_cycle
local function OnCyclesChanged(world, cycle)
    if last_cycle == cycle or PEARL.IsShuttingDown() then
        return
    end

    last_cycle = cycle

    PEARL.DiscordLogger:LogLine(LogLine()
        :SetContent(MARKDOWN.codeline(
            STRINGS.PEARL.LOGS.DAY:format(
                ((cycle or 0) + 1),
                PEARL.GetSeasonFancyName(),
                math.floor((world.state.temperature or 0) / 2 + 0.5)

                --- @TEMPORARY until catcoon is finished.
                -- PEARL.ServerNetwork:GetConnectedClientsCount(),
                -- TheNet:GetDefaultMaxPlayers()
            ):center(10)
        ))
        :SetSize(LogLine.SIZES.MEDIUM)
    )
end

local function OnPhaseChanged(world, phase)
    if phase == "day" or not InGamePlay() or PEARL.IsShuttingDown() then
        return
    end

    world.state._loaded = true

    local moonphase_icon
    if world.state.iswaxingmoon then
        moonphase_icon = PEARL.ICONS.MOONPHASES.WAXING[world.state.moonphase]
    else
        moonphase_icon = PEARL.ICONS.MOONPHASES.WANNING[world.state.moonphase]
    end

    PEARL.DiscordLogger:LogLine(LogLine()
        :SetContent(MARKDOWN.codeline(STRINGS.PEARL.LOGS.PHASE:format(
            STRINGS.PEARL.PHASES[string.upper(phase)]
        )))
        :SetIcon(moonphase_icon)
        --:SetSize(LogLine.SIZES.SMALL)
    )
end

local prev_prec = "none"
local function OnPrecipitationChanged(world, precipitation)
    if not precipitation or precipitation == prev_prec then
        return
    end

    PEARL.WallScheduler:ExecuteInTime(0, function()
        local started = precipitation ~= "none"
        if TheWorld.components.frograin then
            local frogdata = TheWorld.components.frograin:OnSave()
            if frogdata then
                local frogcap = tonumber(frogdata.frogcap)
                if frogcap > 0 then
                    precipitation = "frograin"
                end
            end
        end

        local prec = started and precipitation or prev_prec
        local prec_name = STRINGS.PEARL.PRECIPITATION_NAMES[prec] or prec

        PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS[(started and "PRECIPITATION_START" or "PRECIPITATION_STOP")]:format(
            prec_name
        ))

        prev_prec = precipitation
    end)
end

local quakeing = false
local function OnQuakeStarted()
    if quakeing then
        return
    end

    quakeing = true
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.QUAKE_START)
end

local function OnQuakeEnded()
    if not quakeing then
        return
    end

    quakeing = false
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.QUAKE_END)
end

local function OnSendLightningStrike(world, pos)
    local ents = TheSim:FindEntities(pos.x, pos.y, pos.z, 3, {"canlight"})
    if #ents <= 0 then
        return
    end

    local blockers = TheSim:FindEntities(pos.x, pos.y, pos.z, 3, {"lightningrod", "lightningblocker"})
    local x, y, z = pos:Get()
    for blocker in ipairs(blockers) do
        if blocker.components.lightningblocker and blocker:GetDistanceSqToPoint(x, y, z) <= (blocker.components.lightningblocker.block_rsq + 0.0001) then
            return -- This strike was in a range of a lightning blocker -> ignore...
        end
    end

    local str = PEARL.BuildFancyStringFor(PEARL.GroupEntitiesByPrefab(ents))
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.LIGHTNING_STRIKE:format(str), PEARL.ICONS.LIGHTNING)
end

-------------------------------
-- [[ Client State Handlers ]]
-------------------------------

local function OnClientAuthenticationComplete(world, data)
    -- TheNet:GetClientTableForUser crashes for nil values
    local client = data and data.userid and TheNet:GetClientTableForUser(data.userid) or {}
    -- This is quite spammy without the joining check tbh.
    if not client or not PEARL.ServerNetwork:IsClientJoining(client.userid) then
        return
    end

    local logline = LogLine(MARKDOWN.hlink(
        MARKDOWN.codeline(
            STRINGS.PEARL.LOGS.AUTH:format(
                client.name, client.userid
            )
        ), client.netid and MARKDOWN.escape_link_embeds(PEARL.CONSTS.STEAM_ACCOUNT_URL:format(
            client.netid
        )) or nil
    )):SetIcon(PEARL.ICONS.PLAYER_STATE.AUTH)

    if client.name and ProfanityFilter:Detect(client.name) then
        logline:Censor()
    end

    PEARL.DiscordLogger:LogLine(logline)
end

local function OnClientConnectionClosed(userid, reason)
    if not userid then
        return
    end

    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.CONNECTION_CLOSE:format(
        userid, reason or "?"
    ), PEARL.ICONS.PLAYER_STATE.FORCE_DISCONNECTED)
end

local function OnClientDisconnected(userid, expected, reason, reason_title)
    -- The userid here can sometimes be an empty string
    -- if we have failed to authenticate the client.
    -- Do not announce such cases.
    if type(userid) ~= "string" or #userid < 3 then
        return
    end

    -- Hide custom reasons in public logs.
    if type(reason_title) == "string" and #reason_title > 0 then
        reason = "ID_DST_DYNAMIC_REASON"
    end

    local client = TheNet:GetClientTableForUser(userid)
    local name = client and client.name
    local pattern_spec = (type(name) ~= "string" or #name < 3) and "DISCONNECT_GENERIC" or
                    (type(reason) == "string" and #reason > 1) and "DISCONNECT_REASON" or
                    (expected == false) and "DISCONNECT_UNEXPECTED" or "DISCONNECT"

    local shardname = PEARL.GetShardFancyName()
    local pattern = STRINGS.PEARL.LOGS[pattern_spec]
    local logline = LogLine(
        MARKDOWN.codeline(pattern:format((name or userid), shardname, userid, reason or ""))
    )

    if name and ProfanityFilter:Detect(name) then
        logline:Censor()
    end

    PEARL.DiscordLogger:LogLine(logline)
end

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
    ), PEARL.ICONS.PLAYER_PREFABS[player.prefab] or PEARL.ICONS.PLAYER_PREFABS.unknown)

    -- We have to also support the case where the agreement is disabled.
    if not PEARL.DB:FirstTimeJoined(player.userid) then
        return
    end

    -- Execute this here to make sure the player is new.
    -- Send a nice welcome message for novices.
    local welcome_msg_template = STRINGS.PEARL.NOVICE_ANNOUNCEMENTS[math.random(1, #STRINGS.PEARL.NOVICE_ANNOUNCEMENTS)]
    local welcome_msg = welcome_msg_template:format(player:GetDisplayName())
    if PEARL.ServerNetwork:GetConnectedClientsCount() > 1 then
        -- Only announce it if there are more people on the server.
        return PEARL.AnnounceWithType(welcome_msg, PEARL.CONSTS.ANN_TYPE.WELCOME)
    end

    return PEARL.DiscordLogger:LogString(
        welcome_msg, PEARL.ICONS.ANNOUNCEMENTS[PEARL.CONSTS.ANN_TYPE.WELCOME]
    )
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

local function OnPlayerSpawned(self, player)
    print("OnPlayerSpawned")
    if not player.userid or player.userid == "" then
        return
    end

    local x, y, z = player.Transform:GetWorldPosition()
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.SPAWN_AT:format(
        player:GetDisplayName(), PEARL.GetShardFancyName(), x, y, z
    ), PEARL.ICONS.PLAYER_PREFABS[player.prefab] or PEARL.ICONS.PLAYER_PREFABS.unknown)
end

local function OnReset(self)
    PEARL.DiscordLogger:LogStringHighlighted(STRINGS.PEARL.LOGS.RESET:format(
        MARKDOWN.codeline(PEARL.GetShardFancyName())
    ), PEARL.ICONS.SIM_STATE.REGENERATE)
end

local function OnRollback(self, snapshots)
    -- Zero snapshots means a regular reload.
    if not snapshots or snapshots <= 0 then
        return
    end

    PEARL.DiscordLogger:LogStringHighlighted(STRINGS.PEARL.LOGS.ROLLBACK:format(
        MARKDOWN.codeline(tostring(snapshots))
    ), PEARL.ICONS.SERVER_STATE.ROLLBACK)
end

local function OnDaysBack(self, days, after)
    -- Zero days means a regular reload.
    if not days or days <= 0 then
        return
    end

    local pt_spec = "DAYSBACK"
    local cycles = TheWorld and TheWorld.state and TheWorld.state.cycles
    local target_day = cycles and (cycles + 1 - days)
    if target_day and target_day > 0 then
        pt_spec = pt_spec.."_COUNT"
    else
        target_day = nil
    end

    if type(after) == "number" and after > 0 then
        pt_spec = pt_spec.."_AFTER"
    else
        after = nil
    end

    PEARL.DiscordLogger:LogStringHighlighted(STRINGS.PEARL.LOGS[pt_spec]:format(
        target_day or days, after
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
            world:SafeListenForEvent("precipitationchanged", OnPrecipitationChanged)

            world:SafeListenForEvent("showworldreset", OnResetCountDownStart)
            world:SafeListenForEvent("hideworldreset", OnResetCountDownStop)

            world:SafeListenForEvent("ms_sendlightningstrike", OnSendLightningStrike)

            world:SafeListenForEvent("ms_startvote", OnStartVote)
            world:SafeListenForEvent("ms_stopvote", OnStopVote)
        else
            world:SafeListenForEvent("ms_playerspawn", OnPlayerSpawnedInCaves)
        end

        world:SafeListenForEvent("ms_clientauthenticationcomplete", OnClientAuthenticationComplete)
        world:SafeListenForEvent("ms_playerdespawnandmigrate", OnPlayerMigrating)
        world:SafeListenForEvent("ms_playerdespawnanddelete", OnPlayerDespawnAndDelete)
        world:SafeListenForEvent("ms_newplayerspawned", OnNewPlayerSpawn)
        --world:SafeListenForEvent("ms_playerspawn", OnPlayerSpawned)
        world:SafeListenForEvent("ms_save", OnSaved)

        --> Mod Events
        world:ListenForModEvent("world_rollback", OnRollback)
        world:ListenForModEvent("world_rollback_days", OnDaysBack)
        world:ListenForModEvent("world_restart", OnRestart)
        world:ListenForModEvent("world_reset", OnReset)
        world:ListenForModEvent("worldgencomplete", OnWorldGenComplete)

        -- if world.components.playerspawner then
        --     --- Use precall because some data may be cleared during the original function execution.
        --     PEARL.AddClassFunctionPreCall("SpawnAtLocation", function(self, world, player, x, y, z, isloading)
        --         if player and x and y and z then
        --             OnPlayerSpawnedAt(player, x, y, z)
        --         end
        --     end, world.components.playerspawner)
        -- end
    end
end)

local function RegisterNetworkListeners(network)
    if network.components.quaker or PEARL.CONFIG.DEBUG_MODE then
        network:ListenForEvent("endquake", OnQuakeEnded)
        network:ListenForEvent("startquake", OnQuakeStarted)
    end
end

AddPrefabPostInit("cave_network", RegisterNetworkListeners)
AddPrefabPostInit("forest_network", RegisterNetworkListeners)

--> Mod Internal Events
PEARL.EventProcessor:AddSafeEventHandler("clientconnectionclosed", OnClientConnectionClosed)
PEARL.EventProcessor:AddSafeEventHandler("ms_clientdisconnected", OnClientDisconnected)
