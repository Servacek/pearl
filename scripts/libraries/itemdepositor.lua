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
    Checks the content of an inventory when it's owner despawns.
    Logs suspicious intentories to discord.
--]]

if not TheNet:GetIsServer() then
    return -- Server only lib
end

-------------------------------
-- [[ Constants ]]
-------------------------------

local CONTAINER_SIGN_RADIUS = 0.5

local SIGN_MUST_TAGS = {"sign", "drawable"}
local CHEST_MUST_TAGS = {"chest", "structure"}
local CHEST_CANT_TAGS = {"burnt", "INLIMBO", "FX"}

local NEARBY_CHEST_RADIUS = 5
local SIGN_CHEST_RADIUS = 1

--- <item_name>: <priority>
local DROP_DEPOS = {
    -- We should not get this far.
    ["multiplayer_portal"] = -1,
    ["cave_exit"]       = 0,

    ["firepit"]         = 1.01,   -- Usually the center of a base.
    ["coldfirepit"]     = 1.1, -- Can potentially keep perishables more fresh
    ["chester"]         = 1.3, -- Better than on the ground I guess.
    ["backpack"]        = 1.5,
    ["piggyback"]       = 1.6, -- More storage potentially and not burnable
    ["treasurechest"]   = 1.64, -- Burnable but more accessible and common
    ["krampus_sack"]    = 1.65, -- Not burnable + much more storage
    ["spicepack"]       = 1.67, -- This one can hold even non-perishable items.
    ["dragonflychest"]  = 1.69, -- More space (also not burnable) Ideal for rare items
    ["bookstation"]     = 1.699, -- Filter out magic books
    ["seedpouch"]       = 1.7, -- Filter out the seeds
    ["candybag"]        = 1.8, -- Filter out the candies
    ["icepack"]         = 1.9, -- Filter out the food
    ["beargerfur_sack"] = 2, -- Filter out the dishes

    --- Perishable food storage (not burnable as well)
    ["icebox"]          = 4,
    ["saltbox"]         = 4,
}

local SIGNABLE = {
    ["treasurechest"]   = true,
    ["dragonflychest"]  = true,
}

local SIGNS = {
    ["minisign"] = true,
}

local ITEM_TAG_PRIORITY = {
    [1] = {"fresh", "stale", "spoiled"},
    [2] = {"tool"}
}

local ITEM_COMPONENT_PRIORITY = {
    [1] = {"fueled", "waterproofer", "armor"},
    [2] = {"insulator"},
    [3] = {"finituses", "heater", "equippable"},
}

-------------------------------
-- [[ Class Declaration ]]
-------------------------------

--- @class ItemDepositor
local ItemDepositor = {}

-------------------------------
-- [[ Locals ]]
-------------------------------

local _depos = {}

-------------------------------
-- [[ Sorters ]]
-------------------------------

local function sort_depo_by_priority(a, b)
    local priority_a, priority_b = DROP_DEPOS[a.prefab] or 0, DROP_DEPOS[b.prefab] or 0
    if (priority_a ~= 0 or priority_b ~= 0) and priority_a ~= priority_b then
        return priority_a > priority_b
    end

    return (a.__nerby_chest_count or 0) > (b.__nerby_chest_count or 0)
end

local function sort_item_by_rarity(a, b)
    return a:GetRarity() > b:GetRarity()
end

--- if a,b -> true then b,a -> must be false
local function sort_item_by_priority(a, b)
    local rarity_a, rarity_b = a:GetRarity(),b:GetRarity()
    if (rarity_a > 0 or rarity_b > 0) and rarity_a ~= rarity_b then
        -- Rare items first
        return rarity_a > rarity_b
    end

    for _, components in ipairs(ITEM_COMPONENT_PRIORITY) do
        local a_has_comps = a:HasAnyOfComponents(components)
        local b_has_comps = b:HasAnyOfComponents(components)
        if (a_has_comps or b_has_comps) and a_has_comps ~= b_has_comps then
            return a_has_comps
        end
    end

    for _, tags in ipairs(ITEM_TAG_PRIORITY) do
        local a_has_tags, b_has_tags = a:HasOneOfTags(tags), b:HasOneOfTags(tags)
        if (a_has_tags or b_has_tags) and a_has_tags ~= b_has_tags then
            return a_has_tags
        end
    end

    --- For regular items
    return PEARL.GetStackSize(a) > PEARL.GetStackSize(b)
