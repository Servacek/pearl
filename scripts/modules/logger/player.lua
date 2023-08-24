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

--- @type ActionLog
local AL = PEARL.loadfile("libraries/actionlog")
local QueuedLogAction = PEARL.loadfile("models/queuedlogaction")

------------------------
-- [[ Global Localization ]]
------------------------

local TheSim = TheSim

local removearrayvalue = table.removearrayvalue

------------------------
-- [[ Constants ]]
------------------------

local MAX_COMMAND_LENGTH = 500

local REPUTATIONS = PEARL.CONSTS.REPUTATION_TABLES

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
    if type(action) ~= "table" then
        error("invalid action")
    end

    if type(handler) ~= "function" then
        error("invalid action handler")
    end

    local _action = action.fn
    action.fn = function(act, ...)
        local success = _action(act, ...)
        if success and act ~= nil and handler ~= nil then
            local doer, target, item, pos = act.doer, act.target, (act.invobject or act.recipe), act:GetActionPoint()
            pos = pos or (target and target:GetPosition())

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

    local silent = false
    if not ((
        -- The target is a structure or craftable item
        target:HasTag("structure") or type(AllRecipes[target.prefab]) == "table"
    ) or (
        -- Or the target is anything but it's near some plant's or structures
        near and (#near > 4 or table.find(near, structuresearchfn))
    )) then
        silent = true
    end

    if near and #near > 0 then
        return AL:LogAction(doer, PEARL.CONSTS.ANNOUNCEMENT_TYPES.IGNITE, subfmt(STRINGS.PEARL.ACTIONS.IGNITE.NEAR, {
            doer = doer:GetDisplayName(), target = target:GetFancyName(), near = PEARL.BuildFancyStringForEntities(near)
        }), silent)
    end

    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.IGNITE.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.IGNITE)
        :SetIsSilent(silent)
        :AddTarget(target)
end)

RegisterPlayerActionHandler(ACTIONS.EAT, function(doer, target, item)
    local silent = not PEARL.PREFABS.RARE_ITEMS[item.prefab]
    local type = PEARL.CONSTS.ANNOUNCEMENT_TYPES[silent and "EAT" or "SWALLOW"]

    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.EAT.GENERIC, doer)
        :SetLogType(type)
        :SetIsSilent(silent)
        :AddTarget(item)
end)

RegisterPlayerActionHandler(ACTIONS.TEACH, function(doer, target, item)
    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.TEACH.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.TEACH)
        :SetIsSilent(item.is_rare ~= true)
        :AddTarget(target)
end)

RegisterPlayerActionHandler(ACTIONS.HAMMER, function(doer, target)
    local workable = target.components and target.components.workable or nil
    if workable and workable.workleft and workable.workleft <= 0 then
        local silent = false
        -- Only announce hammering when the structure was built by a player
        -- This makes sure we only log when a base structure get's hammered.
        if not workable:HasBuilder() or workable:IsBuildBy(doer.userid) then
            silent = true
        end

        -- Ignore burned structures
        if target:HasTag("burnt") then
            silent = true
        end

        local action
        if workable:HasBuilder() then
            action = AL:QueueEntAct(STRINGS.PEARL.ACTIONS.HAMMER.OWNED, doer,
            QueuedLogAction.STATIC_FIELDS.OWNER, workable:GetBuilderName())
        else
            action = AL:QueueEntAct(STRINGS.PEARL.ACTIONS.HAMMER.GENERIC, doer)
        end

        action:SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.HAMMER)
        action:SetIsSilent(silent)
        action:AddTarget(target)
    end
end)

RegisterPlayerActionHandler(ACTIONS.READ, function(doer, target, item)
    -- This is here to handle cases where a player reads the book
    -- but does not cast the book's spell (e. g. Wurt).
    if not doer.components.reader or doer.components.reader:IsAspiringBookworm() then
        return
    end

    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.READ.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.READ)
        :SetIsSilent(PEARL.PREFABS.OFFENSIVE_BOOKS[item.prefab] ~= true)
        :AddTarget(item)
end)

RegisterPlayerActionHandler(ACTIONS.ACTIVATE, function(doer, target)
    --- @WARNING: This is a Terrarium specific tag! @TODO
    if target.is_on and PEARL.PREFABS.ACTIVATABLE[target.prefab] and not target.components.activatable:IsLastPlayerActivator(doer) then
        target.components.activatable:SetLastPlayerActivator(doer)

        -- No point in queuing this action since it's so specific.
        AL:LogAction(doer, PEARL.CONSTS.ANNOUNCEMENT_TYPES.ACTIVATE, STRINGS.PEARL.ACTIONS.ACTIVATE:format(
            -- No stacksize here
            doer:GetDisplayName(), target:GetBasicDisplayName()
        ), false)
    end
end)

