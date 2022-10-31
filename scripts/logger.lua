require('class')

setfenv(1, _G.SUB.env)
local TheShard, TheNet = TheShard, TheNet
local SUB = SUB

local G = GLOBAL

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

-- Used to determine wheter the client is connecting to the server for the first time
-- or just migrating between the server shards.
local function is_client_migrating(client)
    return client.prefab ~= "" and client.lobbycharacter == "" and client.playerage > 0
end

-------------------------------------
-- [[ Public functions ]]
-------------------------------------

function Logger:PostInChat(str, icon)
    if icon ~= nil then
        str = str.." "..icon
    end

    G.TheNet:SystemMessage(str)
end

function Logger:LogInventoryForPlayer(userid)
    local inventory, target_prefab, name = SUB.GetInventoryTabelFor(userid)

    if inventory and not G.IsTableEmpty(inventory) then
        name = name or userid
        local icon = G.SUB.ICONS.PLAYER_PREFABS[target_prefab]
        local title = icon.." Inventár hráča `"..name.."`"

        local description = ""
        for prefab, count in pairs(inventory) do
            -- If the item is rare we want to make it bold
            if G.SUB.PREFABS.MONITOR_PICKUP[prefab] then
                description = description.."**"..count.."x "..SUB.ItemPrefabToName(prefab).."**\n"
            else
                description = description.."`"..count.."x "..SUB.ItemPrefabToName(prefab).."`\n"
            end
        end

        local message = Message()
        message:AddEmbed(Embed()
            :SetTitle(title)
            :SetDescription(description)
        )

        SUB.Webhook:SendMessageToDiscord(message)

        return true
    end

    return false
end

-------------------------------
-- [[ Chat State Handlers ]]
-------------------------------

function Logger:OnAnnouncement(message, announce_type)
    if message ~= nil and announce_type ~= nil and TheShard:IsMaster() then
        local icon = SUB.ICONS.LOGS[announce_type] or string.codeblock("[Announcement]")

        -- Deprecated
        -- if announce_type == "join_game" or announce_type == "leave_game" then
        --     local max_players = G.TheNet:GetServerMaxPlayers()

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

        SUB.Webhook:SendMessageToDiscord(Message(
            string.codeblock(message), icon
        ))
    end
end

function Logger:OnSkinReceived(user_name, skin_prefab)
    if G.TheShard:IsMaster() and user_name ~= nil and skin_prefab ~= nil then
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

        SUB.Webhook:SendMessageToDiscord(message)
    end
end

function Logger:OnSay(userid, name, prefab, message, whisper)
    -- Whispers aren't broadcasted to other shards
    if not whisper and G.TheShard:IsSecondary() then
        return
    end

    if message ~= nil and name ~= nil and userid ~= nil and prefab ~= nil then
        local icon = SUB.ICONS.PLAYER_PREFABS[prefab] or string.codeblock("["..string.capitalize(prefab).."]")

        local str
        if whisper then
            str = string.format(
                SUB.STRINGS.SAY_WHISPER,
                string.codeblock(userid),
                string.bold(string.DDF(name)),
                string.italic(string.emojify(string.DDF(message)))
            )
        else
            str = string.format(
                SUB.STRINGS.SAY,
                string.codeblock(userid),
                string.bold(string.DDF(name)),
                string.emojify(string.DDF(message))
            )
        end

        SUB.Webhook:SendMessageToDiscord(Message(
            str, icon
        ))
    end
end

function Logger:OnSlashCommand(userid, cmd)
    local client = G.TheNet:GetClientTableForUser(userid)

    if client ~= nil and cmd ~= nil then
        local message = string.format(
            string.codeblock(SUB.STRINGS.SLASH_CMD), client.name, tostring(cmd)
        )

        SUB.Webhook:SendMessageToDiscord(Message(
            message, SUB.ICONS.LOGS["cmd"]
        ))
    end
end

-------------------------------
-- [[ World State Handlers ]]
-------------------------------

function Logger.OnCyclesChanged(world, cycle)
    if TheShard:IsSecondary() then
        return
    end

    if world ~= nil and cycle ~= nil and world.ismastersim and world.state ~= nil then
        SUB.Webhook:SendMessageToDiscord(Message(
            string.codeblock(string.rep(" ", 30).."Day "..(cycle + 1).." - "..string.capitalize(world.state.season)..""..string.rep(" ", 30))
        ))
    end
end

function Logger.OnPhaseChanged(world, phase)
    if TheShard:IsSecondary() then
        return
    end

    if world ~= nil and world.ismastersim and phase ~= nil and phase ~= "day" then
        SUB.Webhook:SendMessageToDiscord(Message(
            string.codeblock(string.capitalize(phase))
        ))
    end
end

function Logger.OnPrecipitationChanged(world, precipitation)
    if TheShard:IsSecondary() then
        return
    end

    if world ~= nil and world.ismastersim and precipitation ~= nil then
        SUB.Webhook:SendAnnouncement(string.format(
            SUB.STRINGS.PRECIPITATION,
            math.floor(TheWorld.state.temperature / 2 + 0.5)
        ), SUB.ICONS.PRECIPITATION[tostring(precipitation)])
    end
end

-------------------------------
-- [[ Client State Handlers ]]
-------------------------------

-- TODO: Fix Steam Family Sharing abuse
function Logger.OnClientAuthenticationComplete(data)
    local client = TheNet:GetClientTableForUser(data.userid)
    if is_client_migrating(client) then return end

    if client ~= nil and client.name ~= nil and client.userid then
        SUB.Webhook:SendMessageToDiscord(Message(
            string.codeblock(string.format(
                SUB.STRINGS.AUTH, client.userid, client.name
            )),
            SUB.ICONS.LOGS["auth"]
        ))
    end
