--[[
    Stores logging handlers for event's pushed by TheWorld.
--]]


--local PEARL = PEARL
local TheShard, TheNet = TheShard, TheNet
local string, math = string, math

local MARKDOWN = PEARL.loadfile("libraries/markdown")

local UserCommands = require("usercommands")

-------------------------------
-- [[ World State Handlers ]]
-------------------------------

local function OnCyclesChanged(world, cycle)
    if not world then
        return
    end

    PEARL.DiscordLogger:LogStringRaw(MARKDOWN.bold(MARKDOWN.codeline(
        STRINGS.PEARL.LOGS.DAY:format(
            ((cycle or 0)+ 1),
            PEARL.GetSeasonFancyName(),
            math.floor((world.state.temperature or 0) / 2 + 0.5)
        ):center(30)
    )))
end

local function OnPhaseChanged(world, phase)
    if not (world and phase and phase ~= "day") then
        return
    end

    -- local moonphase_icon
    -- if world.state.iswaxingmoon then
    --     moonphase_icon = PEARL.ICONS.MOONPHASES.WAXING[world.state.moonphase]
    -- else
    --     moonphase_icon = PEARL.ICONS.MOONPHASES.WANNING[world.state.moonphase]
    -- end

    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PHASE:format(
        STRINGS.UI.SERVERLISTINGSCREEN.PHASES[string.upper(phase)]
    ))
end

-------------------------------
-- [[ Client State Handlers ]]
-------------------------------

local function OnClientAuthenticationComplete(world, data)
    -- TheNet:GetClientTableForUser crashes for nil values
    local client = data and data.userid and TheNet:GetClientTableForUser(data.userid)
    if not client or PEARL.IsClientMigrating(client) then
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

local function OnClientConnectionClosed(world, data)
    if not (data and data.userid) then
        return
    end

    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.CONNECTION_CLOSE:format(
        data.userid, data.reason or "?"
    ), PEARL.ICONS.PLAYER_STATE.FORCE_DISCONNECTED)
end

local function OnClientDisconnected(world, data)
    local client = data and data.userid and TheNet:GetClientTableForUser(data.userid)
    if not (client and client.name) then
        return
    end

    if data.expected == false then
        return PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.DISCONNECT_UNEXPECTED:format(
                client.name, PEARL.GetShardName()
        ))
    end

    return PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.DISCONNECT:format(
            client.name, PEARL.GetShardName()
    ))
end

--- @deprecated: Now the allowlist is handled by the 'JoinServerFilter'.
--- So the not allowlisted connections are being filtered before the user
--- can even join the server.
-- local function OnClientNotWhitelisted(userid)
--     if not userid then return end

--     PEARL.DiscordLogger:LogString(
--         STRINGS.PEARL.NOT_WHITELISTED:format(userid),
--         PEARL.ICONS.ANNOUNCEMENTS['kicked_from_game']
--     )
-- end

--- @TODO: v2.1
-- local function Logger.OnPlayerWarnedForGriefing(name)
--     if not name then return end

--     PEARL.Logger:LogString(
--         STRINGS.PEARL.LOGS.WARNED:format(name),
--         PEARL.ICONS.ANNOUNCEMENTS["default"]
--     )
-- end

local function OnPlayerMigrating(self, data)
    if not (data and data.player) then
        return
    end

    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.MIGRATING:format(
        data.player:GetDisplayName(), TheShard:IsMaster() and "Caves" or "Master"
    ), TheShard:IsMaster() and PEARL.ICONS.PLAYER_STATE.CAVE_ENTER or PEARL.ICONS.PLAYER_STATE.CAVE_LEAVE)
end

-------------------------------
-- [[ Server State Handlers ]]
-------------------------------