-- This is being called for cooking in crockpots as well.
RegisterPlayerItemActionHandler(ACTIONS.COOK, function(doer, target, item)
    -- Maybe add the crockpot support at some point?
    -- if target and target.components.stewer and target.compoponents.stewer.ingredient_prefabs then
    --     for _, prefab in ipairs(target.compoponents.stewer.ingredient_prefabs) do

    --     end
    -- end

    local prohibited = target and PEARL.PREFABS.RARE_ITEMS[target.prefab] ~= nil or PEARL.PREFABS.RARE_ITEMS[item.prefab] ~= nil
    local type = PEARL.CONSTS.ANNOUNCEMENT_TYPES[prohibited and "SWALLOW" or "COOK"]

    AL:QueueEntAct(STRINGS.PEARL.COOK, doer)
        :SetLogType(type)
        :SetIsSilent(true)
        :AddTarget(target)
end)

RegisterPlayerActionHandler(ACTIONS.MANUALEXTINGUISH, function(doer, target, item)
    if target:HasTag("structure") then
        PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.EXTINGUISH_STRUCT)
    end

    print("TOOL", item)
    return AL:QueueEntAct(STRINGS.PEARL.ACTIONS.EXTINGUISH[item and "WITH" or "GENERIC"], doer,
        QueuedLogAction.STATIC_FIELDS.TOOL, item)
        :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.EXTINGUISH)
        :SetIsSilent(true)
        :AddTarget(target)
end)

RegisterPlayerActionHandler(ACTIONS.CHOP, function(doer, target)
    local prohibited = PEARL.PREFABS.DO_NOT_CHOP[target.prefab]
    if not prohibited then
        return
    end

    local workable = target.components and target.components.workable or nil
    if not (workable and workable.workleft and workable.workleft <= 0) then
        return
    end

    -- Too spammy, announce only if prohibited.
    if prohibited then
        return AL:QueueEntAct(STRINGS.PEARL.ACTIONS.CHOP.GENERIC, doer)
            :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.CHOP)
            :SetIsSilent(not prohibited)
            :AddTarget(target)
    end
end)

RegisterPlayerActionHandler(ACTIONS.DIG, function(doer, target)
    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.DIG.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.DIG)
        :SetIsSilent(true)
        :AddTarget(target)
end)

RegisterPlayerActionHandler(ACTIONS.PLANT, function(doer, target)
    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.PLANT.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.PLANT)
        :SetIsSilent(true)
        :AddTarget(target)
end)

RegisterPlayerActionHandler(ACTIONS.SLEEPIN, function(doer, target)
    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.SLEEP.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.SLEEP)
        :SetIsSilent(true)
        :AddTarget(target)
end)

RegisterPlayerItemActionHandler(ACTIONS.GIVE, function(doer, target, item)
    local prohibited = PEARL.PREFABS.DO_NOT_CHOP[target.prefab]

    -- Too spammy, announce only if prohibited.
    if prohibited then
        return AL:QueueEntAct(STRINGS.PEARL.ACTIONS.GIVE.GENERIC, doer)
            :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.GIVE)
            :SetIsSilent(not prohibited)
            :AddTarget(target)
    end
end)

RegisterPlayerItemActionHandler(ACTIONS.PLAY, function(doer, target, item)
    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.PLAY.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.PLAY)
        :SetIsSilent(true)
        :AddTarget(item)
end)

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

    if target then
        removearrayvalue(entities, target)
    end

    if #entities > 0 then
        return OnAreaCast(
            doer, item, target, entities,
            PEARL.CONSTS.ANNOUNCEMENT_TYPES.BURN
        )
    end

    if not target or not target:HasOneOfTags(PEARL.CONSTS.ENT_ONEOF_TAGS) then
        return -- Something we do not really care about away from anything we care.
    end

    OnCast(doer, item, target, PEARL.CONSTS.ANNOUNCEMENT_TYPES.BURN, false, true)
end

