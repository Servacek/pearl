--local formatter = require('/tools/formatter')
local G = GLOBAL
local ICONS = G.SUB.ICONS
local prefabs = G.SUB.prefabs

-- CONFIG
local FIRE_RADIUS = GetModConfigData("FIRE_RADIUS")

--------------------------------------------------------
-- Local Helper Functions
--------------------------------------------------------

-- Concatenates two tables into a new table
function table.concatenate(source, target)
    local result = {}

    for _, sv in ipairs(source) do
        table.insert(result, sv)
    end

    for _, tv in ipairs(target) do
        table.insert(result, tv)
    end

    return result
end

local function GetEntitiesNear(center, radius, musttags, canttags, mustoneoftags)
    local x, y, z = center.Transform:GetWorldPosition()
    local results = G.TheSim:FindEntities(x, y, z, radius, musttags, canttags, mustoneoftags)

    -- Removes the center ent
    if results ~= nil then
        for i, ent in ipairs(results) do
            if ent == center then
                table.remove(results, i)
                break
            end
        end
    end

    return results
end

local function GetImportantEnetitiesNear(center, radius)
    local entities = GetEntitiesNear(center, radius, {}, {"burnt", "fire", "wildfireprotected"}, {})
    local near_structures = {}
    local near_plants = {}

    if entities ~= nil then
        for _, ent in ipairs(entities) do
            if ent ~= nil and ((ent:HasTag("structure") or ent:HasTag("wall")) and ent.components.burnable) then
                table.insert(near_structures, ent)
            end

            if ent ~= nil and prefabs.plants[ent.prefab] ~= nil then
                table.insert(near_plants, ent)
            end
        end
    end

    return near_structures, near_plants
end

local function IsImportant(entity)
    return entity ~= nil and entity:IsValid() and (entity:HasTag("structure")
    or entity:HasTag("wall") or prefabs.plants[entity.prefab] ~= nil)
end

local function CountEntities(entities)
    local result = {}
    local lenght = 0

    if entities ~= nil then
        for _, ent in ipairs(entities) do
            if result[ent.prefab] == nil then
                result[ent.prefab] = 1
                lenght = lenght + 1
            else
                result[ent.prefab] = result[ent.prefab] + 1
            end
        end
    end

    return result, lenght
end

local function FormatEntityList(entities)
    local result = ""
    local counted_structs, lenght = CountEntities(entities)
    local index = 1
    local ending = ", "
    local connector = ""

    if entities ~= nil then
        for prefab, count in pairs(counted_structs) do
            local name = G.STRINGS.NAMES[string.upper(prefab)] or entities[index]:GetDisplayName() or "N/A"

            if index == (lenght - 1) or index == lenght then -- if we are one tile before end
                ending = ""
            end

            if index == lenght and lenght > 1 then -- If we are on end of the list
                connector = " a "
            end

            if count > 1 then
                result = result..connector..count.."x "..name..ending
            else
                result = result..connector..name..ending
            end

            index = index + 1
        end
    end

    return result
end

--------------------------------------------------------
-- Event Handlers
--------------------------------------------------------

local function HandleEntityDeath(target, data)
    if target ~= nil and data.afflicter ~= nil
    and target:IsValid() and data.afflicter:IsValid() then
        G.TheNet:Announce(
           data.afflicter:GetDisplayName().." zabil/a "..target:GetDisplayName().."! "..ICONS.DST_EMOTES.HAMBAT
        )
    end
end

local function HandleStructureBurntUp(structure)
    -- if structure ~= nil and structure:IsValid() then
        -- G.TheNet:Announce(
        --     structure:GetDisplayName().." zhorel/a! "..ICONS.DST_EMOTES.FIRE
        -- )
    -- end
end

-- local function HandleNewInvItem(doer, target)
--     if doer ~= nil and target ~= nil and target.item ~= nil and doer:HasTag("player") and
--     prefabs.special_items[target.item.prefab] ~= nil then
--         G.TheNet:Announce(doer.name.." zobral/a "..target.item.name.."! "..ICONS.DST_EMOTES.BACKPACK)
--     end
-- end

--------------------------------------------------------
-- Action Handlers
--------------------------------------------------------

local _ACTION_LIGHT = G.ACTIONS.LIGHT.fn
G.ACTIONS.LIGHT.fn = function(act)
    if act.doer ~= nil and act.target ~= nil and act.doer:IsValid() and act.target:IsValid() then
        local near_structures, near_plants = GetImportantEnetitiesNear(act.target, FIRE_RADIUS)
        local near_entities = table.concatenate(near_structures, near_plants)

        if not IsImportant(act.target) and ((#near_entities == 0) or
        (#near_structures == 0 and #near_plants < 3)) then
            return _ACTION_LIGHT(act)
        end

        local near_entities = table.concatenate(near_structures, near_plants)
        if near_entities ~= nil and #near_entities > 0 then
            G.TheNet:Announce(
                act.doer:GetDisplayName().." zapálil/a "..act.target:GetDisplayName().." pri "..FormatEntityList(near_entities).."! "..ICONS.DST_EMOTES.TORCH
            )
        else
            G.TheNet:Announce(
                act.doer:GetDisplayName().." zapálil/a "..act.target:GetDisplayName().."! "..ICONS.DST_EMOTES.TORCH
            )
        end
    end

    return _ACTION_LIGHT(act)
end

local _ACTION_EAT = G.ACTIONS.EAT.fn
G.ACTIONS.EAT.fn = function(act)
    if act.doer ~= nil and act.invobject ~= nil and act.doer:IsValid() and act.invobject:IsValid()
    and act.doer:HasTag("player") and prefabs.dont_eat[act.invobject.prefab] ~= nil then
        G.TheNet:Announce(
            act.doer:GetDisplayName().." zjedol/la "..act.invobject:GetDisplayName().."! "..ICONS.DST_EMOTES.FAKETEETH
        )
    end

    return _ACTION_EAT(act)
end

local _ACTION_HAMMER = G.ACTIONS.HAMMER.fn
G.ACTIONS.HAMMER.fn = function(act, ...)
    local doer = act.doer
    local target = act.target

    if doer ~= nil and target ~= nil  and doer:IsValid() and target:IsValid()
    and not target:HasTag("burnt") and not target:HasTag("fire") and target:HasTag("structure")
    and target.components and target.components.workable and target.components.workable.workleft <= 1 then
        G.TheNet:Announce(
            doer:GetDisplayName().." rozbil/a "..target:GetDisplayName().."! "..ICONS.DST_EMOTES.HAMMER
        )
    end

    return _ACTION_HAMMER(act, ...)
end

--------------------------------------------------------
-- Post Inits
--------------------------------------------------------

-- MOBS
for k, _ in pairs(prefabs.mobs) do
    AddPrefabPostInit(k, function(inst)
        if not G.TheWorld.ismastersim then
            return
        end

        inst:ListenForEvent("death", HandleEntityDeath)
    end)
end

-- STRUCTURES
for _, ent in ipairs(G.PREFABFILES) do
    AddPrefabPostInit(ent, function(inst)
        if not G.TheWorld.ismastersim or inst == nil or not inst:HasTag("structure") or
        inst:HasTag("burnt") then
            return
        end

        if inst.components.burnable then
            inst:ListenForEvent("burntup", HandleStructureBurntUp)
        end
    end)
end

-- TODO: Should be reworked
-- PLAYERS
-- AddPlayerPostInit(function(inst)
--     inst:ListenForEvent("gotnewitem", HandleNewInvItem)
-- end)