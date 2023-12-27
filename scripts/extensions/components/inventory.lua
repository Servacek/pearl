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
