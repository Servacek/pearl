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

local NEARBY_CHEST_RADIUS = 5

--- <item_name>: <priority>
local DROP_DEPOS = {
    ["firepit"]         = 1,
    ["treasurechest"]   = 2,
    ["dragonflychest"]  = 3, -- More space (also not burnable)

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
    [1] = {"finituses", "heater", "equippable", "fueled"}
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

local _sorted = false

-------------------------------
-- [[ Sorters ]]
-------------------------------

local function sort_depo_by_priority(a, b)
    local priority_a, priority_b = DROP_DEPOS[a.prefab] or 0, DROP_DEPOS[b.prefab] or 0
    if (priority_a > 0 or priority_b > 0) and priority_a ~= priority_b then
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
-- [[ Local Functions ]]
-------------------------------

local function GetSignForContainer(container)
    if container.Transform then
        return GetClosestInstWithTag({"sign", "drawable"}, container, CONTAINER_SIGN_RADIUS)
    end
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
            if not used[depo] and not (container and container:IsFull()) then
                local amount = container and container:CountItem(item.prefab) or 0
                -- if amount <= 0 and SIGNABLE[depo.prefab] == true then
                --     local sign = GetSignForContainer(depo)
                --     if sign and sign.components.drawable then
                --         local prefab = sign.components.drawable.imagename
                --         print("SIGN IMAGE PREFAB", prefab)
                --         if prefab == item.prefab then
                --             amount = 1
                --         end
                --     else
                --         print("NO SIGN ")
                --     end
                -- end

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
            print("ITEM SUCCESSFULLY DEPLOYED!")
            return -- We have managed to add the whole item to the container.
        end

        print("CHECKING DEPO:", depo, item)
        local container = depo.components and depo.components.container
        if not container then
            print("Dropping the item at depo position", item)
            if inventory:DropItem(item, true, true, depo:GetPosition()) then
                item = nil
            end
        elseif container:CanTakeItemInSlot(item) and container:AcceptsStacks() then
            local slot = container:GetSlotForItem(item.prefab)
            print("GOT SLOT:", slot)
            local dest = container:GetItemInSlot(slot)
            if dest and dest.components.stackable then
                print("Adding item to stack...")
                item = dest.components.stackable:Put(item)
            else
                print("Putting the item in the container...")
                item = item.components.inventoryitem:RemoveFromOwner(true)
                if container:GiveItem(item, nil, nil, false) then
                    print("SUCCESS")
                    item = nil
                end
            end
        end
    end

    print("Dropping on the ground...")
    -- If no depo existed for this item.
    inventory:DropItem(item, true, true)
end

function ItemDepositor:DepositAllItems(inventory)
    inventory:ForEachItemSorted(function(item)
        if self:IsItemDepositable(item) then
            self:DepositItem(inventory, item)
        end
    end, sort_item_by_priority)
end

function ItemDepositor:DepositRareItems(inventory, rarity_threshold)
    rarity_threshold = tonumber(rarity_threshold) or 0

    inventory:ForEachItemSorted(function(item)
        if not self:IsItemDepositable(item) then
            return
        end

        if item:GetRarity() > rarity_threshold then
            self:DepositItem(inventory, item)
        end
    end, sort_item_by_rarity)
end

-------------------------------
-- [[ Event Handlers ]]
-------------------------------

local function OnDepoRemove(inst)
    for i = #_depos, 1, -1 do
        if _depos[i].GUID == inst.GUID then
            -- Keeps them sorted
            table.remove(_depos, i)
        end
    end
end

local function OnDepoInit(inst)
    local nearby_chests = inst:GetNearbyEntities(
        NEARBY_CHEST_RADIUS, {"chest", "structure"}, {"burnt", "INLIMBO", "FX"}
    )
    if table.empty(nearby_chests) == false then
        for _, chest in ipairs(nearby_chests) do
            inst.__nerby_chest_count = (inst.__nerby_chest_count or 0) + 1
            chest.__nerby_chest_count = (chest.__nerby_chest_count or 0) + 1
        end

        _depos[#_depos+1] = inst
        table.sort(_depos, sort_depo_by_priority)
    else
        table.insort(_depos, inst, sort_depo_by_priority)
    end

    --ItemDepositor:SortDepos()
    table.foreach(_depos, print)
end

local function OnSignRemove(inst)

end

local function OnSignInit(inst)
    --- @TODO: Handle minisign spawning.
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

            if inst.components.workable and not inst.components.workable:HasBuilder() then
                return -- Special case for naturaly generated chests for example.
            end

            inst:SafeListenForEvent("onremove", OnDepoRemove)
            inst:SafeListenForEvent("onburntup", OnDepoRemove)
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

            inst:SafeListenForEvent("onremove", OnSignRemove)
            inst:SafeListenForEvent("onburntup", OnSignRemove)
            OnSignInit(inst)
        end)
    end)
end

-------------------------------
-- [[ Return ]]
-------------------------------

return ItemDepositor
