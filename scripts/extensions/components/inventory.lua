--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--- @TODO: This calculating needs some improvements.

local PEARL = PEARL

local Inventory = require("components/inventory")
local Legality = PEARL.loadfile("components/legality")

-----------------------------------
-- [[ Extension Functions ]]
-----------------------------------

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

function Inventory:DropRareItems(rarity, randomdir, pos)
    -- By default drop only very rare items.
    rarity = rarity or 1

    self:ForEachItem(function(item)
        local item_rarity = PEARL.PREFABS.RARE_ITEMS[item.prefab]
        if item_rarity and item_rarity > rarity then
            self:DropItem(item, true, randomdir, pos)
        end
    end)
end

function Inventory:IsEmpty()
    return table.empty(self.itemslots)
end

-----------------------------------
-- [[ Class Post Construct ]]
-----------------------------------

PEARL.AddClassPostConstruct("components/inventory", function(self)
    self.legality = Legality(self)
end)