end

function Logger.OnClientDisconnected(world, data)
    local client = TheNet:GetClientTableForUser(data.userid)

    if client ~= nil and client.name ~= nil then
        SUB.Webhook:SendMessageToDiscord(Message(
            string.codeblock(string.format(
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
    SUB.Webhook:SendMessageToDiscord(Message(
        string.bold(string.format(SUB.STRINGS.SHUTDOWN, SUB.GetShardName()))
    ), true)
end

function Logger:OnRegenerateWorld()
    SUB.Webhook:SendMessageToDiscord(Message(
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

    SUB.Webhook:SendMessageToDiscord(Message(
        string.bold(message)
    ), true)
end

function Logger:OnShardStateUpdate(world_id, state)
    local ready = state == G.REMOTESHARDSTATE.READY

    if TheShard:IsMaster() then
        SUB.Webhook:SendAnnouncement(string.format(
            SUB.STRINGS.CAVES_STATE_UPDATE,
            world_id, ready and 'connected' or 'disconnected'
        ))
    end
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
        if neighbors ~= nil and #neighbors > 1 then

            message = string.format(
                SUB.STRINGS.IGNITE_NEAR, doer:GetDisplayName(), target:GetDisplayName(), SUB.EntitiesToString(neighbors, target)
            )
        else
            message = string.format(
                SUB.STRINGS.IGNITE, doer:GetDisplayName(), target:GetDisplayName()
            )
        end

        if SUB.CONSTANTS.ANNOUNCE_IGNITE and target:HasTag("structure") or #neighbors > 2 then
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
        local icon = SUB.ICONS.DST_EMOTES.HAMMER
        local message = string.format(SUB.STRINGS.DESTROY,
            doer:GetDisplayName(), target:GetDisplayName()
        )..(target.builder and " Majiteľ: "..target.builder.name or "")

        if SUB.CONSTANTS.ANNOUNCE_DESTROY and target.builder ~= nil
        and target.builder.userid ~= doer.userid
        then
            Logger:PostInChat(message, icon)
        end

        SUB.Webhook:SendAnnouncement(message, icon)
    end
end

function Logger.OnBuild(doer, inst)
    if doer ~= nil and doer:IsValid() and inst ~= nil  and inst:IsValid() then
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

function Logger.OnActionCastSpell(doer, target, invobject, pos)
    if (doer == nil or invobject == nil or not doer:HasTag("player"))
    or (target == nil and pos == nil) then
        return
    end

    pos = pos or target:GetPosition()
    local entities = G.TheSim:FindEntities(pos.x, pos.y, pos.z, SUB.CONSTANTS.FIRE_RADIUS,
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

        -- Using a non-area ranged staff on a structure (ex. Deconstruction Staff)
        elseif target:HasTag("structure") and not ignore_structure(target) then
            message = string.format(SUB.STRINGS.USE_STAFF_ON,
                doer:GetDisplayName(), invobject:GetDisplayName(), target:GetDisplayName()
            )
        end

        if message ~= nil and SUB.CONSTANTS.ANNOUNCE_DESTROY then
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

    if message ~= nil then
        SUB.Webhook:SendAnnouncement(message, icon)
    end
end

function Logger.OnActionFeed(doer, target, invobject)
    if doer ~= nil and doer:IsValid() and target ~= nil and target:IsValid() and invobject ~= nil
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

function Logger.OnStructureBurntUp(inst)
    if not SUB.Watcher:IsSimulationReady() then return end

    if inst ~= nil and inst:IsValid() then
        local icon = SUB.ICONS.DST_EMOTES.FIRE
        local message = string.format(
            SUB.STRINGS.BURNTUP, inst:GetDisplayName()
        )..(inst.builder and " Majiteľ: "..inst.builder.name or "")

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
        ))
    end
end

function Logger.OnEntityDeath(world, data)
    local inst, afflicter
    if data ~= nil then
        inst = data.inst
        afflicter = data.afflicter
    end

    if not (afflicter ~= nil and inst ~= nil and afflicter:IsValid() and inst:IsValid() and afflicter:HasTag("player")) then
        return
    end

    -- MOB SPREADING FIRE AFTER DEATH
    if SUB.PREFABS.MOBS.FIRE_SPREADERS[inst.prefab] then
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
    elseif SUB.PREFABS.MOBS.MONITOR_POPULATION[inst.prefab] then
        local left_count = (G.c_countprefabs(inst.prefab, false) - 1)
        local icon = SUB.ICONS.DST_EMOTES.HAMBAT
        local message = string.format(SUB.STRINGS.MONITORED_MOB_KILLED,
            afflicter:GetDisplayName(), inst:GetDisplayName(), left_count
        )

        if SUB.CONSTANTS.ANNOUNCE_KILLMONITORED then
            Logger:PostInChat(message, icon)
        end

        SUB.Webhook:SendAnnouncement(message, icon)

    -- BOSS
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
    elseif SUB.PREFABS.MOBS.COMPANIONS[inst.prefab] then
        local icon = SUB.ICONS.DST_EMOTES.HAMBAT
        local message = string.format(
            SUB.STRINGS.MOB_KILLED, afflicter:GetDisplayName(), inst:GetDisplayName()
        )

        if SUB.CONSTANTS.ANNOUNCE_KILLFOLLOWER then
            Logger:PostInChat(message, icon)
        end

        SUB.Webhook:SendAnnouncement(message, icon)

    -- FOLLOWER
    elseif inst.components and inst.components.follower then
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