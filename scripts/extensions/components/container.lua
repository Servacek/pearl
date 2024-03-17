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

--- @class Container
local Container = require("components/container")

--------------------------------
-- [[ Getters ]]
--------------------------------

function Container:GetNextEmptySlot()
    for slot = 1, self.numslots do
        if self.slots[slot] == nil then
            return slot
        end
    end
end

function Container:GetSlotForItem(prefab)
    for slot, item in pairs(self.slots) do
        if item.prefab == prefab and item.components.stackable and not item.components.stackable:IsFull() then
            return slot
        end
    end

    return self:GetNextEmptySlot()
end

function Container:GetRareItems()
    local items = {}

    -- Go just one level deep for now
    self:ForEachItem(function(item)
        if item.components.inventoryitem:IsRare() then
            items[#items + 1] = item
        end
    end)

    return items
end

function Container:GetItems()
    local veryrare, items = false, {}
    self:ForEachItem(function(item)
        if item.components.inventoryitem:IsVeryRare() then
            veryrare = true
        end

        items[#items+1] = item
    end)

    return items, veryrare
end

function Container:CountItem(prefab)
    local count = 0

    self:ForEachItem(function(item)
        if item.prefab == prefab then
            count = count + item.components.inventoryitem:GetStackSize()
        end
    end)

    return count
end

--------------------------------
-- [[ Public Functions ]]
--------------------------------

PEARL.AddClassFunctionPostCall("Close", function(self, doer)
    if doer then
        doer:PushModEvent("closedcontainer", self.inst)
    end
end, Container)

-- PEARL.AddClassFunctionPreCall("Open", function(self, doer)
--     if doer then
--         doer:PushModEvent("openedcontainer", self.inst)
--     end
-- end, Container)
