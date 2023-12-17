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

local MAX_COMMAND_LENGTH = 256

local REPUTATIONS = PEARL.CONSTS.REPUTATION_TABLES

-- Determines the number of burnable structures needed to activate the extinguisher.
local EXTINGUISHER_STRUCTURES = 4
local EXTINGUISHER_ANY = 6
local EXTINGUISHER_RADIUS = PEARL.CONSTS.EXTINGUISH_RADIUS

local TIME_UNTIL_EXTINGUISH = 4 -- in seconds

local MAX_ATTACKERS = 5
local MAX_REMEMBERING_DELAY = 8 * 60 -- Circa one in-game cycle
local MIN_DAMAGE_DEALT = 10

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
--- @param action class<Action> The action to register the handler for.
--- @param handler function The additional handler for the provided action.
--- @param checkfn function? Optional check function used to verify the arguments passed for the action handler.
--- @return function handler? The handler parameter. Used for chaining.
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
            if type(checkfn) ~= "function" or checkfn(doer, target, item, pos) then
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

    return handler
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
    -- Burnable entities in the propagation radius
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

    --- @TODO: Create some separate "pyromaniac" component for this.
    --- Cache the ignited entities somewhere.
    --- For now this is enough since griefing is not that big of a problem as it was.
    if doer.Transform and (
        #near >= EXTINGUISHER_ANY or
        table.find(near, burnablestructuresearchfn, EXTINGUISHER_STRUCTURES)
    ) and PEARL.CONFIG.PERMISSIVE_MODE ~= true then
        PEARL.info("Extinguishing the fires!")

        local doername = doer:GetDisplayName()
        local x, y, z = doer.Transform:GetWorldPosition()
        -- Extinguish fires near the doer.
        -- Use TheWorld as a more reliable parent for the task.
        TheWorld:DoTaskInTime(TIME_UNTIL_EXTINGUISH, function()
            if PEARL.ExtinguishFires(x, y, z, EXTINGUISHER_RADIUS) > 0 then
                PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.IGNITING_AT_BASE, true)
            end

            if type(doername) ~= "string" then
                return TheNet:SystemMessage(STRINGS.PEARL.LOGS.EXTINGUISH)
            end

            if doername then
                TheNet:SystemMessage(
                    STRINGS.PEARL.LOGS.EXTINGUISH_NEAR:format(
                        doername
                    )
                )
            end
        end)
    end

    if near and #near > 0 then
        return AL:LogAction(doer, PEARL.CONSTS.ANN_TYPE.IGNITE, subfmt(STRINGS.PEARL.ACTIONS.IGNITE.NEAR, {
            doer = doer:GetDisplayName(), target = target:GetFancyName(), near = PEARL.BuildFancyStringForEntities(near)
        }), silent)
    end

    local mult = silent and 1 or (near and #near or 0) + 1
    PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.IGNITED_STRUCTURE * mult, true)

    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.IGNITE.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.IGNITE)
        :SetIsSilent(silent)
        :AddTarget(target)
end)

RegisterPlayerActionHandler(ACTIONS.EAT, function(doer, target, item)
    local rarity = PEARL.GetRarityForPrefab(item.prefab)
    local silent = rarity <= 0
    local type = PEARL.CONSTS.ANN_TYPE[silent and "EAT" or "SWALLOW"]

    if rarity > 0 then
        PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.EAT_RARE * rarity)
    end

    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.EAT.GENERIC, doer)
        :SetLogType(type)
        :SetIsSilent(silent)
        :AddTarget(item, 1)
end)

RegisterPlayerActionHandler(ACTIONS.HEAL, function(doer, target, item)
    if target and target:HasTag("player") and target.components.health and target.components.health:IsHurt() then
        PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.PLAYER_HEALED)
    end

    local pt = STRINGS.PEARL.ACTIONS.HEAL[target and "TARGET" or "USING"]
    AL:QueueEntAct(pt, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.HEAL)
        :SetIsSilent(true)
        :AddToDynamicField(QueuedLogAction.STATIC_FIELDS.TOOL, item, 1)
        :AddTarget(target, 1)
