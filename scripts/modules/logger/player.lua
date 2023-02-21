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
Temporary solution for logging.
--]]

------------------------
-- [[ Global Localization ]]
------------------------

local TheSim = TheSim

local removearrayvalue = table.removearrayvalue

------------------------
-- [[ Constants ]]
------------------------

local MAX_COMMAND_LENGTH = 500

------------------------
-- [[ Check Functions ]]
------------------------

local function structuresearchfn(index, entity)
    return entity and entity:HasTag("structure")
end

local function burnablestructuresearchfn(index, entity)
    return entity and entity:HasTag("structure") and entity:HasTag("canlight")
end

local function defaultactioncheck(doer, target, item, pos)
    return (target ~= nil or item ~= nil)
end

local function playeractioncheck(doer, target, item, pos)
    return defaultactioncheck(doer, target, item, pos) and doer ~= nil and doer:HasTag("player")
end

local function playeritemactioncheck(doer, target, item, pos)
    return playeractioncheck(doer, target, item, pos) and item ~= nil
end

------------------------

-- A wrapper function for registering action handlers
local function RegisterActionHandler(action, handler, checkfn)
    local _action = action.fn
    action.fn = function(act, ...)
        local success = _action(act, ...)
        if success and act ~= nil and handler ~= nil then
            local doer, target, item, pos = act.doer, act.target, (act.invobject or act.recipe), act:GetActionPoint()

            local result, was_successfull
            if checkfn(doer, target, item, pos) then
                was_successfull, result = PEARL.SafeRun(handler,
                    doer, target, item, pos
                )
            end

            -- Check for explicit false
            if was_successfull == false then
                PEARL.error("Error while executing an action handler!\n Reason: "..tostring(result), "error")
            end
        end

        return success
    end
end

-- local function RegisterDefaultActionHandler(action, handler)
--     return RegisterActionHandler(action, handler, defaultactioncheck)
-- end

local function RegisterPlayerActionHandler(action, handler)
    return RegisterActionHandler(action, handler, playeractioncheck)
end

local function RegisterPlayerItemActionHandler(action, handler)
    return RegisterActionHandler(action, handler, playeritemactioncheck)
end

------------------------
-- [[ Action Handler ]]
------------------------

