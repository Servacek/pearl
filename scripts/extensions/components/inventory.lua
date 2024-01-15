--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--- @class Inventory
local Inventory = require("components/inventory")

--- @class InventoryReplica
local InventoryReplica = require("components/inventory_replica")

-----------------------------------
-- [[ Extension Functions ]]
-----------------------------------

function Inventory:GetNumberOfItems()
    local num = 0
    self:ForEachItem(function(item)
        num = num + PEARL.GetStackSize(item)
    end)

    return num
end

function Inventory:CountItemPrefabs()
    local num = 0
    local prefabs = {}
    self:ForEachItem(function(item)
        if item and not prefabs[item.prefab] then
            num = num + 1
            prefabs[item.prefab] = true
        end
    end)

    return num
end

function Inventory:GetAllItems()
    local items = {}
    self:ForEachItem(function(item)
        items[#items + 1] = item
    end)

    return items
end

function Inventory:GetAllItemsSorted(sortfn)
    local items = self:GetAllItems()
    table.sort(items, sortfn)

    return items
end

function Inventory:ForEachItemSorted(fn, sortfn)
    local sorted = self:GetAllItemsSorted(sortfn)
    for _, item in ipairs(sorted) do
        fn(item)
    end

    return sorted
end

function Inventory:GetItemCount(prefab)
    local count = 0

    for _, item in pairs(self.itemslots) do
        if item.prefab == prefab then
            count = count + PEARL.GetStackSize(item)
        end
    end

    for _, item in pairs(self.equipslots) do
        if item.prefab == prefab then
            count = count + PEARL.GetStackSize(item)
        end
    end

    if self.activeitem and self.activeitem.prefab == prefab then
        count = count + PEARL.GetStackSize(self.activeitem)
    end

    local overflow = self:GetOverflowContainer()
    if overflow ~= nil then
        for _, item in pairs(overflow:FindItems(function(item)
            return item.prefab == prefab
        end)) do
            count = count + PEARL.GetStackSize(item)
        end
    end

    return count
end

function Inventory:IsEmpty()
    return table.empty(self.itemslots) == true
end

-- Returns the previous handler if any
function Inventory:AddLeftoversHandler(fn)
    local prev = self.HandleLeftoversFn
    self.HandleLeftoversFn = fn

    return prev
end

function Inventory:GiveItemPrefabCount(prefab, count, drop)
    local leftovers = 0
    local handleleftovers = drop ~= true
    local leftovers_handler
    if handleleftovers then
        leftovers_handler = self:AddLeftoversHandler(function(self, item)
            leftovers = leftovers + PEARL.GetStackSize(item)
        end)
    end

    local item
    local count_left = math.max(count or 1, 1)
    count = count_left
    while count_left > 0 do
        item = SpawnPrefab(prefab)
        if item == nil then
            return
        end

        local maxsize = item.components.stackable and item.components.stackable.maxsize or 1
        -- Between 1 - maxsize
        local stacksize = math.max(math.min(maxsize, count_left), 1)

        if item.components.stackable and stacksize > 1 then
            item.components.stackable:SetStackSize(stacksize)
        end

        self:GiveItem(item)

        count_left = count_left - stacksize
    end

    if handleleftovers then
        -- Restore the previous leftovers handler if any.
        self:AddLeftoversHandler(leftovers_handler)
    end

    return item, count - leftovers
end

function Inventory:GiveItemPrefabs(items, nodrop)
    local total, added = 0, 0
    for prefab, count in pairs(items) do
        count = tonumber(count)
        total = total + (count or 1)
        if count then
            local _, given = self:GiveItemPrefabCount(prefab, count, nodrop)
            added = added + given
        end
    end

    return added, total - added
end

------------------------------

-- PEARL.AddClassFunctionPreCall("SetPickupPos", function(self)
--     if not self.classified then
--         return false
--     end
-- end, InventoryReplica)