end)

RegisterPlayerActionHandler(ACTIONS.SEW, function(doer, target, item)
    local pt = STRINGS.PEARL.ACTIONS.SEW[item and "USING" or "GENERIC"]
    AL:QueueEntAct(pt, doer, "tool", item)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.SEW)
        :SetIsSilent(true)
        :AddTarget(target, 1)
end)

RegisterPlayerActionHandler(ACTIONS.TEACH, function(doer, target, item)
    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.TEACH.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.TEACH)
        :SetIsSilent(item.is_rare ~= true)
        :AddTarget(target, 1)
end)

RegisterPlayerActionHandler(ACTIONS.HAMMER, function(doer, target)
    local workable = target.components and target.components.workable or nil
    if workable and workable.workleft and workable.workleft <= 0 then
        local silent = false
        local mult = 1
        -- Only announce hammering when the structure was built by a player
        -- This makes sure we only log when a base structure get's hammered.
        if not workable:HasBuilder() or workable:IsBuildBy(doer.userid) then
            silent = true
            mult = .5
        end

        -- Ignore burned structures
        if target:HasTag("burnt") then
            silent = true
        else
            PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.HAMMER_STRUCTURE * mult, true)
        end

        local action
        if workable:HasBuilder() then
            action = AL:QueueEntAct(STRINGS.PEARL.ACTIONS.HAMMER.OWNED, doer,
            QueuedLogAction.STATIC_FIELDS.OWNER, workable:GetBuilderName())
        else
            action = AL:QueueEntAct(STRINGS.PEARL.ACTIONS.HAMMER.GENERIC, doer)
        end

        action:SetLogType(PEARL.CONSTS.ANN_TYPE.HAMMER)
        action:SetIsSilent(silent)
        action:AddTarget(target, 1)
    end
end)

RegisterPlayerActionHandler(ACTIONS.READ, function(doer, target, item)
    -- This is here to handle cases where a player reads the book
    -- but does not cast the book's spell (e. g. Wurt).
    if not doer.components.reader or doer.components.reader:IsAspiringBookworm() then
        return
    end

    local prohibited = PEARL.PREFABS.OFFENSIVE_BOOKS[item.prefab] == true
    if prohibited then
        PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.READ_OFFENSIVE_BOOK)
    end

    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.READ.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.READ)
        :SetIsSilent(not prohibited)
        :AddTarget(item, 1)
end)

RegisterPlayerActionHandler(ACTIONS.ACTIVATE, function(doer, target)
    --- @WARNING: This is a Terrarium specific tag! @TODO
    if target.is_on and PEARL.PREFABS.ACTIVATABLE[target.prefab] and not target.components.activatable:IsLastPlayerActivator(doer) then
        target.components.activatable:SetLastPlayerActivator(doer)

        -- No point in queuing this action since it's so specific.
        AL:LogAction(doer, PEARL.CONSTS.ANN_TYPE.ACTIVATE, STRINGS.PEARL.ACTIONS.ACTIVATE:format(
            -- No stacksize here
            doer:GetDisplayName(), target:GetBasicDisplayName()
        ), false)
    end
end)

