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

local Inventory = require("components/inventory")

-----------------------------------
-- [[ Extension Functions ]]
-----------------------------------

function Inventory:GetNumberOfItems()
    local num = 0
    for _, item in pairs(self.itemslots) do
        num = num + PEARL.GetStackSize(item)
    end

    return num
end

function Inventory:GetSorted()
    local length = 0
    local result = {}
    self:ForEachItem(function(item)
        if not result[item.prefab] then
            length = length + 1
        end

        result[item.prefab] = (result[item.prefab] or 0) + PEARL.GetStackSize(item)
    end)

    return result, length
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

function Inventory:GiveItemPrefabCount(prefab, count)
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

    return item, count
end

function Inventory:GiveItemPrefabs(items)
    local added, ignored = 0, 0
    for prefab, count in pairs(items) do
        count = tonumber(count)
        if count and self:GiveItemPrefabCount(prefab, count) then
            added = added + count
        else
            ignored = ignored + (count or 1)
        end
    end

    return added, ignored
end
