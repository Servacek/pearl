
local PEARL = PEARL
local TheSim = TheSim
local table, tostring = table, tostring

-----------------------------------
-- [[ Class Declaration ]]
-----------------------------------

--require("entityscript")
--- @class EntityScript
local EntityScript = EntityScript

-----------------------------------
-- [[ Member Functions ]]
-----------------------------------

-- TODO: Maybe move these to workable.lua?
-- function EntityScript:HasBuilder()
--     return self.builder     ~= nil
--     and self.builder.userid ~= nil
--     and self.builder.name   ~= nil
-- end

-- function EntityScript:SetBuilder(builder)
--     self.builder = builder
-- end

-- function EntityScript:GetBuilderName()
--     return self:HasBuilder() and tostring(self.builder.name) or "UNKNOWN"
-- end

-- function EntityScript:IsBuildBy(userid)
--     return userid and self.builder.userid == userid
-- end

function EntityScript:IsBaseStructure()
    return self:IsValid()
        and self:HasOneOfTags(PEARL.CONSTS.BASE_STRUCTURE_TAGS)
        and self:HasBuilder()
end

function EntityScript:IsResourcePlant()
    return self:IsValid()
        and self:HasOneOfTags(PEARL.CONSTS.RESOURCE_PLANT_TAGS)
end

function EntityScript:GetPropagableEntities(musttags, canttags, mustoneoftags, checkfn)
    local x, y, z = self.Transform:GetWorldPosition()
    if not (x and y and z) then
        return {}
    end

    local radius = self.components.propagator and self.components.propagator.propagaterange
        or PEARL.CONSTS.DEFAULT_PROPAGATOR_RADIUS

    if TheWorld and TheWorld.state and TheWorld.state.isspring then
        radius = radius * TUNING.SPRING_FIRE_RANGE_MOD
    end

    local entities = TheSim:FindEntities(
        x, y, z, radius, musttags, canttags, mustoneoftags
    ) or {}

    return table.filter(entities, function(k, v)
        return v and v.GUID ~= self.GUID and (not checkfn or checkfn(v))
    end)
end

function EntityScript:GetFancyName()
    local stacksize = PEARL.GetStackSize(self)

    if stacksize and stacksize > 1 then
        return STRINGS.PEARL.LOGS.ITEM:format(
            stacksize, self:GetBasicDisplayName()
        )
    end

    return self:GetBasicDisplayName()
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
    return self:ListenForEvent(event, function(...)
        PEARL.SafeRun(fn, ...)
    end, ...)
end

--- Uses PEARL.SafeRun to call the event handlers.
--- Do not use for event's registed with 'SafeListenForEvent'.
---
--- @param ... any Additional parameters to the 'PushEvent' function.
function EntityScript:SafePushEvent(...)
    return PEARL.SafeRun(self.PushEvent, ...)
end
