
local PEARL = PEARL
local TheSim = TheSim
local table, tostring = table, tostring

-----------------------------------
-- [[ Class Declaration ]]
-----------------------------------

require("entityscript")
local EntityScript = EntityScript

-----------------------------------
-- [[ Member Functions ]]
-----------------------------------

-- TODO: Maybe move these to workable.lua?
function EntityScript:HasBuilder()
    return self.builder     ~= nil
    and self.builder.userid ~= nil
    and self.builder.name   ~= nil
end

function EntityScript:SetBuilder(builder)
    self.builder = builder
end

function EntityScript:GetBuilderName()
    return self:HasBuilder() and tostring(self.builder.name) or "UNKNOWN"
end

function EntityScript:IsBuildBy(userid)
    return userid and self.builder.userid == userid
end

function EntityScript:IsBaseStructure()
    return self:IsValid()
        and self:HasOneOfTags(PEARL.CONSTS.BASE_STRUCTURE_TAGS)
        and self:HasBuilder()
end

function EntityScript:IsResourcePlant()
    return self:IsValid()
        and self:HasOneOfTags(PEARL.CONSTS.RESOURCE_PLANT_TAGS)
end

function EntityScript:IsMonitored()
    return self:IsValid()
        and self.prefab
        and PEARL.MOBS.MONITOR_POPULATION[self.prefab]
end

function EntityScript:GetPropagableEntities(musttags, canttags, mustoneoftags, checkfn)
    local x, y, z = self.Transform:GetWorldPosition()
    if not (x and y and z) then return {} end

    local radius = self.components.propagator and self.components.propagator.propagaterange
        or PEARL.CONSTS.DEFAULT_PROPAGATOR_RADIUS
    PEARL.debug("RADIUS", radius)
    local entities = TheSim:FindEntities(
        x, y, z, radius, musttags, canttags, mustoneoftags
    ) or {}

    return table.filter(entities, function(k, v)
        return v and v.GUID ~= self.GUID and (not checkfn or checkfn(v))
    end)
end

-- Used for lazy debugging
function EntityScript:SafeListenForEvent(event, fn, source)
    self:ListenForEvent(event, function(...)
        PEARL.SafeRun(fn, ...)
    end, source)
end