end

-------------------------------
-- [[ Static ]]
-------------------------------

ItemDepositor.SORTBY = {
    PRIORITY = sort_item_by_priority,
    RARITY   = sort_item_by_rarity,
}

-------------------------------
-- [[ Local Functions ]]
-------------------------------

-- local function GetSignForContainer(container)
--     return GetClosestInstWithTag(SIGN_MUST_TAGS, container, SIGN_CHEST_RADIUS)
-- end

local function GetParentContainerForSign(sign)
    return GetClosestInstWithTag(CHEST_MUST_TAGS, sign, SIGN_CHEST_RADIUS)
    -- local nearby_chests = sign:GetNearbyEntities(
    --     SIGN_CHEST_RADIUS, CHEST_MUST_TAGS, CHEST_CANT_TAGS, nil, function(inst)
    --         -- Find an unsigned container
    --         return inst:IsValid() and inst.__sign_prefab == nil
    --     end
    -- )

    -- return nearby_chests[1] ~= sign and nearby_chests[1] or nearby_chests[2]
end

local function GetNearbyContainers(container)
    return container:GetNearbyEntities(
        NEARBY_CHEST_RADIUS, {"chest", "structure"}, {"burnt", "INLIMBO", "FX"}
    )
end

-------------------------------
-- [[ Public Methods ]]
-------------------------------

-- function ItemDepositor:SortDepos()
--     PEARL.debug("ItemDepositor:SortDepos")

--     table.sort(_depos, sort_depo_by_priority)
--     _sorted = true
-- end

function ItemDepositor:GetDepoForItem(item)
    -- Map for marking depos as used.
    local used = {}
    return function()
        local optimal_depo
        -- Optimal amount is calculated for each iteration starting from the previous depo.
        local optimal_amount = -1

        -- Depos are sorted, so the containers are being iterated first.
        for _, depo in ipairs(_depos) do
            -- If there is nothing better to go for.
            if optimal_amount > 0 and not depo.components.container then
                break
            end

            local container = depo.components.container
            if not used[depo] then -- Do not check if we are full here since we may still stack.
                local amount = container and container:CountItem(item.prefab) or 0
                if depo.__sign_prefab == item.prefab then
                    amount = math.huge -- Prioritize signed chests
                end

                if amount > optimal_amount then
                    optimal_amount = amount
                    optimal_depo = depo
                end
            end
        end

        if optimal_depo ~= nil then
            used[optimal_depo] = true
        end

        return optimal_depo
    end
end

function ItemDepositor:IsItemDepositable(item)
    return not item:HasTag("nosteal")
end

function ItemDepositor:DepositItem(inventory, item)
    item.components.inventoryitem:SetLastPicker(nil)
    item.components.inventoryitem:SetLastOwner(nil)
    item.components.inventoryitem:SetLastPlayerOwner(nil)

    local target_prefab = item.prefab
    for depo in self:GetDepoForItem(item) do
        if item == nil then
            return -- We have managed to add the whole item to the container.
        end

        local container = depo.components and depo.components.container
        if not container then
            if inventory:DropItem(item, true, true, depo:GetPosition()) then
                item = nil
            end
        elseif container:CanTakeItemInSlot(item) and container:AcceptsStacks() then
            local slot = container:GetSlotForItem(item.prefab)
            local dest = container:GetItemInSlot(slot)
            if dest and dest.components.stackable then
                item = dest.components.stackable:Put(item)
            else
                item = item.components.inventoryitem:RemoveFromOwner(true)
                if container:GiveItem(item, nil, nil, false) then
                    item = nil
                end
            end
        end
    end

    -- local pos -- Let the function handle the position by default.
    -- local owner = inventory.inst
    -- if not owner or not owner:HasValidWorldPosition() then
    --     pos = owner:GetPosition()
    -- end
    -- If no depo existed for this item.
    inventory:DropItem(item, true, true)
end

function ItemDepositor:DepositAllItems(inventory)
    return inventory:ForEachItemSorted(function(item)
        if self:IsItemDepositable(item) then
            self:DepositItem(inventory, item)
        end
    end, sort_item_by_priority)
end

