--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--[[
Temporary solution for logging.
--]]

local containers = require("containers")

--- @type ActionLog
local AL = PEARL.loadfile("libraries/actionlog")
local QueuedLogAction = PEARL.loadfile("models/queuedlogaction")

------------------------
-- [[ Global Localization ]]
------------------------

local removearrayvalue = table.removearrayvalue

local Rep = PEARL.Reputation

------------------------
-- [[ Constants ]]
------------------------

local MAX_COMMAND_LENGTH = 256

--- @type REPUTATION_TABLES
local REPUTATIONS = PEARL.CONSTS.REPUTATION_TABLES

-- Determines the number of burnable structures needed to activate the extinguisher.
local EXTINGUISHER_STRUCTURES = 3
local EXTINGUISHER_PLANTS = 5
local EXTINGUISHER_BOTH = 5
local EXTINGUISHER_RADIUS = PEARL.CONSTS.EXTINGUISH_RADIUS

local TIME_UNTIL_EXTINGUISH = 4 -- in seconds

local MIN_DAMAGE_DEALT_PERCENT = .1 -- Max 10 players logged
local MAX_REMEMBERING_DELAY = 8 * 60 -- Circa one in-game cycle
local MIN_DAMAGE_DEALT = 10

-- For both food and fuel.
local MAX_WASTE_TOLERANCE = .5

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
--- @param pre boolean? Whether the action should be proccessed before the handler.
--- @return function handler? The handler parameter. Used for chaining.
local function RegisterActionHandler(action, handler, checkfn, pre, postevent)
    if type(action) ~= "table" then
        error("invalid action")
    end

    if type(handler) ~= "function" then
        error("invalid action handler")
    end

    local _action = action.fn
    action.fn = function(act, ...)
        local was_successfull, result
        local doer, target, item, pos = act.doer, act.target, (act.invobject or act.recipe), act:GetActionPoint()
        pos = pos or (target and target:GetPosition())
        if pre == true then
            if type(checkfn) ~= "function" or checkfn(doer, target, item, pos) then
                was_successfull, result = PEARL.SafeRun(handler,
                    doer, target, item, pos
                )
            end
        end

        -- If the original action handler crashes, let the error propagate.
        local action_res = {_action(act, ...)}
        local success = action_res[1] == true
        if postevent ~= nil then
            PEARL.EventProcessor:HandleEvent(postevent, success)
        end

        if success and pre ~= true then
            if type(checkfn) ~= "function" or checkfn(doer, target, item, pos) then
                was_successfull, result = PEARL.SafeRun(handler,
                    doer, target, item, pos
                )
            end
        end

        -- Check for explicit false
        if was_successfull == false then
            PEARL.error("Error while executing an action handler!\n Reason: "..tostring(result), "error")
        end

        return unpack(action_res)
    end

    return handler
end

-- local function RegisterDefaultActionHandler(action, handler)
--     return RegisterActionHandler(action, handler, defaultactioncheck)
-- end

local function RegisterPlayerActionHandler(action, handler, pre)
    return RegisterActionHandler(action, handler, playeractioncheck, pre)
end

local function RegisterPlayerItemActionHandler(action, handler, pre)
    return RegisterActionHandler(action, handler, playeritemactioncheck, pre)
end

------------------------
-- [[ Action Handler ]]
------------------------