-- This is being called for cooking in crockpots as well.
--- @param doer EntityScript The doer (player) of the action.
--- @param tool EntityScript? The tool used for the action or the target item.
--- @param item EntityScript? The optional target item that was used to click on the cooking tool.
RegisterPlayerActionHandler(ACTIONS.COOK, function(doer, tool, item)
    if tool and tool.components.cookable and not (item and item.components.cookable) then
        tool, item = item, tool
    end

    local prohibited = false
    local rarity = PEARL.GetRarityForPrefab(item and item.prefab)
    if rarity > 0 then
        prohibited = true

        PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.COOKED_RARE * rarity)
    end

    local pattern = STRINGS.PEARL.ACTIONS.COOK.GENERIC
    local stewer = tool and tool.components.stewer
    if tool then
        pattern = STRINGS.PEARL.ACTIONS.COOK.ON

        if tool.components.stewer then
            pattern = STRINGS.PEARL.ACTIONS.COOK.IN
        end
    end

    local action = AL:QueueEntAct(pattern, doer, "tool", tool)
    if stewer and stewer.ingredient_prefabs and not table.empty(stewer.ingredient_prefabs) then
        for _, prefab in ipairs(stewer.ingredient_prefabs) do
            action:AddTarget(PEARL.PrefabToName(prefab), 1)

            rarity = PEARL.GetRarityForPrefab(prefab)
            if rarity > 0 then
                PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.COOKED_RARE_INGRED * rarity)

                prohibited = true
            end
        end
    elseif item ~= nil and item.components.cookable then
        action:AddTarget(item, 1)
    end

    action:SetLogType(PEARL.CONSTS.ANN_TYPE[prohibited and "SWALLOW" or "COOK"])
    action:SetIsSilent(not prohibited)
end)

RegisterPlayerActionHandler(ACTIONS.SMOTHER,
RegisterPlayerActionHandler(ACTIONS.MANUALEXTINGUISH, function(doer, target, item)
    if target:HasTag("structure") then
        PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.EXTINGUISH_STRUCT)
    else
        PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.EXTINGUISH)
    end

    return AL:QueueEntAct(STRINGS.PEARL.ACTIONS.EXTINGUISH[item and "WITH" or "GENERIC"], doer,
        QueuedLogAction.STATIC_FIELDS.TOOL, item)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.EXTINGUISH)
        :SetIsSilent(true)
        :AddTarget(target)
end))

RegisterPlayerActionHandler(ACTIONS.CHOP, function(doer, target)
    -- Too spammy, announce only if prohibited.
    local prohibited = PEARL.PREFABS.DO_NOT_CHOP[target.prefab]
    if not prohibited then
        return
    end

    local workable = target.components and target.components.workable or nil
    if not (workable and workable.workleft and workable.workleft <= 0) then
        return
    end

    PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.CHOPPED_PROHIBITED)

    -- Too spammy, announce only if prohibited.
    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.CHOP.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.CHOP)
        :SetIsSilent(not prohibited)
        :AddTarget(target)
end)

RegisterPlayerItemActionHandler(ACTIONS.ADDFUEL, function(doer, target, item)
    local reserve = math.max(target.components.fueled.maxfuel - target.components.fueled.currentfuel, 0)
    local added = item.components.fuel.fuelvalue
    local waste = math.min(added - reserve, 0) / added

    if item.components.inventoryitem:IsRare() then
        waste = 1
    end

    local type = PEARL.CONSTS.ANN_TYPE.PROPAGATOR
    local str = STRINGS.PEARL.ACTIONS.ADDFUEL.GENERIC
    if waste > 0.5 then
        str = STRINGS.PEARL.ACTIONS.ADDFUEL.WASTE
        type = PEARL.CONSTS.ANN_TYPE.WASTE

        PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.FUEL_WASTED * waste)
    end

    AL:QueueEntAct(str, doer, "source", target)
        :SetLogType(type)
        :SetIsSilent(true)
        :AddTarget(item)
end)

RegisterPlayerActionHandler(ACTIONS.DIG, function(doer, target)
    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.DIG.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.DIG)
        :SetIsSilent(true)
        :AddTarget(target)
end)

-- This is for planting in a farm plot or something like that.
-- RegisterPlayerActionHandler(ACTIONS.PLANT, function(doer, target, item)
--     PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.FERTILIZE)

--     AL:QueueEntAct(STRINGS.PEARL.ACTIONS.PLANT.GENERIC, doer)
--         :SetLogType(PEARL.CONSTS.ANN_TYPE.PLANT)
--         :SetIsSilent(true)
--         :AddTarget(item, 1)
-- end)