local function OnCastAreaDestruction(doer, item, target, pos, radius)
    local entities = TheSim:FindEntities(pos.x, pos.y, pos.z, radius,
        -- Do not care about plants here since they are not heavily affected by destruction.
        nil, nil, PEARL.CONSTS.BASE_STRUCTURE_TAGS
    )

    if target then
        removearrayvalue(entities, target)
    end

    if #entities > 0 then
        return OnAreaCast(
            doer, item, target, entities,
            PEARL.CONSTS.ANNOUNCEMENT_TYPES.HAMMER, true
        )
    end

    if not target or not target:HasTag("structure") then
        return
    end

    return OnCast(doer, item, target, PEARL.CONSTS.ANNOUNCEMENT_TYPES.HAMMER)
end

RegisterPlayerItemActionHandler(ACTIONS.CASTSPELL, function(doer, target, item, pos)
    -- Green Staff
    if PEARL.PREFABS.DESTRUCTION_ITEMS[item.prefab] then
        return OnCastDestruction(doer, item, target)
    end

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
    -- Handle special transition case for Klaus.
    if target:HasTag("epic") and not (target.sg and target.sg:HasTag("transition")) then
        local doer_name = (doer and doer:GetDisplayName()) or (data.explosion and "Explosion") or "Shenanigans"
        return AL:QueueEntAct(STRINGS.PEARL.ACTIONS.KILL.BOSS, doer_name)
            :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.DEFEAT)
            :AddTarget(target)
    end

    if not (doer and doer:HasTag("player")) then
        return
    end

    -- NOT RESPAWNABLE MOB
    local pop_threshold = PEARL.PREFABS.MOBS.MONITOR_POPULATION[target.prefab]
    if pop_threshold and pop_threshold > 0 then
        --- This works for the current shard only, but is just enough for our use cases currently.
        local remaining = c_countprefabs(target.prefab, false) - 1 or -1
        if remaining < 0 or remaining > pop_threshold then
            return
        end

        if remaining == 0 then
            -- Queue to make sure this will be announced after the last remaining announcement.
            return AL:QueueEntAct(STRINGS.PEARL.ACTIONS.KILL.LAST, doer)
                :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.KILL)
                :AddTarget(target)
        end

        return AL:QueueEntAct(STRINGS.PEARL.ACTIONS.KILL.REMAINING, doer)
            :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.KILL)
            :AddTarget(target)
            :SetDynamicField(QueuedLogAction.DYNAMIC_FIELDS.REMAINING, remaining)
    end


    -- COMPANION
    if PEARL.PREFABS.MOBS.COMPANIONS[target.prefab] then
        return AL:QueueEntAct(STRINGS.PEARL.ACTIONS.KILL.GENERIC, doer)
            :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.KILL)
            :AddTarget(target)
    end

    -- FOLLOWER
    local leader = target.components.follower and target.components.follower:GetLeader() or nil
    if leader and leader:HasTag("player") and leader ~= doer then
        return AL:QueueEntAct(STRINGS.PEARL.ACTIONS.KILL.FOLLOWER, doer,
            QueuedLogAction.STATIC_FIELDS.OWNER, leader)
            :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.KILL)
            :AddTarget(target)
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
        AL:QueueAct(STRINGS.PEARL.ACTIONS.BURNTUP.OWNED,
            QueuedLogAction.STATIC_FIELDS.OWNER, workable:GetBuilderName())
            :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.BURN)
            :AddTarget(target)
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
-- PLAYER STATES --
-------------------
--- These are already announced by the game.
local function onrespawnfromghost(inst, data)
    if data and data.user and data.user.userid then
        PEARL.Reputation:EarnFor(data.user.userid, REPUTATIONS.REVIVE)
    end
end

local function ondeath(inst)
    if inst and inst.userid then
        PEARL.Reputation:GiveTo(inst.userid, REPUTATIONS.DIED)
    end
end

-------------------
-- Killers --
-------------------
-- Track damage dealt to bosses.
--- @TODO: Rework the defeat announcement to contain all attackers.
local function onhitother(inst, data)
    if not data or not data.target or not data.target:IsValid() or not data.target:HasTag("epic") then
        return
    end

    local dmg = math.max(data.damageresolved or data.damage or 1, 1)
    PEARL.Reputation:EarnFor(
        inst.userid, dmg * REPUTATIONS.BOSS_DAMAGE
    )
end

-------------------
-- Builders --
-------------------

local function onbuilditem(doer, data)

end

