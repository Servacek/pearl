setfenv(1, _G.SUB.env)
local TheShard, TheNet = TheShard, TheNet
local SUB = SUB
local c_countprefabs = c_countprefabs

local Message = require('models/message')
local Embed = require('models/embed')

-------------------------------------

local Logger = Class(function(self) end)

-------------------------------------
-- [[ Private functions ]]
-------------------------------------

local function ignore_structure(inst)
    return inst == nil or not inst:IsValid() or inst:HasTag("fire") or inst:HasTag("burnt")
end

-------------------------------------
-- [[ Public functions ]]
-------------------------------------

function Logger:PostInChat(str, icon)
    if not str then return end

    if icon then
        str = string.format("%s %s", str, icon)
    end

    TheNet:SystemMessage(str)
end

-------------------------------
-- [[ Chat State Handlers ]]
-------------------------------

function Logger.OnAnnouncement(message, announce_type)
    if message ~= nil and announce_type ~= nil and TheShard:IsMaster() then
        local icon = SUB.ICONS.LOGS[announce_type] or string.codeline("[Announcement]")

        -- Deprecated
        -- if announce_type == "join_game" or announce_type == "leave_game" then
        --     local max_players = TheNet:GetServerMaxPlayers()

        --     local current_players
        --     if announce_type == "join_game" then
        --         current_players = #G.AllPlayers + 1
        --     else
        --         current_players = #G.AllPlayers - 1
        --     end

        --     message = string.format(
        --         SUB.STRINGS.PLAYER_COUNT, message, current_players, max_players
        --     )
        -- end

        SUB.Webhook:SendMessage(Message(
            string.codeline(message), icon
        ))
    end
end

function Logger.OnSkinReceived(user_name, skin_prefab)
    if TheShard:IsMaster() and user_name ~= nil and skin_prefab ~= nil then
        local message = Message()
        message:AddEmbed(Embed()
            :SetDescription(GetSkinDescription(skin_prefab))
            :SetTitle(string.format(
                SUB.STRINGS.SKIN_RECEIVED, user_name, GetSkinName(skin_prefab)
            ))
            :SetImage(string.format(
                SUB.CONSTANTS.SKINS_PREVIEW_URL, skin_prefab, "small"
            ))
        )

        SUB.Webhook:SendMessage(message)
    end
end

function Logger.OnSay(userid, name, prefab, message, whisper)
    -- Whispers aren't broadcasted to other shards
    if not whisper and TheShard:IsSecondary() then
        return
    end

    if message ~= nil and name ~= nil and userid ~= nil and prefab ~= nil then
        local icon = SUB.ICONS.PLAYER_PREFABS[prefab] or string.codeline("["..string.capitalize(prefab).."]")

        local str
        if whisper then
            str = string.format(
                SUB.STRINGS.SAY_WHISPER,
                string.bold(string.DDF(name)),
                string.italic(string.emojify(string.DDF(message)))
            )
        else
            str = string.format(
                SUB.STRINGS.SAY,
                string.bold(string.DDF(name)),
                string.emojify(string.DDF(message))
            )
        end

        SUB.Webhook:SendMessage(Message(
            str, icon
        ))
    end
end

function Logger.OnSlashCommand(userid, cmd)
    local client = TheNet:GetClientTableForUser(userid)

    -- Ignore emotes
    if client ~= nil and cmd ~= nil and not SUB.IsEmoteCommand(cmd) then
        local message = string.format(
            string.codeline(SUB.STRINGS.SLASH_CMD), client.name, tostring(cmd)
        )

        SUB.Webhook:SendMessage(Message(
            message, SUB.ICONS.LOGS["cmd"]
        ))
    end
end

-------------------------------
-- [[ World State Handlers ]]
-------------------------------

function Logger.OnCyclesChanged(world, cycle)
    if TheShard:IsSecondary() then return end

    if world and cycle and world.ismastersim and world.state then
        SUB.Webhook:SendMessage(Message(
            string.bold(string.codeline(
                SUB.STRINGS.DAY:format(
                    (cycle + 1),
                    tostring(world.state.season):capitalize(),
                    math.floor(world.state.temperature / 2 + 0.5)
                ):center(30)
            ))
        ))
    end