RegisterPlayerActionHandler(ACTIONS.DEPLOY, function(doer, target, item)
    if item:HasTag("plant") then
        if item:HasTag("witherable") then
            PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.PLANT_WITHERABLE)
        else
            PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.PLANT)
        end
    end

    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.PLANT.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.PLANT)
        :SetIsSilent(true)
        :AddTarget(item, 1)
end)

RegisterPlayerItemActionHandler(ACTIONS.FERTILIZE, function(doer, target, item)
    PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.FERTILIZE)

    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.FERTILIZE.WITH, doer, "item", item)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.FERTILIZE)
        :SetIsSilent(true)
        :AddTarget(target)
end)

RegisterPlayerActionHandler(ACTIONS.SLEEPIN, function(doer, target)
    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.SLEEP.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.SLEEP)
        :SetIsSilent(true)
        :AddTarget(target)
end)

RegisterPlayerItemActionHandler(ACTIONS.GIVEALLTOPLAYER,
RegisterPlayerItemActionHandler(ACTIONS.GIVETOPLAYER,
RegisterPlayerItemActionHandler(ACTIONS.GIVE, function(doer, target, item)
    local prohibited = PEARL.GetRarityForPrefab(item.prefab) >= 1

    return AL:QueueEntAct(STRINGS.PEARL.ACTIONS.GIVE.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.GIVE)
        :AddToDynamicField(QueuedLogAction.STATIC_FIELDS.TOOL, item, 1)
        :SetIsSilent(not prohibited)
        :AddTarget(target, 1)
end)))

RegisterPlayerItemActionHandler(ACTIONS.PLAY, function(doer, target, item)
    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.PLAY.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.PLAY)
        :SetIsSilent(true)
        :AddTarget(item)
end)

RegisterPlayerActionHandler(ACTIONS.MINE, function(doer, target)
    if not target.components.workable then
        local prohibited = PEARL.PREFABS.DO_NOT_MINE[target.prefab]

        -- Too spammy, announce only if prohibited.
        if prohibited then
            AL:QueueEntAct(STRINGS.PEARL.ACTIONS.MINE.GENERIC, doer)
                :SetLogType(PEARL.CONSTS.ANN_TYPE.MINE)
                :SetIsSilent(not prohibited)
                :AddTarget(target, 1)
        end
    end
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
        PEARL.CONSTS.ANN_TYPE.HAMMER
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
            PEARL.CONSTS.ANN_TYPE.BURN
        )
    end

    if not target or not target:HasOneOfTags(PEARL.CONSTS.ENT_ONEOF_TAGS) then
        return -- Something we do not really care about away from anything we care.
    end

    OnCast(doer, item, target, PEARL.CONSTS.ANN_TYPE.BURN, false, true)
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
            PEARL.CONSTS.ANN_TYPE.HAMMER, true
        )
    end

    if not target or not target:HasTag("structure") then
        return
    end

    return OnCast(doer, item, target, PEARL.CONSTS.ANN_TYPE.HAMMER)
end

--- @DEBUG + Add Reputation
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