function ItemDepositor:DepositRareItems(inventory, rarity_threshold)
    rarity_threshold = tonumber(rarity_threshold) or 0

    return inventory:ForEachItemSorted(function(item)
        if item:GetRarity() > rarity_threshold and self:IsItemDepositable(item) then
            self:DepositItem(inventory, item)
        end
    end, sort_item_by_rarity)
end

function ItemDepositor:DepostItemsFromArray(inventory, arr)
    for _, item in ipairs(arr) do
        if self:IsItemDepositable(item) then
            self:DepositItem(inventory, item)
        end
    end
end

-------------------------------
-- [[ Event Handlers ]]
-------------------------------

local function OnDepoRemove(inst)
    for i = #_depos, 1, -1 do
        if _depos[i].GUID == inst.GUID then
            -- Keeps them sorted
            table.remove(_depos, i)

            local nearby_chests = GetNearbyContainers(inst)
            if table.empty(nearby_chests) == false then
                for _, chest in ipairs(nearby_chests) do
                    chest.__nerby_chest_count = (chest.__nerby_chest_count or 0) - 1
                end

                -- Make sure also the nearby chests are being sorted accordingly.
                table.sort(_depos, sort_depo_by_priority)
            end
        end
    end

    inst.__sign_prefab = nil
    inst.__nerby_chest_count = nil
end

local function OnDepoInit(inst)
    local nearby_chests = GetNearbyContainers(inst)
    if table.empty(nearby_chests) == false then
        for _, chest in ipairs(nearby_chests) do
            inst.__nerby_chest_count = (inst.__nerby_chest_count or 0) + 1
            chest.__nerby_chest_count = (chest.__nerby_chest_count or 0) + 1
        end

        _depos[#_depos+1] = inst
        -- Make sure also the nearby chests are being sorted accordingly.
        table.sort(_depos, sort_depo_by_priority)
    else
        table.insort(_depos, inst, sort_depo_by_priority)
    end
end

local function OnSignRemove(sign)
    local parent_chest = sign.__parent_GUID
    if parent_chest ~= nil then
        parent_chest.__sign_prefab = nil
        sign.__parent_GUID = nil
    end
end

local function OnSignDrawn(sign, drawning_prefab)
    --table.foreach(drawning_prefab, print)
    if not PEARL.PrefabExists(drawning_prefab) then
        return -- Drawn some weird image or wrong sign?
    end

    local parent_chest = GetParentContainerForSign(sign)
    if parent_chest ~= nil and parent_chest:IsValid() and parent_chest.__sign_prefab == nil then
        parent_chest.__sign_prefab = drawning_prefab
        sign.__parent_GUID = parent_chest.GUID
    end
end

local function OnSignInit(inst)
    -- Handle already loaded drawnings
    if inst.components.drawable.imagename then
        OnSignDrawn(inst, inst.components.drawable.imagename)
    end

    -- Handle new drawnings
    PEARL.AddClassFunctionPreCall("OnDrawn", function(self, imagename, src)
        OnSignDrawn(inst, (src and src.prefab) or imagename)
    end, inst.components.drawable)
end

-------------------------------
-- [[ Listeners ]]
-------------------------------

for depo_prefab, _ in pairs(DROP_DEPOS) do
    PEARL.AddPrefabPostInit(depo_prefab, function(inst)
        PEARL.WallScheduler:ExecuteInTime(0, function()
            if not inst:IsValid() then
                return
            end

            if not inst.components.built then
                return -- Special case for naturaly generated chests for example.
            end

            if inst.components.inventoryitem and inst.components.inventoryitem:IsHeld() then
                return -- Special case for item depos being held by someone.
            end

            inst:SafeListenForEvent("onremove", OnDepoRemove)
            inst:SafeListenForEvent("onburnt", OnDepoRemove)
            OnDepoInit(inst)
        end)
    end)
end

for sign, _ in pairs(SIGNS) do
    PEARL.AddPrefabPostInit(sign, function(inst)
        PEARL.WallScheduler:ExecuteInTime(0, function()
            if not inst:IsValid() then
                return
            end

            if not inst.components.drawable then
                return
            end

            inst:SafeListenForEvent("onremove", OnSignRemove)
            inst:SafeListenForEvent("onburnt", OnSignRemove)
            OnSignInit(inst)
        end)
    end)
end

-------------------------------
-- [[ Return ]]
-------------------------------

return ItemDepositor