end

function Logger.OnPhaseChanged(world, phase)
    if TheShard:IsSecondary() then
        return
    end

    if world ~= nil and world.ismastersim and phase ~= nil and phase ~= "day" then
        SUB.Webhook:SendMessage(Message(
            string.codeline(string.capitalize(phase))
        ))
    end
end

-- function Logger.OnPrecipitationChanged(world, precipitation)
    -- if TheShard:IsSecondary() then
    --     return
    -- end

    -- if world ~= nil and world.ismastersim and precipitation ~= nil then
    --     SUB.Webhook:SendAnnouncement(string.format(
    --         SUB.STRINGS.PRECIPITATION,
    --         math.floor(world.state.temperature / 2 + 0.5)
    --     ), SUB.ICONS.PRECIPITATION[tostring(precipitation)])
    -- end
-- end

-------------------------------
-- [[ Client State Handlers ]]
-------------------------------

function Logger.OnClientAuthenticationComplete(data)
    if not data or not data.userid then return end

    local client = TheNet:GetClientTableForUser(data.userid)
    if client and client.name and client.userid and not SUB.IsClientMigrating(client) then
        SUB.Webhook:SendMessage(Message(
            string.hyperlink(string.codeline(string.format(
                SUB.STRINGS.AUTH, client.userid, client.name
            )), client.netid and string.dislink(string.format(
                SUB.CONSTANTS.STEAM_ACCOUNT_URL, client.netid
            )) or nil),

            SUB.ICONS.LOGS["auth"]
        ))
    end
end

function Logger.OnClientDisconnected(world, data)
    local client = TheNet:GetClientTableForUser(data.userid)

    if client ~= nil and client.name ~= nil then
        SUB.Webhook:SendMessage(Message(
            string.codeline(string.format(
                SUB.STRINGS.DISCONNECT, client.name, SUB.GetShardName()
            ))
        ))
    end
end

function Logger.OnClientNotWhitelisted(userid)
    SUB.Webhook:SendAnnouncement(string.format(
        SUB.STRINGS.NOT_WHITELISTED, userid
    ), SUB.ICONS.LOGS['kicked_from_game'])
end

function Logger.OnAltClientWithBannedRoot(userid, rootid)
    SUB.Webhook:SendAnnouncement(string.format(
        SUB.STRINGS.BANNED_ROOT_CLIENT, userid, rootid
    ), SUB.ICONS.LOGS['banned_from_game'])
end

-------------------------------
-- [[ Server State Handlers ]]
-------------------------------
-- TODO!!!
-- local was_paused = false
-- function Logger:OnServerPausedDirty(pause, autopause, gameautopause, source)
--     local is_paused = pause or autopause or gameautopause

--     if was_paused and not is_paused then
--         print("UNPAUSE")
--         print(pause, autopause, gameautopause, source)

--         was_paused = false
--     elseif not is_paused and pause then
--         if source then
--             print("[Logger:OnServerPausedDirty] PAUSE BY", source)
--             --SUB.Webhook:SendNotifyImportant(string.format(SUB.STRINGS.PAUSE_BY,
--             --    source
--             --), true) -- DDF this message
--         else
--             table.foreach(pause, print)
--             print("[Logger:OnServerPausedDirty] PAUSE")
--             --SUB.Webhook:SendNotifyImportant(SUB.STRINGS.PAUSE)
--         end
--         print("[Logger:OnServerPausedDirty] PAUSE")

--         was_paused = true
--     elseif autopause and not pause then
--         print(pause, autopause, source)

--         print("[Logger:OnServerPausedDirty] AUTOPAUSE")
--         --SUB.Webhook:SendNotifyImportant(SUB.STRINGS.UNPAUSE)

--         was_paused = true
--     end
-- end

-- Here we want to force the message because the queue resets
function Logger:OnSaveShutdown()
    SUB.Webhook:SendMessage(Message(
        string.bold(string.format(SUB.STRINGS.SHUTDOWN, SUB.GetShardName()))
    ), true)
end

function Logger:OnRegenerateWorld()
    SUB.Webhook:SendMessage(Message(
        string.bold(string.format(SUB.STRINGS.RESET, SUB.GetShardName()))
    ), true)