--- @DEBUG + Add Reputation
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
    --- @DEBUG Handle special transition case for Klaus.
    if target:HasTag("epic") and not (target.sg and target.sg:HasStateTag("transition")) then
        local pt = STRINGS.PEARL.ACTIONS.KILL.BOSS
        pt = pt:nformat("target", target:GetBasicDisplayName())

        if target.components.memory then
            local doers = {}
            local records = target.components.memory:Sorted()
            for userid, _ in pairs(records) do
                local player = LookupPlayerInstByUserID(userid)
                if player then
                    doers[#doers + 1] = player:GetDisplayName()
                end
            end

            target.components.memory:Clear()
            target:RemoveComponent("memory")
            pt = pt:nformat("doer", PEARL.FancyTableConcat(doers))
        else
            pt = pt:nformat("doer", (doer and doer:GetDisplayName()) or (data.explosion and "Explosion") or "Shenanigans")
        end

        return AL:LogAction(doer.entity, PEARL.CONSTS.ANN_TYPE.DEFEAT, pt)
    end

    --- @DEBUG
    -- MOB SPREADING FIRE AFTER DEATH
    if PEARL.PREFABS.MOBS.FIRE_SPREADERS[target.prefab] then
        local near = target:GetPropagableBurnableEntities(
            nil, nil, PEARL.CONSTS.LARGE_PROPAGATOR_RADIUS
        )

        local prohibited = #near >= 4 or table.find(near, structuresearchfn)

        return AL:LogAction(doer, PEARL.CONSTS.ANN_TYPE.FIRE, subfmt(STRINGS.PEARL.ACTIONS.KILL.NEAR, {
            doer = doer:GetDisplayName(), target = target:GetFancyName(), near = PEARL.BuildFancyStringForEntities(near)
        }), not prohibited)
    end

    --- @DEBUG
    -- NOT RESPAWNABLE MOB
    local pop_threshold = PEARL.PREFABS.MOBS.MONITOR_POPULATION[target.prefab]
    if pop_threshold and pop_threshold > 0 then
        --- This works for the current shard only, but is just enough for our use cases currently.
        local remaining = PEARL.CountPrefabs(target.prefab) - 1
        if remaining < 0 or remaining > pop_threshold then
            return
        end

        if remaining == 0 then
            -- Queue to make sure this will be announced after the last remaining announcement.
            return AL:QueueEntAct(STRINGS.PEARL.ACTIONS.KILL.LAST, doer)
                :SetLogType(PEARL.CONSTS.ANN_TYPE.KILL)
                :SetColorEntity(doer and doer.entity)
                :AddTarget(target)
        end

        return AL:QueueEntAct(STRINGS.PEARL.ACTIONS.KILL.REMAINING, doer)
            :SetLogType(PEARL.CONSTS.ANN_TYPE.KILL)
            :SetColorEntity(doer and doer.entity)
            :AddTarget(target)
            :SetDynamicField(QueuedLogAction.DYNAMIC_FIELDS.REMAINING, remaining)
    end

    local leader = target.components.follower and target.components.follower:GetLeader() or nil
    if PEARL.PREFABS.MOBS.COMPANIONS[target.prefab] then

    -- FOLLOWER
    elseif leader and leader:HasTag("player") then
        return AL:QueueEntAct(STRINGS.PEARL.ACTIONS.KILL.FOLLOWER, doer,
            QueuedLogAction.STATIC_FIELDS.OWNER, leader)
            :SetLogType(PEARL.CONSTS.ANN_TYPE.KILL)
            :SetColorEntity(doer and doer.entity)
            :AddTarget(target)
    end

    if not (doer and doer:HasTag("player")) then
        return
    end

    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.KILL.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.KILL)
        :SetColorEntity(doer and doer.entity)
        :AddTarget(target)
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
            :SetLogType(PEARL.CONSTS.ANN_TYPE.BURN)
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
        PEARL.Reputation:EarnFor(inst.userid, REPUTATIONS.DIED)
    end
end

-------------------
-- Killers --
-------------------

local onhealthdelta
onhealthdelta = function(target, data)
    if data.cause == "regen" and target.components.memory and target.components.health then
        PEARL.debug("onhealthdelta - REGEN", data.amount)

        -- The boss was healed to maximal HP
        if target.components.heatlh.currenthealth == target.components.health.maxhealth then
            PEARL.debug("onhealthdelta: Boss was healed to maximal health! Clearing memory!")
            target.components.memory:Clear()
            target:RemoveComponent("memory")
            target:RemoveEventCallback("healthdelta", onhealthdelta)
        end

        target.components.memory:ForEach(function(userid, damage, records)
            records[userid] = damage - data.amount
            if records[userid] <= MIN_DAMAGE_DEALT then
                -- Remove the record if there is no damage delath.
                records[userid] = nil
            end
        end)
    end
end