local function OnStartVote(self, data)
    local doer = data and data.starteruserid and TheNet:GetClientTableForUser(data.starteruserid)
    local target = data and data.targetuserid and TheNet:GetClientTableForUser(data.targetuserid)
    if not (doer and target) then
        return
    end

    local command = UserCommands.GetCommandFromHash(data.commandhash)
    local votefmt = ResolveCommandStringProperty(command, "votenamefmt", STRINGS.UI.NOTIFICATION.DEFAULTVOTENAMEFMT)
    local votename = votefmt:format(target and target.name or "?")

    --- @TODO: add some custom icon
    PEARL.DiscordLogger:LogString(
        (doer and doer.name) and STRINGS.PEARL.LOGS.START_VOTE:format(
            doer.name, votename
        ) or STRINGS.PEARL.LOGS.START_VOTE_ANONYMOUS:format(
            votename
        )
    )
end

local function OnStopVote(self)
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.STOP_VOTE)
end

local function OnNewPlayerSpawn(self, player)
    if not player then
        return
    end

    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.NEW_PLAYER_SPAWN:format(
        player:GetDisplayName(), STRINGS.CHARACTER_NAMES[player.prefab] or STRINGS.CHARACTER_NAMES.UNKNOWN
    ), PEARL.ICONS.PLAYER_PREFABS[player.prefab])
end

local function OnResetCountDownStart(self)
    if InGamePlay() then
        PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.RESET_COUNTDOWN_START)
    end
end

local function OnResetCountDownStop(self)
    if InGamePlay() then
        PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.RESET_COUNTDOWN_STOP)
    end
end

local function OnReset(self)
    PEARL.DiscordLogger:LogStringHighlighted(STRINGS.PEARL.LOGS.RESET:format(
        MARKDOWN.codeline(PEARL.GetShardName())
    ), PEARL.ICONS.SIM_STATE.REGENERATE)
end

local function OnRollback(self, count)
    local message
    local icon

    if count ~= nil and count > 0 then
        message = STRINGS.PEARL.LOGS.ROLLBACK:format(count)
        icon = PEARL.ICONS.SERVER_STATE.ROLLBACK
    else
        message = STRINGS.PEARL.LOGS.RESTART:format(MARKDOWN.codeline(PEARL.GetShardName()))
        icon = PEARL.ICONS.SERVER_STATE.RESTART
    end

    PEARL.DiscordLogger:LogStringHighlighted(message, icon)
end

-------------------------------
-- [[ Entity State Handlers ]]
-------------------------------

local function OnFireSpreaderKilled(doer, target)
    local x, y, z = target.Transform:GetWorldPosition()
    local entities = TheSim:FindEntities(x, y, z,
        -- The flames have bigger radius in this case
        PEARL.CONSTS.LARGE_PROPAGATOR_RADIUS,
        PEARL.CONSTS.FIRE_MUSTHAVE_TAGS,
        PEARL.CONSTS.ENT_CANTHAVE_TAGS,
        PEARL.CONSTS.ENT_ONEOF_TAGS
    )

    if #entities >= 4 or PEARL.ArrayContainsEntityWithTag(entities, "structure") then
        local message = subfmt(STRINGS.PEARL.ACTIONS.KILL.NEAR, {
            doer = doer:GetDisplayName(), target = target:GetDisplayName(), near = PEARL.FormatSortedPrefabs(entities)
        })

        PEARL.AnnounceWithType(message, PEARL.CONSTS.ANNOUNCEMENT_TYPES, doer.entity)
    end
end

local function OnNonRenewableMobKilled(doer, target)
    --- @TODO This is not ideal (also it works only for the current shard)
    local count = c_countprefabs(target.prefab, false) or -1
    if count <= 0 or count > PEARL.CONSTS.MONITORED_POPULATION_LIMIT then
        return
    end

    local message = subfmt(STRINGS.PEARL.ACTIONS.KILL.REMAINING, {
        doer = doer:GetDisplayName(), target = target:GetDisplayName()
    })

    PEARL.AnnounceWithType(message, PEARL.CONSTS.ANNOUNCEMENT_TYPES.KILL, doer.entity)
end

local function OnBossDefeated(doer, target)
    local message = subfmt(STRINGS.PEARL.ACTIONS.KILL.BOSS, {
        doer = doer:GetDisplayName(), target = target:GetDisplayName()
    })

    PEARL.AnnounceWithType(message, PEARL.CONSTS.ANNOUNCEMENT_TYPES.DEFEAT, doer.entity)