--- @TODO: Create some separate "pyromaniac" component for this.
--- Cache the ignited entities somewhere.
local function OnIgniteNear(doer, near, pos)
    if PEARL.CONFIG.PERMISSIVE_MODE == true then
        return
    end

    pos = pos or doer:GetPosition()

    local structures = {}
    local plants = {}
    local other = {}
    for _, entity in ipairs(near) do
        if entity:IsResourcePlant() then
            plants[#plants+1] = entity
        elseif entity:IsBaseStructure() then
            structures[#structures+1] = entity
        else
            other[#other+1] = entity
        end
    end

    local rep_delta = #structures * REPUTATIONS.IGNITED_STRUCTURE
        + #plants * REPUTATIONS.IGNITED_PLANT
        + #other * REPUTATIONS.IGNITED_ENTITY

    --- For now this is enough since griefing is not that big of a problem as it was.
    if doer.Transform and (
        #structures >= EXTINGUISHER_STRUCTURES or
        #plants >= EXTINGUISHER_PLANTS or
        (#structures + #plants) >= EXTINGUISHER_BOTH
    ) then
        PEARL.info("Extinguishing the fires!")

        rep_delta = rep_delta + REPUTATIONS.IGNITING_AT_BASE

        local doername = doer:GetDisplayName()
        -- Extinguish fires near the doer.
        -- Use WallScheduler in case the server gets paused after this.
        PEARL.WallScheduler:ExecuteInTime(TIME_UNTIL_EXTINGUISH, function()
            local count = PEARL.ExtinguishFires(pos.x, pos.y, pos.z, EXTINGUISHER_RADIUS)
            if not count or count == 0 then
                return -- No fires were actually extinguished.
            end

            if type(doername) ~= "string" then
                return TheNet:SystemMessage(STRINGS.PEARL.LOGS.EXTINGUISH:nformat("count", count))
            end

            TheNet:SystemMessage(
                STRINGS.PEARL.LOGS.EXTINGUISH_NEAR:nformat{
                    target = doername, count = count
                }
            )
        end)
    end

    Rep:EarnFor(
        doer.userid, rep_delta, Rep.LIMIT.WORST, "pyromaniac"
    )
end

-- Announce when an object gets set on fire and who set it on fire.
-- Only announces setting items and structures on fire (player creations)
RegisterPlayerActionHandler(ACTIONS.LIGHT, function(doer, target)
    if target:IsFireProtected() then
        return
    end

    local near = target:GetPropagableBurnableEntities()
    local silent = false
    if not ((
        -- The target is a structure or craftable item
        target:HasTag("structure") or type(AllRecipes[target.prefab]) == "table"
    ) or (
        -- Or the target is anything but it's near some plant's or structures
        near and (#near > 4 or table.findall(near, structuresearchfn))
    )) then
        silent = true
    end

    local fire_protected = target:IsFireProtected()
    if fire_protected then
        silent = true
    end

    if near and #near > 0 then
        if not fire_protected then
            OnIgniteNear(doer, near)
        end

        return AL:Log(doer, PEARL.CONSTS.ANN_TYPE.IGNITE, subfmt(STRINGS.PEARL.ACTIONS.IGNITE.NEAR, {
            doer = doer:GetDisplayName(), target = target:GetFancyName(), near = PEARL.BuildFancyStringForEntities(near)
        }), silent)
    end

    AL:EntityAct(STRINGS.PEARL.ACTIONS.IGNITE.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.IGNITE)
        :SetIsSilent(silent)
        :AddTarget(target)
end)

RegisterActionHandler(ACTIONS.PICKUP, function(doer, target, item)
    if not doer:HasTag("player") and not doer:HasTag("companion") and not doer:HasTag("storagerobot") then
        local items
        local veryrare = target.components.inventoryitem and target.components.inventoryitem:IsVeryRare()
        if target.components.container then
            items, veryrare = target.components.container:GetItems()
        elseif target.components.unwrappable then
            for _, itemdata in pairs(target.components.unwrappable.itemdata) do
                if PEARL.GetRarityForPrefab(itemdata.prefab) >= 1 then
                    veryrare = true
                end

                items = items or {}
                items[#items+1] = PEARL.PrefabToName(itemdata.prefab, PEARL.GetStackSize(itemdata))
            end
        end

        if not veryrare then
            return -- Announce only very rare stuff being picked up by a mob to prevent spam.
        end

        local pt = items and STRINGS.PEARL.ACTIONS.TAKE_ITEM.WITH or STRINGS.PEARL.ACTIONS.TAKE_ITEM.GENERIC
        AL:EntityAct(pt, doer, "source", target)
            :SetLogType(PEARL.CONSTS.ANN_TYPE.TAKE)
            :SetIsSilent(not veryrare)
            :AddTargets(items or target)
    end
end)

-- Track also mobs eating rare stuff.
RegisterActionHandler(ACTIONS.EAT, function(doer, target, item)
    local food = item or target
    local pt = doer and STRINGS.PEARL.ACTIONS.EAT.DOER or STRINGS.PEARL.ACTIONS.EAT.GENERIC
    local rarity = PEARL.GetRarityForPrefab(food.prefab)
    local rare = rarity > 0
    if not rare and (not doer or not doer:HasTag("player")) then
        return
    end

    local silent = not rare
    local atyp = PEARL.CONSTS.ANN_TYPE[silent and "EAT" or "SWALLOW"]

    -- Safe some data before the actual eating and compare them afterwards.
    local pre_hunger, pre_health, pre_sanity
    if doer then
        local eater = doer.components.eater
        pre_hunger = doer.components.hunger and doer.components.hunger.current * eater.hungerabsorption
        pre_sanity = doer.components.sanity and doer.components.sanity.current * eater.sanityabsorption
        pre_health = doer.components.health and doer.components.health.currenthealth * eater.healthabsorption
    end

    -- This event is guarateed to be ALWAYS pushed after the action is executed.
    PEARL.EventProcessor:AddSafeOneTimeHandler("ACTIONS.EAT", function(success)
        if not success then
            return -- Action failed, no food has been actual eaten.
        end

        -- Calculate wasted value only for players. Mobs are allowed to waste food.
        local edible = food.components.edible
        local max = edible and (
            (edible.healthvalue or 0)+(edible.hungervalue or 0)+(edible.sanityvalue or 0)
        ) or 0
        if edible and doer:HasTag("player") and pre_hunger and pre_sanity and pre_health and max > 0 then
            local hunger_delta = doer.components.hunger.current - pre_hunger
            local sanity_delta = doer.components.sanity.current - pre_sanity
            local health_delta = doer.components.health.currenthealth - pre_health
            local actual = hunger_delta + sanity_delta + health_delta
            local waste = 1 - actual / max -- Max is always > 0
            if rarity >= 1 then
                waste = waste + 1
            end

            if waste > MAX_WASTE_TOLERANCE then
                atyp = PEARL.CONSTS.ANN_TYPE.SWALLOW
                pt = STRINGS.PEARL.ACTIONS.EAT.FULL
                Rep:EarnFor(doer.userid, REPUTATIONS.WASTE_FOOD * waste, Rep.LIMIT.VERY_BAD)
            end
        end

        if doer.userid and rarity > 0 then
            Rep:EarnFor(doer.userid, REPUTATIONS.EAT_RARE * rarity, Rep.LIMIT.VERY_BAD)

            if rarity >= 1 then
                Rep:EarnFor(doer.userid, REPUTATIONS.EAT_VERY_RARE, Rep.LIMIT.WORST, "big_eater")
            end
        end

        AL:EntityAct(pt, doer)
            :SetLogType(atyp)
            :SetIsSilent(silent)
            :AddTarget(food, 1)
    end)
end, nil, true, "ACTIONS.EAT")

RegisterPlayerActionHandler(ACTIONS.HEAL, function(doer, target, item)
    if target and target:HasTag("player") and target.components.health and target.components.health:IsHurt() then
        Rep:EarnFor(doer.userid, REPUTATIONS.PLAYER_HEALED)
    end

    local pt = STRINGS.PEARL.ACTIONS.HEAL[target and "TARGET" or "USING"]
    AL:EntityAct(pt, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.HEAL)
        :SetIsSilent(true)
        :AddToStackableField(QueuedLogAction.FIELDS.TOOL, item, 1)
        :AddTarget(target, 1)
end)

RegisterPlayerActionHandler(ACTIONS.SEW, function(doer, target, item)
    local pt = STRINGS.PEARL.ACTIONS.SEW[item and "USING" or "GENERIC"]
    AL:EntityAct(pt, doer, "tool", item)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.SEW)
        :SetIsSilent(true)
        :AddTarget(target, 1)
end)

RegisterPlayerActionHandler(ACTIONS.NET, function(doer, target, item)
    local pt = STRINGS.PEARL.ACTIONS.CATCH[item and "DOER_WITH" or "DOER"]
    AL:EntityAct(pt, doer, "tool", item)
        :SetIcon(PEARL.ICONS.ANNOUNCEMENTS["catch"])
        :SetIsSilent(true)
        :AddTarget(target, 1)
end)

RegisterPlayerActionHandler(ACTIONS.TEACH, function(doer, target, item)
    local src  = item or target
    local rare = src.is_rare == true
    if doer.components.age and not doer.components.age:IsTrustworthy() then
        local reputation = rare and REPUTATIONS.LEARNED_RAREPRINT or REPUTATIONS.LEARNED_BLUEPRINT
        Rep:EarnFor(doer.userid, reputation, Rep.LIMIT.VERY_BAD)
    end

    AL:EntityAct(STRINGS.PEARL.ACTIONS.TEACH.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.TEACH)
        :SetIsSilent(not rare)
        -- We need the exact name here.
        :AddTarget(src:GetDisplayName())
end)

RegisterPlayerActionHandler(ACTIONS.HAMMER, function(doer, target)
    local workable = target.components and target.components.workable or nil
    if workable and workable.workleft and workable.workleft <= 0 then
        local silent = false
        local mult = 1
        -- Only announce hammering when the structure was built by a player
        -- This makes sure we only log when a base structure get's hammered.
        if not target.components.built or target.components.built:By(doer.userid) then
            silent = true
            mult = .6
        end

        -- Ignore burned structures
        if target:HasTag("burnt") or target:HasTag("wall") or not target:HasTag("structure") then
            silent = true
        else
            Rep:EarnFor(doer.userid, REPUTATIONS.HAMMER_STRUCTURE * mult, Rep.LIMIT.WORST, "destroyer")
        end

        local action
        if target.components.built then
            action = AL:EntityAct(STRINGS.PEARL.ACTIONS.HAMMER.OWNED, doer,
            QueuedLogAction.FIELDS.OWNER, target.components.built.doer:GetName())
        else
            action = AL:EntityAct(STRINGS.PEARL.ACTIONS.HAMMER.GENERIC, doer)
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
        Rep:EarnFor(doer.userid, REPUTATIONS.READ_OFFENSIVE_BOOK, Rep.LIMIT.VERY_BAD)
    end

    AL:EntityAct(STRINGS.PEARL.ACTIONS.READ.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.READ)
        :SetIsSilent(not prohibited)
        :AddTarget(item, 1)
end)

if ACTIONS.WAX then
    RegisterPlayerActionHandler(ACTIONS.WAX, function(doer, target, item)
        local pt = item and STRINGS.PEARL.ACTIONS.WAX.WITH or STRINGS.PEARL.ACTIONS.WAX.GENERIC
        AL:EntityAct(pt, doer, "tool", item)
            :SetIcon(PEARL.ICONS.BEEWAX)
            :SetIsSilent(true)
            :AddTarget(target)
    end)
end

--- @TODO: Add reputation for this?
RegisterPlayerActionHandler(ACTIONS.UPGRADE, function(doer, target, item)
    local pt = item and STRINGS.PEARL.ACTIONS.UPGRADE.WITH or STRINGS.PEARL.ACTIONS.UPGRADE.GENERIC
    AL:EntityAct(pt, doer, "tool", item)
        :SetIcon(PEARL.EMOJIS.GAME_TO_DISCORD.SALT)
        :SetIsSilent(true)
        :AddTarget(target)
end)

RegisterPlayerActionHandler(ACTIONS.ACTIVATE, function(doer, target, item)
    local thing = target or item
    local activatable = thing and thing.components.activatable
    if activatable and PEARL.PREFABS.ACTIVATABLE[target.prefab] and not target.components.activatable:IsLastPlayerActivator(doer) then
        target.components.activatable:SetLastPlayerActivator(doer)

        -- No point in queuing this action since it's so specific.
        AL:Log(doer, PEARL.CONSTS.ANN_TYPE.ACTIVATE, STRINGS.PEARL.ACTIONS.ACTIVATE:format(
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

    --- @TODO: Maybe execute cooking in a crockpot immediately?
    local prohibited, execute = false, false
    local rarity = PEARL.GetRarityForPrefab(item and item.prefab)
    if rarity > 0 then
        prohibited = true

        Rep:EarnFor(doer.userid, REPUTATIONS.COOKED_RARE * rarity)
    end

    local pattern = STRINGS.PEARL.ACTIONS.COOK.GENERIC
    local stewer = tool and tool.components.stewer
    if tool then
        pattern = STRINGS.PEARL.ACTIONS.COOK.ON

        if tool.components.stewer then
            pattern = STRINGS.PEARL.ACTIONS.COOK.IN
        end
    end

    local action = AL:EntityAct(pattern, doer, "tool", tool)
    if stewer and stewer.ingredient_prefabs and not table.empty(stewer.ingredient_prefabs) then
        for _, prefab in ipairs(stewer.ingredient_prefabs) do
            action:AddTarget(PEARL.PrefabToName(prefab), 1)

            rarity = PEARL.GetRarityForPrefab(prefab)
            if rarity > 0 then
                Rep:EarnFor(doer.userid, REPUTATIONS.COOKED_RARE_INGRED * rarity)

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
    if target.components.burnable and (not target.components.burnable.doer or target.components.burnable.doer:GetUserID() ~= doer.userid) then
        if target:HasTag("structure") then
            Rep:EarnFor(doer.userid, REPUTATIONS.EXTINGUISH_STRUCT)
        else
            Rep:EarnFor(doer.userid, REPUTATIONS.EXTINGUISH)
        end
    end

    return AL:EntityAct(STRINGS.PEARL.ACTIONS.EXTINGUISH[item and "WITH" or "GENERIC"], doer,
        QueuedLogAction.FIELDS.TOOL, item)
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

    Rep:EarnFor(doer.userid, REPUTATIONS.CHOPPED_PROHIBITED)

    -- Too spammy, announce only if prohibited.
    AL:EntityAct(STRINGS.PEARL.ACTIONS.CHOP.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.CHOP)
        :SetIsSilent(not prohibited)
        :AddTarget(target)
end)

RegisterPlayerActionHandler(ACTIONS.ADDFUEL, function(doer, target, item)
    local added = item.components.fuel.fuelvalue
    local reserve = math.max(target.components.fueled.maxfuel - target.components.fueled.currentfuel, 0)
    local waste = math.max(added - reserve, 0) / added

    if item.components.inventoryitem:IsRare() or item.components.teacher then
        waste = 1

        -- For very rare items (rare blueprints, etc...)
        if item.is_rare then
            waste = 2
        end
    end

    local type = PEARL.CONSTS.ANN_TYPE.PROPAGATOR
    local str = STRINGS.PEARL.ACTIONS.ADDFUEL.GENERIC
    if waste > MAX_WASTE_TOLERANCE then
        str = STRINGS.PEARL.ACTIONS.ADDFUEL.WASTE
        type = PEARL.CONSTS.ANN_TYPE.WASTE

        Rep:EarnFor(doer.userid, REPUTATIONS.FUEL_WASTED * waste)
    elseif target.components.wateryprotection then
        Rep:EarnFor(doer.userid, REPUTATIONS.FUEL_TO_PROTECTOR * (1 - waste))
    end

    AL:EntityAct(str, doer, "source", target)
        :SetLogType(type)
        :SetIsSilent(true)
        :AddTarget(item, 1)
end, true) -- We have to do the calculations before the action actually happens.

RegisterPlayerActionHandler(ACTIONS.DIG, function(doer, target)
    if PEARL.PREFABS.DO_DIGUP[target.prefab] == true then
        Rep:EarnFor(doer.userid, REPUTATIONS.DUG_UP_GOODS)
    end

    if PEARL.PREFABS.DO_NOT_DIGUP_FOREST[target.prefab] == true and TheWorld:HasTag("forest") then
        Rep:EarnFor(doer.userid, REPUTATIONS.DUG_UP_BAD)
    end

    AL:EntityAct(STRINGS.PEARL.ACTIONS.DIG.GENERIC, doer)
        :SetIcon(PEARL.EMOJIS.GAME_TO_DISCORD.SHOVEL)
        :SetIsSilent(true)
        :AddTarget(target)
end)

-- This is for planting in a farm plot or something like that.
local OnPlant = RegisterPlayerActionHandler(ACTIONS.PLANT, function(doer, target, item)
    Rep:EarnFor(doer.userid, REPUTATIONS.PLANT)

    AL:EntityAct(STRINGS.PEARL.ACTIONS.PLANT[target and "IN" or "GENERIC"], doer,
        QueuedLogAction.FIELDS.SOURCE, target)
        :SetIcon(PEARL.EMOJIS.GAME_TO_DISCORD.FARM)
        :SetIsSilent(true)
        :AddTarget(item, 1)
end)

RegisterPlayerActionHandler(ACTIONS.PLANTWEED,
RegisterPlayerActionHandler(ACTIONS.PLANTSOIL,
RegisterPlayerActionHandler(ACTIONS.DEPLOY, function(doer, target, item)
    local icon = PEARL.EMOJIS.GAME_TO_DISCORD.EYEPLANT
    if item:HasTag("deployedplant") or item:HasTag("plant") then
        icon = PEARL.EMOJIS.GAME_TO_DISCORD.BERRY
        if item:HasTag("witherable") then
            Rep:EarnFor(doer.userid, REPUTATIONS.PLANT_WITHERABLE)
        else
            Rep:EarnFor(doer.userid, REPUTATIONS.PLANT)
        end
    end

    if target ~= nil then
        icon = PEARL.EMOJIS.GAME_TO_DISCORD.FARM
    end

    AL:EntityAct(STRINGS.PEARL.ACTIONS.PLANT.GENERIC, doer)
        :SetIcon(icon)
        :AddTarget(item, 1)
end)))

RegisterPlayerActionHandler(ACTIONS.DEPLOY_TILEARRIVE,
RegisterPlayerActionHandler(ACTIONS.FERTILIZE, function(doer, target, item)
    local icon = PEARL.EMOJIS.GAME_TO_DISCORD.RMB
    local pt = STRINGS.PEARL.ACTIONS.USED[target and "ON" or "GENERIC"]
    if not item or item.components.fertilizer then
        Rep:EarnFor(doer.userid, REPUTATIONS.FERTILIZED)

        icon = PEARL.EMOJIS.GAME_TO_DISCORD.POOP
        pt = STRINGS.PEARL.ACTIONS.FERTILIZE.FIELD
        if target then
            pt = STRINGS.PEARL.ACTIONS.FERTILIZE.WITH
        elseif item  then
            pt = STRINGS.PEARL.ACTIONS.FERTILIZE.FIELD_WITH
        end
    end

    AL:EntityAct(pt, doer, "item", item)
        :SetIcon(icon)
        :AddTarget(target or STRINGS.NAMES.FARM_SOIL_DEBRIS)
end))

RegisterPlayerActionHandler(ACTIONS.SLEEPIN, function(doer, target, item)
    AL:EntityAct(STRINGS.PEARL.ACTIONS.SLEEP.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.SLEEP)
        :AddTarget(target or item)
end)

RegisterPlayerActionHandler(ACTIONS.DRY, function(doer, target, item)
    AL:EntityAct(STRINGS.PEARL.ACTIONS.DRIED.GENERIC, doer,
        QueuedLogAction.FIELDS.TARGET, target)
        :SetIcon(PEARL.EMOJIS.GAME_TO_DISCORD.MEAT)
        :AddToStackableField(QueuedLogAction.FIELDS.ITEM, item, 1)
end)

RegisterPlayerItemActionHandler(ACTIONS.GIVEALLTOPLAYER,
RegisterPlayerItemActionHandler(ACTIONS.GIVETOPLAYER,
RegisterPlayerItemActionHandler(ACTIONS.GIVE, function(doer, target, item)
    if target.components.grower or target.components.harvestable then
        return OnPlant(doer, target, item)
    end

    local prohibited = PEARL.GetRarityForPrefab(item.prefab) >= 1

    return AL:EntityAct(STRINGS.PEARL.ACTIONS.GIVE.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.GIVE)
        :AddToStackableField(QueuedLogAction.FIELDS.TOOL, item, 1)
        :SetIsSilent(not prohibited)
        :AddTarget(target, 1)
end)))

RegisterPlayerActionHandler(ACTIONS.PLAY, function(doer, target, item)
    AL:EntityAct(STRINGS.PEARL.ACTIONS.PLAY.GENERIC, doer,
        QueuedLogAction.FIELDS.TARGET, PEARL.GetStandardizedNameFor((target or item), true))
        :SetLogType(PEARL.CONSTS.ANN_TYPE.PLAY)
end)

RegisterPlayerActionHandler(ACTIONS.MINE, function(doer, target)
    local prohibited = PEARL.PREFABS.DO_NOT_MINE[target and target.prefab]
    if prohibited ~= true then
        return -- Too spammy, announce only if prohibited.
    end

    local workable = target.components and target.components.workable or nil
    if not workable or (workable.workleft and workable.workleft <= 0) then
        AL:EntityAct(STRINGS.PEARL.ACTIONS.MINE.GENERIC, doer)
            :SetLogType(PEARL.CONSTS.ANN_TYPE.MINE)
            :AddTarget(target, 1)
    end
end)

-- Using a cast affecting entities around in a certain radius.
local function OnAreaCast(doer, item, target, entities, tp, nosilent)
    if not entities or #entities <= 0 then
        return
    end

    local pt = (target and STRINGS.PEARL.ACTIONS.CAST.ON_NEAR or STRINGS.PEARL.ACTIONS.CAST.NEAR):nformat({
        doer = doer:GetStandardizedName(),
        item = item and item:GetStandardizedName(),
        target = target and target:GetStandardizedName(),
        near = PEARL.BuildFancyStringForEntities(entities),
    })

    return AL:Log(
        doer, tp, pt, nosilent ~= true and (not tp or #entities < 3), PEARL.EMOJIS.GAME_TO_DISCORD.ARCANE)
end

-- Regular casting with or without a target.
local function OnCast(doer, item, target, tp)
    local owner = target and target.components.built and target.components.built.doer
    local has_owner = owner ~= nil
    local prohibited = target and target:HasTag("structure")
    local pt = STRINGS.PEARL.ACTIONS.CAST.GENERIC
    if target then
         pt = has_owner and STRINGS.PEARL.ACTIONS.CAST.ON_OWNERED or STRINGS.PEARL.ACTIONS.CAST.ON
    end

    AL:EntityAct(pt, doer,
        {item = item and item:GetStandardizedName(), owner = owner and owner:GetName()})
        :AddTarget(target)
        :SetIsSilent(not tp or not prohibited)
        :SetIcon(PEARL.EMOJIS.GAME_TO_DISCORD.ARCANE)
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
        OnIgniteNear(doer, entities, pos)

        return OnAreaCast(
            doer, item, target, entities,
            PEARL.CONSTS.ANN_TYPE.BURN
        )
    end

    OnCast(doer, item, target, PEARL.CONSTS.ANN_TYPE.BURN)
end

local function OnCastAreaDestruction(doer, item, target, pos, radius)
    local entities = PEARL.GetEntitiesNearPos(pos, radius,
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

    return OnCast(doer, item, target, PEARL.CONSTS.ANN_TYPE.HAMMER)
end

RegisterPlayerActionHandler(ACTIONS.CASTAOE,
RegisterPlayerActionHandler(ACTIONS.CASTSPELL, function(doer, target, item, pos)
    if not item or item:HasTag("veryquickcast") then -- Ignore stuff like resking tool...
        return
    end

    local prefab = item.components.spellbook and item.components.spellbook:GetSpellName() or item.prefab
    -- Green Staff
    if PEARL.PREFABS.DESTRUCTION_ITEMS[prefab] then
        return OnCast(doer, item, target, PEARL.CONSTS.ANN_TYPE.HAMMER)
    end

    local ign_radius = PEARL.PREFABS.AREA_IGNITE_STAFFS[prefab] or 0
    if ign_radius > 0 then
        return OnCastFire(doer, item, target, pos, ign_radius)
    end

    -- Tornado Staff
    local des_radius = PEARL.PREFABS.AREA_DESTRUCTIVE_STAFFS[prefab] or 0
    if des_radius > 0 then
        return OnCastAreaDestruction(doer, item, target, pos, des_radius)
    end

    return OnCast(doer, item, target)
end))

RegisterPlayerActionHandler(ACTIONS.ATTACK, function(doer, target, item, pos)
    if not item then
        return
    end

    -- Fire Staff - Using it counts as attacking not casting.
    local ign_radius = PEARL.PREFABS.AREA_IGNITE_STAFFS[item.prefab] or 0
    if ign_radius > 0 then
        return OnCastFire(doer, item, target, pos, ign_radius)
    end
end)

-------------------
-- KILLS --
-------------------

local function onepicdeath(doer, target, data)
    local pt = STRINGS.PEARL.ACTIONS.KILL.BOSS

    -- Only bosses have memory because of their large HP capacity.
    if target.components.memory then
        local doers = {}
        local total_hp = math.max(tonumber(target.components.health.maxhealth) or 1, 1)
        -- Iterate over the ids sorted by damage dealt
        for _, id in ipairs(target.components.memory:SortedKeys()) do
            local damage = target.components.memory:Get(id)
            if damage <= 0 or (damage / total_hp) < MIN_DAMAGE_DEALT_PERCENT then
                break -- we are sorted, so the next one can be even worse.
            end

            local attacker = LookupPlayerInstByUserID(id) or Ents[id]
            if attacker then
                doers[#doers + 1] = PEARL.GetStandardizedNameFor(attacker, true)
            end
        end

        if #doers > 1 then
            pt = STRINGS.PEARL.ACTIONS.KILL.BOSS_DOERS
        end

        target.components.memory:Clear()
        target:RemoveComponent("memory")
        pt = pt:nformat(QueuedLogAction.FIELDS.DOER, PEARL.FancyTableConcat(doers))
    else
        local doername = doer and doer:GetStandardizedName() or nil
        local cause = doername or (data and (data.explosion == true and "Explosion" or data.cause))
        pt = pt:nformat(QueuedLogAction.FIELDS.DOER, cause or "Shenanigans")
    end

    return AL:EntityAct(pt, doer, "target", target)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.DEFEAT)
        :SetIsSilent(false)
end

local function onfirespreaderdeath(doer, target)
    local near = target:GetPropagableBurnableEntities(
        nil, nil, PEARL.CONSTS.LARGE_PROPAGATOR_RADIUS
    )

    if doer.userid then
        Rep:EarnFor(doer.userid, #near * REPUTATIONS.BURNABLE_NEAR_FIRE)
    end

    local pt = doer and STRINGS.PEARL.ACTIONS.KILL.GENERIC or STRINGS.PEARL.ACTIONS.KILL.NODOER
    if table.empty(near) == false then
        pt = doer and STRINGS.PEARL.ACTIONS.KILL.NEAR or STRINGS.PEARL.ACTIONS.KILL.NODOERNEAR
    end

    local prohibited = #near >= 4 or table.findall(near, structuresearchfn)
    AL:EntityAct(pt, doer,
    {target = target, near = PEARL.BuildFancyStringForEntities(near)})
        :SetIsSilent(not prohibited)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.BURN)
end

local function onmonitoreddeath(doer, target, threshold)
    local remaining = PEARL.CountPrefabs(target.prefab)
    local extinct = remaining <= 0
    if doer.userid and extinct  then
        Rep:EarnFor(doer.userid, REPUTATIONS.POPULATION_EXTINCT)
    end

    local str = extinct and STRINGS.PEARL.ACTIONS.KILL.LAST or STRINGS.PEARL.ACTIONS.KILL.REMAINING
    local action = AL:EntityAct(str, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.EXTINCT)
        :SetColorEntity(doer and doer.entity)
        :SetIsSilent(remaining > threshold)
        :AddTarget(target)
        :SetStackableField(QueuedLogAction.FIELDS.REMAINING, remaining)

    -- Make sure the extinct announcement will be after this one.
    if remaining <= 1 then
        AL:LogAction(action)
    end
end

-- This is for announcing the last hit made by an player/mob to another mob.
-- Try to increase/decrease the reputation
-- for each damage point dealt where possible.
local function onentitydeath(doer, target, data)
    if not target then
        return -- Give us at least a target.
    end

    -- For bosses with multiple lifes announce all deaths.
    if target:HasTag("epic") then
        return onepicdeath(doer, target, data)
    end

    -- MOB SPREADING FIRE AFTER DEATH
    if PEARL.PREFABS.MOBS.FIRE_SPREADERS[target.prefab] and not target:IsFireProtected() then
        return onfirespreaderdeath(doer, target)
    end

    -- NOT RESPAWNABLE MOB
    local pop_threshold = PEARL.PREFABS.MOBS.MONITOR_POPULATION[target.prefab]
    if pop_threshold and pop_threshold > 0 then
        return onmonitoreddeath(doer, target, pop_threshold)
    end

    if not doer then
        return
    end

    local leader = target.components.follower and target.components.follower:GetLeader() or nil
    -- Process untamed followers first since they can have an leader as well.
    if PEARL.PREFABS.MOBS.COMPANIONS[target.prefab] == true then
        return AL:EntityAct(STRINGS.PEARL.ACTIONS.KILL.GENERIC, doer)
            :SetLogType(PEARL.CONSTS.ANN_TYPE.MURDER)
            :SetIsSilent(false)
            :SetColorEntity(doer)
            :AddTarget(target)
    -- FOLLOWER
    elseif leader and leader:HasTag("player") then
        return AL:EntityAct(STRINGS.PEARL.ACTIONS.KILL.FOLLOWER, doer,
            QueuedLogAction.FIELDS.OWNER, leader)
            :SetLogType(PEARL.CONSTS.ANN_TYPE.KILL)
            :SetIsSilent(false)
            :SetColorEntity(doer)
            :AddTarget(target)
    end

    if not doer:HasTag("player") then
        return
    end

    local pt = STRINGS.PEARL.ACTIONS.KILL.GENERIC
    if target and target:HasTag("structure") or target:HasTag("hive") then
        pt = STRINGS.PEARL.ACTIONS.KILL.STRUCTURE
    end

    AL:EntityAct(pt, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.KILL)
        :SetColorEntity(doer)
        :AddTarget(target)
end

RegisterPlayerActionHandler(ACTIONS.MURDER, function(doer, target, item)
    onentitydeath(doer, target or item)
end)

PEARL.AddPrefabPostInit("world", function(world)
    -- Pushed for every living entity (players too) that dies in the current shard.
    world:SafeListenForEvent("entity_death", function(self, data)
        if not data then
            return
        end

        onentitydeath(data.afflicter, data.inst, data)
    end)
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

    local cmps = target.components
    if not (cmps.built or (cmps.pickable and cmps.pickable.transplanted)) then
        return
    end

    -- We will not need this callback anymore.
    target:RemoveEventCallback("burntup", onburntup)

    local pattern = STRINGS.PEARL.ACTIONS.BURNTUP.GENERIC
    local builder = target.components.built and target.components.built.doer
    if builder then
        pattern = STRINGS.PEARL.ACTIONS.BURNTUP.OWNED:nformat(
            QueuedLogAction.FIELDS.OWNER, builder:GetName()
        )
    end

    AL:Act(pattern)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.BURN)
        -- Only announce when a player creation burns up.
        :SetIsSilent(builder == nil)
        :AddTarget(target, nil, true)
end

--- This is only available after the March beta of 2024
if containers.params and containers.params.dragonflyfurnace and containers.params.dragonflychest.widget then
    PEARL.AddFunctionPreCall("fn", function(inst, doer)
        if inst and inst.components.container then
            local items, veryrare = {}, false
            inst.components.container:ForEachItem(function(item)
                items[#items+1] = item
                if item.components.inventoryitem:IsVeryRare() then
                    veryrare = true
                end
            end)

            return AL:EntityAct(STRINGS.PEARL.ACTIONS.DESTROY.IN, doer, "source", inst)
                :SetIcon(PEARL.ICONS.TRASHCAN)
                :SetIsSilent(not veryrare)
                :AddTargets(items)
        end
    end, containers.params.dragonflyfurnace.widget.buttoninfo)
end

--- @param inst EntityScript
PEARL.AddComponentPostInit("burnable", function(self, inst)
    inst:SafeListenForEvent("onburnt", onburntup)
end)

-------------------
-- PLAYER STATES --
-------------------
--- These are already announced by the game.
local function onrespawnfromghost(inst, data)
    if data and data.user and data.user.userid then
        Rep:EarnFor(data.user.userid, REPUTATIONS.REVIVE)
    end
end

local function ondeath(inst)
    if inst and inst.userid then
        Rep:EarnFor(inst.userid, REPUTATIONS.DIED)
    end
end

-------------------
-- Killers --
-------------------

local function onplayerhitepic(doer, target, dmg, mult)
    local maxhealth = target.components.health.maxhealth

    if type(target.components.memory) ~= "table" then
        target:AddComponent("memory")
    end

    -- The more damage we deal to the mob, the longer will it remember us.
    local total_dmg = (tonumber(target.components.memory:Get(doer.userid) or nil) or 0) + dmg
    local ttl = math.min(MAX_REMEMBERING_DELAY * total_dmg / maxhealth, MAX_REMEMBERING_DELAY)
    target.components.memory:Set(doer.userid, total_dmg)
    target.components.memory:SetLifetime(doer.userid, ttl)

    Rep:EarnFor(
        doer.userid, dmg * mult * REPUTATIONS.BOSS_DAMAGE
    )
end

-- Track damage dealt to bosses.
-- Higher level version of onhitother for players and their followers.
local function onplayerhitother(player, target, damage, follower)
    if not damage or not target.components.health then
        return
    end

    local dmg = math.max(damage or 1, 1)
    local hpercent = target.components.health:GetPercent()
    -- The less HP the boss has the more damage we get.
    -- Reputation is halved for followers and is constant.
    local mult = follower ~= nil and .5 or (1 - hpercent + 1)

    if target:HasTag("epic") then
        -- Special handler for bosses.
        return onplayerhitepic(player, target, dmg, mult)
    end

    if PEARL.PREFABS.MOBS.COMPANIONS[target.prefab] == true then
        Rep:EarnFor(player.userid, mult * dmg * REPUTATIONS.COMPANION_DAMAGE)
        return
    end

    local leader = target.components.follower and target.components.follower:GetLeader()
    if leader ~= nil and leader.userid ~= player.userid then
        Rep:EarnFor(player.userid, mult * dmg * REPUTATIONS.FOLLOWER_DAMAGE)
        return
    end
end

local function onhitother(doer, data)
    local target = data and data.target
    if not (target and target.components.health and target:IsValid()) then
        return
    end

    local leader
    -- Non-players are required to have a player leader in order for us to not ignore them.
    if not doer:HasTag("player") then
        leader = doer.components.follower and doer.components.follower:GetLeader() or nil
        leader = leader or (doer.brain and doer.brain._leader)
        if leader == nil or not leader.userid then
            return
        end
    end

    local player = leader or doer
    local damage = math.max(data.damageresolved or data.damage or 1, 1)
    onplayerhitother(player, target, damage, leader and doer or nil)
end

-------------------
-- Builders --
-------------------

local function onbuilditem(doer, data)
    local target = data.item
    if not target then
        return
    end

    Rep:EarnFor(doer.userid, REPUTATIONS.CRAFTED_ITEM, nil, data.item.prefab)

    return AL:EntityAct(STRINGS.PEARL.ACTIONS.CRAFT.GENERIC, doer)
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
    if propagator and propagator.spreading then
        type = PEARL.CONSTS.ANN_TYPE.PROPAGATOR

        local near = target:GetPropagableBurnableEntities()
        if near and #near > 0 then
            Rep:EarnFor(doer.userid, REPUTATIONS.BURNABLE_NEAR_FIRE * #near)

            silent = not (#near > 2 or table.findall(near, structuresearchfn))
            type = PEARL.CONSTS.ANN_TYPE.BURN
            action = AL:EntityAct(STRINGS.PEARL.ACTIONS.BUILD.NEAR, doer, "near", PEARL.BuildFancyStringForEntities(near))
        end
    else
        Rep:EarnFor(doer.userid, REPUTATIONS.BUILT_STRUCTURE, nil, target.prefab)
    end

    if not action then
        action = AL:EntityAct(STRINGS.PEARL.ACTIONS.BUILD.GENERIC, doer)
    end

    action
        :SetLogType(type)
        :SetIsSilent(silent)
        :AddTarget(target)
end

local function onplayerconstructed(doer, target)
    local pt = STRINGS.PEARL.ACTIONS.CONSTRUCT.GENERIC
    if target:HasTag("structure") or target:HasTag("multiplayer_portal") then
        Rep:EarnFor(doer.userid, REPUTATIONS.CONSTRUCTED, nil, target.prefab)
    else
        pt = STRINGS.PEARL.ACTIONS.CONSTRUCT.QUEST
        Rep:EarnFor(doer.userid, REPUTATIONS.QUEST_COMPLETED, nil, target.prefab)
    end

    AL:EntityAct(pt, doer, QueuedLogAction.FIELDS.TARGET, target)
        :SetIcon(PEARL.EMOJIS.GAME_TO_DISCORD.REFINE)
end

-------------------
-- Warnings --
-------------------

local wave_level
local function onhoundwarning(player, level)
    if wave_level == level then
        return
    end

    local wave_type
    if level == HOUNDWARNINGTYPE.LVL4 then
        wave_type = STRINGS.PEARL.LOGS.HOUNDS
    elseif level == HOUNDWARNINGTYPE.LVL4_WORM then
        wave_type = STRINGS.PEARL.LOGS.DEPTH_WORMS
    end

    if wave_type ~= nil then
        AL:Log(nil, nil, STRINGS.PEARL.LOGS.WAVE_WARNING:format(
            wave_type
        ), true, PEARL.EMOJIS.GAME_TO_DISCORD.HORN)
    end

    wave_level = level
end

-------------------
-- AFK --
-------------------

local function onafkstatechanged(userid, is_afk)
    local player = LookupPlayerInstByUserID(userid)
    if not player then
        return
    end

    local name = PEARL.GetStandardizedNameFor(player)
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
local last_command -- To prevent spam.
local function oncommandexecuted(doer, fnstr)
    -- It's totally normal when the command is just an empty string.
    -- This happens for example when you just open and then close the console.
    if not doer or not (type(fnstr) == "string" and #fnstr > 0) or last_command == fnstr then
        return
    end

    -- Ignore commands from the server owner.
    if TheNet:GetUserID() == doer.userid then
        return
    end

    last_command = fnstr

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

    local veryrare = item.components.inventoryitem:IsVeryRare()
    if not veryrare or (item.components.inventoryitem:IsLastPlayerOwner(doer) or item.components.inventoryitem:IsLastPicker(doer)) then
        return
    end

    AL:EntityAct(STRINGS.PEARL.ACTIONS.TAKE_ITEM.GENERIC, doer)
        :SetLogType(PEARL.CONSTS.ANN_TYPE.TAKE)
        :SetIsSilent(not veryrare)
        :AddTarget(item)
end

local function ontookrarecontainer(doer, data)
    if not (doer and data and data.items and data.container) then
        return PEARL.warn("Called ontookrarecontainer with invalid arguments!")
    end

    local items_str = PEARL.BuildFancyStringForEntities(data.items)
    AL:Log(doer, PEARL.CONSTS.ANN_TYPE.TAKE, STRINGS.PEARL.ACTIONS.TAKE_ITEM.WITH:nformat{
        doer = doer:GetStandardizedName(), source = data.container:GetStandardizedName(), target = items_str
    })
end

local function onfinishedlooting(doer, data)
    if not (doer and data and data.items and data.container) then
        return PEARL.warn("Called onfinishedlooting with invalid arguments!")
    end

    -- Do not queue this action
    local loot_string = PEARL.BuildFancyStringForEntities(data.items)
    AL:Log(doer, PEARL.CONSTS.ANN_TYPE.TAKE, STRINGS.PEARL.ACTIONS.TAKE_ITEM.FROM:nformat({
        doer = doer:GetDisplayName(), target = loot_string, source = data.container:GetFancyName()
    }), false, PEARL.EMOJIS.GAME_TO_DISCORD.CHEST) --data.items.rare)
end

-------------------------------
-- [[ Listeners ]]
-------------------------------

--- @param player EntityScript
PEARL.AddPlayerPostInit(function(player)
    if not player.components.playerthief then
        player:AddComponent("playerthief")
    end

    --- Thief component events
    player:ListenForModEvent("tookrareitem", ontookrareitem)
    player:ListenForModEvent("tookrarecontainer", ontookrarecontainer)
    player:ListenForModEvent("finishedlooting", onfinishedlooting)

    player:SafeListenForEvent("respawnfromghost", onrespawnfromghost)
    player:SafeListenForEvent("death", ondeath)

    player:SafeListenForEvent("houndwarning", onhoundwarning)

    if player.components.builder then
        player:SafeListenForEvent("builditem", onbuilditem)
        player:SafeListenForEvent("buildstructure", onbuildstructure)
    end

    if PEARL.DiscordLogger:IsEnabled() and PEARL.CONFIG.LOG_CONSOLE_COMMANDS then
        player:ListenForModEvent("ms_commandexecuted", oncommandexecuted)
    end

    if PEARL.CONFIG.DEBUG_MODE then
        player:SafeListenForEvent("performaction", function(self, buffered, ...)
            PEARL.debug("PERFORMACTION: ", buffered.action, ...)
        end)
    end
end)

PEARL.AddComponentPostInit("combat", function(self)
    -- Wait a tick in order for all the components to be added.
    self.inst:DoTaskInTime(0, function()
        --- Do only track damage dealt by followers and players.
        --- Do not check the leader here since it can be changed later on.
        if not self.inst:HasTag("player") and not self.inst.components.follower then
            return
        end

        self.inst:SafeListenForEvent("onhitother", onhitother)
    end)
end)

PEARL.AddComponentPostInit("finiteuses", function(self)
    self.inst:SafeListenForEvent("percentusedchange", function()
        if not self.inst.components.inventoryitem then
            return
        end

        -- A repairable item was broken.
        if self.current <= 0 then --and self.inst.components.repairable then
            local doer = self.inst.components.inventoryitem.owner
            if not doer or not doer:HasTag("player") then
                doer = nil
            end

            if doer and doer.userid then
                local rarity = math.min(self.inst:GetRarity() + 1, 2)
                PEARL.Reputation:EarnFor(doer.userid, REPUTATIONS.BROKE_REPAIRABLE * rarity)
            end

            local pt = STRINGS.PEARL.ACTIONS.WOREOUT[doer and "DOER" or "GENERIC"]
            AL:EntityAct(pt, doer)
                :SetIcon(PEARL.ICONS.ANNOUNCEMENTS["broke"])
                :SetIsSilent(true)
                :AddTarget(self.inst, 1)
        end
    end)
end)

PEARL.EventProcessor:AddSafeEventHandler("afk_statechanged", onafkstatechanged)

PEARL.EventProcessor:AddSafeEventHandler("playerwarnedforbadrep", function(player)
    PEARL.WallScheduler:ExecuteInTime(0, function()
        PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.WARNED:format(
            player:GetDisplayName()), PEARL.ICONS.WARN
        )
    end)
end)

PEARL.EventProcessor:AddSafeEventHandler("constructionfinished", function(doer, target)
    if doer and doer:HasTag("player") and target then
        onplayerconstructed(doer, target)
    end
end)

--- Maybe remove some reputation when being kicked?
----- Rather not since not every kick is meant to be bad...
--PEARL.EventProcessor:AddSafeEventHandler("clientkicked", onplayerkicked)