-- Track damage dealt to bosses.
-- Higher level version of onhitother for players and their followers.
local function onplayerhitother(player, target, damage)
    -- Only for bosses for now.
    if not target or not target.HasTag or not target:HasTag("epic") then
        return
    end

    print("HIT", damage)
    local dmg = math.max(damage or 1, 1)
    local maxhealth = target.components.health.maxhealth

    if type(target.components.memory) ~= "table" then
        target:AddComponent("memory")
    end

    local total_dmg = (tonumber(target.components.memory:Get(player.userid)) or 0) + dmg
    local ttl = math.min(MAX_REMEMBERING_DELAY * total_dmg / maxhealth, MAX_REMEMBERING_DELAY)
    target.components.memory:Add(player.userid, total_dmg)
    target.components.memory:SetLifetime(player.userid, ttl)
    target:SafeListenForEvent("healthdelta", onhealthdelta)

    PEARL.Reputation:EarnFor(
        player.userid, dmg * REPUTATIONS.BOSS_DAMAGE
    )
end

local function onhitother(inst, data)
    local target = data and data.target
    if not (target and target.components.health and target:IsValid()) then
        return
    end

    --- @DEBUG
    if not inst.userid then
        inst.userid = inst.GUID
    end
    --------------------------------------

    local damage = math.max(data.damageresolved or data.damage or 1, 1)

    local leader
    --- @DEBUG
    --local leader = inst.components.follower and inst.components.follower:GetLeader()

    onplayerhitother(leader and leader:HasTag("player") and leader or inst, target, damage)
end

-------------------
-- Builders --
-------------------

local function onbuilditem(doer, data)
    local target = data.item
    if not target then
        return
    end

    PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.CRAFTED_ITEM)

    return AL:QueueEntAct(STRINGS.PEARL.ACTIONS.CRAFT.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.CRAFT)
        :SetIsSilent(true)
        :AddTarget(target)
end

local function onbuildstructure(doer, data)
    local target = data.item
    if not target then
        return
    end

    local action, silent = nil, true
    local type = PEARL.CONSTS.ANN_TYPE.BUILD
    local propagator = target.components.propagator
    -- Make sure we are actively propagating heat.
    if propagator and propagator.spreading and (tonumber(propagator.heatouput) or 0) > 0 then
        type = PEARL.CONSTS.ANN_TYPE.PROPAGATOR

        local near = target:GetPropagableBurnableEntities()
        if near and #near > 0 then
            PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.BURNABLE_NEAR_FIRE * #near)

            silent = not (#near > 2 or table.find(near, structuresearchfn))
            type = PEARL.CONSTS.ANN_TYPE.BURN
            action = AL:QueueEntAct(STRINGS.PEARL.ACTIONS.BUILD.NEAR, doer, "near", PEARL.BuildFancyStringForEntities(near))
        end
    else
        PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.BUILT_STRUCTURE)
    end

    if not action then
        action = AL:QueueEntAct(STRINGS.PEARL.ACTIONS.BUILD.GENERIC, doer)
    end

    action
        :SetLogType(type)
        :SetIsSilent(silent)
        :AddTarget(target)
end

-------------------
-- AFK --
-------------------

local function onafkdisconnected(userid)
    local player = LookupPlayerInstByUserID(userid)
    local client = userid and TheNet:GetClientTableForUser(userid)
    if not (player or client) then
        return
    end

    local userflags = client and client.userflags
    if player and player:HasTag("playerghost") or (userflags and checkbit(userflags, USERFLAGS.IS_GHOST)) then
        PEARL.Reputation:EarnFor(userid, REPUTATIONS.AFK_GHOST_KICKED)
    else
        PEARL.Reputation:EarnFor(userid, REPUTATIONS.AFK_KICKED)
    end

    return PEARL.AnnounceWithType(STRINGS.PEARL.LOGS.USER_INACTIVE_KICKED:format(
        player and player:GetDisplayName() or client.name
    ), PEARL.CONSTS.ANN_TYPE.KICKED_FROM_GAME, player and player.entity or nil)
end