end

function Logger:OnRollback(count)
    local message
    if count ~= nil and count > 0 then
        message = string.format(
            SUB.STRINGS.ROLLBACK, count
        )
    else
        message = SUB.STRINGS.RESTART
    end

    SUB.Webhook:SendMessage(Message(
        string.bold(message)
    ), true)
end

function Logger:OnShardStateUpdate(world_id, state)
    local ready = state == REMOTESHARDSTATE.READY

    if TheShard:IsMaster() then
        SUB.Webhook:SendAnnouncement(string.format(
            SUB.STRINGS.CAVES_STATE_UPDATE,
            world_id, ready and 'connected' or 'disconnected'
        ))
    end
end

function Logger:OnError(error_msg)
    SUB.Webhook:SendReport(error_msg)
end

-------------------------------
-- [[ Console State Handlers ]]
-------------------------------

-- Disabled
-- TODO: Needs some debug
-- function Logger.OnCommandReceived(fnstr, guid)
--     local inst = Ents[guid]
--     if inst and inst:IsValid() and fnstr and #fnstr > 0 then
--         local icon = SUB.ICONS.LOGS['cmd']
--         SUB.Webhook:SendAnnouncement(
--             string.format(SUB.STRINGS.CONSOLE_CMD, inst:GetDisplayName(), fnstr),
--             icon
--         )
--     end
-- end

-------------------------------
-- [[ Entity Action Handlers ]]
-------------------------------

function Logger.OnIgniteEntity(doer, target, neighbors)
    if doer ~= nil and target ~= nil and neighbors ~= nil then

        local message -- The response message
        local icon = SUB.ICONS.DST_EMOTES.TORCH
        local target_name = SUB.EntityToStringSupportStacks(target)
        if #neighbors > 0 then
            message = string.format(
                SUB.STRINGS.IGNITE_NEAR, doer:GetDisplayName(), target_name, SUB.EntitiesToString(neighbors, target)
            )
        else
            message = string.format(
                SUB.STRINGS.IGNITE, doer:GetDisplayName(), target_name
            )
        end

        if SUB.CONSTANTS.ANNOUNCE_IGNITE
        and (target:HasTag("structure") or #neighbors > 2
        or SUB.ArrayContainsEntityWithTag(neighbors, "structure", SUB.IsBurnable)) then
            Logger:PostInChat(message, icon)
        end

        SUB.Webhook:SendAnnouncement(message, icon)
    end
end

function Logger.OnActionHammer(doer, target)
    if doer ~= nil and target ~= nil and doer:HasTag("player")
    and target:HasTag("structure") and not ignore_structure(target)
    and target.components and target.components.workable and target.components.workable.workleft ~= nil
    and target.components.workable.workleft <= 1
    then
        local message
        local icon = SUB.ICONS.DST_EMOTES.HAMMER
        if target.builder and target.builder.name then
            message = SUB.STRINGS.OWNER:format(
                SUB.STRINGS.DESTROY:format(doer:GetDisplayName(), target:GetDisplayName()),
                target.builder.name
            )
        else
            message = SUB.STRINGS.DESTROY:format(
                doer:GetDisplayName(), target:GetDisplayName()
            )
        end

        -- We announce this to the game only if there is a builder
        if SUB.CONSTANTS.ANNOUNCE_DESTROY and target.builder
        and target.builder.userid ~= doer.userid
        then
            Logger:PostInChat(message, icon)
        end

        SUB.Webhook:SendAnnouncement(message, icon)
    end
end

