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

-------------------------------
-- [[ Constants ]]
-------------------------------

--- <item_name>: <priority>
local DROP_DEPOS = {
    ["firepit"]         = 1,
    ["treasurechest"]   = 2,
    ["dragonflychest"]  = 3,
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

local function sort_by_priority(a, b)
    return (DROP_DEPOS[a.prefab] or 0) < (DROP_DEPOS[b.prefab] or 0)
end

-------------------------------
-- [[ Public Methods ]]
-------------------------------

function ItemDepositor:SortDepos()
    table.sort(_depos, sort_by_priority)

    _sorted = true
end

function ItemDepositor:GetDepoForItem(item)
    -- Map for marking depos as used.
    local used = {}
    return function()
        local optimal_depo
        -- Optimal amount is calculated for each iteration starting from the previous depo.
        local optimal_amount = -1

        -- Depos are sorted, so the containers are being iterated first.
        for _, depo in ipairs(_depos) do
            if not used[depo] then
                used[depo] = true

                local container = depo.components.container
                local amount = container and container:CountItem(item.prefab) or 0
                if amount > optimal_amount then
                    optimal_amount = amount
                    optimal_depo = depo
                end
            end
        end

        return optimal_depo
    end
end

function ItemDepositor:DepositItem(inventory, item)
    item.components.inventoryitem:RemoveFromOwner()

    if not _sorted then
        print("SORTING DEPOS...")
        self:SortDepos()
    end

    for depo in self:GetDepoForItem(item) do
        if item == nil then
            print("ITEM SUCCESSFULLY DEPLOYED!")
            return -- We have managed to add the whole item to the container.
        end

        print("CHECKING DEPO:", depo)
        local container = depo.components and depo.components.container
        if container and container:CanTakeItemInSlot(item) and container:AcceptsStacks() then
            local slot = container:GetSlotForItem(item.prefab)
            print("GOT SLOT:", slot)
            local dest = container:GetItemInSlot(slot)
            if dest and dest.components.stackable then
                print("Adding item to stack...")
                item = dest.components.stackable:Put(item)
            else
                print("Putting the item in the container...")
                if container:GiveItem(item) then
                    print("SUCCESS")
                    item = nil
                end
            end
        elseif depo.Transform then
            print("Dropping the item at depo position", item)
            if inventory:DropItem(item, true, true, depo:GetPosition()) then
                item = nil
            end
        end
    end

    print("Dropping on the ground...")
    -- If no depo existed for this item.
    inventory:DropItem(item, true, true)
end

function ItemDepositor:DepositAllItems(inventory)
    inventory:ForEachItem(function(item)
        self:DepositItem(inventory, item)
    end)
end

function ItemDepositor:DepositRareItems(inventory, rarity_threshold)
    inventory:ForEachItem(function(item)
        local item_rarity = PEARL.PREFABS.RARE_ITEMS[item.prefab]
        if item_rarity and item_rarity > rarity_threshold then
            self:DepositItem(inventory, item)
        end
    end)
end

-------------------------------
-- [[ Event Handlers ]]
-------------------------------

local function OnDepoRemove(inst)
    for i = #_depos, 1, -1 do
        if _depos[i].GUID == inst.GUID then
            print("REMOVING A DEPO", inst)
            -- Keeps them sorted
            table.remove(_depos, i)
        end
    end
end

local function OnDepoInit(inst)
    print("NEW DEPO ADDED!", inst)
    _depos[#_depos+1] = inst

    _sorted = false
end

-------------------------------
-- [[ Listeners ]]
-------------------------------

for depo_prefab, _ in pairs(DROP_DEPOS) do
    PEARL.AddPrefabPostInit(depo_prefab, function(inst)
        print("OnPrefabPostInit", inst)
        PEARL.WallScheduler:ExecuteInTime(0, function()
            if inst.components.workable and not inst.components.workable:HasBuilder() then
                print("IGNORING NEW DEPO!")
                return -- Special case for naturaly generated chests for example.
            end

            OnDepoInit(inst)

            inst:SafeListenForEvent("onremove", OnDepoRemove)
        end)
    end)
end

-------------------------------
-- [[ Return ]]
-------------------------------

return ItemDepositor