end

local function OnCompanionKilled(doer, target)
    local message = subfmt(STRINGS.PEARL.ACTIONS.KILL.GENERIC, {
        doer = doer:GetDisplayName(), target = target:GetDisplayName()
    })

    PEARL.AnnounceWithType(message, PEARL.CONSTS.ANNOUNCEMENT_TYPES.KILL, doer.entity)
end

local function OnFollowerKilled(doer, target, leader)
    local message = subfmt(STRINGS.PEARL.ACTIONS.KILL.FOLLOWER, {
        doer = doer:GetDisplayName(), target = target:GetDisplayName(), owner = leader:GetDisplayName()
    })

    PEARL.AnnounceWithType(message, PEARL.CONSTS.ANNOUNCEMENT_TYPES.KILL, doer.entity)
end

local function OnEntityDeath(self, data)
    if not data then
        return
    end

    local inst, afflicter = data.inst, data.afflicter
    if not (afflicter ~= nil and inst ~= nil and afflicter:IsValid() and inst:IsValid()) then
        return
    end

    -- BOSS, this should be announced even if the afflicter isn't a player
    if inst:HasTag("epic") then
        return OnBossDefeated(afflicter, inst)
    end

    if not afflicter:HasTag("player") then
        return
    end

    -- MOB SPREADING FIRE AFTER DEATH
    if PEARL.PREFABS.MOBS.FIRE_SPREADERS[inst.prefab] then
        return OnFireSpreaderKilled(afflicter, inst)
    end

    -- NOT RESPAWNABLE MOB
    if PEARL.PREFABS.MOBS.MONITOR_POPULATION[inst.prefab] then
        return OnNonRenewableMobKilled(afflicter, inst)
    end

    -- BOSS, this should be announced even if the afflicter isn't a player
    if inst:HasTag("epic") then
        return OnBossDefeated(afflicter, inst)
    end

    -- COMPANION
    if PEARL.PREFABS.MOBS.COMPANIONS[inst.prefab] then
        return OnCompanionKilled(afflicter, inst)
    end

    -- FOLLOWER
    local leader = inst.components.follower and inst.components.follower:GetLeader() or nil
    if leader and leader:HasTag("player") and leader ~= afflicter then
        return OnFollowerKilled(afflicter, inst)
    end
end

-------------------------------
-- [[ Listeners ]]
-------------------------------

-- Using game post init instead of world post init to prevent duplicate day announcements
-- between instance starts
PEARL.AddGamePostInit(function()
    local world = TheWorld
    if not (world) then
        return
    end

    world:SafeListenForEvent("entity_death", OnEntityDeath)

    if PEARL.CONFIG.DISCORD.LHOOK.ENABLED then
        if world.ismastershard then
            -- We care about these event's only on the master shard
            world:SafeListenForEvent("cycleschanged", OnCyclesChanged)
            world:SafeListenForEvent("phasechanged", OnPhaseChanged)

            world:SafeListenForEvent("showworldreset", OnResetCountDownStart)
            world:SafeListenForEvent("hideworldreset", OnResetCountDownStop)

            world:SafeListenForEvent("ms_startvote", OnStartVote)
            world:SafeListenForEvent("ms_stopvote", OnStopVote)

            -- Note:
            -- When joining a server, this is being called always on Master.
            -- In caves this can be pushed during migration for example.
            world:SafeListenForEvent("ms_clientauthenticationcomplete", OnClientAuthenticationComplete)
        end

        world:SafeListenForEvent("ms_clientdisconnected", OnClientDisconnected)
        world:SafeListenForEvent("ms_playerdespawnandmigrate", OnPlayerMigrating)
        world:SafeListenForEvent("ms_newplayerspawned", OnNewPlayerSpawn)

        --> Mod Events
        world:ListenForModEvent("clientconnectionclosed", OnClientConnectionClosed)
        world:ListenForModEvent("world_rollback", OnRollback)
        world:ListenForModEvent("world_reset", OnReset)

    end
end)