local function onafkstatechanged(userid, is_afk)
    local player = LookupPlayerInstByUserID(userid)
    local client = userid and TheNet:GetClientTableForUser(userid)
    if not (player or client) then
        return
    end

    local userflags = client and client.userflags
    if is_afk == true and player and player:HasTag("playerghost") or (userflags and checkbit(userflags, USERFLAGS.IS_GHOST)) then
        PEARL.Reputation:EarnFor(userid, REPUTATIONS.AFK_GHOST)
    end

    local name = player and player:GetDisplayName() or client.name
    local entity = player and player.entity or nil
    local message = STRINGS.PEARL.LOGS[is_afk and "USER_INACTIVE" or "USER_ACTIVE"]
    local type = PEARL.CONSTS.ANN_TYPE[is_afk and "AFK_START" or "AFK_STOP"]
    return PEARL.AnnounceWithType(message:format(name), type, entity)
end

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
        fnstr = fnstr:ltake(MAX_COMMAND_LENGTH, nil, "...")
    end

    PEARL.DiscordLogger:LogStringRaw(STRINGS.PEARL.LOGS.CONSOLE_CMD:format(
        doer:GetDisplayName(), fnstr
    ), PEARL.ICONS.PLAYER_STATE.CMD_SEND)
end

local function ontookrareitem(doer, item)
    if not (doer and item) then
        return PEARL.warn("Called ontookrareitem with invalid arguments!")
    end

    if item.components.inventoryitem:IsLastPlayerOwner(doer) or item.components.inventoryitem:IsLastPicker(doer) then
        return
    end

    AL:QueueEntAct(STRINGS.PEARL.ACTIONS.TAKE_ITEM.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.TAKE)
        :SetIsSilent(not item.components.inventoryitem:IsVeryRare())
        :AddTarget(item)
end

local function ontookrarecontainer(doer, data)
    if not (doer and data and data.items and data.container) then
        return PEARL.warn("Called ontookrarecontainer with invalid arguments!")
    end

    local items_str = PEARL.BuildFancyStringForEntities(data.items)
    AL:LogAction(doer, PEARL.CONSTS.ANN_TYPE.TAKE, STRINGS.PEARL.ACTIONS.TAKE_ITEM.WITH:nformat{
        doer = doer:GetStandardizedName(), source = data.container:GetStandardizedName(), target = items_str
    })
end

local function onfinishedlooting(doer, data)
    if not (doer and data and data.items and data.container) then
        return PEARL.warn("Called onfinishedlooting with invalid arguments!")
    end

    -- Do not queue this action
    local loot_string = PEARL.BuildFancyStringForEntities(data.items)
    AL:LogAction(doer, PEARL.CONSTS.ANN_TYPE.TAKE, STRINGS.PEARL.ACTIONS.TAKE_ITEM.FROM:nformat({
        doer = doer:GetDisplayName(), target = loot_string, source = data.container:GetFancyName()
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

    player:SafeListenForEvent("onhitother", onplayerhitother)
    player:SafeListenForEvent("heatlhdelta", onhealthdelta)

    if player.components.builder then
        player:SafeListenForEvent("builditem", onbuilditem)
        player:SafeListenForEvent("buildstructure", onbuildstructure)
    end

    if PEARL.DiscordLogger:IsEnabled() then
        player:ListenForModEvent("ms_commandexecuted", oncommandexecuted)
    end
end)

PEARL.AddComponentPostInit("combat", function(self)
    if not self.inst then
        return
    end

    --- Do only track damage dealt by followers and players.
    if not self.inst:HasTag("player") and not self.inst.components.follower then
        return
    end

    self.inst:SafeListenForEvent("onhitother", onhitother)
end)

PEARL.EventProcessor:AddSafeEventHandler("afk_kicked", onafkdisconnected)
PEARL.EventProcessor:AddSafeEventHandler("afk_statechanged", onafkstatechanged)

--- @TODO: Maybe remove some reputation when being kicked?
--PEARL.EventProcessor:AddSafeEventHandler("clientkicked", onplayerkicked)