-- Announce when an object gets set on fire and who set it on fire.
-- Only announces setting items and structures on fire (player creations)
RegisterPlayerActionHandler(ACTIONS.LIGHT, function(doer, target)
    local near = target:GetPropagableEntities(
        PEARL.CONSTS.ENT_MUST_HAVE_TAGS,
        PEARL.CONSTS.ENT_CANT_HAVE_TAGS
        -- Announce EVERYTHING burnably nearby.
        --PEARL.CONSTS.ENT_ONEOF_TAGS
    )

    if not ((
        -- The target is a structure or craftable item
        target:HasTag("structure") or type(AllRecipes[target.prefab]) == "table"
    ) or (
        -- Or the target is anything but it's near some plant's or structures
        near and (#near > 2 or table.find(near, structuresearchfn))
    )) then
        return
    end

    if near and #near > 0 then
        return PEARL.AnnounceWithType(subfmt(STRINGS.PEARL.ACTIONS.IGNITE.NEAR, {
            doer = doer:GetDisplayName(), target = target:GetFancyName(), near = PEARL.BuildFancyStringForEntities(near)
        }), PEARL.CONSTS.ANNOUNCEMENT_TYPES.IGNITE, doer.entity)
    end

    return PEARL.AnnounceWithType(subfmt(STRINGS.PEARL.ACTIONS.IGNITE.GENERIC, {
        doer = doer:GetDisplayName(), target = target:GetFancyName()
    }), PEARL.CONSTS.ANNOUNCEMENT_TYPES.IGNITE, doer.entity)
end)

RegisterPlayerActionHandler(ACTIONS.EAT, function(doer, target, item)
    -- Check for explicit true
    if not PEARL.PREFABS.RARE_ITEMS[item.prefab] then
        return
    end

    return PEARL.AnnounceWithType(STRINGS.PEARL.ACTIONS.EAT:format(
        -- Use GetBasicDisplayName over GetFancyName because it causes problems
        -- when eating from a stack of items.
        doer:GetDisplayName(), item:GetBasicDisplayName()
    ), PEARL.CONSTS.ANNOUNCEMENT_TYPES.EAT, doer.entity)
end)

RegisterPlayerActionHandler(ACTIONS.TEACH, function(doer, target, item)
    -- Check for explicit true
    if not item.is_rare then
        return
    end

    return PEARL.AnnounceWithType(STRINGS.PEARL.ACTIONS.TEACH:format(
        doer:GetDisplayName(), item:GetBasicDisplayName()
    ), PEARL.CONSTS.ANNOUNCEMENT_TYPES.TEACH, doer.entity)
end)

RegisterPlayerActionHandler(ACTIONS.HAMMER, function(doer, target)
    local workable = target.components and target.components.workable or nil
    if workable and workable.workleft and workable.workleft <= 0 then
        -- Only announce hammering when the structure was built by a player
        if not workable:HasBuilder() or workable:IsBuildBy(doer.userid) then
            return
        end

        return PEARL.AnnounceWithType(subfmt(STRINGS.PEARL.ACTIONS.HAMMER.OWNED, {
            doer = doer:GetDisplayName(), target = target:GetBasicDisplayName(), owner = workable:GetBuilderName()
        }), PEARL.CONSTS.ANNOUNCEMENT_TYPES.HAMMER, doer.entity)
    end
end)

RegisterPlayerActionHandler(ACTIONS.READ, function(doer, target, item)
    -- This is here to handle cases where a player reads the book
    -- but does not cast the book's spell (e. g. Wurt).
    if not doer.components.reader or doer.components.reader:IsAspiringBookworm() then
        return
    end

    -- Check for explicit true
    if PEARL.PREFABS.OFFENSIVE_BOOKS[item.prefab] == true then
        return PEARL.AnnounceWithType(STRINGS.PEARL.ACTIONS.READ:format(
            doer:GetDisplayName(), item:GetBasicDisplayName()
        ), PEARL.CONSTS.ANNOUNCEMENT_TYPES.READ, doer.entity)
    end
end)

RegisterPlayerActionHandler(ACTIONS.ACTIVATE, function(doer, target)
    if PEARL.PREFABS.ACTIVATABLE[target.prefab] and not target.components.activatable:IsLastPlayerActivator(doer) then
        target.components.activatable:SetLastPlayerActivator(doer)

        return PEARL.AnnounceWithType(STRINGS.PEARL.ACTIONS.ACTIVATE:format(
            doer:GetDisplayName(), target:GetBasicDisplayName()
        ), PEARL.CONSTS.ANNOUNCEMENT_TYPES.ACTIVATE, doer.entity)
    end
end)

RegisterPlayerActionHandler(ACTIONS.COOK, function(doer, target, item)
    if PEARL.PREFABS.RARE_ITEMS[item.prefab] ~= nil then
        return PEARL.AnnounceWithType(STRINGS.PEARL.ACTIONS.COOK:format(
            doer:GetDisplayName(), item:GetBasicDisplayName()
        ), PEARL.CONSTS.ANNOUNCEMENT_TYPES.EAT, doer.entity)
    end
end)

--- @TODO: DEBUG!
local function OnAreaCast(doer, item, target, entities, tp, nosilent, noowner)
    if not entities or #entities <= 0 then
        return
    end

    local silent = not nosilent and #entities < 3
    local ents_str = PEARL.BuildFancyStringForEntities(entities)

    if target then
        if not noowner and target.components.workable and target.components.workable:HasBuilder() then
            return PEARL.AnnounceWithType(subfmt(STRINGS.PEARL.ACTIONS.CAST.ON_OWN_NEAR, {
                doer = doer:GetDisplayName(),
                item = item:GetBasicDisplayName(),
                target = target:GetBasicDisplayName(),
                near = ents_str,
                owner = target.components.workable:GetBuilderName(),
            }), tp, doer.entity, silent)
        end

        return PEARL.AnnounceWithType(subfmt(STRINGS.PEARL.ACTIONS.CAST.ON_NEAR, {
            doer = doer:GetDisplayName(),
            item = item:GetBasicDisplayName(),
            target = target:GetBasicDisplayName(),
            near = ents_str
        }), tp, doer.entity, silent)
    end

    return PEARL.AnnounceWithType(subfmt(STRINGS.PEARL.ACTIONS.CAST.NEAR, {
        doer = doer:GetBasicDisplayName(),
        item = item:GetBasicDisplayName(),
        near = ents_str
    }), tp, doer.entity, silent)
end

local function OnCast(doer, item, target, type, nosilent, noowner)
    if not target then
        return
    end

    local has_owner = target.components.workable and target.components.workable:HasBuilder() or false
    local silent = not nosilent and (not has_owner or target.components.workable:IsBuildBy(doer.userid))

    if not noowner and has_owner then
        return PEARL.AnnounceWithType(subfmt(STRINGS.PEARL.ACTIONS.CAST.ON_OWNERED, {
            doer = doer:GetDisplayName(),
            item = item:GetBasicDisplayName(),
            target = target:GetBasicDisplayName(),
            owner = target.components.workable:GetBuilderName(),
        }), type, doer.entity, silent)
    end

    return PEARL.AnnounceWithType(subfmt(STRINGS.PEARL.ACTIONS.CAST.ON, {
        doer = doer:GetDisplayName(),
        item = item:GetBasicDisplayName(),
        target = target:GetBasicDisplayName(),
    }), type, doer.entity, silent)
end

local function OnCastDestruction(doer, item, target)
    return OnCast(
        doer, item, target,
        PEARL.CONSTS.ANNOUNCEMENT_TYPES.HAMMER
    )
end

local function OnCastFire(doer, item, target, pos, radius)
    local entities = target and target:GetPropagableEntities(
        PEARL.CONSTS.ENT_MUST_HAVE_TAGS,
        PEARL.CONSTS.ENT_CANT_HAVE_TAGS,
        PEARL.CONSTS.ENT_ONEOF_TAGS,
        nil, radius
    ) or PEARL.GetBurnableEntitiesNearPos(pos, radius)

    removearrayvalue(entities, target)

    if #entities > 0 then
        return OnAreaCast(
            doer, item, target, entities,
            PEARL.CONSTS.ANNOUNCEMENT_TYPES.BURN
        )
    end

    OnCast(doer, item, target, PEARL.CONSTS.ANNOUNCEMENT_TYPES.BURN, true, true)
end

local function OnCastAreaDestruction(doer, item, target, pos, radius)
    local entities = TheSim:FindEntities(pos.x, pos.y, pos.z, radius,
        -- Do not care about plants here since they are not heavily affected by destruction.
        nil, nil, PEARL.CONSTS.BASE_STRUCTURE_TAGS
    )

    removearrayvalue(entities, target)

    if #entities > 0 then
        return OnAreaCast(
            doer, item, target, entities,
            PEARL.CONSTS.ANNOUNCEMENT_TYPES.HAMMER, true
        )
    end

    return OnCast(doer, item, target, PEARL.CONSTS.ANNOUNCEMENT_TYPES.HAMMER)
end

RegisterPlayerItemActionHandler(ACTIONS.CASTSPELL, function(doer, target, item, pos)
    -- Green Staff
    if PEARL.PREFABS.DESTRUCTION_ITEMS[item.prefab] then
        return OnCastDestruction(doer, item, target)
    end

    pos = pos or target:GetPosition()

    local ign_radius = PEARL.PREFABS.AREA_IGNITE_STAFFS[item.prefab] or 0
    if ign_radius > 0 then
        return OnCastFire(doer, item, target, pos, ign_radius)
    end

    -- Tornado Staff
    local des_radius = PEARL.PREFABS.AREA_DESTRUCTIVE_STAFFS[item.prefab] or 0
    if des_radius > 0 then
        return OnCastAreaDestruction(doer, item, target, pos, des_radius)
    end
end)

RegisterPlayerItemActionHandler(ACTIONS.ATTACK, function(doer, target, item, pos)
    pos = pos or target:GetPosition()

    -- Fire Staff - Using it counts as attacking not casting.
    local ign_radius = PEARL.PREFABS.AREA_IGNITE_STAFFS[item.prefab] or 0
    if ign_radius > 0 then
        return OnCastFire(doer, item, target, pos, ign_radius)
    end
end)

-------------------
-- KILLS --
-------------------

local function onentitydeath(world, data)
    if type(data) ~= "table" then
        return
    end

    local doer = data.afflicter
    local target = data.inst
    if not target then
        return
    end

    -- Bosses (announce their deaths even if they were not killed by a player)
    if target:HasTag("epic") then
        local doer_name = (doer and doer:GetDisplayName()) or (data.explosion and "Explosion") or "Shenanigans"
        return PEARL.AnnounceWithType(subfmt(STRINGS.PEARL.ACTIONS.KILL.BOSS, {
            doer = doer_name, target = target:GetFancyName()
        }), PEARL.CONSTS.ANNOUNCEMENT_TYPES.DEFEAT, doer and doer.entity)
    end

    if not (doer and doer:HasTag("player")) then
        return
    end

    -- NOT RESPAWNABLE MOB
    local pop_threshold = PEARL.PREFABS.MOBS.MONITOR_POPULATION[target.prefab]
    if pop_threshold and pop_threshold > 0 then
        --- @TODOv2.1 This is not ideal (also it works only for the current shard)
        local remaining = c_countprefabs(target.prefab, false) - 1 or -1
        if remaining < 0 or remaining > pop_threshold then
            return
        end

        if remaining == 0 then
            return PEARL.AnnounceWithType(subfmt(STRINGS.PEARL.ACTIONS.KILL.LAST, {
                doer = doer:GetDisplayName(), target = target:GetFancyName()
            }), PEARL.CONSTS.ANNOUNCEMENT_TYPES.KILL, doer.entity)
        end

        return PEARL.AnnounceWithType(subfmt(STRINGS.PEARL.ACTIONS.KILL.REMAINING, {
            doer = doer:GetDisplayName(), target = target:GetFancyName(), remaining = remaining
        }), PEARL.CONSTS.ANNOUNCEMENT_TYPES.KILL, doer.entity)
    end


    -- COMPANION
    if PEARL.PREFABS.MOBS.COMPANIONS[target.prefab] then
        return PEARL.AnnounceWithType(subfmt(STRINGS.PEARL.ACTIONS.KILL.GENERIC, {
            doer = doer:GetDisplayName(), target = target:GetFancyName()
        }), PEARL.CONSTS.ANNOUNCEMENT_TYPES.KILL, doer.entity)
    end

    -- FOLLOWER
    local leader = target.components.follower and target.components.follower:GetLeader() or nil
    if leader and leader:HasTag("player") and leader ~= doer then
        return PEARL.AnnounceWithType(subfmt(STRINGS.PEARL.ACTIONS.KILL.FOLLOWER, {
            doer = doer:GetDisplayName(), target = target:GetFancyName(), owner = leader:GetDisplayName()
        }), PEARL.CONSTS.ANNOUNCEMENT_TYPES.KILL, doer.entity)
    end
end

AddPrefabPostInit("world", function(world)
    -- Pushed for every living entity (players too) that dies in the current shard.
    world:SafeListenForEvent("entity_death", onentitydeath)
end)

-------------------
-- BURNABLE --
-------------------

local onburntup
onburntup = function(target)
    -- Use InGamePlay() check to prevent spam when loading...
    if not target or not InGamePlay() then
        return
    end

    -- We will not need this callback anymore.
    target:RemoveEventCallback("burntup", onburntup)

    local workable = target.components and target.components.workable or nil
    -- Only announce when a player creation burns up.
    if workable and workable:HasBuilder() then
        PEARL.AnnounceWithType(subfmt(STRINGS.PEARL.ACTIONS.BURNTUP.OWNED, {
            target = target:GetFancyName(), owner = workable:GetBuilderName()
        }), PEARL.CONSTS.ANNOUNCEMENT_TYPES.BURN, target.entity)
    end
end

--- @param inst EntityScript
AddComponentPostInit("burnable", function(self, inst)
    if not (inst and inst:HasTag("structure")) then
        return
    end

    -- Announce when a structure burnts up
    inst:SafeListenForEvent("burntup", onburntup)
end)

-------------------
-- THIEFS --
-------------------

-- Note: This causes quite a lot of spam when using some mods
-- like Too Many Items etc...
local function oncommandexecuted(doer, fnstr)
    -- It's totally normal when the command is just an empty string.
    -- This happens for example when you just open and then close the console.
    if not doer or not (type(fnstr) == "string" and #fnstr > 0) then
        return
    end

    -- Ignore commands from the server owner.
    if TheNet:GetUserID() == doer.userid then
        return
    end

    if #fnstr > MAX_COMMAND_LENGTH then
        fnstr = fnstr:ltake(MAX_COMMAND_LENGTH).."..."
    end

    PEARL.DiscordLogger:LogStringRaw(STRINGS.PEARL.LOGS.CONSOLE_CMD:format(
        doer:GetDisplayName(), fnstr
    ), PEARL.ICONS.PLAYER_STATE.CMD_SEND)
end

--- @TODO: Announce these to the game only if the rarity is equal to 1.
local function ontookrareitem(doer, item)
    if not (doer and item) then
        return PEARL.warn("Called ontookrareitem with invalid arguments!")
    end

    if item.components.inventoryitem:IsLastPlayerOwner(doer) or item.components.inventoryitem:IsLastPicker(doer) then
        return
    end

    local silent = not item.components.inventoryitem:IsVeryRare()
    PEARL.AnnounceWithType(subfmt(STRINGS.PEARL.ACTIONS.TAKE_ITEM.GENERIC, {
        doer = doer:GetDisplayName(), item = item:GetFancyName()
    }), PEARL.CONSTS.ANNOUNCEMENT_TYPES.TAKE, doer.entity, silent)
end

local function ontookrarecontainer(doer, data)
    if not (doer and data and data.items and data.container) then
        return PEARL.warn("Called ontookrarecontainer with invalid arguments!")
    end

    local items_str = PEARL.BuildFancyStringForEntities(data.items)
    PEARL.AnnounceWithType(subfmt(STRINGS.PEARL.ACTIONS.TAKE_ITEM.WITH, {
        doer = doer:GetDisplayName(), item = data.container:GetFancyName(), with = items_str
    }), PEARL.CONSTS.ANNOUNCEMENT_TYPES.TAKE, doer.entity)
end

local function onfinishedlooting(doer, data)
    if not (doer and data and data.items and data.container) then
        return PEARL.warn("Called onfinishedlooting with invalid arguments!")
    end

    local loot_string = PEARL.BuildFancyStringForEntities(data.items)
    PEARL.AnnounceWithType(subfmt(STRINGS.PEARL.ACTIONS.TAKE_ITEM.FROM, {
        doer = doer:GetDisplayName(), items = loot_string, target = data.container:GetFancyName()
    }), PEARL.CONSTS.ANNOUNCEMENT_TYPES.TAKE, doer.entity, not data.items.rare)
end

-------------------------------
-- [[ Listeners ]]
-------------------------------

--- @param player EntityScript
PEARL.AddPlayerPostInit(function(player)
    if not player then
        return
    end

    player:AddComponent("playerthief")
    player:ListenForModEvent("tookrareitem", ontookrareitem)
    player:ListenForModEvent("tookrarecontainer", ontookrarecontainer)
    player:ListenForModEvent("finishedlooting", onfinishedlooting)

    if PEARL.CONFIG.DISCORD.LHOOK.ENABLED then
        player:ListenForModEvent("ms_commandexecuted", oncommandexecuted)
    end
end)