local function onbuildstructure(doer, data)
    local target = data.item
    if not target then
        return
    end

    if target.components.propagator then
        print("BUILD FIRE SOURCE")
        local near = target:GetPropagableBurnableEntities()
        if near and #near > 0 then
            local silent = #near > 2 or table.find(near, structuresearchfn)
            local type = PEARL.CONSTS.ANNOUNCEMENT_TYPES[silent and "PROPAGATOR" or "BURNT"]

            AL:QueueEntAct(STRINGS.PEARL.ACTIONS.BUILD.NEAR, doer, {
                near = near
            }):SetLogType(type)
            :SetIsSilent(silent)
            :AddTarget(target)
        end
    end

    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.BUILD.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.BURN)
        :SetIsSilent(true)
        :AddTarget(target)
end

RegisterPlayerActionHandler(ACTIONS.BUILD, function(doer, target, item)
    if not item then
        return
    end

    -- If the target is burning right from the start.
    if item.components.burnable and item.components.burnable:IsBurning() then
        print("BUILT FIRE SOURCE!")
    end

    print("BUILD", target, item)
    return AL:QueueEntAct(STRINGS.PEARL.ACTIONS.CHOP.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.CHOP)
        :SetIsSilent(true)
        :AddTarget(item)
end)

RegisterPlayerActionHandler(ACTIONS.CONSTRUCT, function(doer, target, item)
    print("CONSTRUCT", target, item)
    return AL:QueueEntAct(STRINGS.PEARL.ACTIONS.CHOP.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.CHOP)
        :SetIsSilent(true)
        :AddTarget(target)
end)

-------------------
-- THIEFS --
-------------------

-- Note: This causes quite a lot of spam when using some mods
-- like Too Many Items etc...
-- local function oncommandexecuted(doer, fnstr)
--     -- It's totally normal when the command is just an empty string.
--     -- This happens for example when you just open and then close the console.
--     if not doer or not (type(fnstr) == "string" and #fnstr > 0) then
--         return
--     end

--     -- Ignore commands from the server owner.
--     if TheNet:GetUserID() == doer.userid then
--         return
--     end

--     if #fnstr > MAX_COMMAND_LENGTH then
--         fnstr = fnstr:ltake(MAX_COMMAND_LENGTH, nil, "...")
--     end

--     PEARL.DiscordLogger:LogStringRaw(STRINGS.PEARL.LOGS.CONSOLE_CMD:format(
--         doer:GetDisplayName(), fnstr
--     ), PEARL.ICONS.PLAYER_STATE.CMD_SEND)
-- end

local function ontookrareitem(doer, item)
    if not (doer and item) then
        return PEARL.warn("Called ontookrareitem with invalid arguments!")
    end

    if item.components.inventoryitem:IsLastPlayerOwner(doer) or item.components.inventoryitem:IsLastPicker(doer) then
        return
    end

    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.TAKE_ITEM.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANNOUNCEMENT_TYPES.TAKE)
        :SetIsSilent(not item.components.inventoryitem:IsVeryRare())
        :AddTarget(item)
end

local function ontookrarecontainer(doer, data)
    if not (doer and data and data.items and data.container) then
        return PEARL.warn("Called ontookrarecontainer with invalid arguments!")
    end

    local items_str = PEARL.BuildFancyStringForEntities(data.items)
    AL:LogAction(doer, PEARL.CONSTS.ANNOUNCEMENT_TYPES.TAKE, STRINGS.PEARL.ACTIONS.TAKE_ITEM.WITH:nformat{
        doer = doer:GetStandardizedName(), source = data.container:GetStandardizedName(), target = items_str
    })
end

local function onfinishedlooting(doer, data)
    if not (doer and data and data.items and data.container) then
        return PEARL.warn("Called onfinishedlooting with invalid arguments!")
    end

    -- Do not queue this action
    local loot_string = PEARL.BuildFancyStringForEntities(data.items)
    AL:LogAction(doer, PEARL.CONSTS.ANNOUNCEMENT_TYPES.TAKE, STRINGS.PEARL.ACTIONS.TAKE_ITEM.FROM:nformat({
        doer = doer:GetDisplayName(), items = loot_string, target = data.container:GetFancyName()
    }), not data.items.rare)
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

    player:SafeListenForEvent("respawnfromghost", onrespawnfromghost)
    player:SafeListenForEvent("death", ondeath)

    player:SafeListenForEvent("onhitother", onhitother)

    if player.components.builder then
        player:SafeListenForEvent("builditem", onbuilditem)
        player:SafeListenForEvent("buildstructure", onbuildstructure)
    end

    -- if PEARL.CONFIG.DISCORD.LHOOK.ENABLED then
    --     player:ListenForModEvent("ms_commandexecuted", oncommandexecuted)
    -- end
end)
