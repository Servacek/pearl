--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local PEARL = PEARL
local table, tostring = table, tostring

-----------------------------------
-- [[ Class Declaration ]]
-----------------------------------

-- Make sure the global is declared.
require("entityscript")

--- @class EntityScript
local EntityScript = EntityScript

-----------------------------------
-- [[ Static Variables ]]
-----------------------------------

EntityScript.PREFAB_NAME_OVERRIDES = {}
EntityScript.FN_TO_PCALL = {}

-----------------------------------
-- [[ Member Functions ]]
-----------------------------------

--- Whether this entity is a base structure.
--- WARNING: Doesn't count items that are not built by a player.
--- @return boolean
function EntityScript:IsBaseStructure()
    return self:IsValid()
        and self:HasOneOfTags(PEARL.CONSTS.BASE_STRUCTURE_TAGS)
        and self.components.built ~= nil and self.components.built.doer ~= nil
end

function EntityScript:IsResourcePlant()
    return self:IsValid()
        and self:HasOneOfTags(PEARL.CONSTS.RESOURCE_PLANT_TAGS)
end

function EntityScript:HasComponent(component)
    return self.components[component] ~= nil
end

function EntityScript:HasAnyOfComponents(components)
    if table.empty(self.components) == false then
        for _, component in ipairs(components) do
            if self:HasComponent(component) then
                return true
            end
        end
    end

    return false
end

function EntityScript:HasValidWorldPosition()
    return self.__simulated ~= true and self.Transform ~= nil or false
end

function EntityScript:IsFireProtected()
    return PEARL.IsPosFireProtected(self:GetPosition())
end

function EntityScript:GetNearbyEntities(radius, musttags, canttags, mustoneoftags, filterfn)
    return PEARL.GetEntitiesNearPos(self:GetPosition(),
        radius, musttags,  canttags, mustoneoftags,
        function(ent)
            return ent and (ent.GUID ~= self.GUID) and (not filterfn or filterfn(ent))
        end
    )
end

--- @param filterfn fun(ent: Entity): boolean
function EntityScript:GetPropagableEntities(musttags, canttags, mustoneoftags, filterfn, rad)
    -- For example flares.
    if self.components.propagator and (self.components.propagator.heatoutput or 0) <= 0 then
        return {}
    end

    local radius = self.components.propagator and self.components.propagator.propagaterange
        or rad or PEARL.CONSTS.DEFAULT_PROPAGATOR_RADIUS

    if TheWorld and TheWorld.state and TheWorld.state.isspring then
        radius = radius * TUNING.SPRING_FIRE_RANGE_MOD
    end

    return self:GetNearbyEntities(
        radius,
        musttags,
        canttags,
        mustoneoftags,
        filterfn
    )
end

function EntityScript:GetPropagableBurnableEntities(mustoneoftags, ...)
    return self:GetPropagableEntities(PEARL.CONSTS.BURNABLE_MUST_TAGS, PEARL.CONSTS.BURNABLE_CANT_TAGS, mustoneoftags or {}, ...)
end

--- @return value number
function EntityScript:CalcValueOfNearbyBurnables(mustoneoftags, ...)
    local value = 0
    local burnables = self:GetPropagableBurnableEntities(mustoneoftags, ...)
    for _, burnable in ipairs(burnables) do
        value = value + burnable:GetValue()
    end

    return value
end

function EntityScript:GetRarity()
    local rarity = PEARL.GetRarityForPrefab(self.prefab)
    local recipe = AllRecipes[self.prefab]
    local ingredients = self.components.built and self.components.built.ingredients or (recipe and recipe.ingredients)
    if ingredients then
        for _, ingredient in ipairs(ingredients) do
            rarity = rarity + PEARL.GetRarityForPrefab(ingredient.type) * (ingredient.amount or 1)
        end
    end

    local mult = self.components.built and self.components.built.doer and 2 or 1
    return rarity * mult
end

function EntityScript:GetStandardizedName()
    return PEARL.GetStandardizedNameFor(self)
end

function EntityScript:GetFancyName()
    local stacksize = PEARL.GetStackSize(self)

    local name = self:GetStandardizedName()
    if stacksize and stacksize > 1 then
        return STRINGS.PEARL.LOGS.ITEM:format(
            stacksize, name
        )
    end

    return name
end

function EntityScript:GetUserFlags()
    return self.Network ~= nil and self.Network:GetUserFlags() or 0
end

function EntityScript:GetStateNumber()
    local userflags = self:GetUserFlags()
    local states = {
        USERFLAGS.CHARACTER_STATE_1, USERFLAGS.CHARACTER_STATE_2, USERFLAGS.CHARACTER_STATE_3
    }

    for i, state in ipairs(states) do
        if checkbit(userflags, state) then
            return i
        end
    end

    return 0