function Logger.OnBuild(doer, inst)
    if doer ~= nil and doer:IsValid() and doer:HasTag("player") and inst ~= nil and inst:IsValid() then
        if not inst.builder then
            inst.builder = {
                userid = doer.userid,
                name = doer:GetDisplayName(),
            }
        end

        if not SUB.PREFABS.FIRE_SOURCES[inst.prefab] then return end
        local entities = SUB.GetEntitiesNear(
            inst, SUB.CONSTANTS.FIRE_RADIUS,
            SUB.CONSTANTS.FIRE_MUSTHAVE_TAGS,
            SUB.CONSTANTS.FIRE_CANTHAVE_TAGS,
            SUB.CONSTANTS.FIRE_ONEOF_TAGS
        )

        if #entities <= 0 then return end

        local icon = SUB.ICONS.DST_EMOTES.FIRE
        local message = string.format(SUB.STRINGS.FIRE_SOURCE_BUILT_NEAR,
            doer:GetDisplayName(), inst:GetDisplayName(), SUB.EntitiesToString(entities)
        )
        if SUB.CONSTANTS.ANNOUNCE_IGNITE and (#entities >= 4 or SUB.ArrayContainsEntityWithTag(entities, "structure")) then
            Logger:PostInChat(message, icon)
        end

        SUB.Webhook:SendAnnouncement(message, icon)
    end
end

-- TODO
-- function Logger.OnActionAttack(doer, target, invobject)
--     if doer == nil or not doer:HasTag("player") or invobject == nil or target == nil then
--         return
--     end

--     if not SUB.PREFABS.AREA_RANGED_STAFFS[invobject.prefab] or not invobject:HasTag("lighter") then
--         return
--     end

--     local message
--     local entities = SUB.GetEntitiesNear(target, SUB.CONSTANTS.FIRE_RADIUS, nil, {"fireimmune"})
--     if (#entities > 2 and SUB.ArrayContainsEntityWithTag(entities, "structure")) or #entities >= 5 then
--         print("LIGHTER ATTACK")
--     end
-- end

-- TODO: Apply grief protection
-- TODO: justify the radiuses
function Logger.OnActionCastSpell(doer, target, invobject, pos)
    if (doer == nil or invobject == nil or not doer:HasTag("player"))
    or (target == nil and pos == nil) then
        return
    end

    pos = pos or target:GetPosition()
    local entities = TheSim:FindEntities(pos.x, pos.y, pos.z, SUB.CONSTANTS.FIRE_RADIUS,
        SUB.CONSTANTS.FIRE_MUSTHAVE_TAGS,
        SUB.CONSTANTS.FIRE_CANTHAVE_TAGS,
        SUB.CONSTANTS.FIRE_ONEOF_TAGS
    )

    local message
    local icon
    if target ~= nil then
        icon = SUB.ICONS.DST_EMOTES.HAMMER
         -- Using a area ranged staff on a target near structures (ex. Weather Pain)
        if SUB.PREFABS.AREA_RANGED_STAFFS[invobject.prefab]
        and (#entities > 2 and SUB.ArrayContainsEntityWithTag(entities, "structure")) then
            message = string.format(SUB.STRINGS.USE_STAFF_ON_NEAR,
                doer:GetDisplayName(), invobject:GetDisplayName(), target:GetDisplayName(), SUB.EntitiesToString(entities, target)
            )

        -- Using a non-area ranged staff on a structure (Deconstruction Staff)
        -- TODO: replace magic string with a constant
        elseif invobject.prefab == "greenstaff"
        and target:HasTag("structure") and not ignore_structure(target) then
            message = string.format(SUB.STRINGS.USE_STAFF_ON,
                doer:GetDisplayName(), invobject:GetDisplayName(), target:GetDisplayName()
            )
        end

        if message and SUB.CONSTANTS.ANNOUNCE_DESTROY then
            Logger:PostInChat(message, icon)
        end
    else
        -- Using a staff to summon fire object near objects (ex. Star Caller Staff)
        if SUB.PREFABS.AREA_RANGED_STAFFS[invobject.prefab]
        and (#entities > 0 and SUB.ArrayContainsEntityWithTag(entities, "structure", SUB.IsBurnable)) or #entities >= 5 then
            icon = SUB.ICONS.DST_EMOTES.FIRE
            message = string.format(SUB.STRINGS.USE_STAFF_NEAR,
                doer:GetDisplayName(), invobject:GetDisplayName(), SUB.EntitiesToString(entities, target)
            )
        end

        if message ~= nil and SUB.CONSTANTS.ANNOUNCE_IGNITE then
            Logger:PostInChat(message, icon)
        end
    end

    SUB.Webhook:SendAnnouncement(message, icon)
end

function Logger.OnActionFeed(doer, target, invobject)
    if doer ~= nil and doer:IsValid() and doer:HasTag("player")
    and target ~= nil and target:IsValid() and invobject ~= nil
    and SUB.PREFABS.FOOD[invobject.prefab] then
        local icon = SUB.ICONS.DST_EMOTES.FAKETEETH
        local message = string.format(
            SUB.STRINGS.FEED, doer:GetDisplayName(), target:GetDisplayName(), invobject:GetDisplayName()
        )

        if SUB.CONSTANTS.ANNOUNCE_EATRARE then
            Logger:PostInChat(message, icon)
        end

        SUB.Webhook:SendAnnouncement(message, icon)
    end
end

function Logger.OnStructureBurntUp(target)
    if not SUB.Watcher:IsSimulationReady() then return end

    if target and target:IsValid() then
        local message
        local icon = SUB.ICONS.DST_EMOTES.FIRE
        if target.builder and target.builder.name then
            message = SUB.STRINGS.OWNER:format(
                SUB.STRINGS.BURNTUP:format(target:GetDisplayName()),
                target.builder.name
            )
        else
            message = SUB.STRINGS.BURNTUP:format(
                target:GetDisplayName()
            )
        end

        if SUB.CONSTANTS.ANNOUNCE_BURNTUP then
            Logger:PostInChat(message, icon)
        end

        SUB.Webhook:SendAnnouncement(message, icon)
    end
end

function Logger.OnPlayerAteFood(world, data)
    if not (SUB.CONSTANTS.ANNOUNCE_EATRARE or SUB.CONSTANTS.DISCORD_LOGS_ENABLED) then
        return
    end

    local feeder, food
    if data ~= nil then
        feeder = data.feeder
        food = data.food
    end

    if food and feeder and food:IsValid() and feeder:IsValid() and SUB.PREFABS.FOOD[food.prefab] then
        local icon = SUB.ICONS.DST_EMOTES.FAKETEETH
        local message = string.format(
            SUB.STRINGS.EAT, feeder:GetDisplayName(), food:GetDisplayName()
        )

        if SUB.CONSTANTS.ANNOUNCE_EATRARE then
            Logger:PostInChat(message, icon)
        end

        SUB.Webhook:SendAnnouncement(message, icon)
    end
end

function Logger.OnPlayerMigrating(world, data)
    if data ~= nil and data.player ~= nil and data.player:IsValid() then
        SUB.Webhook:SendAnnouncement(string.format(
            SUB.STRINGS.MIGRATING, data.player:GetDisplayName(), TheShard:IsMaster() and "Caves" or "Master"
        ), SUB.ICONS.LOGS["migrating"])
    end
end

function Logger.OnEntityDeath(data)
    local inst, afflicter
    if data ~= nil then
        inst = data.inst
        afflicter = data.afflicter
    end

    if not inst.prefab then return end

    if not (afflicter ~= nil and inst ~= nil and afflicter:IsValid() and inst:IsValid()) then
        return
    end

    -- MOB SPREADING FIRE AFTER DEATH
    if SUB.PREFABS.MOBS.FIRE_SPREADERS[inst.prefab] and afflicter:HasTag("player") then
        local entities = SUB.GetEntitiesNear(
            -- The flames have bigger radius in this case
            inst, (SUB.CONSTANTS.FIRE_RADIUS + 3),
            SUB.CONSTANTS.FIRE_MUSTHAVE_TAGS,
            SUB.CONSTANTS.FIRE_CANTHAVE_TAGS,
            SUB.CONSTANTS.FIRE_ONEOF_TAGS
        )

        if #entities >= 4 or SUB.ArrayContainsEntityWithTag(entities, "structure") then
            local icon = SUB.ICONS.DST_EMOTES.FIRE
            local message = string.format(SUB.STRINGS.MOB_KILLED_NEAR,
                afflicter:GetDisplayName(), inst:GetDisplayName(), SUB.EntitiesToString(entities, inst)
            )

            if SUB.CONSTANTS.ANNOUNCE_IGNITE then
                Logger:PostInChat(message, icon)
            end

            SUB.Webhook:SendAnnouncement(message, icon)
        end

    -- NOT RESPAWNABLE MOB
    elseif SUB.PREFABS.MOBS.MONITOR_POPULATION[inst.prefab] and afflicter:HasTag("player") then
        local count = _G.c_countprefabs(inst.prefab, false) or -1
        if count <= 0 then return end

        local left_count = count - 1
        local icon = SUB.ICONS.DST_EMOTES.HAMBAT
        local message = string.format(SUB.STRINGS.MONITORED_MOB_KILLED,
            afflicter:GetDisplayName(), inst:GetDisplayName(), left_count
        )

        if SUB.CONSTANTS.ANNOUNCE_KILLMONITORED then
            Logger:PostInChat(message, icon)
        end

        SUB.Webhook:SendAnnouncement(message, icon)

    -- BOSS, this should be announced even if the afflicter isn't a player
    elseif inst.components and inst.components.health and inst.components.health.maxhealth >= SUB.CONSTANTS.BOSS_HP then
        local icon = SUB.ICONS.DST_EMOTES.TROPHY
        local message = string.format(
            SUB.STRINGS.MOB_KILLED, afflicter:GetDisplayName(), inst:GetDisplayName()
        )

        if SUB.CONSTANTS.ANNOUNCE_KILLBOSS then
            Logger:PostInChat(message, icon)
        end

        SUB.Webhook:SendAnnouncement(message, icon)

    -- COMPANION
    elseif SUB.PREFABS.MOBS.COMPANIONS[inst.prefab] and afflicter:HasTag("player") then
        local icon = SUB.ICONS.DST_EMOTES.HAMBAT
        local message = string.format(
            SUB.STRINGS.MOB_KILLED, afflicter:GetDisplayName(), inst:GetDisplayName()
        )

        if SUB.CONSTANTS.ANNOUNCE_KILLFOLLOWER then
            Logger:PostInChat(message, icon)
        end

        SUB.Webhook:SendAnnouncement(message, icon)

    -- FOLLOWER
    elseif inst.components and inst.components.follower and afflicter:HasTag("player") then
        local leader = inst.components.follower:GetLeader()
        if leader and leader:IsValid() and leader.userid ~= afflicter.userid and leader:HasTag("player") then
            local icon = SUB.ICONS.DST_EMOTES.HAMBAT
            local message = string.format(
                SUB.STRINGS.FOLLOWER_KILLED, afflicter:GetDisplayName(), inst:GetDisplayName(), leader:GetDisplayName()
            )

            if SUB.CONSTANTS.ANNOUNCE_KILLFOLLOWER then
                Logger:PostInChat(message, icon)
            end

            SUB.Webhook:SendAnnouncement(message, icon)
        end
    end
end

-- local last_picked = nil
-- local last_picker = nil
-- function Logger.OnPutInInventory(item, owner)
--     if not (owner ~= nil and item ~= nil) then
--         return
--     end

--     -- For backpacks, bundles and stuff like that
--     owner = item.components.inventoryitem:GetGrandOwner()

--     -- Not only players have inventory!
--     if owner:HasTag("player") and owner ~= item.lastowner and owner ~= nil
--     and (last_picked ~= item or last_picker ~= owner) then
--         local count = 1
--         if item.components.stackable then
--             count = item.components.stackable:StackSize()
--         end

--         local icon = SUB.ICONS.DST_EMOTES.BACKPACK
--         local message = string.format(
--             SUB.STRINGS.ITEM_PICKED, owner:GetDisplayName(), count, item:GetDisplayName()
--         )

--         if SUB.CONSTANTS.ANNOUNCE_PICKUP then
--             Logger:PostInChat(message, SUB.ICONS.DST_EMOTES.BACKPACK)
--         end

--         SUB.Webhook:SendAnnouncement(message, icon)
--     end

--     print("-------------------------")
--     print("Last owner: ", item.lastowner)
--     print("New owner: ", owner)
--     print("Last picker: ", last_picker)
--     print("Last picked: ", last_picked)

--     item.lastowner = owner
--     last_picked = item
--     if owner:HasTag("player") then
--         last_picker = owner
--     end
-- end

----------------------------

SUB.Logger = Logger()