end

function EntityScript:GetFancyPrefabName()
    local userflags = self:GetUserFlags()
    local prefabname = tostring(self.prefab)
    if prefabname == "" then
        prefabname = "unknown"
    end

    if checkbit(userflags, USERFLAGS.IS_GHOST) then
        prefabname = "ghost_"..prefabname
    end

    local state_number = self:GetStateNumber()
    if state_number and state_number > 0 then
        prefabname = prefabname.."_"..tostring(state_number)
    end

    return prefabname
end

-----------------------------------
-- [[ Event System Extensions ]]
-----------------------------------

--- Doesn't use the safe version of 'PushEvent' since all
--- mod events should be registered with 'ListenForModEvent'
--- which handles already all the nasty errors for us.
--- Adds the mod's event prefix to the event name.
---
--- @param event string The non-prefixed event name.
--- @param ... any Additional parameters to the 'PushEvent' function.
function EntityScript:PushModEvent(event, ...)
    return self:PushEvent(PEARL.CONSTS.EVENT_PREFIX..event, ...)
end

--- Used for listening to event's pushed by 'PushModEvent'.
--- Uses PEARL.SafeRun to call the event handlers.
--- Adds the mod's event prefix to the event name.
---
--- @param event string The non-prefixed event name.
--- @param ... any Additional parameters to 'SafeListenForEvent'.
function EntityScript:ListenForModEvent(event, ...)
    return self:SafeListenForEvent(PEARL.CONSTS.EVENT_PREFIX..event, ...)
end

--- Uses PEARL.SafeRun to call the event handlers.
---
--- @param event string The event name.
--- @param fn function A reference to the handler function.
--- @param ... any Additional parameters to the handler.
function EntityScript:SafeListenForEvent(event, fn, ...)
    local pfn = function(...) PEARL.SafeRun(fn, ...) end
    EntityScript.FN_TO_PCALL[fn] = pfn
    self:ListenForEvent(event, pfn, ...)

    return pfn -- Return the pcall so we have a reference to that as well.
end

--- @param event string The event name.
--- @param fn function A reference to the handler function.
--- @param delay integer The delay in seconds for the event handler.
--- @param ... any Additional parameters to the handler.
function EntityScript:ListenForEventDelayed(event, fn, delay, ...)
    local dfn = function(...)
        PEARL.WallScheduler:ExecuteInTime(delay or 0, fn, nil, ...)
    end
    self:ListenForEvent(event, dfn, ...)

    return dfn -- Return the delayed function so we have a reference to that as well.
end

--- Uses PEARL.SafeRun to call the event handlers.
--- Do not use for event's registed with 'SafeListenForEvent'.
---
--- @param ... any Additional parameters to the 'PushEvent' function.
function EntityScript:SafePushEvent(...)
    -- Don't forget the 'self' parameter!
    return PEARL.SafeRun(self.PushEvent, TheWorld, ...)
end

function EntityScript:RemoveModEventCallback(event, ...)
    return self:RemoveEventCallback(PEARL.CONSTS.EVENT_PREFIX..event, ...)
end

-----------------------------------
-- [[ Function Extensions ]]
-----------------------------------

--- When an event is added via SafeListenForEvent, the actual reference that is saved
--- is the reference to the newly created function in the protected call.
--- So when we try to intuitively remove it using the original function reference,
--- it won't remove these safe versions.
--- With this extensions, it removes both correctly.
local _RemoveEventCallback --- @type function
_RemoveEventCallback = assert(PEARL.AddClassFunctionPostCall("RemoveEventCallback", function(self, event, fn, ...)
    --PEARL.debug("RemoveEventCallback", _RemoveEventCallback)

    local pfn = EntityScript.FN_TO_PCALL[fn]
    if pfn ~= nil then
        EntityScript.FN_TO_PCALL[fn] = nil -- Time remove this reference as well.

        if type(pfn) == "function" then
            -- A pcall was used as the fn argument so nothing was actually removed
            _RemoveEventCallback(self, event, pfn, ...) -- Really scared of an infinite loop...
        end
    end
end, EntityScript))

if PEARL.CONFIG.PERFORMANCE_MODE then
    --- Do not do this for DoTaskInTime since that's used for growable component.
    --- A better aproach to this would be to make tasks sleepable.
    local _DoPeriodicTask = EntityScript.DoPeriodicTask
    function EntityScript:DoPeriodicTask(time, fn, ...)
        return _DoPeriodicTask(self, time, function(...)
            if self.entity:IsAwake() then
                fn(...)
            end
        end, ...)
    end
end
